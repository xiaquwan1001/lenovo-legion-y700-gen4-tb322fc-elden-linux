// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * gunyah_share_mod — standalone out-of-tree runtime-SHARE module for the
 * *upstream* gunyah driver. This copy (GKI6.6/) serves android15-6.6 AND
 * android16-6.12: their struct gunyah_vm is identical up to every field we
 * touch, so one source builds both. GKI6.1/ holds the sibling copy for the
 * downstream gh_* driver. The directory says which driver a copy is for --
 * the file name is the same in both on purpose. Reproduces an in-tree
 * "SHARE_BLOB" ioctl without patching drivers/virt/gunyah.
 *
 * Purpose: let crosvm SHARE an arbitrary userspace buffer (a host-visible
 * virtio-gpu blob backing) to a *running* protected guest as an RM memparcel,
 * and return the mem_handle. The guest then accepts it itself via a raw HVC
 * mem_accept (see guest gunyah_guest.ko) into its own stage-2 at the BAR GPA.
 * This is the "GuestAccept" path — no eager arena, no reserved-memory node,
 * no dtb_shim, and a clean per-blob accept/release/reclaim lifecycle.
 *
 * Why a module and not a kernel patch: the gunyah VM fd's ioctl switch
 * (gunyah_vm_ioctl) is static; we expose our own /dev/gunyah_share char device
 * and take the VM fd as a request field. The RM RPC helpers
 * (gunyah_rm_mem_share/reclaim) are global but NOT EXPORT_SYMBOL, so we resolve
 * them via kallsyms. struct gunyah_vm is private; we read vmid/rm/vm_status by
 * BTF-verified byte offset (overridable via module params if a build shifts them).
 *
 * FRAGILE BY DESIGN: the offsets below were read out of a live 6.6.118-android15
 * vmlinux.btf and re-derived from the 6.12 source; every field we touch sits ahead
 * of everything 6.12 added, which is why one source serves both. Verify them
 * against the target vmlinux.btf before trusting this on another build.
 */
#define pr_fmt(fmt) "gunyah_share: " fmt

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/fs.h>
#include <linux/miscdevice.h>
#include <linux/uaccess.h>
#include <linux/file.h>
#include <linux/mm.h>
#include <linux/slab.h>
#include <linux/kprobes.h>
#include <linux/dcache.h>
#include <linux/debugfs.h>
#include <linux/types.h>
#include <linux/bitops.h>
#include <linux/workqueue.h>
#include <linux/delay.h>
#include <linux/vmalloc.h>	/* vmalloc_user/vfree: 6.12 dropped the transitive include */
#include <linux/dma-buf.h>
#include <linux/dma-mapping.h>
#include <linux/scatterlist.h>

/* ---- UAPI (inlined; must match crosvm gunyah_sys bindings + l233 uapi) ---- */
#define GHSM_IOCTL_TYPE 0x47 /* 'G' */
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
struct ghsm_unshare_blob {
	__s32 vm_fd;
	__u32 label;
};
#define GHSM_UNSHARE_BLOB _IOW(GHSM_IOCTL_TYPE, 0x15, struct ghsm_unshare_blob)

/* ---- vendored 6.6 RM types (match include/linux/gunyah.h @ 6.6.118) ---- */
enum gunyah_rm_mem_type { GUNYAH_RM_MEM_TYPE_NORMAL = 0, GUNYAH_RM_MEM_TYPE_IO = 1 };

struct gunyah_rm_mem_acl_entry {
	__le16 vmid;
	u8 perms;
	u8 reserved;
} __packed;

struct gunyah_rm_mem_entry {
	__le64 phys_addr;
	__le64 size;
} __packed;

struct gunyah_rm_mem_parcel {
	enum gunyah_rm_mem_type mem_type;
	u32 label;
	size_t n_acl_entries;
	struct gunyah_rm_mem_acl_entry *acl_entries;
	size_t n_mem_entries;
	struct gunyah_rm_mem_entry *mem_entries;
	u32 mem_handle;
};

#define GUNYAH_RM_ACL_X		BIT(0)
#define GUNYAH_RM_ACL_W		BIT(1)
#define GUNYAH_RM_ACL_R		BIT(2)
#define GUNYAH_MEM_HANDLE_INVAL	U32_MAX

/* crosvm/uapi mem-allow flags (uapi/linux/gunyah.h) */
#define GH_ALLOW_READ	(1u << 0)
#define GH_ALLOW_WRITE	(1u << 1)
#define GH_ALLOW_EXEC	(1u << 2)

/* struct gunyah_vm private-layout offsets (BTF vmlinux.btf, 6.6.118-android15;
 * unchanged on 6.12, whose additions all land after vm_status). */
static int vmid_off      = 0;	/* u16 gunyah_vm.vmid   */
static int rm_off        = 504;	/* struct gunyah_rm *gunyah_vm.rm */
static int vm_status_off = 536;	/* enum gunyah_rm_vm_status gunyah_vm.vm_status */
module_param(vmid_off, int, 0444);
module_param(rm_off, int, 0444);
module_param(vm_status_off, int, 0444);

/*
 * Namespace bit for the label we hand the RM.
 *
 * 6.12's in-tree driver started stamping parcel->label from the userspace region
 * label (vm_mgr_mem.c, "parcel->label = b->label"); 6.6 left it 0 for every parcel
 * it made. Our labels come from crosvm too, so from 6.12 on the two share one
 * namespace and a collision means the RM sees two parcels of one VM under the same
 * label -- a share refused, or worse a reclaim landing on the driver's parcel.
 *
 * Only the RM-facing copy is namespaced: the ioctl ABI, our (vm,label) table and
 * every log line keep crosvm's own label, so nothing outside this file notices.
 * The guest is unaffected -- it accepts by handle with validate_label=0.
 * Applied on 6.6 as well: harmless there, and one code path beats two.
 */
