/* SPDX-License-Identifier: GPL-2.0-or-later */
/*
 * Userspace ABI for the standalone gunyah_share module.
 *
 * The in-tree patch added GH_VM_ANDROID_SHARE_BLOB as a new ioctl on the
 * gunyah VM fd itself (a case inside gh_vm_ioctl()). A standalone module
 * cannot inject a case into that switch, so this module exposes its OWN
 * character device (/dev/gunyah_share) and takes the gunyah VM fd as a
 * field of the request. Semantics are otherwise identical.
 *
 * Userspace flow:
 *   int vmfd  = <the gunyah VM fd you already own>;
 *   int gsfd  = open("/dev/gunyah_share", O_RDWR);
 *   struct ghsm_share_blob b = {
 *       .vm_fd          = vmfd,
 *       .label          = ...,
 *       .flags          = GH_MEM_ALLOW_READ | GH_MEM_ALLOW_WRITE,
 *       .guest_phys_addr= gpa,
 *       .memory_size    = size,           // page aligned
 *       .userspace_addr = (uintptr_t)buf, // page aligned
 *   };
 *   ioctl(gsfd, GHSM_SHARE_BLOB, &b);     // b.mem_handle filled on return
 */
#ifndef _UAPI_GUNYAH_SHARE_H
#define _UAPI_GUNYAH_SHARE_H

#include <linux/types.h>
#include <linux/ioctl.h>

#define GHSM_IOCTL_TYPE 0x47 /* 'G' */

/**
 * struct ghsm_share_blob - runtime-SHARE a userspace buffer to a running guest.
 * @vm_fd: the gunyah VM fd (from GH_CREATE_VM); validated by the module.
 * @label: parcel label, unique within this VM.
 * @flags: GH_MEM_ALLOW_READ / _WRITE / _EXEC (see uapi/linux/gunyah.h).
 * @mem_handle: OUT - resource-manager memparcel handle for the guest to accept.
 * @guest_phys_addr: GPA the guest intends to accept it at (informational).
 * @memory_size: page-aligned size.
 * @userspace_addr: page-aligned host buffer to share.
 */
struct ghsm_share_blob {
	__s32 vm_fd;
	__u32 label;
	__u32 flags;
	__u32 mem_handle;
	__u64 guest_phys_addr;
	__u64 memory_size;
	__u64 userspace_addr;
};

#define GHSM_SHARE_BLOB _IOWR(GHSM_IOCTL_TYPE, 0x14, struct ghsm_share_blob)

/**
 * struct ghsm_share_dmabuf - runtime-SHARE a DMA-BUF to a running guest.
 * @vm_fd: the gunyah VM fd (from GH_CREATE_VM); validated by the module.
 * @dmabuf_fd: DMA-BUF fd in the calling process.
 * @label: parcel label, unique within this VM.
 * @flags: GH_MEM_ALLOW_READ / _WRITE / _EXEC (see uapi/linux/gunyah.h).
 * @mem_handle: OUT - resource-manager memparcel handle for the guest to accept.
 * @reserved: must be zero.
 * @guest_phys_addr: GPA the guest intends to accept it at (informational).
 * @memory_size: page-aligned byte count to share.
 * @dmabuf_offset: page-aligned offset into the DMA-BUF.
 *
 * Unlike GHSM_SHARE_BLOB, this does not try to GUP the DMA-BUF's userspace
 * mmap.  Many device exporters use VM_PFNMAP/VM_MIXEDMAP VMAs that GUP must
 * reject.  The module holds an attachment and builds the memparcel from its
 * sg-table until GHSM_UNSHARE_BLOB has reclaimed the parcel.
 */
struct ghsm_share_dmabuf {
	__s32 vm_fd;
	__s32 dmabuf_fd;
	__u32 label;
	__u32 flags;
	__u32 mem_handle;
	__u32 reserved;
	__u64 guest_phys_addr;
	__u64 memory_size;
	__u64 dmabuf_offset;
};

#define GHSM_SHARE_DMABUF _IOWR(GHSM_IOCTL_TYPE, 0x16, struct ghsm_share_dmabuf)

/**
 * struct ghsm_unshare_blob - reclaim a blob previously shared with GHSM_SHARE_BLOB.
 * @vm_fd: the gunyah VM fd; validated by the module.
 * @label: parcel label to reclaim (the guest has already released its acceptance).
 *
 * Reclaims the RM memparcel (gh_rm_mem_reclaim), unpins the host pages and drops
 * the mapping from the VM's list, so the guest_phys_addr/BAR offset can be reused.
 */
struct ghsm_unshare_blob {
	__s32 vm_fd;
	__u32 label;
};

#define GHSM_UNSHARE_BLOB _IOW(GHSM_IOCTL_TYPE, 0x15, struct ghsm_unshare_blob)

#endif /* _UAPI_GUNYAH_SHARE_H */
