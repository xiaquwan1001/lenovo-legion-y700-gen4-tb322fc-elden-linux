// SPDX-License-Identifier: MIT
/*
 * Does KGSL accept a PHYSICALLY FRAGMENTED dma-buf?
 *
 * The kgsl native context currently windows every BO onto one contiguous slice of the pool
 * (kgsl_arena_window -> UDMABUF_CREATE{memfd, off, size}).  Moving to guest-alloc would replace
 * that with a drm_buddy allocation, i.e. a LIST of blocks, so the dma-buf handed to
 * GPUOBJ_IMPORT would carry a multi-entry sg_table.  Nothing in-tree exercises that today, so
 * this asks the driver directly before any of that work starts.
 *
 * Phase 1 mirrors the shipping path exactly (one window, one sg entry) so a failure here means
 * the harness is wrong, not the kernel.
 * Phase 2 builds the same total size out of strided single-page items via UDMABUF_CREATE_LIST.
 * The stride is what forces fragmentation: consecutive items skip a page, so the pages cannot
 * be physically adjacent and sg_alloc_table_from_pages() cannot coalesce them away.
 *
 * Both phases end at GPUMEM_BIND_RANGES, which is the operation guest-alloc would depend on --
 * an import that binds is the acceptance test.  It does NOT prove the GPU can read the memory;
 * that needs a submit and is deliberately out of scope here.
 *
 * Build: see kgsl_frag_test_build.sh (NDK, static).  Run as root on the device.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <linux/udmabuf.h>

#include "msm_kgsl.h"

#define PAGE  4096u
#define TOTAL (8u << 20)          /* 8 MiB -- a realistic BO size */
/* udmabuf caps a list at `list_limit` items (1024 by default, both upstream and in our
 * module), so the worst-case single-page phase has to stay at or under that. */
#define NITEM 1024u               /* 1024 single-page items = 4 MiB, 1024 sg entries */

static int kgsl_fd = -1;

static int xioctl(int fd, unsigned long req, void *arg)
{
    int ret;
    do {
        ret = ioctl(fd, req, arg);
    } while (ret == -1 && (errno == EINTR || errno == EAGAIN));
    return ret;
}

/* A memfd whose pages are faulted in, so udmabuf has something to pin. */
static int make_memfd(size_t size)
{
    int fd = syscall(SYS_memfd_create, "kgsl-frag-test", MFD_ALLOW_SEALING);
    if (fd < 0) {
        perror("memfd_create");
        return -1;
    }
    if (ftruncate(fd, size)) {
        perror("ftruncate");
        close(fd);
        return -1;
    }
    void *p = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (p == MAP_FAILED) {
        perror("mmap memfd");
        close(fd);
        return -1;
    }
    /* Touch every page: udmabuf pins what is already resident. */
    for (size_t off = 0; off < size; off += PAGE)
        ((volatile char *)p)[off] = 1;
    munmap(p, size);
    /* udmabuf refuses a memfd that can still shrink. */
    if (fcntl(fd, F_ADD_SEALS, F_SEAL_SHRINK))
        fprintf(stderr, "  note: F_SEAL_SHRINK failed (%s), continuing\n", strerror(errno));
    return fd;
}

static uint32_t import_dmabuf(int dmabuf_fd)
{
    struct kgsl_gpuobj_import_dma_buf priv = { .fd = dmabuf_fd };
    struct kgsl_gpuobj_import req = {
        .priv = (uintptr_t)&priv,
        .priv_len = sizeof(priv),
        .flags = 0,
        .type = KGSL_USER_MEM_TYPE_DMABUF,
    };
    if (xioctl(kgsl_fd, IOCTL_KGSL_GPUOBJ_IMPORT, &req)) {
        fprintf(stderr, "  GPUOBJ_IMPORT failed: %s\n", strerror(errno));
        return 0;
    }
    return req.id;
}

static void free_gpuobj(uint32_t id)
{
    struct kgsl_gpuobj_free req = { .id = id };
    xioctl(kgsl_fd, IOCTL_KGSL_GPUOBJ_FREE, &req);
}

/*
 * The renderer walks a ladder down from 1 TiB and lands on 128 GiB on this device.  Do NOT
 * start higher here: in a process with no other GPU allocations the driver will happily hand
 * out a 256 GiB VBO, and then every subsequent GPUOBJ_IMPORT fails with ENOMEM because the
 * reservation has eaten the address space the imported object needs its own gpuaddr from.
 * That failure looks exactly like "KGSL rejected the dma-buf" and is not.
 */