#define GHSM_LABEL_NS	BIT(31)

/* 6.12 added this terminal VM state; on 6.6 the enum stops short of it, so the
 * comparison simply never fires there. */
#define GHSM_VM_STATUS_RESET_FAILED	12

/* Defined here rather than beside its siblings below because the reaper, which is
 * the only caller, comes first in this file. Safe ONLY while the map still holds
 * the VM's file -- see struct ghsm_map. */
static inline u32 ghvm_status(void *ghvm)
{
	return *(u32 *)((u8 *)ghvm + vm_status_off);
}

/* ---- resolved-at-load symbols ---- */
struct gunyah_rm;
static int (*p_rm_mem_share)(struct gunyah_rm *rm, struct gunyah_rm_mem_parcel *p);
static int (*p_rm_mem_reclaim)(struct gunyah_rm *rm, struct gunyah_rm_mem_parcel *p);
/* gunyah_rm_get_vmid is global (T) but NOT in the GKI module KMI whitelist, so
 * it cannot be linked; resolve it via kallsyms like the mem_share helpers. */
static int (*p_rm_get_vmid)(struct gunyah_rm *rm, u16 *vmid);
#define gunyah_rm_get_vmid(rm, vmid) p_rm_get_vmid((rm), (vmid))
/* Optional (best-effort) RM device refcounting, so a cached rm pointer stays
 * valid for deferred reclaim after the owning VM is destroyed. */
static struct device *(*p_rm_get)(struct gunyah_rm *rm);
static void (*p_rm_put)(struct gunyah_rm *rm);
/* Synchronous fput for the rmmod path: a plain fput() defers the file release
 * to task_work, which cannot run until the rmmod syscall returns — so zombie
 * VMs would never tear down inside ghsm_exit's retry loop. */
static void (*p_fput_sync)(struct file *f);

/* Registered in ghsm_init(); also used as the DMA-BUF importer device. */
static struct miscdevice ghsm_dev;

static unsigned long lookup_name(const char *name)
{
	static unsigned long (*kln)(const char *);
	struct kprobe kp = { .symbol_name = "kallsyms_lookup_name" };
	if (!kln) {
		if (register_kprobe(&kp))
			return 0;
		kln = (void *)kp.addr;
		unregister_kprobe(&kp);
	}
	return kln ? kln(name) : 0;
}

/* ---- tracked live parcels (per (vm,label)) so we can reclaim + unpin ---- */
struct ghsm_map {
	struct list_head node;
	void *ghvm;			/* struct gunyah_vm* (identity only; NEVER
					 * dereferenced once vm_file is dropped) */
	struct file *vm_file;		/* pins the VM file so ghvm/rm stay valid;
					 * dropped on reclaim OR when deferring a
					 * dead VM's parcel (letting the VM tear
					 * down is what unblocks the reclaim) */
	struct gunyah_rm *rm;		/* cached at share time (+device ref via
					 * gunyah_rm_get) so deferred reclaim never
					 * touches a dead ghvm */
	u32 label;
	int retries;
	bool reset_failed;		/* the VM's reset failed (6.12+): it will never
					 * release the guest's accepts, so retrying the
					 * reclaim is pointless. Latched while vm_file
					 * still made ghvm safe to read. */
	bool dying;			/* reclaim this parcel regardless of VM
					 * liveness (explicit UNSHARE that the RM
					 * refused, or VM found ownerless) */
	struct page **pages;
	unsigned long npages;
	/* DMA-BUF source.  map_attachment pins/stabilizes the exporter backing for
	 * the whole memparcel lifetime, so this replaces pages[]/GUP when set. */
	struct dma_buf *dmabuf;
	struct dma_buf_attachment *attachment;
	struct sg_table *sgt;
	struct gunyah_rm_mem_parcel parcel;
};
static LIST_HEAD(ghsm_maps);
static DEFINE_MUTEX(ghsm_lock);

static struct ghsm_map *find_map(void *ghvm, u32 label)
{
	struct ghsm_map *m;
	list_for_each_entry(m, &ghsm_maps, node)
		if (m->ghvm == ghvm && m->label == label && !m->dying)
			return m;
	return NULL;
}

/* Free a map whose parcel was successfully reclaimed.  Only here do the pinned
 * pages go back to the kernel — pages the RM/hypervisor may still map are
 * never unpinned (leak-over-corruption). */
static void ghsm_map_free(struct ghsm_map *m)
{
	if (m->dmabuf) {
		dma_buf_unmap_attachment(m->attachment, m->sgt,
					 DMA_BIDIRECTIONAL);
		dma_buf_detach(m->dmabuf, m->attachment);
		dma_buf_put(m->dmabuf);
	} else {
		unpin_user_pages(m->pages, m->npages);
	}
	if (m->vm_file)
		fput(m->vm_file);
	if (p_rm_put)
		p_rm_put(m->rm);
	kvfree(m->pages);
	kfree(m->parcel.acl_entries);
	kvfree(m->parcel.mem_entries);	/* kvcalloc'd in ghsm_share() */
	kfree(m);
}

/* Try to reclaim a (detached) map's parcel.  0 = reclaimed and freed.  On
 * failure the vm-file ref is dropped so the (dead) VM can finish tearing down
 * — the RM releases the guest's accepts at VM stop/reset, which is what makes
 * a later retry succeed — pages stay pinned, and the map stays allocated. */
