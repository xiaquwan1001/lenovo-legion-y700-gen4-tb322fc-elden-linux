/*
 * eldroid-sensord — 传感器数据源 daemon（C4，宿主侧）
 *
 * 背景：Waydroid 镜像里的 sensors HAL（android.hardware.sensors@1.0-service.waydroid）
 * 原版是 stub（getSensorsList 返回空）；我们把 hardware/waydroid/sensors/Sensors.cpp
 * 实现成「UDP 收值 → 喂 Android framework」。本程序是宿主侧的**值来源**：
 *   - --fake       内置轨迹生成器（旋转/陀螺/光照，兜底纯软件）
 *   - --stdin      逐行读文本协议（来自 Termux 转发器 / 测试脚本 / 真机 UDP 中继）
 * 并经 UDP 发给容器（HAL 监听 0.0.0.0:52012；容器与宿主经 waydroid0 网桥互通）。
 *
 * 文本行协议（人类可调试，nc/echo 可直接发）：
 *   acc <x> <y> <z>     加速度计 m/s²
 *   gyr <x> <y> <z>     陀螺仪 rad/s
 *   mag <x> <y> <z>     磁力计 µT
 *   light <v>           环境光 lux
 *   prox <v>            接近距离 cm（0=近）
 *
 * 用法：
 *   eldroid-sensord --send <host> [--port 52012] [--fake] [--rate 50] [--stdin]
 *   eldroid-sensord --fake                     # 干跑：只打印要发的行
 *   eldroid-sensord --selftest                 # 冒烟：解析样例 + 轨迹样本（qemu 可跑）
 *   cat values.txt | eldroid-sensord --send 192.168.240.2 --stdin
 *
 * 真值来源（设计，ANDROID-COMPAT.md §2①）：
 *   首选同型号另一单元的 a 槽 Android（Termux:API 转发，见
 *   env-pass/scripts/sensor-send-termux.sh），备选其他安卓设备，兜底 --fake。
 *
 * 编译：scripts/build-sensord.sh（native + aarch64 static）
 */
#define _POSIX_C_SOURCE 200809L
#define _DEFAULT_SOURCE
#include <arpa/inet.h>
#include <inttypes.h>
#include <math.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define DEF_PORT   52012
#define DEF_RATE_MS 50
#define LINE_MAX_   256

static volatile sig_atomic_t g_stop = 0;
static void on_int(int s) { (void)s; g_stop = 1; }

static uint64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

static void logf_(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    fputs("[eldroid-sensord] ", stderr);
    vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);
    va_end(ap);
}

/* ---------- 协议解析 ---------- */

/* 解析一行文本协议；成功返回 1 并填 type(短名)与最多 3 个值 */
static int parse_line(const char *line, char *type, float *v, int *nv) {
    char t[16] = {0};
    float a = 0, b = 0, c = 0;
    v[0] = v[1] = v[2] = 0;
    if (sscanf(line, " %15s %f %f %f", t, &a, &b, &c) < 2) return 0;
    if (!strcmp(t, "acc") || !strcmp(t, "gyr") || !strcmp(t, "mag")) {
        strcpy(type, t); v[0] = a; v[1] = b; v[2] = c; *nv = 3; return 1;
    }
    if (!strcmp(t, "light") || !strcmp(t, "prox")) {
        strcpy(type, t); v[0] = a; *nv = 1; return 1;
    }
    return 0;
}

/* Termux termux-sensor 的 JSON 行 → 文本协议（仅单行内嵌 values 数组，手写不引库） */
static int parse_termux_json(const char *line, char *type, float *v, int *nv) {
    const char *p;
    const char *map[][2] = {
        {"Accelerometer", "acc"}, {"Gyroscope", "gyr"},
        {"Magnetic", "mag"}, {"Light", "light"}, {"Proximity", "prox"},
    };
    p = strstr(line, "\"sensor\"");
    if (!p) return 0;
    int i, hit = -1;
    v[0] = v[1] = v[2] = 0;
    for (i = 0; i < 5; i++) if (strstr(line, map[i][0])) { hit = i; break; }
    if (hit < 0) return 0;
    p = strstr(line, "\"values\"");
    if (!p) return 0;
    p = strchr(p, '[');
    if (!p) return 0;
    p++;
    strcpy(type, map[hit][1]);
    *nv = 0;
    while (*nv < 3) {
        char *end;
        float f = strtof(p, &end);
        if (end == p) break;
        v[(*nv)++] = f;
        p = strchr(end, ',');
        if (!p) break;
        p++;
    }
    return *nv > 0;
}

/* ---------- UDP 输出 ---------- */

struct sink {
    int fd;                 /* -1 = 干跑（打印） */
    struct sockaddr_in addr;
    int verbose;
};

static void sink_send(struct sink *s, const char *line) {
    if (s->fd < 0) {
        if (s->verbose) fputs(line, stdout);
        return;
    }
    sendto(s->fd, line, strlen(line), 0,
           (struct sockaddr *)&s->addr, sizeof(s->addr));
}

static void sink_line(struct sink *s, const char *type, const float *v, int nv, uint64_t ts) {
    char buf[LINE_MAX_];
    if (nv == 3)
        snprintf(buf, sizeof buf, "%s %.6f %.6f %.6f %" PRIu64 "\n",
                 type, v[0], v[1], v[2], ts);
    else
        snprintf(buf, sizeof buf, "%s %.6f %" PRIu64 "\n", type, v[0], ts);
    sink_send(s, buf);
}

