/* SPDX-License-Identifier: GPL-2.0-or-later
 *
 * librime-piped.c — 常驻 RIME 守护进程（A 方案：零修改 phosh-osk-stub）
 *
 * 职责：
 *   持有一个 librime session，把 OSK 每次按键送来的 preedit 增量喂给 RIME，
 *   再把 RIME 的候选按 `pipe` completer 协议吐给薄客户端。
 *
 * 关键设计（为什么这样做，见 reports/ime-rime-backend-20261123.md §1.4）：
 *  1) **增量喂键而不是每次重放**：OSK 只给"当前完整 preedit"，不给键序列。
 *     于是维护 `fed`（已经喂进 session 的 preedit 快照），每次请求比较新旧：
 *       - 追加   → 只把新增字符 process_key 进去（1 次调用/键）
 *       - 缩短   → 发 XK_BackSpace（RIME 自己会退一格组字状态）
 *       - 其它   → RimeClearSession + 全量重放（光标跳转/换词等罕见路径）
 *     这样"n→ni→nih→niha→nihao"是 5 次 process_key，而不是 15 次；
 *     backspace 也走 RIME 原生语义（会正确撤销一个音节）。
 *  2) **一次连接一问一答**：OSK 每键 spawn 一个客户端，客户端连上来发一行、
 *     读若干行、关掉；守护端是单线程 poll 循环，按键本身在 OSK 侧就是串行的。
 *  3) **--oneshot**：不起 socket，直接算一次候选并退出 —— 供 verify 脚本与
 *     bench 用（`librime-piped --oneshot nihao`），也是"没有 OSK 也能判据"的关键。
 *
 * 用法：
 *   librime-piped [options]
 *     --socket PATH        监听路径（默认 $XDG_RUNTIME_DIR/elden-rime.sock）
 *     --shared-data DIR    RIME 共享数据（默认 /usr/share/rime-data）
 *     --user-data DIR      用户数据/编译产物（默认 $XDG_DATA_HOME/elden-rime）
 *     --schema ID          默认 luna_pinyin_simp
 *     --limit N            最多返回 N 个候选（默认 9；OSK 候选条宽度有限）
 *     --oneshot PREEDIT    不起 socket，打印候选后退出（判据/bench 用）
 *     --idle-exit SEC      空闲 SEC 秒后退出（默认 0=不退出；user unit 里配 1800）
 *     --verbose
 *   退出码：0 正常；1 librime 初始化失败；2 参数错误。
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <poll.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>

#include <rime_api.h>

#include "rime-ipc.h"

#define XK_BACKSPACE 0xff08
#define MAX_CANDIDATES 32

/* librime >= 1.6 不再导出扁平 C 符号（nm -D 只有 RimeFindModule/RimeRegisterModule），
 * 唯一入口是 rime_get_api() 返回的版本化函数表 ⇒ 这里用一层薄宏，源码读起来仍像老 API。 */
static RimeApi *g_api;
#define RIME_SETUP(t)            g_api->setup((t))
#define RIME_INIT(t)             g_api->initialize((t))
#define RIME_FINALIZE()          g_api->finalize()
#define RIME_START_MAINT(full)   g_api->start_maintenance((full))
#define RIME_JOIN_MAINT()        g_api->join_maintenance_thread()
#define RIME_NEW_SESSION()       g_api->create_session()
#define RIME_DROP_SESSION(s)     g_api->destroy_session((s))
#define RIME_CLEAR_COMPOSITION(s) g_api->clear_composition((s))
#define RIME_PROCESS_KEY(s, k, m) g_api->process_key((s), (k), (m))
#define RIME_GET_CONTEXT(s, c)   g_api->get_context((s), (c))
#define RIME_FREE_CONTEXT(c)     g_api->free_context((c))
#define RIME_SELECT_SCHEMA(s, id) g_api->select_schema((s), (id))
#define RIME_SET_OPTION(s, o, v) g_api->set_option((s), (o), (v))

static RimeSessionId g_sid = 0;
static char *g_fed;              /* 已喂进 session 的 preedit 快照 */
static int g_limit = 9;
static int g_verbose;
static int g_simplify = 1;
static const char *g_schema = "luna_pinyin_simp";