static int ghsm_try_destroy(struct ghsm_map *m)
{
	int ret = p_rm_mem_reclaim(m->rm, &m->parcel);
	if (ret == 0) {
		ghsm_map_free(m);
		return 0;
	}
	if (m->vm_file) {
		fput(m->vm_file);
		m->vm_file = NULL;
	}
	return ret;
}

#define GHSM_REAP_INTERVAL	msecs_to_jiffies(2000)
#define GHSM_REAP_MAX_TRIES	60	/* ~2 min, then leak the pages (safe) */

static void ghsm_reaper(struct work_struct *work);
static DECLARE_DELAYED_WORK(ghsm_reaper_work, ghsm_reaper);

/*
 * GC tick, armed whenever any parcel exists.
 *
 * Liveness signal: each map holds a get_file() on its VM's file, so once
 * file_count(vm_file) equals the number of our own maps referencing it, every
 * crosvm fd to that VM is gone — crosvm died (crosvm cannot issue shares
 * without holding the VM fd, and it keeps it for the VM's lifetime).  This is
 * deliberately NOT keyed on /dev/gunyah_share fds: crosvm opens that device
 * freshly for every SHARE/UNSHARE ioctl, so a per-fd .release would reclaim
 * parcels that are very much alive.
 *
 * Dying parcels are reclaimed with retries: the RM refuses while the zombie
 * VM still holds the guest's accepts; ghsm_try_destroy drops our vm-file ref
 * on failure, the VM tears down (RM releases the accepts, gh_hugepage_reserve
 * sees the destroy and sweeps its owner), and the next tick's reclaim goes
 * through.  Pages return to the buddy allocator at order 9, where the reserve
 * pool's free hook pulls them back.
 */
static void ghsm_reaper(struct work_struct *work)
{
	struct ghsm_map *m, *tmp, *n;
	bool rearm = false;

	mutex_lock(&ghsm_lock);

	/* Pass 1: mark every parcel of an ownerless (dead-crosvm) VM dying. */
	list_for_each_entry(m, &ghsm_maps, node) {
		long ours = 0;

		if (m->dying || !m->vm_file)
			continue;
		list_for_each_entry(n, &ghsm_maps, node)
			if (n->vm_file == m->vm_file)
				ours++;
		if (file_count(m->vm_file) > ours)
			continue;	/* crosvm still holds the VM fd */
		pr_info("VM of parcel label=%u is ownerless — reclaiming its parcels\n",
			m->label);
		list_for_each_entry(n, &ghsm_maps, node)
			if (n->vm_file == m->vm_file)
				n->dying = true;
	}

	/* Pass 2: reclaim dying parcels. */
	list_for_each_entry_safe(m, tmp, &ghsm_maps, node) {
		u32 label = m->label;
		unsigned long npages = m->npages;

		if (!m->dying || m->retries >= GHSM_REAP_MAX_TRIES)
			continue;

		/*
		 * Read the VM's state while we still hold its file -- that ref is the
		 * only thing keeping ghvm from being freed, and the first failed
		 * reclaim drops it. A VM whose reset failed never releases the guest's
		 * accepts, so the retry budget would be spent for nothing and end in
		 * the same leak two minutes later. Latch it and give up now.
		 */
		if (m->vm_file && ghvm_status(m->ghvm) == GHSM_VM_STATUS_RESET_FAILED)
			m->reset_failed = true;
		if (m->reset_failed) {
			pr_warn("VM of parcel label=%u failed to reset — giving up now, leaking %lu pinned pages\n",
				label, npages);
			m->retries = GHSM_REAP_MAX_TRIES;
			if (m->vm_file) {
				fput(m->vm_file);
				m->vm_file = NULL;
			}
			continue;
		}

		list_del(&m->node);
		if (ghsm_try_destroy(m) == 0) {
			pr_info("reaper reclaimed parcel label=%u pages=%lu\n",
				label, npages);
			continue;
		}
		m->retries++;
		list_add_tail(&m->node, &ghsm_maps);
		if (m->retries >= GHSM_REAP_MAX_TRIES)
			pr_warn("reaper giving up on parcel label=%u — leaking %lu pinned pages\n",
				label, npages);
	}

	/* Keep ticking while anything needs watching (skip parked leaks). */
	list_for_each_entry(m, &ghsm_maps, node) {
		if (!(m->dying && m->retries >= GHSM_REAP_MAX_TRIES)) {
			rearm = true;
			break;
		}
	}
	if (rearm)
		schedule_delayed_work(&ghsm_reaper_work, GHSM_REAP_INTERVAL);
	mutex_unlock(&ghsm_lock);
}

/* Resolve a userspace gunyah VM fd to its struct gunyah_vm*, validated by the
 * anon-inode name "gunyah-vm" (anon_inode_getfile in vm_mgr.c). Returns the file
 * (caller must fput) via *out_file, and the ghvm pointer. */
static void *ghsm_get_ghvm(int vm_fd, struct file **out_file)
{
	struct file *f = fget(vm_fd);
	if (!f)
		return NULL;
	if (!f->f_path.dentry ||
	    strcmp(f->f_path.dentry->d_name.name, "gunyah-vm") != 0) {
		fput(f);
		return NULL;
	}
	*out_file = f;
	return f->private_data;
}

static inline u16 ghvm_vmid(void *ghvm) { return *(u16 *)((u8 *)ghvm + vmid_off); }
static inline struct gunyah_rm *ghvm_rm(void *ghvm)
{
	return *(struct gunyah_rm **)((u8 *)ghvm + rm_off);
}

static u8 flags_to_perms(u32 flags)
{
	u8 p = 0;
	if (flags & GH_ALLOW_READ)  p |= GUNYAH_RM_ACL_R;
	if (flags & GH_ALLOW_WRITE) p |= GUNYAH_RM_ACL_W;
	if (flags & GH_ALLOW_EXEC)  p |= GUNYAH_RM_ACL_X;
	return p;
}

