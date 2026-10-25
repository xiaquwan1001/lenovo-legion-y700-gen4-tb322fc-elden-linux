// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * gunyah_share_mod - standalone (out-of-tree) decoupling of the in-tree
 * gunyah SHARE_BLOB patch + the "命门探针" host-side lend/share probe.
 *
 * Goal: provide the exact same functionality as the in-tree modification to
 * drivers/virt/gunyah/{vm_mgr.c,vm_mgr_mm.c,gh_share_probe.c} WITHOUT touching
 * any kernel source file and as a loadable .ko.
 *
 * How it avoids modifying the kernel:
 *   1. The new ioctl could not be injected into gh_vm_ioctl()'s switch, so this
 *      module exposes its own /dev/gunyah_share node and takes the gunyah VM fd
 *      as a request field (see uapi_gunyah_share.h).
 *   2. gh_vm_mem_share_blob() (the patch's new function) is reimplemented here
 *      verbatim, calling the gunyah driver's internal helpers.
 *   3. The GLOBAL-but-unexported helpers (gh_vm_mem_alloc, gh_rm_mem_share,
 *      gh_rm_mem_lend, gh_rm_mem_reclaim, gh_rm_get_vmid) are resolved at load
 *      time via kallsyms (kprobe on kallsyms_lookup_name, the standard 5.7+
 *      technique); calling through the resolved pointer bypasses the
 *      EXPORT_SYMBOL link requirement. The driver's STATIC helpers
 *      (__gh_vm_mem_find_by_label, gh_vm_mem_reclaim_mapping) get inlined away
 *      on production builds -- no kallsyms entry -- so they are reimplemented
 *      locally instead. The VM fd is validated by its anon-inode name
 *      "gunyah-vm" rather than the static gh_vm_fops/gh_vm_ioctl symbol.
 *   4. struct gh_vm / struct gh_vm_mem are private to the gunyah driver. Their
 *      layout is vendored below VERBATIM from drivers/virt/gunyah/vm_mgr.h for
 *      this exact kernel (6.1.118). It is compiled against the same kernel
 *      headers/config, so the layout matches byte-for-byte.
 *
 * Requirements: CONFIG_KPROBES=y, CONFIG_KALLSYMS=y, the gunyah driver loaded
 * before this module, and (on signed kernels, CONFIG_MODULE_SIG_PROTECT=y) a
 * properly signed .ko or sig-enforcement disabled. See README.md.
 *
 * THIS IS FRAGILE BY DESIGN: it depends on the gunyah private struct layout and
 * on internal symbol names. If the gunyah driver changes, re-vendor the struct
 * and re-check the symbol list. Prefer the in-tree patch for anything shipping.
 */

#define pr_fmt(fmt) "gunyah_share: " fmt

#include <linux/debugfs.h>
#include <linux/file.h>
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/io.h>
#include <linux/kprobes.h>
#include <linux/list.h>
#include <linux/miscdevice.h>
#include <linux/mm.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/notifier.h>
#include <linux/rbtree.h>
#include <linux/rwsem.h>
#include <linux/sched.h>
#include <linux/sched/mm.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/types.h>
#include <linux/uaccess.h>
#include <linux/wait.h>
#include <linux/workqueue.h>

#include <linux/gunyah_rsc_mgr.h>
#include <linux/gunyah_vm_mgr.h>
#include <uapi/linux/gunyah.h>

#include "uapi_gunyah_share.h"

/* ------------------------------------------------------------------ */
/* Vendored gunyah private layout (drivers/virt/gunyah/vm_mgr.h, 6.1)  */
/* Keep these BYTE-IDENTICAL to the in-tree definitions.              */
/* ------------------------------------------------------------------ */

struct gh_vm_mem {
	struct list_head list;
	enum gh_vm_mem_share_type {
		VM_MEM_SHARE,
		VM_MEM_LEND,
	} share_type;
	struct gh_rm_mem_parcel parcel;

	__u64 guest_phys_addr;
	struct page **pages;
	unsigned long npages;
};

struct gh_vm {
	u16 vmid;
	struct gh_rm *rm;
	struct device *parent;
	enum gh_rm_vm_auth_mechanism auth;
	struct gh_vm_dtb_config dtb_config;
	struct gh_vm_firmware_config fw_config;

	struct notifier_block nb;
	enum gh_rm_vm_status vm_status;
	wait_queue_head_t vm_status_wait;
	struct rw_semaphore status_lock;
	struct gh_vm_exit_info exit_info;

	struct work_struct free_work;
	struct kref kref;
	struct mm_struct *mm; /* userspace tied to this vm */
	struct mutex mm_lock;
	struct list_head memory_mappings;
	struct mutex fn_lock;
	struct list_head functions;
	struct mutex resources_lock;
	struct list_head resources;
	struct list_head resource_tickets;
	struct rb_root mmio_handler_root;
	struct rw_semaphore mmio_handler_lock;
};

/* ------------------------------------------------------------------ */
/* Resolved gunyah internal symbols                                    */
/* ------------------------------------------------------------------ */

/*
 * Only GLOBAL (non-static) symbols are resolved via kallsyms: the gunyah
 * driver's static helpers get inlined by the compiler and have no kallsyms
 * entry on production builds, so we reimplement those locally instead.
 */
typedef int (*gh_vm_mem_alloc_t)(struct gh_vm *ghvm,
				 struct gh_userspace_memory_region *region,
				 bool lend);
typedef int (*rm_mem_share_t)(struct gh_rm *rm, struct gh_rm_mem_parcel *parcel);
typedef int (*rm_mem_lend_t)(struct gh_rm *rm, struct gh_rm_mem_parcel *parcel);
typedef int (*rm_mem_reclaim_t)(struct gh_rm *rm, struct gh_rm_mem_parcel *parcel);
typedef int (*rm_get_vmid_t)(struct gh_rm *rm, u16 *vmid);

static gh_vm_mem_alloc_t p_gh_vm_mem_alloc;
static rm_mem_share_t p_rm_mem_share;
static rm_mem_lend_t p_rm_mem_lend;
static rm_mem_reclaim_t p_rm_mem_reclaim;
static rm_get_vmid_t p_rm_get_vmid;
/* Global in kallsyms but not exported on some 6.1 vendor kernels (OPPO 6.1.118). */
static typeof(&account_locked_vm) p_account_locked_vm;

typedef unsigned long (*kln_t)(const char *name);
static kln_t kln;

static int resolve_kallsyms_lookup_name(void)
{
	struct kprobe kp = { .symbol_name = "kallsyms_lookup_name" };
	int ret;

	ret = register_kprobe(&kp);
	if (ret < 0) {
		pr_err("register_kprobe(kallsyms_lookup_name) failed: %d\n", ret);
		return ret;
	}
	kln = (kln_t)kp.addr;
	unregister_kprobe(&kp);
	if (!kln) {
		pr_err("could not obtain kallsyms_lookup_name address\n");
		return -ENOENT;
	}
	return 0;
}

#define RESOLVE(dst, name)                                             \
	do {                                                           \
		unsigned long _a = kln(name);                          \
		if (!_a) {                                              \
			pr_err("symbol not found: %s\n", name);        \
			return -ENOENT;                                \
		}                                                      \
		(dst) = (void *)_a;                                    \
	} while (0)

static int resolve_symbols(void)
{
	int ret = resolve_kallsyms_lookup_name();

	if (ret)
		return ret;

	/*
	 * The static helpers __gh_vm_mem_find_by_label() and
	 * gh_vm_mem_reclaim_mapping() are inlined away on production builds (no
	 * kallsyms entry) -- reimplemented locally as ghsm_find_by_label() and
	 * ghsm_reclaim_mapping(). The gunyah VM fd is validated by its anon-inode
	 * name "gunyah-vm" instead of a static gh_vm_ioctl/gh_vm_fops symbol.
	 * Hence only these GLOBAL symbols are resolved:
	 */
	RESOLVE(p_gh_vm_mem_alloc, "gh_vm_mem_alloc");
	RESOLVE(p_rm_mem_share, "gh_rm_mem_share");
	RESOLVE(p_rm_mem_lend, "gh_rm_mem_lend");
	RESOLVE(p_rm_mem_reclaim, "gh_rm_mem_reclaim");
	RESOLVE(p_rm_get_vmid, "gh_rm_get_vmid");
	RESOLVE(p_account_locked_vm, "account_locked_vm");
	return 0;
}

/* ------------------------------------------------------------------ */
/* SHARE_BLOB - verbatim reimplementation of gh_vm_mem_share_blob()    */
/* ------------------------------------------------------------------ */

/* Local reimplementation of the inlined static __gh_vm_mem_find_by_label(). */
static struct gh_vm_mem *ghsm_find_by_label(struct gh_vm *ghvm, u32 label)
{
	struct gh_vm_mem *mapping;

	list_for_each_entry(mapping, &ghvm->memory_mappings, list)
		if (mapping->parcel.label == label)
			return mapping;
	return NULL;
}

/*
 * Local reimplementation of the inlined static gh_vm_mem_reclaim_mapping().
 * Verbatim to the in-tree helper; uses only the resolved gh_rm_mem_reclaim and
 * exported unpin_user_pages/account_locked_vm. Caller holds ghvm->mm_lock.
 */
static void ghsm_reclaim_mapping(struct gh_vm *ghvm, struct gh_vm_mem *mapping)
{
	int ret = 0;

	if (mapping->parcel.mem_handle != GH_MEM_HANDLE_INVAL) {
		ret = p_rm_mem_reclaim(ghvm->rm, &mapping->parcel);
		if (ret)
			pr_warn("failed to reclaim memory parcel for label %d: %d\n",
				mapping->parcel.label, ret);
	}

	if (!ret) {
		unpin_user_pages(mapping->pages, mapping->npages);
		p_account_locked_vm(ghvm->mm, mapping->npages, false);
	}

	kvfree(mapping->pages);
	kfree(mapping->parcel.acl_entries);
	kvfree(mapping->parcel.mem_entries);

	list_del(&mapping->list);
}

/*
 * Same reclaim, but the mapping survives a refusal.
 *
 * ghsm_reclaim_mapping() is the in-tree helper verbatim, and the in-tree helper is only ever
 * called from teardown, where dropping a parcel the RM refused to reclaim costs nothing: the VM
 * is going away anyway. The reaper below calls it while the VM is still alive, so a refusal must
 * leave the mapping exactly as it was -- on the VM's list, pages pinned, parcel handle intact --
 * for the in-tree teardown to deal with. Returns the RM's error, 0 if the parcel is gone.
 */
static int ghsm_reclaim_mapping_if_free(struct gh_vm *ghvm, struct gh_vm_mem *mapping)
{
	int ret;

	if (mapping->parcel.mem_handle == GH_MEM_HANDLE_INVAL)
		return 0;

	ret = p_rm_mem_reclaim(ghvm->rm, &mapping->parcel);
	if (ret)
		return ret;

	unpin_user_pages(mapping->pages, mapping->npages);
	p_account_locked_vm(ghvm->mm, mapping->npages, false);
	kvfree(mapping->pages);
	kfree(mapping->parcel.acl_entries);
	kvfree(mapping->parcel.mem_entries);
	list_del(&mapping->list);
	kfree(mapping);
	return 0;
}

/* ------------------------------------------------------------------ */
/* Liveness GC: reclaim a dead crosvm's blobs before the VM tears down */
/* ------------------------------------------------------------------ */

/*
 * Ported from the 6.6/6.12 copy of this module, which needs it because it owns its parcels
 * outright. This copy does not: every blob goes through the driver's own gh_vm_mem_alloc(), so
 * it sits on ghvm->memory_mappings and the in-tree gh_vm_free() -> gh_vm_mem_reclaim() already
 * reclaims it when the VM object dies. What that path does NOT do is get there promptly: it
 * first calls gh_rm_vm_reset() and then waits, unconditionally, for the RM to report RESET --
 *
 *     ret = gh_rm_vm_reset(ghvm->rm, ghvm->vmid);
 *     if (ret) dev_err(ghvm->parent, "Failed to reset the vm: %d\n", ret);
 *     wait_event(ghvm->vm_status_wait, ghvm->vm_status == GH_RM_VM_STATUS_RESET);
 *
 * (drivers/virt/gunyah/vm_mgr.c, 6.1) -- so a VM that will not reset takes a kernel worker with
 * it and never reaches the reclaim. Clearing our SHAREs first is the one thing this module can
 * do about that, and it is worth doing on its own: a blob the guest already unmapped is pure
 * leftovers, and returning it costs nothing.
 *
 * Two things the 6.6 copy does are deliberately absent here:
 *   - no post-refusal retry. There, a cached rm reference lets a reclaim be retried after the
 *     VM file ref is dropped; here the parcel can only be reached through ghvm, which is only
 *     safe to touch while we hold that ref -- and holding it is exactly what stops the reset
 *     that would release the guest's accepts. So: one attempt, then get out of the way.
 *   - no RESET_FAILED latch. That state (12) does not exist in this kernel's enum, which stops
 *     at GH_RM_VM_STATUS_RESET = 11.
 */
struct ghsm_blob {
	struct list_head node;
	struct gh_vm *ghvm;	/* only dereferenced while vm_file is held */
	struct file *vm_file;	/* our ref; delays gh_vm_release() until we are done */
	u32 label;
};

static LIST_HEAD(ghsm_blobs);
static DEFINE_MUTEX(ghsm_blob_lock);

#define GHSM_REAP_INTERVAL msecs_to_jiffies(2000)

static void ghsm_reaper(struct work_struct *work);
static DECLARE_DELAYED_WORK(ghsm_reaper_work, ghsm_reaper);

/* Caller holds no locks. Takes a ref on the VM file that the reaper releases. */
static void ghsm_track(struct gh_vm *ghvm, struct file *vm_file, u32 label)
{
	struct ghsm_blob *b = kzalloc(sizeof(*b), GFP_KERNEL);

	if (!b) {
		pr_warn("cannot track label=%u (no memory); it will only be reclaimed at VM teardown\n",
			label);
		return;
	}
	b->ghvm = ghvm;
	b->vm_file = get_file(vm_file);
	b->label = label;

	mutex_lock(&ghsm_blob_lock);
	list_add_tail(&b->node, &ghsm_blobs);
	mutex_unlock(&ghsm_blob_lock);

	schedule_delayed_work(&ghsm_reaper_work, GHSM_REAP_INTERVAL);
}

static void ghsm_untrack(struct gh_vm *ghvm, u32 label)
{
	struct ghsm_blob *b, *tmp;

	mutex_lock(&ghsm_blob_lock);
	list_for_each_entry_safe(b, tmp, &ghsm_blobs, node) {
		if (b->ghvm != ghvm || b->label != label)
			continue;
		list_del(&b->node);
		fput(b->vm_file);
		kfree(b);
		break;
	}
	mutex_unlock(&ghsm_blob_lock);
}

/*
 * Liveness signal, same as the 6.6 copy: every tracked blob holds a get_file() on its VM's
 * file, so once file_count() is down to just our own refs, every crosvm fd to that VM is gone.
 * Keyed on the VM file and not on /dev/gunyah_share, which crosvm opens afresh for each ioctl.
 */
static void ghsm_reaper(struct work_struct *work)
{
	struct ghsm_blob *b, *tmp, *n;
	bool rearm = false;

	mutex_lock(&ghsm_blob_lock);
	list_for_each_entry_safe(b, tmp, &ghsm_blobs, node) {
		struct gh_vm *ghvm = b->ghvm;
		struct gh_vm_mem *mapping;
		u32 label = b->label;
		long ours = 0;
		int ret;

		list_for_each_entry(n, &ghsm_blobs, node)
			if (n->vm_file == b->vm_file)
				ours++;
		if (file_count(b->vm_file) > ours) {
			rearm = true;	/* crosvm still holds the VM fd */
			continue;
		}

		mutex_lock(&ghvm->mm_lock);
		mapping = ghsm_find_by_label(ghvm, label);
		ret = mapping ? ghsm_reclaim_mapping_if_free(ghvm, mapping) : 0;
		mutex_unlock(&ghvm->mm_lock);

		if (ret)
			pr_warn("crosvm is gone but the RM still refuses label=%u (%d) — leaving it to VM teardown\n",
				label, ret);
		else
			pr_info("crosvm is gone; reclaimed label=%u%s\n", label,
				mapping ? "" : " (already gone)");

		list_del(&b->node);
		fput(b->vm_file);
		kfree(b);
	}
	if (rearm)
		schedule_delayed_work(&ghsm_reaper_work, GHSM_REAP_INTERVAL);
	mutex_unlock(&ghsm_blob_lock);
}

/*
 * Reclaim a single blob by label: gh_rm_mem_reclaim + unpin + drop from the
 * VM's list. Called from the GHSM_UNSHARE_BLOB ioctl when the guest has unmapped
 * the blob (and already released its own stage-2 acceptance). Caller must NOT
 * hold ghvm->mm_lock (taken here).
 */
static int ghsm_unshare_by_label(struct gh_vm *ghvm, u32 label)
{
	struct gh_vm_mem *mapping;

	mutex_lock(&ghvm->mm_lock);
	mapping = ghsm_find_by_label(ghvm, label);
	if (!mapping) {
		mutex_unlock(&ghvm->mm_lock);
		return -ENOENT;
	}
	ghsm_reclaim_mapping(ghvm, mapping);
	kfree(mapping);
	mutex_unlock(&ghvm->mm_lock);
	pr_info("unshared blob label=%u\n", label);
	return 0;
}

static int ghsm_mem_share_blob(struct gh_vm *ghvm,
			       struct gh_userspace_memory_region *region,
			       u32 *mem_handle)
{
	struct gh_vm_mem *mapping;
	int ret;

	/*
	 * Blobs are now reclaimed explicitly at guest UNMAP time (GHSM_UNSHARE_BLOB),
	 * so the list should never already contain this label. If it does, the guest
	 * is reusing a GPA whose previous blob it has NOT unmapped (still LIVE) -- we
	 * must NOT reclaim it (reclaiming a live SHARE parcel succeeds on the RM owner
	 * side but leaves the guest stage-2 mapped, orphaning it and causing the next
	 * mem_share at that GPA to fail with EINVAL). Refuse cleanly instead; the guest
	 * then retries at a fresh offset.
	 */
	mutex_lock(&ghvm->mm_lock);
	mapping = ghsm_find_by_label(ghvm, region->label);
	mutex_unlock(&ghvm->mm_lock);
	if (mapping) {
		pr_warn("share refused: label=%u gpa=0x%llx still tracked (guest must UNMAP it first)\n",
			region->label, region->guest_phys_addr);
		return -EBUSY;
	}

	/* lend=false => SHARE: host retains access, ACL gets host vmid in [1]. */
	ret = p_gh_vm_mem_alloc(ghvm, region, false);
	if (ret) {
		pr_err("mem_alloc FAILED ret=%d gpa=0x%llx size=0x%llx label=%u\n",
		       ret, region->guest_phys_addr, region->memory_size,
		       region->label);
		return ret;
	}

	mutex_lock(&ghvm->mm_lock);
	mapping = ghsm_find_by_label(ghvm, region->label);
	if (!mapping) {
		mutex_unlock(&ghvm->mm_lock);
		return -ENOENT;
	}

	mapping->parcel.acl_entries[0].vmid = cpu_to_le16(ghvm->vmid);
	ret = p_rm_mem_share(ghvm->rm, &mapping->parcel);
	if (ret) {
		struct gh_vm_mem *m;
		u64 ngpa = region->guest_phys_addr;
		u64 nend = ngpa + region->memory_size;

		pr_err("mem_share FAILED ret=%d gpa=0x%llx size=0x%llx label=%u handle=0x%x — dumping tracked parcels near this gpa:\n",
		       ret, ngpa, region->memory_size, region->label,
		       mapping->parcel.mem_handle);
		list_for_each_entry(m, &ghvm->memory_mappings, list) {
			u64 s = m->guest_phys_addr;
			u64 e = s + ((u64)m->npages << PAGE_SHIFT);
			bool ov = (s < nend && ngpa < e);

			pr_err("  parcel label=%u gpa=0x%llx size=0x%llx handle=0x%x%s\n",
			       m->parcel.label, s, e - s, m->parcel.mem_handle,
			       ov ? "  <== OVERLAPS new region" : "");
		}
		ghsm_reclaim_mapping(ghvm, mapping);
		kfree(mapping);
		mutex_unlock(&ghvm->mm_lock);
		return ret;
	}

	*mem_handle = mapping->parcel.mem_handle;
	mutex_unlock(&ghvm->mm_lock);
	return 0;
}

/*
 * Turn a userspace gunyah VM fd into its struct gh_vm *, validating that the
 * fd really is a gunyah VM by its anon-inode name "gunyah-vm" (set by
 * anon_inode_getfile() in gh_dev_ioctl_create_vm). This needs no symbol
 * resolution, unlike comparing f_op against the static gh_vm_fops/gh_vm_ioctl.
 * Returns the file (caller must fput) and *out_ghvm.
 */
static struct file *ghsm_get_ghvm(int vm_fd, struct gh_vm **out_ghvm)
{
	struct file *f = fget(vm_fd);

	if (!f)
		return ERR_PTR(-EBADF);

	if (!f->f_path.dentry ||
	    strcmp(f->f_path.dentry->d_name.name, "gunyah-vm") != 0) {
		fput(f);
		return ERR_PTR(-EINVAL);
	}

	*out_ghvm = f->private_data;
	if (!*out_ghvm) {
		fput(f);
		return ERR_PTR(-ENODEV);
	}
	return f;
}

static long ghsm_dev_ioctl(struct file *filp, unsigned int cmd,
			   unsigned long arg)
{
	void __user *argp = (void __user *)arg;
	struct gh_userspace_memory_region region = {};
	struct ghsm_share_blob blob;
	struct gh_vm *ghvm;
	struct file *vmf;
	long r;

	if (cmd == GHSM_UNSHARE_BLOB) {
		struct ghsm_unshare_blob u;

		if (copy_from_user(&u, argp, sizeof(u)))
			return -EFAULT;

		vmf = ghsm_get_ghvm(u.vm_fd, &ghvm);
		if (IS_ERR(vmf))
			return PTR_ERR(vmf);

		if (ghvm->mm != current->mm) {
			fput(vmf);
			return -EPERM;
		}

		r = ghsm_unshare_by_label(ghvm, u.label);
		if (r == 0 || r == -ENOENT)
			ghsm_untrack(ghvm, u.label);
		fput(vmf);
		return r;
	}

	if (cmd != GHSM_SHARE_BLOB)
		return -ENOTTY;

	if (copy_from_user(&blob, argp, sizeof(blob)))
		return -EFAULT;

	if (blob.flags & ~(GH_MEM_ALLOW_READ | GH_MEM_ALLOW_WRITE |
			   GH_MEM_ALLOW_EXEC))
		return -EINVAL;

	vmf = ghsm_get_ghvm(blob.vm_fd, &ghvm);
	if (IS_ERR(vmf))
		return PTR_ERR(vmf);

	/* only allow the owner task to share memory (matches in-tree patch) */
	if (ghvm->mm != current->mm) {
		r = -EPERM;
		goto out;
	}

	region.label = blob.label;
	region.flags = blob.flags;
	region.guest_phys_addr = blob.guest_phys_addr;
	region.memory_size = blob.memory_size;
	region.userspace_addr = blob.userspace_addr;

	r = ghsm_mem_share_blob(ghvm, &region, &blob.mem_handle);
	if (r)
		goto out;

	/* Tracked from here on, so that a crosvm that dies without unsharing does not leave the
	 * parcel for the VM teardown path to trip over. */
	ghsm_track(ghvm, vmf, blob.label);

	if (copy_to_user(argp, &blob, sizeof(blob)))
		r = -EFAULT;
out:
	fput(vmf);
	return r;
}

static const struct file_operations ghsm_dev_fops = {
	.owner = THIS_MODULE,
	.unlocked_ioctl = ghsm_dev_ioctl,
	.compat_ioctl = compat_ptr_ioctl,
	.llseek = noop_llseek,
};

static struct miscdevice ghsm_misc = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = "gunyah_share",
	.fops = &ghsm_dev_fops,
	.mode = 0600,
};

