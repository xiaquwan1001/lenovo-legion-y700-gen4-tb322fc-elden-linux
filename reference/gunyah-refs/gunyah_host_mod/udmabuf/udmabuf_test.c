// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * udmabuf_test - exercise /dev/udmabuf end to end.
 *
 *   udmabuf_test <MiB> [hold_seconds]
 *
 * Creates a sealed memfd of the requested size, wraps it in a udmabuf, then
 * writes a pattern through the *memfd* mapping and reads it back through the
 * *dma-buf* mapping.  A pass proves the dma-buf really points at the memfd's
 * pages (not fresh memory), which is the property gfxstream depends on.  Then
 * it repeats the exercise with UDMABUF_CREATE_LIST, the multi-chunk ioctl
 * crosvm actually uses.  hold_seconds keeps the buffer open so `rmmod` can be
 * tried against a live buffer (it must fail).
 *
 * A size above the built-in driver's size_limit_mb (64 by default) is the
 * cleanest check of whether udmabuf.ko's hijack is in charge: it fails with
 * EINVAL on the built-in and passes once the module is loaded.
 *
 *   aarch64-linux-gnu-gcc -static -O1 -o udmabuf_test udmabuf_test.c
 */
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

#ifndef MFD_ALLOW_SEALING
#define MFD_ALLOW_SEALING 0x0002U
#endif
#ifndef F_ADD_SEALS
#define F_ADD_SEALS 1033
#define F_SEAL_SHRINK 0x0002
#endif

struct udmabuf_create {
	__u32 memfd;
	__u32 flags;
	__u64 offset;
	__u64 size;
};

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

#define UDMABUF_CREATE _IOW('u', 0x42, struct udmabuf_create)
#define UDMABUF_CREATE_LIST _IOW('u', 0x43, struct udmabuf_create_list)
#define UDMABUF_FLAGS_CLOEXEC 0x01

/* The path crosvm actually uses: one CREATE_LIST of several chunks, CLOEXEC. */
static int test_create_list(int ufd, int mfd, unsigned long size, int chunks)
{
	char buf[sizeof(struct udmabuf_create_list) +
		 16 * sizeof(struct udmabuf_create_item)];
	struct udmabuf_create_list *head = (void *)buf;
	unsigned long chunk = (size / chunks) & ~4095UL;
	int i, dfd;
	char *dmem, *mmem;

	head->flags = UDMABUF_FLAGS_CLOEXEC;
	head->count = chunks;
	for (i = 0; i < chunks; i++) {
		head->list[i].memfd = mfd;
		head->list[i].__pad = 0;
		head->list[i].offset = (unsigned long)i * chunk;
		head->list[i].size = chunk;
	}

	dfd = ioctl(ufd, UDMABUF_CREATE_LIST, head);
	if (dfd < 0) {
		printf("FAIL UDMABUF_CREATE_LIST %d x %lu MiB: %s\n",
		       chunks, chunk >> 20, strerror(errno));
		return 1;
	}
	if (!(fcntl(dfd, F_GETFD) & FD_CLOEXEC)) {
		printf("FAIL CREATE_LIST ignored UDMABUF_FLAGS_CLOEXEC\n");
		close(dfd);
		return 1;
	}
	printf("OK   UDMABUF_CREATE_LIST %d x %lu MiB -> fd %d (cloexec)\n",
	       chunks, chunk >> 20, dfd);

	mmem = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, mfd, 0);
	dmem = mmap(NULL, (unsigned long)chunks * chunk, PROT_READ | PROT_WRITE,
		    MAP_SHARED, dfd, 0);
	if (mmem == MAP_FAILED || dmem == MAP_FAILED) {
		printf("FAIL mmap after CREATE_LIST: %s\n", strerror(errno));
		close(dfd);
		return 1;
	}
	/* Each chunk of the dma-buf must land on its own slice of the memfd. */
	for (i = 0; i < chunks; i++) {
		unsigned long src = (unsigned long)i * chunk;

		memset(mmem + src, 0x11 * (i + 1), 4096);
		if (memcmp(mmem + src, dmem + src, 4096)) {
			printf("FAIL CREATE_LIST chunk %d does not map its range\n", i);
			munmap(mmem, size);
			munmap(dmem, (unsigned long)chunks * chunk);
			close(dfd);
			return 1;
		}
	}
	printf("OK   every CREATE_LIST chunk maps its own memfd range\n");
	munmap(mmem, size);
	munmap(dmem, (unsigned long)chunks * chunk);
	close(dfd);
	return 0;
}