/* Submit a fully-built map to the RM and publish it in the live table.  The
 * caller still owns @m on failure and must unwind its chosen backing type. */
static int ghsm_submit_share(struct ghsm_map *m, u16 guest_vmid,
			     u32 *out_handle)
{
	int ret, tries;

	/* RM occasionally rejects a share transiently while a just-reclaimed
	 * parcel is still settling.  Keep the existing bounded retry behavior for
	 * both GUP and DMA-BUF sources. */
	for (tries = 0; tries < 8; tries++) {
		ret = p_rm_mem_share(m->rm, &m->parcel);
		if (!ret)
			break;
		usleep_range(500, 1500);
	}
	if (ret) {
		pr_err("rm_mem_share label=%u ret=%d (after %d tries)\n",
		       m->label, ret, tries);
		return ret;
	}
	if (tries)
		pr_info("share label=%u succeeded after %d retries\n",
			m->label, tries);

	*out_handle = m->parcel.mem_handle;
	mutex_lock(&ghsm_lock);
	list_add(&m->node, &ghsm_maps);
	schedule_delayed_work(&ghsm_reaper_work, GHSM_REAP_INTERVAL);
	mutex_unlock(&ghsm_lock);
	pr_info("SHARE label=%u gpa_pages=%lu entries=%zu source=%s guest_vmid=%u handle=0x%x\n",
		m->label, m->npages, m->parcel.n_mem_entries,
		m->dmabuf ? "dmabuf" : "gup", guest_vmid, *out_handle);
	return 0;
}

/* Core: pin the userspace buffer, build a SHARE parcel (guest keeps host access),
 * hand it to the RM, return the handle. Mirrors gunyah_gup_share_parcel. */
static int ghsm_share(void *ghvm, struct file *vmf, struct gunyah_rm *rm,
		      u32 label, u32 flags, u64 uaddr, u64 size, u32 *out_handle)
{
	unsigned long npages, i, n_entries, entry;
	struct page **pages;
	struct ghsm_map *m;
	u16 guest_vmid, host_vmid;
	unsigned int gup_flags;
	u64 run_size;
	long pinned;
	int ret;

	if (!IS_ALIGNED(uaddr, PAGE_SIZE) || !IS_ALIGNED(size, PAGE_SIZE) || !size)
		return -EINVAL;
	npages = size >> PAGE_SHIFT;

	mutex_lock(&ghsm_lock);
	if (find_map(ghvm, label)) {
		mutex_unlock(&ghsm_lock);
		return -EBUSY;		/* guest must UNSHARE the old parcel first */
	}
	mutex_unlock(&ghsm_lock);

	/* kvcalloc: a 24MB blob needs a 48KB pointer array; under host fragmentation the
	 * order-4 kmalloc intermittently ENOMEMs, killing the share. vmalloc fallback is fine
	 * here (slow path, freed with kvfree). */
	pages = kvcalloc(npages, sizeof(*pages), GFP_KERNEL_ACCOUNT);
	if (!pages) {
		pr_err("SHARE label=%u: pages[] alloc failed (npages=%lu)\n", label, npages);
		return -ENOMEM;
	}

	gup_flags = FOLL_LONGTERM;
	if (flags & GH_ALLOW_WRITE)
		gup_flags |= FOLL_WRITE;
	pinned = pin_user_pages_fast(uaddr, npages, gup_flags, pages);
	if (pinned < 0) {
		/* FOLL_LONGTERM on CMA-resident pages (our folio reserve) forces a migration
		 * out of CMA first; under host fragmentation that migration ENOMEMs. Log it:
		 * this failure is otherwise silent and reaches the guest as a bare map error. */
		pr_err("SHARE label=%u: pin_user_pages_fast(npages=%lu, LONGTERM) failed: %ld\n",
		       label, npages, pinned);
		ret = pinned;
		goto free_pages;
	}
	if (pinned != npages) {
		pr_err("SHARE label=%u: short pin %ld/%lu\n", label, pinned, npages);
		ret = -EFAULT;
		goto unpin;
	}

	m = kzalloc(sizeof(*m), GFP_KERNEL);
	if (!m) { ret = -ENOMEM; goto unpin; }
	m->ghvm = ghvm; m->label = label; m->pages = pages; m->npages = npages;
	m->vm_file = get_file(vmf);
	m->rm = rm;
	if (p_rm_get)
		p_rm_get(rm);

	/* SHARE: 2 ACL entries — guest (from flags) + host (RWX). */
	guest_vmid = ghvm_vmid(ghvm);
	ret = gunyah_rm_get_vmid(rm, &host_vmid);
	if (ret) goto free_m;

	m->parcel.mem_type = GUNYAH_RM_MEM_TYPE_NORMAL;
	m->parcel.label = label | GHSM_LABEL_NS;
	m->parcel.mem_handle = GUNYAH_MEM_HANDLE_INVAL;
	m->parcel.n_acl_entries = 2;
	m->parcel.acl_entries = kcalloc(2, sizeof(*m->parcel.acl_entries), GFP_KERNEL);
	if (!m->parcel.acl_entries) { ret = -ENOMEM; goto free_m; }
	m->parcel.acl_entries[0].vmid = cpu_to_le16(guest_vmid);
	m->parcel.acl_entries[0].perms = flags_to_perms(flags);
	m->parcel.acl_entries[1].vmid = cpu_to_le16(host_vmid);
	m->parcel.acl_entries[1].perms = GUNYAH_RM_ACL_R | GUNYAH_RM_ACL_W | GUNYAH_RM_ACL_X;

	/* Coalesce physically-contiguous page runs into single mem_entries.
	 * THP/mthp-backed buffers (2MB folios) collapse 512:1, which is what
	 * keeps large blobs under the RM's per-parcel resource limits. */
	n_entries = 1;
	for (i = 1; i < npages; i++) {
		if (page_to_phys(pages[i]) != page_to_phys(pages[i - 1]) + PAGE_SIZE)
			n_entries++;
	}
	m->parcel.n_mem_entries = n_entries;
	/* kvcalloc for the same reason as pages[] above, and it is the harder case:
	 * when coalescing fails (a fragmented host has no 2MB folios to collapse)
	 * n_entries approaches npages, so a 128MB pool-grow step needs 32768 * 16B
	 * = a 512KB order-7 contiguous kmalloc. That ENOMEMs on a long-uptime
	 * fragmented host, and the failure surfaces far away: SHARE fails -> the
	 * guest's gpu_guest pool cannot grow -> a large guest blob fails to
	 * allocate -> GL_OUT_OF_MEMORY inside the guest app. Freed with kvfree. */
	m->parcel.mem_entries = kvcalloc(n_entries, sizeof(*m->parcel.mem_entries),
					 GFP_KERNEL_ACCOUNT);
	if (!m->parcel.mem_entries) { ret = -ENOMEM; goto free_acl; }
	entry = 0;
	m->parcel.mem_entries[0].phys_addr = cpu_to_le64(page_to_phys(pages[0]));
	run_size = PAGE_SIZE;
	for (i = 1; i < npages; i++) {
		if (page_to_phys(pages[i]) == page_to_phys(pages[i - 1]) + PAGE_SIZE) {
			run_size += PAGE_SIZE;
			continue;
		}
		m->parcel.mem_entries[entry].size = cpu_to_le64(run_size);
		entry++;
		m->parcel.mem_entries[entry].phys_addr =
			cpu_to_le64(page_to_phys(pages[i]));
		run_size = PAGE_SIZE;
	}
	m->parcel.mem_entries[entry].size = cpu_to_le64(run_size);

	ret = ghsm_submit_share(m, guest_vmid, out_handle);
	if (!ret)
		return 0;

	kvfree(m->parcel.mem_entries);
free_acl:
	kfree(m->parcel.acl_entries);
free_m:
	if (p_rm_put)
		p_rm_put(m->rm);
	fput(m->vm_file);
	kfree(m);
unpin:
	unpin_user_pages(pages, pinned > 0 ? pinned : 0);
free_pages:
	kvfree(pages);
	return ret;
}

