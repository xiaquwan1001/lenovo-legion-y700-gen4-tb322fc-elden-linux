// SPDX-License-Identifier: GPL-2.0
/*
 * elden-hapticd — Waydroid "vibrator" passthrough bridge (2026-10-13)
 *
 * Problem
 *   The Waydroid vendor HAL android.hardware.vibrator@1.0-service.waydroid
 *   (lineage hardware/waydroid/vibrator/Vibrator.cpp) implements the AOSP
 *   "LED trigger" vibrator interface by *writing files*:
 *        /sys/class/leds/vibrator/state      = 1
 *        /sys/class/leds/vibrator/duration   = <ms>
 *        /sys/class/leds/vibrator/activate   = 1   (0 = off)
 *        /sys/devices/virtual/timed_output/vibrator/enable = <ms> / 0
 *   Mainline elden has neither a leds-class "vibrator" nor a timed_output
 *   class: every write fails silently (std::ofstream, return value ignored),
 *   so Android believes vibration works but nothing moves.
 *
 * Bridge ABI (host dir bind-mounted over /sys/class/leds in the container)
 *   activate   0/1        — vibration on/off (HIDL HAL and AIDL HAL both)
 *   duration   ms         — requested duration
 *   amplitude  0..255     — 255 = full; scales both motors (AIDL HAL / amplitude-capable HAL)
 *   state      -          — informational (written by the HAL)
 *
 * Mapping
 *   Each request is replayed on the two kernel haptics devices (input FF_RUMBLE)
 *   exposed by drivers/input/misc/aw86927.c.  Motors are labelled A/B by a
 *   stable sort of their sysfs (i2c) address, so per-side strength can be
 *   configured without guessing: --amp-a/--amp-b (or --amp for both).
 *
 * Usage
 *   elden-hapticd [--dir DIR] [--amp N] [--amp-a N] [--amp-b N]
 *                 [--poll MS] [--test a|b] [--verbose]
 *   DIR defaults to /run/elden-haptic/leds/vibrator (0..0xffff magnitudes)
 *
 * Expected kernel evidence (per on/off pair):
 *   kprobe aw86927_haptics_play / aw86927_haptics_play_work
 */
#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <limits.h>
#include <linux/input.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

#define MAX_DEVS 8
#define PATHLEN 256
#define SAFETY_MAX_MS 15000L /* never leave a motor running longer than this */

struct motor {
    int fd;
    int eff;                /* FF effect id, -1 = not uploaded */
    unsigned short mag;     /* magnitude currently uploaded */
    int amp;                /* configured max magnitude for this motor */
    char path[PATHLEN];     /* /dev/input/eventN */
    char addr[32];          /* stable id: sysfs device address (e.g. 6-005a) */
};

static struct motor m[MAX_DEVS];
static int nmot;
static int amp_both = 0xffff;
static int amp_a = -1, amp_b = -1;
static int poll_ms = 3;
static int verbose;
static int running;
static long started_at, cur_dur;
static unsigned cur_amp255 = 255;
static char bridge_dir[PATHLEN] = "/run/elden-haptic/leds/vibrator";
static volatile sig_atomic_t stop_now;

static long now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long)ts.tv_sec * 1000L + ts.tv_nsec / 1000000L;
}

static void logmsg(const char *fmt, ...) {
    va_list ap;
    char ts[32];
    time_t t = time(NULL);
    struct tm tm;
    localtime_r(&t, &tm);
    strftime(ts, sizeof ts, "%H:%M:%S", &tm);
    fprintf(stderr, "[%s] ", ts);
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fputc('\n', stderr);
}

/* ---- input devices -------------------------------------------------- */

/* bounded copy (no -Wformat-truncation noise, always NUL-terminated) */
static void copy_str(char *dst, size_t dlen, const char *src) {
    size_t k = strlen(src);
    if (k > dlen - 1) k = dlen - 1;
    memcpy(dst, src, k);
    dst[k] = '\0';
}