int main(int argc, char **argv)
{
	unsigned long mib = (argc > 1) ? strtoul(argv[1], NULL, 0) : 128;
	unsigned long size = mib << 20;
	struct udmabuf_create create = { 0 };
	int mfd, dfd, ufd, i, rc = 0;
	char *mmem, *dmem;

	mfd = syscall(SYS_memfd_create, "udmabuf_test", MFD_ALLOW_SEALING);
	if (mfd < 0) {
		printf("FAIL memfd_create: %s\n", strerror(errno));
		return 1;
	}
	if (ftruncate(mfd, size) < 0) {
		printf("FAIL ftruncate %lu MiB: %s\n", mib, strerror(errno));
		return 1;
	}
	if (fcntl(mfd, F_ADD_SEALS, F_SEAL_SHRINK) < 0) {
		printf("FAIL F_SEAL_SHRINK: %s\n", strerror(errno));
		return 1;
	}

	ufd = open("/dev/udmabuf", O_RDWR);
	if (ufd < 0) {
		printf("FAIL open /dev/udmabuf: %s\n", strerror(errno));
		return 1;
	}

	create.memfd = mfd;
	create.flags = 0;
	create.offset = 0;
	create.size = size;
	dfd = ioctl(ufd, UDMABUF_CREATE, &create);
	if (dfd < 0) {
		printf("FAIL UDMABUF_CREATE %lu MiB: %s\n", mib, strerror(errno));
		return 1;
	}
	printf("OK   UDMABUF_CREATE %lu MiB -> fd %d\n", mib, dfd);

	mmem = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, mfd, 0);
	if (mmem == MAP_FAILED) {
		printf("FAIL mmap memfd: %s\n", strerror(errno));
		return 1;
	}
	dmem = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, dfd, 0);
	if (dmem == MAP_FAILED) {
		printf("FAIL mmap dmabuf: %s\n", strerror(errno));
		return 1;
	}
	printf("OK   mmap both mappings\n");

	/* Touch the first, middle and last page of each: write via the memfd,
	 * read via the dma-buf, then the reverse. */
	for (i = 0; i < 3; i++) {
		unsigned long off = (i == 0) ? 0 :
				    (i == 1) ? (size / 2) & ~4095UL : size - 4096;

		memset(mmem + off, 0xA5 + i, 4096);
		if (memcmp(mmem + off, dmem + off, 4096)) {
			printf("FAIL memfd->dmabuf mismatch at 0x%lx\n", off);
			rc = 1;
		}
		memset(dmem + off, 0x5A + i, 4096);
		if (memcmp(mmem + off, dmem + off, 4096)) {
			printf("FAIL dmabuf->memfd mismatch at 0x%lx\n", off);
			rc = 1;
		}
	}
	if (!rc)
		printf("OK   memfd and dma-buf share the same pages\n");

	/* Fault in the whole buffer, so a bad page array shows up as a crash
	 * here rather than later inside gfxstream. */
	for (unsigned long off = 0; off < size; off += 4096)
		dmem[off] = (char)(off >> 12);
	printf("OK   faulted in all %lu pages\n", size >> 12);

	if (argc > 2) {
		/* Hold the dma-buf open so rmmod can be tried against it. */
		printf("OK   holding the buffer for %s seconds\n", argv[2]);
		fflush(stdout);
		sleep(strtoul(argv[2], NULL, 0));
	}

	munmap(mmem, size);
	munmap(dmem, size);
	close(dfd);

	rc |= test_create_list(ufd, mfd, size, 4);

	close(ufd);
	close(mfd);
	printf("%s\n", rc ? "RESULT: FAIL" : "RESULT: PASS");
	return rc;
}