/* Share an existing DMA-BUF without going through its userspace VMA.  The
 * attachment is the lifetime pin; the RM receives physical runs sliced from
 * the exporter's sg-table. */
static int ghsm_share_dmabuf(void *ghvm, struct file *vmf,
			     struct gunyah_rm *rm, u32 label, u32 flags,
			     int dmabuf_fd, u64 offset, u64 size,
			     u32 *out_handle)
{
	struct dma_buf_attachment *attachment;
	struct gunyah_rm_mem_entry *entries;
	struct dma_buf *dmabuf;
	struct ghsm_map *m;
	struct scatterlist *sg;
	u64 skip, remain;
	u16 guest_vmid, host_vmid;
	unsigned int i;
	size_t n_entries = 0;
	int ret;

	if (!IS_ALIGNED(offset, PAGE_SIZE) || !IS_ALIGNED(size, PAGE_SIZE) || !size)
		return -EINVAL;

	mutex_lock(&ghsm_lock);
	if (find_map(ghvm, label)) {
		mutex_unlock(&ghsm_lock);
		return -EBUSY;
	}
	mutex_unlock(&ghsm_lock);

	dmabuf = dma_buf_get(dmabuf_fd);
	if (IS_ERR(dmabuf)) {
		/* Tell userspace that an ordinary fd should use the VA/GUP ioctl. */
		ret = PTR_ERR(dmabuf);
		return ret == -EINVAL ? -ENOTTY : ret;
	}
	if (offset > dmabuf->size || size > dmabuf->size - offset) {
		ret = -EINVAL;
		goto put_dmabuf;
	}

	attachment = dma_buf_attach(dmabuf, ghsm_dev.this_device);
	if (IS_ERR(attachment)) {
		ret = PTR_ERR(attachment);
		pr_err("SHARE_DMABUF label=%u: attach failed: %d\n", label, ret);
		goto put_dmabuf;
	}
	m = kzalloc(sizeof(*m), GFP_KERNEL);
	if (!m) {
		ret = -ENOMEM;
		goto detach;
	}
	m->sgt = dma_buf_map_attachment(attachment, DMA_BIDIRECTIONAL);
	if (IS_ERR(m->sgt)) {
		ret = PTR_ERR(m->sgt);
		pr_err("SHARE_DMABUF label=%u: map_attachment failed: %d\n",
		       label, ret);
		m->sgt = NULL;
		goto free_m_only;
	}
	if (!m->sgt->orig_nents) {
		ret = -EINVAL;
		goto unmap;
	}

	/* At most one output run per source SG entry; adjacent physical runs are
	 * folded below. */
	entries = kvcalloc(m->sgt->orig_nents, sizeof(*entries),
			   GFP_KERNEL_ACCOUNT);
	if (!entries) {
		ret = -ENOMEM;
		goto unmap;
	}

	skip = offset;
	remain = size;
	for_each_sgtable_sg(m->sgt, sg, i) {
		u64 phys, take;

		if (!remain)
			break;
		if (skip >= sg->length) {
			skip -= sg->length;
			continue;
		}
		phys = sg_phys(sg) + skip;
		take = min_t(u64, (u64)sg->length - skip, remain);
		if (!IS_ALIGNED(phys, PAGE_SIZE) || !IS_ALIGNED(take, PAGE_SIZE)) {
			pr_err("SHARE_DMABUF label=%u: unaligned SG phys=%#llx len=%#llx\n",
			       label, phys, take);
			ret = -EINVAL;
			goto free_entries_dmabuf;
		}
		if (n_entries &&
		    le64_to_cpu(entries[n_entries - 1].phys_addr) +
		    le64_to_cpu(entries[n_entries - 1].size) == phys) {
			entries[n_entries - 1].size = cpu_to_le64(
				le64_to_cpu(entries[n_entries - 1].size) + take);
		} else {
			entries[n_entries].phys_addr = cpu_to_le64(phys);
			entries[n_entries].size = cpu_to_le64(take);
			n_entries++;
		}
		remain -= take;
		skip = 0;
	}
	if (remain) {
		pr_err("SHARE_DMABUF label=%u: sg-table short by %#llx bytes\n",
		       label, remain);
		ret = -EINVAL;
		goto free_entries_dmabuf;
	}

	m->ghvm = ghvm;
	m->label = label;
	m->npages = size >> PAGE_SHIFT;
	m->vm_file = get_file(vmf);
	m->rm = rm;
	m->dmabuf = dmabuf;
	m->attachment = attachment;
	if (p_rm_get)
		p_rm_get(rm);

	guest_vmid = ghvm_vmid(ghvm);
	ret = gunyah_rm_get_vmid(rm, &host_vmid);
	if (ret)
		goto free_tracked;
	m->parcel.mem_type = GUNYAH_RM_MEM_TYPE_NORMAL;
	m->parcel.label = label | GHSM_LABEL_NS;
	m->parcel.mem_handle = GUNYAH_MEM_HANDLE_INVAL;
	m->parcel.n_acl_entries = 2;
	m->parcel.acl_entries = kcalloc(2, sizeof(*m->parcel.acl_entries), GFP_KERNEL);
	if (!m->parcel.acl_entries) {
		ret = -ENOMEM;
		goto free_tracked;
	}
	m->parcel.acl_entries[0].vmid = cpu_to_le16(guest_vmid);
	m->parcel.acl_entries[0].perms = flags_to_perms(flags);
	m->parcel.acl_entries[1].vmid = cpu_to_le16(host_vmid);
	m->parcel.acl_entries[1].perms =
		GUNYAH_RM_ACL_R | GUNYAH_RM_ACL_W | GUNYAH_RM_ACL_X;
	m->parcel.n_mem_entries = n_entries;
	m->parcel.mem_entries = entries;

	ret = ghsm_submit_share(m, guest_vmid, out_handle);
	if (!ret)
		return 0;

	kfree(m->parcel.acl_entries);
free_tracked:
	if (p_rm_put)
		p_rm_put(m->rm);
	fput(m->vm_file);
	m->vm_file = NULL;
free_entries_dmabuf:
	kvfree(entries);
unmap:
	dma_buf_unmap_attachment(attachment, m->sgt, DMA_BIDIRECTIONAL);
free_m_only:
	kfree(m);
detach:
	dma_buf_detach(dmabuf, attachment);
put_dmabuf:
	dma_buf_put(dmabuf);
	return ret;
}