static int find_devices(void) {
    DIR *d = opendir("/dev/input");
    struct dirent *de;
    char paths[MAX_DEVS][PATHLEN];
    int n = 0, i, j;

    if (!d) { logmsg("opendir /dev/input: %s", strerror(errno)); return -1; }
    while ((de = readdir(d)) != NULL && n < MAX_DEVS) {
        char path[PATHLEN], name[64] = {0};
        int fd;
        if (strncmp(de->d_name, "event", 5) != 0) continue;
        if (snprintf(path, sizeof path, "/dev/input/%s", de->d_name) >= (int)sizeof path)
            continue;
        fd = open(path, O_RDWR | O_CLOEXEC);
        if (fd < 0) continue;
        if (ioctl(fd, EVIOCGNAME(sizeof name), name) < 0 || strcmp(name, "aw86927-haptics") != 0) {
            close(fd);
            continue;
        }
        close(fd);
        copy_str(paths[n], PATHLEN, path);
        n++;
    }
    closedir(d);
    if (n == 0) return -1;

    /* stable order by event node number */
    for (i = 0; i < n; i++)
        for (j = i + 1; j < n; j++)
            if (strcmp(paths[j], paths[i]) < 0) {
                char t[PATHLEN];
                copy_str(t, PATHLEN, paths[i]);
                copy_str(paths[i], PATHLEN, paths[j]);
                copy_str(paths[j], PATHLEN, t);
            }

    for (i = 0; i < n; i++) {
        char evname[32], syspath[PATHLEN], resolved[PATH_MAX];
        char *p, *ev;
        copy_str(evname, sizeof evname, paths[i] + strlen("/dev/input/"));
        snprintf(syspath, sizeof syspath, "/sys/class/input/%.16s/device", evname);
        if (realpath(syspath, resolved) == NULL) copy_str(resolved, sizeof resolved, syspath);
        ev = resolved;
        /* /sys/.../i2c-6/6-005a/6-005a:xx/input/input3 -> "6-005a" (i2c client addr) */
        if ((p = strstr(ev, "/i2c-")) != NULL && (p = strchr(p + 1, '/')) != NULL) {
            ev = p + 1;
            if ((p = strchr(ev, '/')) != NULL) *p = '\0';
        } else {
            ev = resolved;
            p = strrchr(ev, '/');
            if (p && p != ev) *p = '\0';
            p = strrchr(ev, '/');
            if (p && p != ev) ev = p + 1;
        }
        copy_str(m[i].addr, sizeof m[i].addr, ev);
        copy_str(m[i].path, PATHLEN, paths[i]);
        m[i].fd = open(paths[i], O_RDWR | O_CLOEXEC);
        m[i].eff = -1;
        m[i].mag = 0;
        m[i].amp = (i == 0 && amp_a >= 0) ? amp_a : (i == 1 && amp_b >= 0) ? amp_b : amp_both;
        if (m[i].fd < 0) {
            logmsg("open %s: %s", paths[i], strerror(errno));
            continue;
        }
        logmsg("motor %c: %s addr=%s amp=0x%04x", 'A' + i, paths[i], m[i].addr, m[i].amp);
    }
    return n;
}

/* ---- FF effects ------------------------------------------------------ */

static int set_magnitude(int i, unsigned short mag) {
    struct ff_effect e;
    memset(&e, 0, sizeof e);
    e.type = FF_RUMBLE;
    e.id = (int16_t)m[i].eff;
    e.u.rumble.strong_magnitude = mag;
    e.u.rumble.weak_magnitude = 0;
    e.replay.length = 0; /* 0 = keep running until stopped (ff-memless) */
    e.replay.delay = 0;
    if (ioctl(m[i].fd, EVIOCSFF, &e) < 0) {
        logmsg("EVIOCSFF %s failed: %s", m[i].path, strerror(errno));
        m[i].eff = -1;
        return -1;
    }
    m[i].eff = e.id;
    m[i].mag = mag;
    return 0;
}

static void play_dev(int i, int on) {
    struct input_event ev;
    if (m[i].eff < 0) return;
    memset(&ev, 0, sizeof ev);
    ev.type = EV_FF;
    ev.code = (unsigned short)m[i].eff;
    ev.value = on ? 1 : 0;
    if (write(m[i].fd, &ev, sizeof ev) != (ssize_t)sizeof ev)
        logmsg("EV_FF write %s value=%d failed: %s", m[i].path, ev.value, strerror(errno));
}

static unsigned short effective_mag(int i) {
    long v = (long)m[i].amp * (long)cur_amp255 / 255L;
    if (v < 0) v = 0;
    if (v > 0xffff) v = 0xffff;
    return (unsigned short)v;
}

static void play_all(int on) {
    int i;
    char detail[128] = "";
    for (i = 0; i < nmot; i++) {
        if (m[i].fd < 0) continue;
        if (on) {
            unsigned short want = effective_mag(i);
            if (m[i].eff < 0 || m[i].mag != want) set_magnitude(i, want);
            if (m[i].eff < 0) continue;
            if (verbose) {
                char part[48];
                snprintf(part, sizeof part, " %c=0x%04x", 'A' + i, want);
                strncat(detail, part, sizeof detail - strlen(detail) - 1);
            }
        }
        play_dev(i, on);
    }
    if (verbose)
        logmsg("rumble %s (amplitude=%u/255)%s", on ? "ON" : "OFF", cur_amp255, detail);
}

/* ---- bridge files --------------------------------------------------- */

static void bridge_path(char *out, size_t outlen, const char *file) {
    snprintf(out, outlen, "%s/%s", bridge_dir, file);
}

static long read_num(const char *file, long dflt) {
    char path[PATHLEN + 32], buf[32];
    int fd;
    ssize_t n;
    bridge_path(path, sizeof path, file);
    fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return dflt;
    n = read(fd, buf, sizeof buf - 1);
    close(fd);
    if (n <= 0) return dflt;
    buf[n] = '\0';
    return strtol(buf, NULL, 10);
}