/* ------------------------------------------------------------------ */
/* "命门探针" host-side lend/share probe (debugfs)                     */
/* Decoupled: takes the VM fd on the trigger line instead of a global  */
/* registered by gh_vm_start().                                        */
/* ------------------------------------------------------------------ */

#define GSP_MAGIC 0x5A5A0000DEADBEEFULL
#define GSP_LABEL 0x515A
#define GSP_TRANS_LEND 1
#define GSP_TRANS_SHARE 2

static int gsp_do(struct gh_vm *ghvm, u64 size, unsigned int trans)
{
	struct gh_rm_mem_acl_entry acl[2] = {};
	struct gh_rm_mem_entry ent = {};
	struct gh_rm_mem_parcel parcel = {};
	bool share = (trans == GSP_TRANS_SHARE);
	u16 host_vmid = GH_VMID_INVAL;
	struct page *pg;
	phys_addr_t pa;
	void *va;
	int order, ret;

	if (!size)
		size = PAGE_SIZE;
	size = PAGE_ALIGN(size);
	order = get_order(size);

	pg = alloc_pages(GFP_KERNEL, order);
	if (!pg)
		return -ENOMEM;
	size = PAGE_SIZE << order;
	pa = page_to_phys(pg);
	va = page_address(pg);

	memset(va, 0, size);
	*(u64 *)va = GSP_MAGIC;
	wmb();

	if (!share) {
		unsigned long i, n = size >> PAGE_SHIFT;

		for (i = 0; i < n; i++)
			SetPageReserved(pg + i);
	}

	acl[0].vmid = cpu_to_le16(ghvm->vmid);
	acl[0].perms = GH_RM_ACL_R | GH_RM_ACL_W;
	ent.phys_addr = cpu_to_le64(pa);
	ent.size = cpu_to_le64(size);

	parcel.mem_type = GH_RM_MEM_TYPE_NORMAL;
	parcel.label = GSP_LABEL;
	parcel.acl_entries = acl;
	parcel.n_acl_entries = 1;
	parcel.n_mem_entries = 1;
	parcel.mem_entries = &ent;
	parcel.mem_handle = GH_MEM_HANDLE_INVAL;

	if (share) {
		if (p_rm_get_vmid(ghvm->rm, &host_vmid)) {
			__free_pages(pg, order);
			return -EIO;
		}
		acl[1].vmid = cpu_to_le16(host_vmid);
		acl[1].perms = GH_RM_ACL_R | GH_RM_ACL_W | GH_RM_ACL_X;
		parcel.n_acl_entries = 2;
		ret = p_rm_mem_share(ghvm->rm, &parcel);
	} else {
		ret = p_rm_mem_lend(ghvm->rm, &parcel);
	}
	if (ret) {
		pr_err("probe: gh_rm_mem_%s failed: %d\n",
		       share ? "share" : "lend", ret);
		__free_pages(pg, order);
		return ret;
	}

	pr_info("probe: %s to vmid=%u handle=0x%x host_pa=0x%llx size=0x%llx magic=0x%016llx host_vmid=%u\n",
		share ? "SHARED" : "LENT", ghvm->vmid, parcel.mem_handle,
		(u64)pa, (u64)size, GSP_MAGIC, host_vmid);
	/* Deliberately leak pg/parcel so the guest can accept it. Throwaway. */
	return 0;
}