static int ghsm_unshare(void *ghvm, struct gunyah_rm *rm, u32 label)
{
	struct ghsm_map *m;
	int ret;

	mutex_lock(&ghsm_lock);
	m = find_map(ghvm, label);
	if (m)
		list_del(&m->node);
	mutex_unlock(&ghsm_lock);
	if (!m)
		return -ENOENT;

	ret = ghsm_try_destroy(m);
	if (ret) {
		/* Unexpected on a live VM (guest releases before crosvm
		 * unshares).  Keep the pages pinned and let the reaper retry
		 * rather than freeing memory the hypervisor may still map.
		 * dying=true also frees up (ghvm,label) for a re-share. */
		pr_warn("rm_mem_reclaim label=%u ret=%d — deferring to reaper\n",
			label, ret);
		mutex_lock(&ghsm_lock);
		m->retries = 0;
		m->dying = true;
		list_add_tail(&m->node, &ghsm_maps);
		schedule_delayed_work(&ghsm_reaper_work, GHSM_REAP_INTERVAL);
		mutex_unlock(&ghsm_lock);
		return ret;
	}
	pr_info("UNSHARE label=%u ret=0\n", label);
	return 0;
}

/* ---- /dev/gunyah_share char device ---- */
static long ghsm_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
	struct file *vmf = NULL;
	void *ghvm;
	struct gunyah_rm *rm;
	long ret;

	switch (cmd) {
	case GHSM_SHARE_BLOB: {
		struct ghsm_share_blob b;
		u32 handle = 0;
		if (copy_from_user(&b, (void __user *)arg, sizeof(b)))
			return -EFAULT;
		ghvm = ghsm_get_ghvm(b.vm_fd, &vmf);
		if (!ghvm) return -EINVAL;
		rm = ghvm_rm(ghvm);
		ret = ghsm_share(ghvm, vmf, rm, b.label, b.flags,
				 b.userspace_addr, b.memory_size, &handle);
		fput(vmf);
		if (ret) return ret;
		b.mem_handle = handle;
		if (copy_to_user((void __user *)arg, &b, sizeof(b)))
			return -EFAULT;
		return 0;
	}
	case GHSM_SHARE_DMABUF: {
		struct ghsm_share_dmabuf b;
		u32 handle = 0;
		if (copy_from_user(&b, (void __user *)arg, sizeof(b)))
			return -EFAULT;
		if (b.reserved)
			return -EINVAL;
		ghvm = ghsm_get_ghvm(b.vm_fd, &vmf);
		if (!ghvm)
			return -EINVAL;
		rm = ghvm_rm(ghvm);
		ret = ghsm_share_dmabuf(ghvm, vmf, rm, b.label, b.flags,
					b.dmabuf_fd, b.dmabuf_offset,
					b.memory_size, &handle);
		fput(vmf);
		if (ret)
			return ret;
		b.mem_handle = handle;
		if (copy_to_user((void __user *)arg, &b, sizeof(b)))
			return -EFAULT;
		return 0;
	}
	case GHSM_UNSHARE_BLOB: {
		struct ghsm_unshare_blob b;
		if (copy_from_user(&b, (void __user *)arg, sizeof(b)))
			return -EFAULT;
		ghvm = ghsm_get_ghvm(b.vm_fd, &vmf);
		if (!ghvm) return -EINVAL;
		rm = ghvm_rm(ghvm);
		ret = ghsm_unshare(ghvm, rm, b.label);
		fput(vmf);
		return ret;
	}
	default:
		return -ENOTTY;
	}
}

