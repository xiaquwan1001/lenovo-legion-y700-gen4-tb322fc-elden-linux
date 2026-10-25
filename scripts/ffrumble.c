/*
 * ffrumble — 直接向 evdev 节点注入 FF_RUMBLE，用于 aw86927 马达的宿主侧取证。
 *
 * 为什么存在：容器里的振动链路是「HAL → elden-hapticd → sysfs」，中间隔了两个进程，
 * 排障时需要一条**绕过全部中间层**的宿主基线。这就是那条基线（阳性对照）：
 *   ffrumble /dev/input/event2 900 0xffff
 *   → 内核 aw86927_haptics_play() 必然被调用；若这都不震，问题在马达/驱动，不在容器。
 *
 * 兼容性（实测对齐 2026-10-25）：原二进制 `ms` 走 atoi（十进制，走 "0x2000" 会给 0），
 * `magnitude` 支持 0x 前缀；本实现**照此实现**，避免把 0x2000 解释成 8192 ms 的长振动。
 * 与设备上原二进制**接口逐字相同**（默认值 /dev/input/event2、600 ms、0xffff；
 * 输出行 `rumble ON id=%d dev=%s mag=0x%x %dms`），因此可以直接替换。
 * 原二进制源码从未入库（见 packaging/elden-userland/sources.tsv），本文件按用法重写。
 *
 * 用法：ffrumble [dev] [ms] [magnitude]
 *   dev        默认 /dev/input/event2
 *   ms         默认 600（**十进制**，与原二进制 atoi 行为一致）
 *   magnitude  默认 0xffff（0..0xffff，**支持 0x 前缀**，与原二进制一致）
 *
 * SPDX-License-Identifier: MIT
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

static long parse_num(const char *s)
{
	char *end = NULL;
	long v = strtol(s, &end, 0);        /* base 0 ⇒ "0x2000" 与 "8192" 都行 */
	return (end && *end == '\0') ? v : -1;
}

static void sleep_ms(long ms)
{
	struct timespec ts = { ms / 1000, (ms % 1000) * 1000000L };
	while (nanosleep(&ts, &ts) == -1 && errno == EINTR)
		;
}

int main(int argc, char **argv)
{
	const char *dev = "/dev/input/event2";
	long ms = 600;
	long mag = 0xffff;

	if (argc > 1 && argv[1][0] != '-') dev = argv[1];
	if (argc > 2) {
		ms = atol(argv[2]);            /* 十进制：与原二进制 atoi("0x2000")==0 对齐 */
		if (ms <= 0 || ms > 60000) {
			fprintf(stderr, "ffrumble: bad duration %s\n", argv[2]);
			return 2;
		}
	}
	if (argc > 3) {
		mag = parse_num(argv[3]);
		if (mag < 0 || mag > 0xffff) {
			fprintf(stderr, "ffrumble: bad magnitude %s (0..0xffff)\n", argv[3]);
			return 2;
		}
	}

	int fd = open(dev, O_RDWR);
	if (fd < 0) {
		fprintf(stderr, "ffrumble: open %s: %s\n", dev, strerror(errno));
		return 1;
	}

	/* 马达只接受 FF_RUMBLE；strong/weak 各取一半，避免某些驱动把两路相加后削顶 */
	struct ff_effect eff;
	memset(&eff, 0, sizeof(eff));
	eff.type = FF_RUMBLE;
	eff.id = -1;                         /* 让内核分配 id */
	eff.replay.length = (uint16_t)ms;    /* 硬件自动停止时间 */
	eff.replay.delay = 0;
	eff.u.rumble.strong_magnitude = (uint16_t)(mag & 0xffff);
	eff.u.rumble.weak_magnitude   = (uint16_t)(mag & 0xffff);

	if (ioctl(fd, EVIOCSFF, &eff) < 0) {
		fprintf(stderr, "ffrumble: EVIOCSFF %s: %s（该节点不支持 EV_FF？）\n",
			dev, strerror(errno));
		close(fd);
		return 1;
	}

	struct input_event ev;
	memset(&ev, 0, sizeof(ev));
	ev.type = EV_FF;
	ev.code = (uint16_t)eff.id;
	ev.value = 1;                        /* 1 = 播放 */

	printf("rumble ON id=%d dev=%s mag=0x%x %ldms\n", eff.id, dev, (unsigned)mag, ms);
	fflush(stdout);

	if (write(fd, &ev, sizeof(ev)) != (ssize_t)sizeof(ev)) {
		fprintf(stderr, "ffrumble: write EV_FF: %s\n", strerror(errno));
		ioctl(fd, EVIOCRMFF, eff.id);
		close(fd);
		return 1;
	}

	/* 等 replay.length 到期（内核/驱动自己会停），再显式 stop + 释放，保证不留残留效果 */
	sleep_ms(ms + 50);
	ev.value = 0;
	if (write(fd, &ev, sizeof(ev)) != (ssize_t)sizeof(ev))
		fprintf(stderr, "ffrumble: write EV_FF stop: %s\n", strerror(errno));
	ioctl(fd, EVIOCRMFF, eff.id);
	close(fd);
	return 0;
}