/* Self-clear the trigger file after our own safety stop: the HAL only writes
 * activate=1/0 around a real vibration, so leaving 1 behind would make the
 * next poll re-trigger the motor in a loop.  Android never reads it back. */
static void clear_activate(void) {
    char path[PATHLEN + 32];
    int fd;
    bridge_path(path, sizeof path, "activate");
    fd = open(path, O_WRONLY | O_CLOEXEC);
    if (fd < 0) return;
    if (write(fd, "0\n", 2) != 2) { /* best effort */ }
    close(fd);
}

static void on_signal(int sig) { (void)sig; stop_now = 1; }

int main(int argc, char **argv) {
    int test_motor = -1;
    static const struct option opts[] = {
        { "dir", required_argument, NULL, 'd' },
        { "amp", required_argument, NULL, 'a' },
        { "amp-a", required_argument, NULL, 'A' },
        { "amp-b", required_argument, NULL, 'B' },
        { "poll", required_argument, NULL, 'p' },
        { "test", required_argument, NULL, 't' },
        { "verbose", no_argument, NULL, 'v' },
        { "help", no_argument, NULL, 'h' },
        { NULL, 0, NULL, 0 },
    };
    int c;
    while ((c = getopt_long(argc, argv, "d:a:A:B:p:t:vh", opts, NULL)) != -1) {
        switch (c) {
        case 'd': snprintf(bridge_dir, sizeof bridge_dir, "%s", optarg); break;
        case 'a': amp_both = (int)strtol(optarg, NULL, 0); break;
        case 'A': amp_a = (int)strtol(optarg, NULL, 0); break;
        case 'B': amp_b = (int)strtol(optarg, NULL, 0); break;
        case 'p': poll_ms = (int)strtol(optarg, NULL, 0); break;
        case 't': test_motor = (optarg[0] == 'a' || optarg[0] == 'A') ? 0 : 1; break;
        case 'v': verbose = 1; break;
        default:
            fprintf(stderr,
                    "usage: %s [--dir DIR] [--amp N] [--amp-a N] [--amp-b N] [--poll MS] "
                    "[--test a|b] [--verbose]\n",
                    argv[0]);
            return c == 'h' ? 0 : 2;
        }
    }
    if (poll_ms < 1) poll_ms = 1;
    if (amp_both < 0) amp_both = 0;
    if (amp_both > 0xffff) amp_both = 0xffff;
    signal(SIGTERM, on_signal);
    signal(SIGINT, on_signal);

    nmot = find_devices();
    if (nmot < 0) { logmsg("no aw86927-haptics input device found"); return 1; }
    logmsg("bridge %s, %d motor(s), poll=%dms", bridge_dir, nmot, poll_ms);

    if (test_motor >= 0) { /* one-shot identification: --test a|b */
        if (test_motor >= nmot) { logmsg("no motor %c", 'A' + test_motor); return 1; }
        logmsg("test motor %c (%s) 400 ms", 'A' + test_motor, m[test_motor].addr);
        if (set_magnitude(test_motor, (unsigned short)m[test_motor].amp) == 0)
            play_dev(test_motor, 1);
        usleep(400 * 1000);
        play_dev(test_motor, 0);
        return 0;
    }

    while (!stop_now) {
        long act = read_num("activate", 0);
        long dur = read_num("duration", 0);
        long amp255 = read_num("amplitude", 255);
        long now = now_ms();

        if (amp255 < 0) amp255 = 0;
        if (amp255 > 255) amp255 = 255;

        if (act > 0) {
            long want = dur > 0 ? dur : SAFETY_MAX_MS;
            if (want > SAFETY_MAX_MS) want = SAFETY_MAX_MS;
            if (!running) {
                cur_dur = want;
                cur_amp255 = (unsigned)amp255;
                started_at = now;
                play_all(1);
                running = 1;
                logmsg("vibrate ON %ld ms amp=%u/255 (activate=%ld duration=%ld)",
                       cur_dur, cur_amp255, act, dur);
            } else if ((dur > 0 && dur != cur_dur) || (unsigned)amp255 != cur_amp255) {
                int amp_changed = ((unsigned)amp255 != cur_amp255);
                cur_dur = want;
                cur_amp255 = (unsigned)amp255;
                started_at = now;
                /* The AIDL HAL starts the vibration first and only then pushes
                 * setAmplitude(), so an amplitude change must re-upload the FF
                 * effect or the motor keeps running at the stale magnitude. */
                if (amp_changed)
                    play_all(1);
                logmsg("vibrate re-triggered %ld ms amp=%u/255", cur_dur, cur_amp255);
            }
        } else if (running) {
            play_all(0);
            running = 0;
            logmsg("vibrate OFF (activate=0)");
        }

        if (running && now - started_at >= cur_dur) {
            play_all(0);
            running = 0;
            clear_activate();
            logmsg("vibrate AUTO-OFF after %ld ms (activate cleared)", cur_dur);
        }
        usleep((useconds_t)poll_ms * 1000);
    }

    if (running) play_all(0);
    logmsg("exiting");
    return 0;
}