static void logmsg(const char *fmt, ...)
{
    va_list ap;
    struct timespec ts;

    if (!g_verbose)
        return;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    fprintf(stderr, "[%ld.%03ld] ", (long)ts.tv_sec, ts.tv_nsec / 1000000);
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fputc('\n', stderr);
}

/* ---------------------------------------------------------------- librime 喂键 */

/* 把一个 UTF-8 字符喂给 RIME：ASCII 直接用字节值（= keysym），其它用码位。 */
static void feed_char(const char *c)
{
    unsigned char b = (unsigned char)c[0];
    int keycode;

    if (b < 0x80) {
        keycode = b;
    } else {
        /* 非 ASCII：解 1 个码位当 keysym 传（luna_pinyin 用不到，防御性处理） */
        unsigned cp = 0;
        int n = 1;
        if ((b & 0xE0) == 0xC0) { cp = b & 0x1F; n = 2; }
        else if ((b & 0xF0) == 0xE0) { cp = b & 0x0F; n = 3; }
        else if ((b & 0xF8) == 0xF0) { cp = b & 0x07; n = 4; }
        else { cp = b; n = 1; }
        for (int i = 1; i < n && c[i]; i++)
            cp = (cp << 6) | (c[i] & 0x3F);
        keycode = (int)cp;
    }
    RIME_PROCESS_KEY(g_sid, keycode, 0);
}

/* 把 [from, to) 区间（按字符边界）逐个喂进去 */
static void feed_range(const char *s, size_t from, size_t to)
{
    for (size_t i = from; i < to; i++) {
        unsigned char b = (unsigned char)s[i];
        if (b >= 0x80 && (b & 0xC0) == 0x80) /* 续字节：随前导字节一起喂过了 */
            continue;
        feed_char(s + i);
    }
}

/* 指针落在字符边界上 */
static size_t back_to_boundary(const char *s, size_t i)
{
    while (i > 0 && ((unsigned char)s[i] & 0xC0) == 0x80)
        i--;
    return i;
}

static void set_fed(const char *pre)
{
    free(g_fed);
    g_fed = strdup(pre);
}

/* 核心：让 session 的状态对齐到 preedit 字符串 */
static void feed_preedit(const char *pre)
{
    size_t lp = strlen(pre);
    size_t lf = g_fed ? strlen(g_fed) : 0;

    if (g_fed && lp == lf && strncmp(g_fed, pre, lp) == 0)
        return; /* 状态已对齐 */

    if (g_fed && lp > lf && strncmp(g_fed, pre, lf) == 0) {
        feed_range(pre, lf, lp);           /* 追加：只喂新增 */
        set_fed(pre);
        return;
    }

    if (g_fed && lp < lf && strncmp(g_fed, pre, lp) == 0) {
        /* 缩短：按"删掉几个字符"发 BackSpace（RIME 自己退音节） */
        int nchars = 0;
        for (size_t i = lf; i > lp; i = back_to_boundary(g_fed, i - 1))
            nchars++;
        for (int i = 0; i < nchars; i++)
            RIME_PROCESS_KEY(g_sid, XK_BACKSPACE, 0);
        set_fed(pre);
        return;
    }

    /* 分叉/换词：整体重放 */
    logmsg("replay session for '%s' (was '%s')", pre, g_fed ? g_fed : "");
    RIME_CLEAR_COMPOSITION(g_sid);
    feed_range(pre, 0, lp);
    set_fed(pre);
}

/* ------------------------------------------------------------------ 取候选 */

/* 返回候选数；cand 由调用者缓冲（最多 MAX_CANDIDATES 条，strdup 后使用） */
static int collect(const char *pre, char **cand, int max)
{
    RIME_STRUCT(RimeContext, ctx);
    int n = 0;

    if (*pre == '\0') {
        RIME_CLEAR_COMPOSITION(g_sid); /* 词已提交：清空组字状态 */
        set_fed("");
        return 0;
    }

    feed_preedit(pre);

    if (!RIME_GET_CONTEXT(g_sid, &ctx)) {
        logmsg("get_context failed");
        return 0;
    }

    for (int i = 0; i < ctx.menu.num_candidates && n < max; i++) {
        const char *t = ctx.menu.candidates[i].text;
        if (t == NULL || *t == '\0')
            continue;
        if (strcmp(t, pre) == 0) /* RIME 会把原串当第 0 个候选，OSK 侧不需要 */
            continue;
        cand[n++] = strdup(t);
    }

    logmsg("'%s' -> %d candidate(s), rime preedit='%s'", pre, n,
           ctx.composition.preedit ? ctx.composition.preedit : "");
    RIME_FREE_CONTEXT(&ctx);
    return n;
}

