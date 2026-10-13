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
 * Bridge
 *   A host directory holding those three files is bind-mounted over
 *   /sys/class/leds inside the Waydroid container (lxc.mount.entry, see
 *   scripts/waydroid-haptics-setup.sh).  This daemon runs on the Alpine host,
 *   polls the files and replays each request on the kernel haptics devices:
 *   the aw86927 driver exposes one input FF_RUMBLE device per motor
 *   ("aw86927-haptics", drivers/input/misc/aw86927.c, input_ff_create_memless).
 *
 * Usage
 *   elden-hapticd [--dir DIR] [--amp 0..65535] [--poll MS] [--verbose]
 *   DIR defaults to /run/elden-haptic/leds/vibrator
 *
 * Expected kernel evidence (per on/off pair):
 *   kprobe aw86927_haptics_play / aw86927_haptics_play_work
 */
#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
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

static int  dev_fd[MAX_DEVS];
static int  dev_eff[MAX_DEVS];
static char dev_path[MAX_DEVS][PATHLEN];
static int  ndev;
static int  amp = 0xffff;
static int  poll_ms = 3;
static int  verbose;
static int  running; /* a rumble is currently playing */
static long started_at, cur_dur;
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

static int find_devices(void) {
    DIR *d = opendir("/dev/input");
    struct dirent *de;
    if (!d) { logmsg("opendir /dev/input: %s", strerror(errno)); return -1; }
    while ((de = readdir(d)) != NULL && ndev < MAX_DEVS) {
        char path[PATHLEN], name[64] = {0};
        int fd;
        if (strncmp(de->d_name, "event", 5) != 0) continue;
        if (snprintf(path, sizeof path, "/dev/input/%s", de->d_name) >= (int)sizeof path)
            continue; /* d_name too long — not one of ours */
        fd = open(path, O_RDWR | O_CLOEXEC);
        if (fd < 0) continue;
        if (ioctl(fd, EVIOCGNAME(sizeof name), name) < 0 || strcmp(name, "aw86927-haptics") != 0) {
            close(fd);
            continue;
        }
        dev_fd[ndev] = fd;
        dev_eff[ndev] = -1;
        snprintf(dev_path[ndev], PATHLEN, "%s", path);
        logmsg("haptics device %d: %s (%s)", ndev, path, name);
        ndev++;
    }
    closedir(d);
    return ndev > 0 ? 0 : -1;
}

static int upload_effect(int i) {
    struct ff_effect e;
    memset(&e, 0, sizeof e);
    e.type = FF_RUMBLE;
    e.id = -1;
    e.u.rumble.strong_magnitude = (unsigned short)amp;
    e.u.rumble.weak_magnitude = 0;
    e.replay.length = 0; /* 0 = keep running until stopped (ff-memless) */
    e.replay.delay = 0;
    if (ioctl(dev_fd[i], EVIOCSFF, &e) < 0) {
        logmsg("EVIOCSFF %s failed: %s", dev_path[i], strerror(errno));
        dev_eff[i] = -1;
        return -1;
    }
    dev_eff[i] = e.id;
    return 0;
}

static void play_dev(int i, int on) {
    struct input_event ev;
    if (dev_eff[i] < 0) return;
    memset(&ev, 0, sizeof ev);
    ev.type = EV_FF;
    ev.code = (unsigned short)dev_eff[i];
    ev.value = on ? 1 : 0;
    if (write(dev_fd[i], &ev, sizeof ev) != (ssize_t)sizeof ev)
        logmsg("EV_FF write %s value=%d failed: %s", dev_path[i], ev.value, strerror(errno));
}

static void play_all(int on) {
    int i;
    for (i = 0; i < ndev; i++) {
        if (dev_eff[i] < 0 && on) upload_effect(i);
        play_dev(i, on);
    }
    if (verbose) logmsg("rumble %s amp=0x%04x", on ? "ON" : "OFF", amp);
}

/* ---- bridge files --------------------------------------------------- */

/* Self-clear the trigger file after our own safety stop: the HAL only writes
 * activate=1/0 around a real vibration, so leaving 1 behind would make the
 * next poll re-trigger the motor in a loop.  Android never reads it back. */
static void clear_activate(void) {
    char path[PATHLEN + 32];
    int fd;
    snprintf(path, sizeof path, "%s/activate", bridge_dir);
    fd = open(path, O_WRONLY | O_CLOEXEC);
    if (fd < 0) return;
    if (write(fd, "0\n", 2) != 2) { /* best effort */ }
    close(fd);
}

static long read_num(const char *file) {
    char path[PATHLEN + 32], buf[32];
    int fd;
    ssize_t n;
    snprintf(path, sizeof path, "%s/%s", bridge_dir, file);
    fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    n = read(fd, buf, sizeof buf - 1);
    close(fd);
    if (n <= 0) return -1;
    buf[n] = '\0';
    return strtol(buf, NULL, 10);
}

static void on_signal(int sig) { (void)sig; stop_now = 1; }

int main(int argc, char **argv) {
    static const struct option opts[] = {
        { "dir", required_argument, NULL, 'd' },
        { "amp", required_argument, NULL, 'a' },
        { "poll", required_argument, NULL, 'p' },
        { "verbose", no_argument, NULL, 'v' },
        { "help", no_argument, NULL, 'h' },
        { NULL, 0, NULL, 0 },
    };
    int c;
    while ((c = getopt_long(argc, argv, "d:a:p:vh", opts, NULL)) != -1) {
        switch (c) {
        case 'd': snprintf(bridge_dir, sizeof bridge_dir, "%s", optarg); break;
        case 'a': amp = (int)strtol(optarg, NULL, 0); break;
        case 'p': poll_ms = (int)strtol(optarg, NULL, 0); break;
        case 'v': verbose = 1; break;
        default:
            fprintf(stderr, "usage: %s [--dir DIR] [--amp N] [--poll MS] [--verbose]\n", argv[0]);
            return c == 'h' ? 0 : 2;
        }
    }
    if (poll_ms < 1) poll_ms = 1;
    amp = amp < 0 ? 0 : (amp > 0xffff ? 0xffff : amp);
    signal(SIGTERM, on_signal);
    signal(SIGINT, on_signal);

    if (find_devices() < 0) { logmsg("no aw86927-haptics input device found"); return 1; }
    logmsg("bridge dir %s, %d motor(s), amp=0x%04x, poll=%dms", bridge_dir, ndev, amp, poll_ms);

    while (!stop_now) {
        long act = read_num("activate");
        long dur = read_num("duration");
        long now = now_ms();

        if (act > 0) {
            long want = dur > 0 ? dur : SAFETY_MAX_MS;
            if (want > SAFETY_MAX_MS) want = SAFETY_MAX_MS;
            if (!running) {
                cur_dur = want;
                started_at = now;
                play_all(1);
                running = 1;
                logmsg("vibrate ON %ld ms (activate=%ld duration=%ld)", cur_dur, act, dur);
            } else if (dur > 0 && dur != cur_dur) {
                cur_dur = want;
                started_at = now;
                logmsg("vibrate re-triggered %ld ms", cur_dur);
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
