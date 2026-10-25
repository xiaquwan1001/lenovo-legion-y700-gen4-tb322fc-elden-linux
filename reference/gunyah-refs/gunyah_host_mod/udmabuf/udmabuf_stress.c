// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright DroidVM contributors
// Additional permissions apply; see ADDITIONAL-PERMISSIONS in the repository root.
/*
 * udmabuf_stress - drive UDMABUF_CREATE_LIST at the entry counts a guest can actually request,
 * and report what the host does at each step, so "the guest can ask for 16384 entries" stops
 * being a thing we reason about and becomes a thing we measured.
 *
 *   udmabuf_stress [max_entries] [hold_seconds]
 *
 * Why this exists: nothing between the guest and the host udmabuf driver clamps the entry count.
 * The guest driver's guest_pool_max_nents is a writable module parameter, nr_entries on the
 * virtio-gpu wire is a Le32, and crosvm sized its list straight from iovecs.len(). So the entry
 * count is guest-chosen and the host's list_limit is the only bound -- which makes the host's
 * behaviour AT that bound the thing worth knowing.
 *
 * The ladder doubles from 64 and stops at max_entries (default 16384, our module's list_limit).
 * Each rung is one CREATE_LIST over a single 4 KiB-granular memfd, which is the worst case for
 * bookkeeping: the most entries for the least memory, so what it measures is the per-entry cost
 * rather than the size cost.
 *
 * It reports MemFree and MemAvailable around every rung. A rung that fails cleanly with ENOMEM or
 * EINVAL is a working limit and is reported as such -- the failure being looked for here is the
 * other kind: the host losing memory that does not come back, or not returning at all.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <linux/types.h>

struct udmabuf_create_item {
	__u32 memfd;
	__u32 __pad;
	__u64 offset;
	__u64 size;
};

struct udmabuf_create_list {
	__u32 flags;
	__u32 count;
	struct udmabuf_create_item list[];
};

#define UDMABUF_CREATE_LIST _IOW('u', 0x43, struct udmabuf_create_list)
#define UDMABUF_FLAGS_CLOEXEC 0x01
#define PAGE 4096UL

#ifndef MFD_ALLOW_SEALING
#define MFD_ALLOW_SEALING 0x0002U
#endif
#ifndef F_ADD_SEALS
#define F_ADD_SEALS 1033
#define F_SEAL_SHRINK 0x0002
#endif

static long meminfo(const char *key)
{
	char line[256];
	FILE *f = fopen("/proc/meminfo", "r");
	long v = -1;

	if (!f)
		return -1;
	while (fgets(line, sizeof(line), f)) {
		if (!strncmp(line, key, strlen(key))) {
			sscanf(line + strlen(key), " %ld", &v);
			break;
		}
	}
	fclose(f);
	return v;
}

static void mem_line(const char *tag)
{
	printf("      %-8s MemFree=%ldMB MemAvailable=%ldMB\n", tag,
	       meminfo("MemFree:") / 1024, meminfo("MemAvailable:") / 1024);
	fflush(stdout);
}

/* One rung: `entries` items of one page each, over a memfd just large enough. */
static int rung(int ufd, int entries, int hold)
{
	size_t need = (size_t)entries * PAGE;
	struct udmabuf_create_list *head;
	int mfd, dfd, rc = 0;
	void *dmem;

	head = calloc(1, sizeof(*head) + (size_t)entries * sizeof(head->list[0]));
	if (!head) {
		printf("  %6d  SKIP could not allocate the request itself (%zu bytes)\n",
		       entries, sizeof(*head) + (size_t)entries * sizeof(head->list[0]));
		return 0;
	}

	/* Sealed against shrinking, or udmabuf refuses the memfd -- with EINVAL, which is the same
	 * error an over-long list gets. An unsealed memfd therefore looks exactly like a working
	 * entry limit, at every rung including the smallest. That is what it looked like here. */
	mfd = syscall(SYS_memfd_create, "stress", MFD_ALLOW_SEALING);
	if (mfd < 0 || ftruncate(mfd, need) ||
	    fcntl(mfd, F_ADD_SEALS, F_SEAL_SHRINK)) {
		printf("  %6d  SKIP memfd %zu MiB: %s\n", entries, need >> 20, strerror(errno));
		free(head);
		if (mfd >= 0)
			close(mfd);
		return 0;
	}

	head->flags = UDMABUF_FLAGS_CLOEXEC;
	head->count = entries;
	for (int i = 0; i < entries; i++) {
		head->list[i].memfd = mfd;
		head->list[i].offset = (__u64)i * PAGE;
		head->list[i].size = PAGE;
	}

	dfd = ioctl(ufd, UDMABUF_CREATE_LIST, head);
	if (dfd < 0) {
		/* A bounded refusal is the correct behaviour, not a failure of this test. */
		printf("  %6d  refused (%zu MiB): %s\n", entries, need >> 20, strerror(errno));
		free(head);
		close(mfd);
		return 0;
	}

	/* Map it and touch every chunk: the pin only actually happens on fault, so a create that
	 * succeeds without mapping proves much less than it looks like it does. */
	dmem = mmap(NULL, need, PROT_READ | PROT_WRITE, MAP_SHARED, dfd, 0);
	if (dmem == MAP_FAILED) {
		printf("  %6d  OK create, but mmap failed: %s\n", entries, strerror(errno));
		rc = 1;
	} else {
		for (size_t off = 0; off < need; off += PAGE)
			((volatile char *)dmem)[off] = 0x5a;
		printf("  %6d  OK  %zu MiB, all %d chunks mapped and written\n",
		       entries, need >> 20, entries);
		if (hold) {
			printf("      holding %ds\n", hold);
			fflush(stdout);
			sleep(hold);
		}
		munmap(dmem, need);
	}

	close(dfd);
	close(mfd);
	free(head);
	return rc;
}

int main(int argc, char **argv)
{
	int max = argc > 1 ? atoi(argv[1]) : 16384;
	int hold = argc > 2 ? atoi(argv[2]) : 0;
	int ufd, bad = 0;

	ufd = open("/dev/udmabuf", O_RDWR);
	if (ufd < 0) {
		printf("FAIL open /dev/udmabuf: %s\n", strerror(errno));
		return 1;
	}
	printf("udmabuf_stress: ladder to %d entries, one page each\n", max);
	mem_line("start");

	for (int n = 64; n <= max; n *= 2) {
		bad += rung(ufd, n, 0);
		mem_line("after");
	}
	/* The exact bound, not just the power of two below it. */
	if (max & (max - 1) || max < 64) {
		bad += rung(ufd, max, hold);
		mem_line("after");
	} else {
		bad += rung(ufd, max, hold);
		mem_line("after");
	}

	printf("%s\n", bad ? "SOME RUNGS MISBEHAVED" : "no rung misbehaved");
	close(ufd);
	return bad ? 1 : 0;
}