static ssize_t gsp_write(struct file *f, const char __user *ubuf, size_t len,
			 loff_t *ppos)
{
	char buf[64];
	int vm_fd = -1;
	u64 size = 0;
	unsigned int trans = GSP_TRANS_LEND;
	struct gh_vm *ghvm;
	struct file *vmf;
	int n, ret;

	if (len >= sizeof(buf))
		return -EINVAL;
	if (copy_from_user(buf, ubuf, len))
		return -EFAULT;
	buf[len] = '\0';

	/* "<vm_fd> <size_hex> [trans]"  trans: 1=LEND (default) 2=SHARE */
	n = sscanf(buf, "%d %llx %x", &vm_fd, &size, &trans);
	if (n < 1)
		return -EINVAL;

	vmf = ghsm_get_ghvm(vm_fd, &ghvm);
	if (IS_ERR(vmf))
		return PTR_ERR(vmf);

	ret = gsp_do(ghvm, size, trans);
	fput(vmf);
	return ret ? ret : len;
}

static const struct file_operations gsp_fops = {
	.owner = THIS_MODULE,
	.write = gsp_write,
};

static struct dentry *gsp_dent;

/* ------------------------------------------------------------------ */

static int __init ghsm_init(void)
{
	int ret;

	ret = resolve_symbols();
	if (ret) {
		pr_err("symbol resolution failed (is the gunyah driver loaded?)\n");
		return ret;
	}

	ret = misc_register(&ghsm_misc);
	if (ret) {
		pr_err("misc_register failed: %d\n", ret);
		return ret;
	}

	gsp_dent = debugfs_create_file("gh_share_probe", 0200, NULL, NULL,
				       &gsp_fops);

	pr_info("loaded (v2: liveness GC for a dead crosvm's blobs). /dev/gunyah_share ready; probe: echo \"<vm_fd> <size_hex> [1=LEND|2=SHARE]\" > /sys/kernel/debug/gh_share_probe\n");
	return 0;
}

static void __exit ghsm_exit(void)
{
	struct ghsm_blob *b, *tmp;

	debugfs_remove(gsp_dent);
	misc_deregister(&ghsm_misc);

	/* Drop the VM file refs without reclaiming: unloading this module is not a reason to take
	 * a parcel away from a VM that may still be using it, and holding the refs would keep
	 * those VMs from ever tearing down. Their parcels go back through gh_vm_free() as they
	 * always did before the reaper existed. */
	cancel_delayed_work_sync(&ghsm_reaper_work);
	mutex_lock(&ghsm_blob_lock);
	list_for_each_entry_safe(b, tmp, &ghsm_blobs, node) {
		list_del(&b->node);
		fput(b->vm_file);
		kfree(b);
	}
	mutex_unlock(&ghsm_blob_lock);

	pr_info("unloaded\n");
}

module_init(ghsm_init);
module_exit(ghsm_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Standalone gunyah SHARE_BLOB + host lend/share probe (no kernel source changes)");
