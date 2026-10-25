// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * gunyah_kvcalloc_mod - out-of-tree fix for large-guest OOM in the Gunyah
 * vm_mgr memory path.
 *
 * Upstream/in-tree fix (commit b6ff6203e4bc) changes gh_vm_mem_alloc() to use
 * kvcalloc()/kvfree() instead of kcalloc()/kfree() for the pinned-page pointer
 * array and the parcel mem_entries array. A large guest needs hundreds of KiB
 * for those arrays; a high-order kmalloc can fail under fragmentation and the
 * VM setup returns -ENOMEM. kvcalloc() falls back to vmalloc().
 *
 * This module reproduces that fix WITHOUT patching the kernel source, by
 * hijacking the two relevant global functions with kprobes and redirecting
 * them to local copies that use kvcalloc()/kvfree():
 *
 *      gh_vm_mem_alloc()     -> ghk_vm_mem_alloc()       (kvcalloc allocs)
 *      gh_vm_mem_reclaim()   -> ghk_vm_mem_reclaim()     (kvfree frees)
 *
 * Both must be replaced as a pair: if alloc hands back a vmalloc pointer, the
 * matching free path must use kvfree(), otherwise a base kernel that still uses
 * kfree() would BUG() on a vmalloc address.
 *
 * Mechanism: on this GKI config CONFIG_FUNCTION_TRACER is OFF, so kprobes use
 * the classic BRK breakpoint (no KPROBES_ON_FTRACE). At the probed function
 * entry the args are still in x0..x3 and x30 holds the caller's return address,
 * so a pre_handler that sets regs->pc to our replacement and returns 1 makes
 * execution continue into our function, which returns straight to the original
 * caller. Standard arm64 full-function-hijack pattern; needs only CONFIG_KPROBES.
 *
 * BUILD/RUN CONSTRAINTS:
 *   - struct gh_vm / gh_vm_mem are private, non-KABI structs. Their layout is
 *     vendored below VERBATIM from drivers/virt/gunyah/vm_mgr.h (same approach
 *     as gunyah_share_mod), so the build needs NO gunyah driver source -- only
 *     the matching public kernel headers/config. The vendored layout must stay
 *     byte-identical to the running kernel's.
 *   - Only has an EFFECT on a base kernel that does NOT already carry the
 *     kvcalloc fix. If the base already uses kvcalloc/kvfree, this module is a
 *     harmless functional no-op (it just runs an identical copy).
 */

#define pr_fmt(fmt) "gh_kvcalloc: " fmt

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/kprobes.h>
#include <linux/slab.h>
#include <linux/mm.h>
#include <linux/vmalloc.h>
#include <linux/list.h>
#include <linux/mutex.h>
#include <linux/mman.h>
#include <linux/notifier.h>
#include <linux/rbtree.h>
#include <linux/rwsem.h>
#include <linux/sched/mm.h>
#include <linux/types.h>
#include <linux/wait.h>
#include <linux/workqueue.h>

#include <linux/gunyah_rsc_mgr.h>
#include <linux/gunyah_vm_mgr.h>
#include <uapi/linux/gunyah.h>

/* ------------------------------------------------------------------ */
/* Vendored gunyah private layout (drivers/virt/gunyah/vm_mgr.h, 6.1)  */
/* struct gh_vm / gh_vm_mem are private, non-KABI structs. They are    */
/* vendored VERBATIM (byte-identical) so this module needs no gunyah   */
/* driver source -- the same approach gunyah_share_mod uses. Compiled  */
/* against the same kernel headers/config, so the layout matches       */
/* byte-for-byte. The by-value sub-structs (dtb_config / fw_config /   */
/* exit_info) resolve from the PUBLIC <linux/gunyah_vm_mgr.h> above.   */
/* If the gunyah driver changes, re-vendor and re-check byte layout.   */
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
/* Runtime-resolved symbols                                            */
/* ------------------------------------------------------------------ */

/* gh_rm_mem_reclaim() is global but NOT exported, so resolve via kallsyms. */
static int (*p_gh_rm_mem_reclaim)(struct gh_rm *rm, struct gh_rm_mem_parcel *parcel);
/* Some 6.1 vendor kernels (e.g. OPPO 6.1.118) do not export these either,
 * though both are global in kallsyms -- resolve them the same way. */
