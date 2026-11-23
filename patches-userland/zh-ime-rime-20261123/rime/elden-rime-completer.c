/* SPDX-License-Identifier: GPL-2.0-or-later
 *
 * elden-rime-completer.c — phosh-osk-stub `pipe` completer 的 RIME 客户端（A 方案）
 *
 * 角色：这是 `sm.puri.phosh.osk.Completers.Pipe command` 指向的那个可执行文件。
 *       OSK 每按一键 spawn 它一次，stdin 给完整 preedit，它必须尽快把候选打到
 *       stdout（每行一个）然后退出。
 *
 * 为什么是 C 而不是 python：OSK 每键 spawn，解释器启动就是 40-60 ms 的固定税
 * （现役 python helper 实测热 20 ms 已算好的，但那是同进程索引缓存）；
 * 本客户端 = connect() + write() + read() + exit()，实测 < 2 ms（见报告 §1.6）。
 *
 * 失败语义（重要）：任何错误都**输出一个空行然后 exit 0**。
 *   理由：① 上游在 stdout 为空串时会读 stdout_buf[-1]（pos-completer-pipe.c:305），
 *        零字节输出是 UB；② 候选为空时 OSK 只是不显示候选条，不影响打字。
 *
 * 用法：
 *   elden-rime-completer                 # OSK 用（stdin=preedit）
 *   elden-rime-completer --selftest      # 不连 socket，只验证自身（打印 0 个候选）
 *   ELDEN_RIME_SOCK=/path elden-rime-completer <nihao>
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/un.h>
#include <unistd.h>

#include "rime-ipc.h"

#define CLIENT_TIMEOUT_MS 400 /* 守护端预算：热路径应 <20 ms；慢于此走"本轮无候选" */
#define MAX_CANDIDATES    16

static int g_debug;

static void dbg(const char *fmt, ...)
{
    va_list ap;
    if (!g_debug)
        return;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
}

/* 读满 stdin（OSK 用 g_subprocess_communicate_utf8_async 写完即关管道） */
static char *read_stdin(void)
{
    char buf[ELDEN_RIME_MAX_LINE + 1];
    size_t n = 0, got;

    while (n < ELDEN_RIME_MAX_LINE &&
           (got = fread(buf + n, 1, ELDEN_RIME_MAX_LINE - n, stdin)) > 0)
        n += got;

    /* 去掉尾部的 \r\n 与空白：preedit 本身不会以空白结束（分隔符会走 commit 路径） */
    while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == '\r' || buf[n - 1] == ' '))
        n--;
    buf[n] = '\0';
    return strdup(buf);
}

/* 输出 0 个候选（= 一个空行，见头注释）并正常退出 */
static void reply_none(void)
{
    if (fputs("\n", stdout) == EOF)
        dbg("write stdout failed\n");
    fflush(stdout);
}

static int connect_daemon(char *path, size_t plen)
{
    struct sockaddr_un sa;
    struct timeval tv = { CLIENT_TIMEOUT_MS / 1000, (CLIENT_TIMEOUT_MS % 1000) * 1000 };
    int fd;

    elden_rime_sock_path(path, plen);
    if (strlen(path) >= sizeof(sa.sun_path)) {
        dbg("socket path too long: %s\n", path);
        return -1;
    }

    memset(&sa, 0, sizeof(sa));
    sa.sun_family = AF_UNIX;
    memcpy(sa.sun_path, path, strlen(path) + 1);

    fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0)
        return -1;
    if (connect(fd, (struct sockaddr *)&sa, sizeof(sa)) < 0) {
        dbg("connect %s: %s\n", path, strerror(errno));
        close(fd);
        return -1;
    }
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
    return fd;
}

int main(int argc, char **argv)
{
    char path[108];
    char line[ELDEN_RIME_MAX_LINE + 2];
    char preedit[ELDEN_RIME_MAX_LINE + 1];
    FILE *f = NULL;
    char *in = NULL;
    size_t used = 0;
    int fd, n_cand = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--selftest") == 0) {
            reply_none();
            return 0;
        }
        if (strcmp(argv[i], "--debug") == 0) {
            g_debug = 1;
            continue;
        }
        fprintf(stderr, "usage: %s [--debug] [--selftest]\n", argv[0]);
        return 2;
    }
    if (getenv("ELDEN_RIME_DEBUG"))
        g_debug = 1;

    /* 别被 OSK 的 SIGTERM 变成"零字节输出"（UB 见头注释） */
    signal(SIGPIPE, SIG_IGN);

    in = read_stdin();
    if (in[0] == '\0') {
        free(in);
        reply_none();
        return 0;
    }

    fd = connect_daemon(path, sizeof(path));
    if (fd < 0) {
        /* 守护没起：静默退化为"无候选"——英文补全/手打汉字仍可用 */
        free(in);
        reply_none();
        return 0;
    }

    used = strlen(in);
    memcpy(preedit, in, used);
    preedit[used++] = '\n';
    free(in);

    if (write(fd, preedit, used) != (ssize_t)used) {
        dbg("write request failed: %s\n", strerror(errno));
        close(fd);
        reply_none();
        return 0;
    }

    f = fdopen(fd, "r");
    if (f == NULL) {
        close(fd);
        reply_none();
        return 0;
    }

    while (fgets(line, sizeof(line), f) != NULL) {
        size_t l = strlen(line);
        if (l && line[l - 1] == '\n')
            line[--l] = '\0';
        if (l == 0) /* 空行 = 响应结束 */
            break;
        if (n_cand >= MAX_CANDIDATES)
            continue;
        fputs(line, stdout);
        fputc('\n', stdout);
        n_cand++;
    }
    fclose(f);

    if (n_cand == 0)
        reply_none();
    else
        fflush(stdout);

    dbg("replied %d candidate(s)\n", n_cand);
    return 0;
}