static const struct file_operations ghsm_fops = {
	.owner = THIS_MODULE,
	.unlocked_ioctl = ghsm_ioctl,
	.compat_ioctl = ghsm_ioctl,
};
static struct miscdevice ghsm_dev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = "gunyah_share",
	.fops = &ghsm_fops,
	.mode = 0600,
};

/* ---- debugfs probe for standalone bring-up (no crosvm): ----
 *   echo "<vm_fd> <size_hex> <label>" > /sys/kernel/debug/gh_share_probe
 * runs in the echoing process's fd table, so that process must hold the VM fd.
 * Allocates size bytes, fills a magic pattern, SHAREs to the guest, prints the
 * handle+gpa-agnostic parcel (the guest accepts by handle). Intentionally leaks
 * the pages so the guest can accept and read them. */
static struct dentry *ghsm_dbg;
static ssize_t gsp_write(struct file *f, const char __user *ub, size_t len, loff_t *off)
{
	char buf[64]; int vm_fd; u64 size; u32 label, handle = 0, *p; unsigned long i;
	struct file *vmf = NULL; void *ghvm; struct gunyah_rm *rm; long ret;
	void *va; struct page **pages; unsigned long npages;

	if (len >= sizeof(buf)) return -EINVAL;
	if (copy_from_user(buf, ub, len)) return -EFAULT;
	buf[len] = 0;
	if (sscanf(buf, "%d %llx %u", &vm_fd, &size, &label) != 3) return -EINVAL;
	size = PAGE_ALIGN(size);
	npages = size >> PAGE_SHIFT;

	ghvm = ghsm_get_ghvm(vm_fd, &vmf);
	if (!ghvm) return -EINVAL;
	rm = ghvm_rm(ghvm);

	va = vmalloc_user(size);		/* page-aligned, user-mappable */
	if (!va) { fput(vmf); return -ENOMEM; }
	p = va;
	for (i = 0; i < size / 4; i++) p[i] = 0xA5A50000u | (u32)i;  /* magic */

	pages = kcalloc(npages, sizeof(*pages), GFP_KERNEL);
	if (!pages) { vfree(va); fput(vmf); return -ENOMEM; }
	for (i = 0; i < npages; i++) pages[i] = vmalloc_to_page(va + i * PAGE_SIZE);

	{
		struct ghsm_map *m = kzalloc(sizeof(*m), GFP_KERNEL);
		u16 gvm = ghvm_vmid(ghvm), hvm;
		if (!m) { kfree(pages); vfree(va); fput(vmf); return -ENOMEM; }
		if (gunyah_rm_get_vmid(rm, &hvm)) { kfree(m); kfree(pages); vfree(va); fput(vmf); return -EIO; }
		m->parcel.mem_type = GUNYAH_RM_MEM_TYPE_NORMAL;
		m->parcel.label = label | GHSM_LABEL_NS;
		m->parcel.mem_handle = GUNYAH_MEM_HANDLE_INVAL;
		m->parcel.n_acl_entries = 2;
		m->parcel.acl_entries = kcalloc(2, sizeof(struct gunyah_rm_mem_acl_entry), GFP_KERNEL);
		m->parcel.acl_entries[0].vmid = cpu_to_le16(gvm);
		m->parcel.acl_entries[0].perms = GUNYAH_RM_ACL_R | GUNYAH_RM_ACL_W;
		m->parcel.acl_entries[1].vmid = cpu_to_le16(hvm);
		m->parcel.acl_entries[1].perms = GUNYAH_RM_ACL_R | GUNYAH_RM_ACL_W | GUNYAH_RM_ACL_X;
		m->parcel.n_mem_entries = npages;
		m->parcel.mem_entries = kcalloc(npages, sizeof(struct gunyah_rm_mem_entry), GFP_KERNEL);
		for (i = 0; i < npages; i++) {
			m->parcel.mem_entries[i].phys_addr = cpu_to_le64(page_to_phys(pages[i]));
			m->parcel.mem_entries[i].size = cpu_to_le64(PAGE_SIZE);
		}
		ret = p_rm_mem_share(rm, &m->parcel);
		handle = m->parcel.mem_handle;
		pr_info("GSP: SHARE probe vm_fd=%d guest_vmid=%u size=0x%llx label=%u => ret=%ld handle=0x%x magic=0xA5A5xxxx (LEAKED for guest accept)\n",
			vm_fd, gvm, size, label, ret, handle);
		/* leak m/pages/va intentionally */
	}
	kfree(pages);		/* the pages[] array; underlying vmalloc pages stay pinned by parcel */
	fput(vmf);
	return ret ? ret : len;
}
static const struct file_operations gsp_fops = { .owner = THIS_MODULE, .write = gsp_write };