static typeof(&account_locked_vm) p_account_locked_vm;
static typeof(&gh_rm_get_vmid) p_gh_rm_get_vmid;

static unsigned long (*p_kallsyms_lookup_name)(const char *name);

static int resolve_kallsyms_lookup_name(void)
{
	struct kprobe kp = { .symbol_name = "kallsyms_lookup_name" };
	int ret;

	ret = register_kprobe(&kp);
	if (ret) {
		pr_err("register_kprobe(kallsyms_lookup_name) failed: %d\n", ret);
		return ret;
	}
	p_kallsyms_lookup_name = (void *)kp.addr;
	unregister_kprobe(&kp);

	if (!p_kallsyms_lookup_name) {
		pr_err("could not obtain kallsyms_lookup_name address\n");
		return -ENOENT;
	}
	return 0;
}

/* ------------------------------------------------------------------ */
/* Static helpers reimplemented locally (originals are static/inlined) */
/* ------------------------------------------------------------------ */

static bool ghk_pages_are_mergeable(struct page *a, struct page *b)
{
	return page_to_pfn(a) + 1 == page_to_pfn(b);
}

static bool ghk_vm_mem_overlap(struct gh_vm_mem *a, u64 addr, u64 size)
{
	u64 a_end = a->guest_phys_addr + (a->npages << PAGE_SHIFT);
	u64 end = addr + size;

	return a->guest_phys_addr < end && addr < a_end;
}

static struct gh_vm_mem *ghk_find_by_label(struct gh_vm *ghvm, u32 label)
{
	struct gh_vm_mem *mapping;

	list_for_each_entry(mapping, &ghvm->memory_mappings, list)
		if (mapping->parcel.label == label)
			return mapping;

	return NULL;
}