static int alloc_vbo(uint32_t *out_id, uint64_t *out_base, uint64_t *out_size)
{
    static const uint64_t ladder[] = {
        0x2000000000ull, 0x800000000ull, 0x100000000ull,
    };
    for (unsigned i = 0; i < sizeof(ladder) / sizeof(ladder[0]); i++) {
        struct kgsl_gpuobj_alloc req = { .size = ladder[i], .flags = KGSL_MEMFLAGS_VBO };
        if (xioctl(kgsl_fd, IOCTL_KGSL_GPUOBJ_ALLOC, &req)) {
            fprintf(stderr, "  VBO size=0x%llx rejected: %s\n",
                    (unsigned long long)ladder[i], strerror(errno));
            continue;
        }
        struct kgsl_gpuobj_info info = { .id = req.id };
        if (xioctl(kgsl_fd, IOCTL_KGSL_GPUOBJ_INFO, &info)) {
            fprintf(stderr, "  GPUOBJ_INFO failed: %s\n", strerror(errno));
            free_gpuobj(req.id);
            continue;
        }
        *out_id = req.id;
        *out_base = info.gpuaddr;
        *out_size = ladder[i];
        printf("  VBO id=%u gpuaddr=0x%llx size=0x%llx\n",
               req.id, (unsigned long long)info.gpuaddr, (unsigned long long)ladder[i]);
        return 0;
    }
    return -1;
}

static int bind_range(uint32_t vbo_id, uint32_t child_id, uint64_t target_offset, uint64_t len)
{
    struct kgsl_gpumem_bind_range range = {
        .child_offset = 0,
        .target_offset = target_offset,
        .length = len,
        .child_id = child_id,
        .op = KGSL_GPUMEM_RANGE_OP_BIND,
    };
    struct kgsl_gpumem_bind_ranges req = {
        .ranges = (uintptr_t)&range,
        .ranges_nents = 1,
        .ranges_size = sizeof(range),
        .id = vbo_id,
        .flags = 0,       /* synchronous */
        .fence_id = 0,
    };
    if (xioctl(kgsl_fd, IOCTL_KGSL_GPUMEM_BIND_RANGES, &req)) {
        fprintf(stderr, "  BIND_RANGES failed: %s\n", strerror(errno));
        return -1;
    }
    return 0;
}

/* Phase 1: one contiguous window, exactly what kgsl_arena_window() builds today. */
static int udmabuf_contiguous(int memfd, size_t size)
{
    struct udmabuf_create uc = {
        .memfd = memfd,
        .flags = UDMABUF_FLAGS_CLOEXEC,
        .offset = 0,
        .size = size,
    };
    int udev = open("/dev/udmabuf", O_RDWR);
    if (udev < 0) {
        perror("open /dev/udmabuf");
        return -1;
    }
    int fd = xioctl(udev, UDMABUF_CREATE, &uc);
    close(udev);
    if (fd < 0)
        fprintf(stderr, "  UDMABUF_CREATE(size=%zu) failed: %s\n", size, strerror(errno));
    return fd;
}

/*
 * Phase 2: the same bytes, but assembled from `nitem` single-page items whose offsets are
 * strided so no two are physically adjacent.  This is the shape a drm_buddy allocation would
 * arrive in, only deliberately worst-case.
 */
static int udmabuf_fragmented(int memfd, unsigned nitem, unsigned stride_pages)
{
    size_t nbytes = sizeof(struct udmabuf_create_list) +
                    (size_t)nitem * sizeof(struct udmabuf_create_item);
    struct udmabuf_create_list *list = calloc(1, nbytes);
    if (!list)
        return -1;
    list->flags = UDMABUF_FLAGS_CLOEXEC;
    list->count = nitem;
    for (unsigned i = 0; i < nitem; i++) {
        list->list[i].memfd  = memfd;
        list->list[i].offset = (uint64_t)i * stride_pages * PAGE;
        list->list[i].size   = PAGE;
    }
    int udev = open("/dev/udmabuf", O_RDWR);
    if (udev < 0) {
        perror("open /dev/udmabuf");
        free(list);
        return -1;
    }
    int fd = xioctl(udev, UDMABUF_CREATE_LIST, list);
    close(udev);
    if (fd < 0)
        fprintf(stderr, "  UDMABUF_CREATE_LIST(count=%u stride=%u) failed: %s\n",
                nitem, stride_pages, strerror(errno));
    free(list);
    return fd;
}

static int run_case(const char *name, int dmabuf_fd, uint64_t expect_len,
                    uint32_t vbo_id, uint64_t vbo_base, uint64_t iova_off)
{
    if (dmabuf_fd < 0) {
        printf("  [%s] FAIL: no dma-buf\n", name);
        return -1;
    }
    off_t len = lseek(dmabuf_fd, 0, SEEK_END);
    printf("  dma-buf fd=%d size=%lld (expected %llu)\n",
           dmabuf_fd, (long long)len, (unsigned long long)expect_len);

    uint32_t mem_id = import_dmabuf(dmabuf_fd);
    close(dmabuf_fd);                 /* KGSL's attachment keeps the pages */
    if (!mem_id) {
        printf("  [%s] FAIL at GPUOBJ_IMPORT\n", name);
        return -1;
    }
    printf("  imported mem_id=%u\n", mem_id);

    int ret = bind_range(vbo_id, mem_id, iova_off, expect_len);
    printf("  [%s] %s\n", name, ret ? "FAIL at GPUMEM_BIND_RANGES" : "PASS (import + bind)");
    free_gpuobj(mem_id);
    return ret;
}