/* ------------------------------------------------------------------ 初始化 */

static int rime_start(const char *shared, const char *user)
{
    RimeTraits t;

    g_api = rime_get_api();
    if (g_api == NULL) {
        fprintf(stderr, "librime-piped: rime_get_api() returned NULL\n");
        return -1;
    }

    memset(&t, 0, sizeof(t));
    RIME_STRUCT_INIT(RimeTraits, t);
    t.shared_data_dir = shared;
    t.user_data_dir = user;
    t.distribution_name = "Elden";
    t.distribution_code_name = "elden-rime-piped";
    t.distribution_version = "1.0";
    t.app_name = "rime.elden";
    t.min_log_level = g_verbose ? 1 : 2;
    t.log_dir = ""; /* 只写 stderr（交给 journald/unit 的 StandardError） */

    RIME_SETUP(&t);
    RIME_INIT(&t);
    if (RIME_START_MAINT(True))       /* 首次运行会部署/编译词库，可能数秒 */
        RIME_JOIN_MAINT();

    g_sid = RIME_NEW_SESSION();
    if (!g_sid) {
        fprintf(stderr, "librime-piped: create_session failed\n");
        return -1;
    }
    if (g_schema && *g_schema && !RIME_SELECT_SCHEMA(g_sid, g_schema))
        fprintf(stderr, "librime-piped: schema '%s' not available, using default\n", g_schema);
    if (g_simplify)
        RIME_SET_OPTION(g_sid, "simplification", True); /* luna_pinyin → 简体输出 */

    set_fed("");
    return 0;
}

/* ----------------------------------------------------------------- 传输层 */

static int listen_on(const char *path)
{
    struct sockaddr_un sa;
    int fd;

    if (strlen(path) >= sizeof(sa.sun_path)) {
        fprintf(stderr, "librime-piped: socket path too long: %s\n", path);
        return -1;
    }
    memset(&sa, 0, sizeof(sa));
    sa.sun_family = AF_UNIX;
    memcpy(sa.sun_path, path, strlen(path) + 1);

    fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0) {
        perror("socket");
        return -1;
    }
    unlink(path); /* 陈旧 socket */
    if (bind(fd, (struct sockaddr *)&sa, sizeof(sa)) < 0) {
        perror("bind");
        close(fd);
        return -1;
    }
    chmod(path, 0600);
    if (listen(fd, 16) < 0) {
        perror("listen");
        close(fd);
        return -1;
    }
    return fd;
}

/* 处理一条连接：读一行请求，写候选，写空行，关连接 */
static void serve_conn(int cfd)
{
    char req[ELDEN_RIME_MAX_LINE + 2];
    size_t n = 0;
    char *cand[MAX_CANDIDATES] = { 0 };
    int n_cand;

    while (n < ELDEN_RIME_MAX_LINE) {
        ssize_t r = read(cfd, req + n, 1);
        if (r <= 0)
            break;
        if (req[n] == '\n')
            break;
        n++;
    }
    req[n] = '\0';

    n_cand = collect(req, cand, g_limit);

    for (int i = 0; i < n_cand; i++) {
        dprintf(cfd, "%s\n", cand[i]);
        free(cand[i]);
    }
    dprintf(cfd, "\n"); /* 终止空行 */
}

/* --------------------------------------------------------------------- main */

static void usage(const char *p)
{
    fprintf(stderr,
            "usage: %s [--socket PATH] [--shared-data DIR] [--user-data DIR] [--schema ID]\n"
            "          [--limit N] [--oneshot PREEDIT] [--idle-exit SEC] [--verbose]\n", p);
}