/* Mirror of gh_vm_mem_reclaim_mapping(), but frees pages/mem_entries with kvfree. */
static void ghk_vm_mem_reclaim_mapping(struct gh_vm *ghvm, struct gh_vm_mem *mapping)
{
	int ret = 0;

	if (mapping->parcel.mem_handle != GH_MEM_HANDLE_INVAL) {
		ret = p_gh_rm_mem_reclaim(ghvm->rm, &mapping->parcel);
		if (ret)
			pr_warn("Failed to reclaim memory parcel for label %d: %d\n",
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

/* ------------------------------------------------------------------ */
/* Replacement: gh_vm_mem_reclaim()                                    */
/* ------------------------------------------------------------------ */

static void ghk_vm_mem_reclaim(struct gh_vm *ghvm)
{
	struct gh_vm_mem *mapping, *tmp;

	mutex_lock(&ghvm->mm_lock);

	list_for_each_entry_safe(mapping, tmp, &ghvm->memory_mappings, list) {
		ghk_vm_mem_reclaim_mapping(ghvm, mapping);
		kfree(mapping);
	}

	mutex_unlock(&ghvm->mm_lock);
}

/* ------------------------------------------------------------------ */
/* Replacement: gh_vm_mem_alloc()  (kvcalloc for pages/mem_entries)    */
/* ------------------------------------------------------------------ */

static int ghk_vm_mem_alloc(struct gh_vm *ghvm,
			    struct gh_userspace_memory_region *region, bool lend)
{
	struct gh_vm_mem *mapping, *tmp_mapping;
	struct page *curr_page, *prev_page;
	struct gh_rm_mem_parcel *parcel;
	int i, j, pinned, ret = 0;
	unsigned int gup_flags;
	size_t entry_size;
	u16 vmid;

	if (!region->memory_size || !PAGE_ALIGNED(region->memory_size) ||
		!PAGE_ALIGNED(region->userspace_addr) ||
		!PAGE_ALIGNED(region->guest_phys_addr))
		return -EINVAL;

	if (overflows_type(region->guest_phys_addr + region->memory_size, u64))
		return -EOVERFLOW;

	ret = mutex_lock_interruptible(&ghvm->mm_lock);
	if (ret)
		return ret;

	mapping = ghk_find_by_label(ghvm, region->label);
	if (mapping) {
		ret = -EEXIST;
		goto unlock;
	}

	list_for_each_entry(tmp_mapping, &ghvm->memory_mappings, list) {
		if (ghk_vm_mem_overlap(tmp_mapping, region->guest_phys_addr,
					region->memory_size)) {
			ret = -EEXIST;
			goto unlock;
		}
	}

	mapping = kzalloc(sizeof(*mapping), GFP_KERNEL_ACCOUNT);
	if (!mapping) {
		ret = -ENOMEM;
		goto unlock;
	}

	mapping->guest_phys_addr = region->guest_phys_addr;
	mapping->npages = region->memory_size >> PAGE_SHIFT;
	parcel = &mapping->parcel;
	parcel->label = region->label;
	parcel->mem_handle = GH_MEM_HANDLE_INVAL; /* to be filled later by mem_share/mem_lend */
	parcel->mem_type = GH_RM_MEM_TYPE_NORMAL;

	ret = p_account_locked_vm(ghvm->mm, mapping->npages, true);
	if (ret)
		goto free_mapping;

	/*
	 * Large guests can require hundreds of KiB just for the pinned-page
	 * pointer array; use vmalloc fallback rather than high-order kmalloc.
	 */
	mapping->pages = kvcalloc(mapping->npages, sizeof(*mapping->pages),
				  GFP_KERNEL_ACCOUNT);
	if (!mapping->pages) {
		ret = -ENOMEM;
		mapping->npages = 0; /* update npages for reclaim */
		goto unlock_pages;
	}

	gup_flags = FOLL_LONGTERM;
	if (region->flags & GH_MEM_ALLOW_WRITE)
		gup_flags |= FOLL_WRITE;

	pinned = pin_user_pages_fast(region->userspace_addr, mapping->npages,
					gup_flags, mapping->pages);
	if (pinned < 0) {
		ret = pinned;
		pr_err("ghk: pin_user_pages_fast failed: %d (npages=%lu)\n", pinned, (unsigned long)mapping->npages);
		goto free_pages;
	} else if (pinned != mapping->npages) {
		ret = -EFAULT;
		pr_err("ghk: short pin %d of %lu\n", pinned, (unsigned long)mapping->npages);
		mapping->npages = pinned; /* update npages for reclaim */
		goto unpin_pages;
	}

	if (lend) {
		parcel->n_acl_entries = 1;
		mapping->share_type = VM_MEM_LEND;
	} else {
		parcel->n_acl_entries = 2;
		mapping->share_type = VM_MEM_SHARE;
	}
	parcel->acl_entries = kcalloc(parcel->n_acl_entries,
				      sizeof(*parcel->acl_entries), GFP_KERNEL);
	if (!parcel->acl_entries) {
		ret = -ENOMEM;
		goto unpin_pages;
	}

	/* acl_entries[0].vmid will be this VM's vmid. We'll fill it when the
	 * VM is starting and we know the VM's vmid.
	 */
	if (region->flags & GH_MEM_ALLOW_READ)
		parcel->acl_entries[0].perms |= GH_RM_ACL_R;
	if (region->flags & GH_MEM_ALLOW_WRITE)
		parcel->acl_entries[0].perms |= GH_RM_ACL_W;
	if (region->flags & GH_MEM_ALLOW_EXEC)
		parcel->acl_entries[0].perms |= GH_RM_ACL_X;

	if (!lend) {
		ret = p_gh_rm_get_vmid(ghvm->rm, &vmid);
		if (ret) {
			pr_err("ghk: gh_rm_get_vmid failed: %d\n", ret);
			goto free_acl;
		}

		parcel->acl_entries[1].vmid = cpu_to_le16(vmid);
		/* Host assumed to have all these permissions. Gunyah will not
		* grant new permissions if host actually had less than RWX
		*/
		parcel->acl_entries[1].perms = GH_RM_ACL_R | GH_RM_ACL_W | GH_RM_ACL_X;
	}

	parcel->n_mem_entries = 1;
	for (i = 1; i < mapping->npages; i++) {
		if (!ghk_pages_are_mergeable(mapping->pages[i - 1], mapping->pages[i]))
			parcel->n_mem_entries++;
	}

	parcel->mem_entries = kvcalloc(parcel->n_mem_entries,
				       sizeof(parcel->mem_entries[0]),
				       GFP_KERNEL_ACCOUNT);
	if (!parcel->mem_entries) {
		ret = -ENOMEM;
		goto free_acl;
	}

	/* reduce number of entries by combining contiguous pages into single memory entry */
	prev_page = mapping->pages[0];
	parcel->mem_entries[0].phys_addr = cpu_to_le64(page_to_phys(prev_page));
	entry_size = PAGE_SIZE;
	for (i = 1, j = 0; i < mapping->npages; i++) {
		curr_page = mapping->pages[i];
		if (ghk_pages_are_mergeable(prev_page, curr_page)) {
			entry_size += PAGE_SIZE;
		} else {
			parcel->mem_entries[j].size = cpu_to_le64(entry_size);
			j++;
			parcel->mem_entries[j].phys_addr =
				cpu_to_le64(page_to_phys(curr_page));
			entry_size = PAGE_SIZE;
		}

		prev_page = curr_page;
	}
	parcel->mem_entries[j].size = cpu_to_le64(entry_size);

	list_add(&mapping->list, &ghvm->memory_mappings);
	mutex_unlock(&ghvm->mm_lock);
	return 0;
free_acl:
	kfree(parcel->acl_entries);
unpin_pages:
	unpin_user_pages(mapping->pages, pinned);
free_pages:
	kvfree(mapping->pages);
unlock_pages:
	p_account_locked_vm(ghvm->mm, mapping->npages, false);
free_mapping:
	kfree(mapping);
unlock:
	mutex_unlock(&ghvm->mm_lock);
	return ret;
}

/* ------------------------------------------------------------------ */
/* kprobe entry hijacks                                                */
/* ------------------------------------------------------------------ */

static int pre_alloc(struct kprobe *p, struct pt_regs *regs)
{
	/* args (x0..x2) already set for ghk_vm_mem_alloc(ghvm, region, lend) */
	instruction_pointer_set(regs, (unsigned long)ghk_vm_mem_alloc);
	return 1; /* skip original body, resume at our replacement */
}

static int pre_reclaim(struct kprobe *p, struct pt_regs *regs)
{
	/* arg (x0) already set for ghk_vm_mem_reclaim(ghvm) */
	instruction_pointer_set(regs, (unsigned long)ghk_vm_mem_reclaim);
	return 1;
}

static struct kprobe kp_alloc = {
	.symbol_name = "gh_vm_mem_alloc",
	.pre_handler = pre_alloc,
};

static struct kprobe kp_reclaim = {
	.symbol_name = "gh_vm_mem_reclaim",
	.pre_handler = pre_reclaim,
};

static int __init ghk_init(void)
{
	int ret;

	ret = resolve_kallsyms_lookup_name();
	if (ret)
		return ret;

	p_gh_rm_mem_reclaim = (void *)p_kallsyms_lookup_name("gh_rm_mem_reclaim");
	if (!p_gh_rm_mem_reclaim) {
		pr_err("could not resolve gh_rm_mem_reclaim\n");
		return -ENOENT;
	}
	p_account_locked_vm = (void *)p_kallsyms_lookup_name("account_locked_vm");
	p_gh_rm_get_vmid = (void *)p_kallsyms_lookup_name("gh_rm_get_vmid");
	if (!p_account_locked_vm || !p_gh_rm_get_vmid) {
		pr_err("could not resolve account_locked_vm/gh_rm_get_vmid\n");
		return -ENOENT;
	}

	ret = register_kprobe(&kp_alloc);
	if (ret) {
		pr_err("register_kprobe(gh_vm_mem_alloc) failed: %d\n", ret);
		return ret;
	}

	ret = register_kprobe(&kp_reclaim);
	if (ret) {
		pr_err("register_kprobe(gh_vm_mem_reclaim) failed: %d\n", ret);
		unregister_kprobe(&kp_alloc);
		return ret;
	}

	pr_info("installed: gh_vm_mem_alloc@%px gh_vm_mem_reclaim@%px use kvcalloc/kvfree\n",
		kp_alloc.addr, kp_reclaim.addr);
	return 0;
}

static void __exit ghk_exit(void)
{
	unregister_kprobe(&kp_reclaim);
	unregister_kprobe(&kp_alloc);
	pr_info("removed\n");
}

module_init(ghk_init);
module_exit(ghk_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Out-of-tree kvcalloc fix for Gunyah large-guest OOM (kprobe hijack)");