/* outstanding: read-only live view of the tracked-parcel table */
static int ghsm_outstanding_get(char *buf, const struct kernel_param *kp)
{
	struct ghsm_map *m;
	int total = 0, dying = 0, parked = 0, n = 0;

	mutex_lock(&ghsm_lock);
	list_for_each_entry(m, &ghsm_maps, node) {
		total++;
		if (m->dying) {
			dying++;
			if (m->retries >= GHSM_REAP_MAX_TRIES)
				parked++;
		}
	}
	n += sysfs_emit_at(buf, n, "total=%d dying=%d parked=%d\n",
			   total, dying, parked);
	list_for_each_entry(m, &ghsm_maps, node) {
		if (n > PAGE_SIZE - 128)
			break;
		n += sysfs_emit_at(buf, n,
				   "label=%u pages=%lu dying=%d retries=%d vm_held=%d reset_failed=%d\n",
				   m->label, m->npages, m->dying, m->retries,
				   !!m->vm_file, m->reset_failed);
	}
	mutex_unlock(&ghsm_lock);
	return n;
}
static const struct kernel_param_ops ghsm_outstanding_ops = {
	.get = ghsm_outstanding_get,
};
module_param_cb(outstanding, &ghsm_outstanding_ops, NULL, 0444);
MODULE_PARM_DESC(outstanding, "Live tracked-parcel table (read-only)");

static int __init ghsm_init(void)
{
	int ret;
	p_rm_mem_share = (void *)lookup_name("gunyah_rm_mem_share");
	p_rm_mem_reclaim = (void *)lookup_name("gunyah_rm_mem_reclaim");
	p_rm_get_vmid = (void *)lookup_name("gunyah_rm_get_vmid");
	if (!p_rm_mem_share || !p_rm_mem_reclaim || !p_rm_get_vmid) {
		pr_err("cannot resolve gunyah_rm_mem_share/reclaim/get_vmid (gunyah loaded first?)\n");
		return -ENOENT;
	}
	/* Best-effort: without these, deferred reclaim relies on the RM device
	 * outliving VMs (it does in practice — it's the platform driver). */
	p_rm_get = (void *)lookup_name("gunyah_rm_get");
	p_rm_put = (void *)lookup_name("gunyah_rm_put");
	if (!p_rm_get || !p_rm_put)
		p_rm_get = NULL, p_rm_put = NULL;
	p_fput_sync = (void *)lookup_name("__fput_sync");
	ret = misc_register(&ghsm_dev);
	if (ret) return ret;
	ret = dma_coerce_mask_and_coherent(ghsm_dev.this_device, DMA_BIT_MASK(64));
	if (ret) {
		misc_deregister(&ghsm_dev);
		return ret;
	}
	ghsm_dbg = debugfs_create_file("gh_share_probe", 0200, NULL, NULL, &gsp_fops);
	pr_info("loaded v6/dmabuf+gup (share=%px reclaim=%px rm_ref=%d vmid_off=%d rm_off=%d)\n",
		p_rm_mem_share, p_rm_mem_reclaim, !!p_rm_get, vmid_off, rm_off);
	return 0;
}
static void __exit ghsm_exit(void)
{
	struct ghsm_map *m, *tmp;
	LIST_HEAD(all);
	int tries, leaked = 0;

	debugfs_remove(ghsm_dbg);
	misc_deregister(&ghsm_dev);	/* no open fds remain (.owner refcount) */
	cancel_delayed_work_sync(&ghsm_reaper_work);

	mutex_lock(&ghsm_lock);
	list_splice_init(&ghsm_maps, &all);
	mutex_unlock(&ghsm_lock);

	/* Drop vm-file refs SYNCHRONOUSLY first so zombie VMs tear down now;
	 * a deferred fput would not run until this syscall returns and the
	 * retry loop below would never see the reclaim unblock. */
	list_for_each_entry(m, &all, node) {
		if (m->vm_file) {
			if (p_fput_sync)
				p_fput_sync(m->vm_file);
			else
				fput(m->vm_file);
			m->vm_file = NULL;
		}
	}

	/* Bounded retry: reclaim goes through once the RM has released the
	 * (dead) guests' accepts at VM stop/reset. */
	for (tries = 0; tries < 10 && !list_empty(&all); tries++) {
		if (tries)
			msleep(1000);
		list_for_each_entry_safe(m, tmp, &all, node) {
			list_del(&m->node);
			if (ghsm_try_destroy(m))
				list_add_tail(&m->node, &all);
		}
	}
	/* Whatever the RM still refuses: leak the pinned pages rather than free
	 * memory a zombie VM's stage-2 may still map. */
	list_for_each_entry_safe(m, tmp, &all, node) {
		list_del(&m->node);
		pr_warn("unload: parcel label=%u unreclaimable — leaking %lu pinned pages\n",
			m->label, m->npages);
		if (p_rm_put)
			p_rm_put(m->rm);
		kvfree(m->pages); kfree(m->parcel.acl_entries);
		kvfree(m->parcel.mem_entries); kfree(m);
		leaked++;
	}
	pr_info("unloaded (%d parcels leaked)\n", leaked);
}
module_init(ghsm_init);
module_exit(ghsm_exit);
MODULE_LICENSE("GPL");
MODULE_IMPORT_NS(DMA_BUF);
MODULE_DESCRIPTION("Standalone runtime SHARE_BLOB/DMABUF for upstream gunyah 6.6 (GuestAccept)");