int main(int argc, char **argv)
{
    static const struct option opts[] = {
        { "socket",      required_argument, NULL, 's' },
        { "shared-data", required_argument, NULL, 'd' },
        { "user-data",   required_argument, NULL, 'u' },
        { "schema",      required_argument, NULL, 'S' },
        { "limit",       required_argument, NULL, 'l' },
        { "oneshot",     required_argument, NULL, 'o' },
        { "idle-exit",   required_argument, NULL, 'i' },
        { "verbose",     no_argument,       NULL, 'v' },
        { "help",        no_argument,       NULL, 'h' },
        { NULL, 0, NULL, 0 },
    };
    char sock_path[108] = { 0 };
    const char *shared = "/usr/share/rime-data";
    const char *user = NULL;
    const char *oneshot = NULL;
    char user_buf[512];
    int idle_exit = 0;
    int lfd, c;
    time_t last_activity;

    while ((c = getopt_long(argc, argv, "s:d:u:S:l:o:i:vh", opts, NULL)) != -1) {
        switch (c) {
        case 's': snprintf(sock_path, sizeof(sock_path), "%s", optarg); break;
        case 'd': shared = optarg; break;
        case 'u': user = optarg; break;
        case 'S': g_schema = optarg; break;
        case 'l': g_limit = atoi(optarg); break;
        case 'o': oneshot = optarg; break;
        case 'i': idle_exit = atoi(optarg); break;
        case 'v': g_verbose = 1; break;
        default: usage(argv[0]); return c == 'h' ? 0 : 2;
        }
    }
    if (g_limit < 1) g_limit = 1;
    if (g_limit > MAX_CANDIDATES) g_limit = MAX_CANDIDATES;

    if (user == NULL) {
        const char *xdg = getenv("XDG_DATA_HOME");
        const char *home = getenv("HOME");
        if (xdg && *xdg)
            snprintf(user_buf, sizeof(user_buf), "%s/elden-rime", xdg);
        else
            snprintf(user_buf, sizeof(user_buf), "%s/.local/share/elden-rime",
                     home ? home : "/tmp");
        user = user_buf;
    }
    mkdir(user, 0700);

    if (rime_start(shared, user) != 0)
        return 1;

    if (oneshot) {
        char *cand[MAX_CANDIDATES] = { 0 };
        int n = collect(oneshot, cand, g_limit);
        for (int i = 0; i < n; i++) {
            printf("%s\n", cand[i]);
            free(cand[i]);
        }
        free(g_fed);
        RIME_DROP_SESSION(g_sid);
        RIME_FINALIZE();
        return n > 0 ? 0 : 3; /* 3 = 有 preedit 但 0 候选（判据用） */
    }

    if (sock_path[0] == '\0')
        elden_rime_sock_path(sock_path, sizeof(sock_path));

    lfd = listen_on(sock_path);
    if (lfd < 0) {
        RIME_FINALIZE();
        return 1;
    }
    signal(SIGPIPE, SIG_IGN);
    logmsg("listening on %s (shared=%s user=%s schema=%s limit=%d)",
           sock_path, shared, user, g_schema, g_limit);

    last_activity = time(NULL);
    for (;;) {
        struct pollfd pfd = { .fd = lfd, .events = POLLIN };
        int timeout = idle_exit > 0 ? 1000 : -1;
        int r = poll(&pfd, 1, timeout);

        if (r < 0) {
            if (errno == EINTR)
                continue;
            perror("poll");
            break;
        }
        if (r == 0) { /* idle */
            if (idle_exit > 0 && time(NULL) - last_activity >= idle_exit) {
                logmsg("idle for %ds, exiting", idle_exit);
                break;
            }
            continue;
        }
        if (pfd.revents & POLLIN) {
            int cfd = accept4(lfd, NULL, NULL, SOCK_CLOEXEC);
            if (cfd >= 0) {
                serve_conn(cfd);
                close(cfd);
                last_activity = time(NULL);
            }
        }
    }

    close(lfd);
    unlink(sock_path);
    RIME_DROP_SESSION(g_sid);
    RIME_FINALIZE();
    free(g_fed);
    return 0;
}