int main(void)
{
    kgsl_fd = open("/dev/kgsl-3d0", O_RDWR | O_CLOEXEC);
    if (kgsl_fd < 0) {
        perror("open /dev/kgsl-3d0");
        return 1;
    }

    uint32_t vbo_id;
    uint64_t vbo_base, vbo_size;
    printf("== VBO ==\n");
    if (alloc_vbo(&vbo_id, &vbo_base, &vbo_size)) {
        fprintf(stderr, "no VBO, cannot continue\n");
        return 1;
    }

    int rc = 0;

    printf("\n== phase 1: contiguous window (mirrors kgsl_arena_window) ==\n");
    int memfd1 = make_memfd(TOTAL);
    if (memfd1 < 0)
        return 1;
    rc |= run_case("contiguous", udmabuf_contiguous(memfd1, TOTAL), TOTAL,
                   vbo_id, vbo_base, 0);
    close(memfd1);

    /* Stride 2 means every other page, so the backing store of the memfd is walked with gaps
     * and consecutive dma-buf pages are guaranteed non-adjacent.  The memfd therefore has to be
     * twice as large as the dma-buf. */
    printf("\n== phase 2: fragmented list, %u items x %u B, stride 2 pages ==\n", NITEM, PAGE);
    int memfd2 = make_memfd((size_t)TOTAL * 2);
    if (memfd2 < 0)
        return 1;
    rc |= run_case("fragmented", udmabuf_fragmented(memfd2, NITEM, 2), (uint64_t)NITEM * PAGE,
                   vbo_id, vbo_base, 0x10000000ull);
    close(memfd2);

    /* A middle case: 64 KiB blocks, which is closer to what drm_buddy would actually hand out
     * than the worst case above. */
    printf("\n== phase 3: fragmented list, 128 items x 64 KiB, stride 32 pages ==\n");
    int memfd3 = make_memfd((size_t)TOTAL * 2);
    if (memfd3 < 0)
        return 1;
    {
        unsigned nitem = 128, blk = 64u << 10;
        size_t nbytes = sizeof(struct udmabuf_create_list) +
                        (size_t)nitem * sizeof(struct udmabuf_create_item);
        struct udmabuf_create_list *list = calloc(1, nbytes);
        list->flags = UDMABUF_FLAGS_CLOEXEC;
        list->count = nitem;
        for (unsigned i = 0; i < nitem; i++) {
            list->list[i].memfd  = memfd3;
            list->list[i].offset = (uint64_t)i * 2 * blk;   /* skip a block between items */
            list->list[i].size   = blk;
        }
        int udev = open("/dev/udmabuf", O_RDWR);
        int fd = udev < 0 ? -1 : xioctl(udev, UDMABUF_CREATE_LIST, list);
        if (udev >= 0)
            close(udev);
        if (fd < 0)
            fprintf(stderr, "  UDMABUF_CREATE_LIST(64K blocks) failed: %s\n", strerror(errno));
        free(list);
        rc |= run_case("frag-64k", fd, (uint64_t)nitem * blk, vbo_id, vbo_base, 0x20000000ull);
    }
    close(memfd3);

    /*
     * Phase 4 is the one that decides whether guest-alloc is viable for real workloads:
     * Minecraft's transient buffer is 128 MiB, and a drm_buddy allocation of that size under
     * fragmentation is thousands of blocks.  udmabuf's list_limit (1024 by default) is the
     * ceiling on items per dma-buf, so this is as much a test of that knob as of KGSL.
     */
    printf("\n== phase 4: 128 MiB from %u x 64 KiB blocks (needs list_limit >= %u) ==\n",
           2048u, 2048u);
    {
        unsigned nitem = 2048, blk = 64u << 10;
        int memfd4 = make_memfd((size_t)nitem * blk * 2);
        if (memfd4 < 0)
            return 1;
        size_t nbytes = sizeof(struct udmabuf_create_list) +
                        (size_t)nitem * sizeof(struct udmabuf_create_item);
        struct udmabuf_create_list *list = calloc(1, nbytes);
        list->flags = UDMABUF_FLAGS_CLOEXEC;
        list->count = nitem;
        for (unsigned i = 0; i < nitem; i++) {
            list->list[i].memfd  = memfd4;
            list->list[i].offset = (uint64_t)i * 2 * blk;
            list->list[i].size   = blk;
        }
        int udev = open("/dev/udmabuf", O_RDWR);
        int fd = udev < 0 ? -1 : xioctl(udev, UDMABUF_CREATE_LIST, list);
        if (udev >= 0)
            close(udev);
        if (fd < 0)
            fprintf(stderr, "  UDMABUF_CREATE_LIST(count=%u) failed: %s\n",
                    nitem, strerror(errno));
        free(list);
        rc |= run_case("frag-128M", fd, (uint64_t)nitem * blk, vbo_id, vbo_base, 0x40000000ull);
        close(memfd4);
    }

    free_gpuobj(vbo_id);
    close(kgsl_fd);
    printf("\n%s\n", rc ? "RESULT: at least one case FAILED" : "RESULT: all cases PASSED");
    return rc ? 1 : 0;
}