/* ---------- --fake 内置轨迹（兜底纯软件） ---------- */

static void fake_emit(struct sink *s, uint64_t t_ns) {
    const double PI2 = 6.283185307179586;
    double t = (double)t_ns / 1e9;
    /* 竖直绕 Y 轴 8 s 一整圈的倾斜：地图旋转/水平仪都有连续变化 */
    float acc[3] = {
        (float)(9.81 * 0.9 * sin(PI2 * t / 8.0)),
        0.0f,
        (float)(9.81 * 0.9 * cos(PI2 * t / 8.0) + 0.981),
    };
    float gyr[3] = {
        (float)(0.05 * sin(PI2 * t / 4.0)),
        (float)(0.3 * PI2 / 8.0),           /* 绕 Y 匀速 */
        (float)(0.05 * cos(PI2 * t / 4.0)),
    };
    float mag[3] = { 42.0f, 5.0f, 28.0f };
    float light = (float)(300.0 + 150.0 * (1.0 + sin(PI2 * t / 12.0)));
    uint64_t ts = now_ns();
    sink_line(s, "acc", acc, 3, ts);
    sink_line(s, "gyr", gyr, 3, ts);
    sink_line(s, "mag", mag, 3, ts);
    sink_line(s, "light", &light, 1, ts);
}

/* ---------- main ---------- */

static int run_selftest(void) {
    static const char *samples[] = {
        "acc 0.12 -0.31 9.79",
        "gyr 0.001 0.235 0.000",
        "mag 42.5 0.0 28.1",
        "light 350.0",
        "prox 5.0",
        "{\"sensor\":\"Accelerometer Sensor\",\"values\":[1.5,-2.25,9.8],\"timestamp\":123}",
        "{\"sensor\":\"Light Sensor\",\"values\":[220.0]}",
        "bogus line without type",
        "unknown 1 2 3",
    };
    int ok = 0, i;
    for (i = 0; i < (int)(sizeof samples / sizeof samples[0]); i++) {
        char type[16]; float v[3]; int nv = 0;
        int r = parse_line(samples[i], type, v, &nv);
        if (!r) r = parse_termux_json(samples[i], type, v, &nv);
        if (r) {
            printf("selftest: %-2s [%g %g %g] nv=%d  <= %s\n",
                   type, v[0], v[1], nv > 2 ? v[2] : 0.0f, nv, samples[i]);
            ok++;
        } else {
            printf("selftest: (rejected)                     <= %s\n", samples[i]);
        }
    }
    /* 轨迹生成器样本 */
    struct sink s = { .fd = -1, .verbose = 1 };
    printf("selftest: fake trajectory samples:\n");
    uint64_t base = 1000000000ull;
    int k;
    for (k = 0; k < 3; k++) fake_emit(&s, base + (uint64_t)k * 500000000ull);
    printf("selftest: %d/7 lines parsed OK\n", ok);
    return ok == 7 ? 0 : 1;
}

int main(int argc, char **argv) {
    const char *host = NULL;
    int port = DEF_PORT, rate_ms = DEF_RATE_MS;
    int fake = 0, use_stdin = 0, selftest = 0;
    int i;

    for (i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--send") && i + 1 < argc) host = argv[++i];
        else if (!strcmp(argv[i], "--port") && i + 1 < argc) port = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--rate") && i + 1 < argc) rate_ms = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--fake")) fake = 1;
        else if (!strcmp(argv[i], "--stdin")) use_stdin = 1;
        else if (!strcmp(argv[i], "--selftest")) selftest = 1;
        else if (!strcmp(argv[i], "-h") || !strcmp(argv[i], "--help")) {
            printf("usage: %s [--send host] [--port N] [--rate ms] [--fake] [--stdin] [--selftest]\n", argv[0]);
            return 0;
        } else { logf_("unknown arg: %s", argv[i]); return 2; }
    }
    if (selftest) return run_selftest();
    if (!fake && !use_stdin) { logf_("nothing to do: pass --fake and/or --stdin"); return 2; }

    struct sink s = { .fd = -1, .verbose = 1 };
    if (host) {
        memset(&s.addr, 0, sizeof s.addr);
        s.addr.sin_family = AF_INET;
        s.addr.sin_port = htons((uint16_t)port);
        if (inet_pton(AF_INET, host, &s.addr.sin_addr) != 1) {
            logf_("bad host: %s (use dotted IP)", host); return 2;
        }
        s.fd = socket(AF_INET, SOCK_DGRAM, 0);
        if (s.fd < 0) { logf_("socket failed"); return 1; }
        s.verbose = 0;
        logf_("sending to udp://%s:%d (fake=%d stdin=%d rate=%dms)",
              host, port, fake, use_stdin, rate_ms);
    } else {
        logf_("dry run (no --send); printing lines to stdout");
    }

    signal(SIGINT, on_int);
    signal(SIGTERM, on_int);

    if (fake) {
        uint64_t start = now_ns();
        while (!g_stop) {
            fake_emit(&s, now_ns() - start);
            usleep((useconds_t)rate_ms * 1000);
        }
    }
    if (use_stdin && !g_stop) {
        char line[LINE_MAX_];
        while (!g_stop && fgets(line, sizeof line, stdin)) {
            char type[16]; float v[3]; int nv = 0;
            if (parse_line(line, type, v, &nv) || parse_termux_json(line, type, v, &nv))
                sink_line(&s, type, v, nv, now_ns());
        }
    }
    if (s.fd >= 0) close(s.fd);
    logf_("bye");
    return 0;
}
