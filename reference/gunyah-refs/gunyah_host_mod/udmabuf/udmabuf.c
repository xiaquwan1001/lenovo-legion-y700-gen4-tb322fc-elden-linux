// SPDX-License-Identifier: GPL-2.0
/*
 * udmabuf_kv - one module that gives every host kernel a udmabuf good enough
 * for gfxstream, whatever state its built-in driver is in.  It picks ONE of
 * three modes at insmod and logs which:
 *
 *   native    - no built-in provider (CONFIG_UDMABUF unset): register
 *               /dev/udmabuf ourselves.  The driver below is the upstream one,
 *               version-gated for 6.1 / 6.6+, with the page-pointer array
 *               allocated by kvmalloc from the start.
 *   override  - built-in provider present but UNSUITABLE.  Two known eras:
 *               the kmalloc era (page-pointer array via kmalloc_array, so a
 *               128 MiB dma-buf needs a contiguous order-6 allocation and
 *               fails once memory is fragmented - fixed upstream for the
 *               folio driver as CVE-2024-56544), and the folio era (>= 6.10,
 *               memfd_pin_folios page collection mis-binds large shmem
 *               folios: over our order-9 reserve folios the GPU gets
 *               different pages than the CPU - measured on SM8850/6.12 as
 *               CP opcode-0 hard faults).  A kprobe redirects the built-in
 *               udmabuf_create() to ours in both eras.
 *   paramonly - built-in provider present, suitable, or not safely hookable:
 *               leave its code alone and only raise its two tunables,
 *               size_limit_mb and list_limit.  Upstream's 64 MiB default is
 *               far below what a VkDeviceMemory blob needs now that they
 *               travel as dma-bufs, so "suitable" is not the same as "needs
 *               nothing from us".
 *
 * The override replacement returns a dma_buf that is entirely OURS - our
 * dma_buf_ops, our private struct - so the built-in driver's own ops never see
 * our objects and we never see its private struct.  That is what makes hooking
 * one function enough: no vendored `struct udmabuf` layout to get wrong, and no
 * paired release_udmabuf hook (a kvmalloc'd pointer can never reach the
 * built-in kfree path, because the built-in release only ever runs for buffers
 * the built-in create made).  Buffers made before/after the hook is installed
 * are each freed by whoever made them.
 *
 * Every kernel function that is not part of the GKI module KMI is looked up by
 * name at runtime and simply left NULL when absent (same discipline as
 * gh_hugepage_reserve's kapi): a missing symbol degrades or disables a mode, it
 * never faults.  Nothing here dereferences a symbol it did not resolve.
 *
 * Differences from the in-tree driver, in every mode:
 *   - hugetlbfs memfds are rejected (6.6 upstream dropped them too; 6.1 loses
 *     that support here).  Only tmpfs/shmem memfds are accepted.
 *   - size_limit_mb defaults to 4096, and its page limit is computed in u64:
 *     upstream's int math overflows at >= 4096 (16384 -> 2^34 truncates to 0,
 *     rejecting everything).  In override mode this parameter, not the
 *     built-in's size_limit_mb, is the one that counts; in paramonly mode the
 *     built-in's own variable is what we raise, and it is clamped to what its
 *     int math can survive.
 */

#define pr_fmt(fmt) "udmabuf_kv: " fmt

#include <linux/version.h>

#include <linux/atomic.h>
#include <linux/cred.h>
#include <linux/device.h>
#include <linux/dma-buf.h>
#include <linux/dma-mapping.h>
#include <linux/err.h>
#include <linux/file.h>
#include <linux/fs.h>
#include <linux/highmem.h>
#include <linux/init.h>
#include <linux/kallsyms.h>
#include <linux/kernel.h>
#include <linux/kprobes.h>
#include <linux/magic.h>
#include <linux/memfd.h>
#include <linux/miscdevice.h>
#include <linux/mm.h>
#include <linux/module.h>
#include <linux/overflow.h>
#include <linux/scatterlist.h>
#include <linux/shmem_fs.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/udmabuf.h>
#include <uapi/linux/fcntl.h>

#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 6, 0)
#include <linux/dma-resv.h>
#include <linux/iosys-map.h>
#include <linux/vmalloc.h>
#endif

/* The folio-based rewrite (6.10) carries the kvmalloc fix and a create() we
 * must not stand in for.  Both this build-time bound and a runtime symbol probe
 * have to agree before anything is hooked. */
#define UKV_FOLIO_ERA	(LINUX_VERSION_CODE >= KERNEL_VERSION(6, 10, 0))

/*
 * In native mode this is our own ceiling.  In override and paramonly modes it is ALSO pushed into
 * the built-in driver, because the count check for UDMABUF_CREATE_LIST lives in the built-in
 * udmabuf_ioctl() -- before the udmabuf_create() we redirect -- so raising only this parameter
 * has no effect on a kernel whose ioctl we did not replace.  That asymmetry cost an afternoon:
 * the module's limit read 8192 while lists were still being rejected at 1024 by a variable
 * nothing pointed at.
 *
 * The ceiling matters for guest-allocated buffers, where one BO arrives as a list of drm_buddy
 * blocks: 128 MiB of 64 KiB blocks is 2048 items, over the upstream default of 1024.
 *
 * A long list has its own high-order allocation, separate from the page array: the item array
 * copied in from userspace, 24 bytes an entry, which upstream copies with memdup_user() --
 * documented as physically contiguous, freed with kfree. 16384 items is 384 KiB, order-7, i.e.
 * worse than the order-6 page-array failure this module was written for. Fixing only the page
 * array would have moved the fragmentation cliff one function earlier rather than removing it.
 *
 * So both allocations are ours now: ukv_ioctl_create_list() uses vmemdup_user(), and override mode
 * redirects udmabuf_ioctl as well as udmabuf_create so that copy runs in our code. Where the
 * ioctl is not ours -- paramonly always, override when the second kprobe fails -- we raise the
 * built-in's own list_limit instead, and then this ceiling is only as usable as the built-in's
 * contiguous copy allows.
 */

/*
 * Both limits are writable at runtime, and a write has to reach wherever the check actually
 * lives.  The app daemon applies its configured cap at VM start by writing size_limit_mb, and in
 * the modes where the built-in driver is still the one serving, a value that only landed in our
 * own variable would be silently ignored -- configured 512 MiB, enforced 64.  So the setter
 * re-pushes into the built-in driver for whichever tunables this mode manages.
 */
static void ukv_push_builtin_limits(void);

static int ukv_param_set_limit(const char *val, const struct kernel_param *kp)
{
	int ret = param_set_int(val, kp);

	if (!ret)
		ukv_push_builtin_limits();
	return ret;
}

static const struct kernel_param_ops ukv_limit_ops = {
	.set = ukv_param_set_limit,
	.get = param_get_int,
};

static int list_limit = 65536; // pseudo unprotected vm use system ram, which is more frag, needs 16384 -> 65536
module_param_cb(list_limit, &ukv_limit_ops, &list_limit, 0644);
MODULE_PARM_DESC(list_limit,
	"udmabuf_create_list->count limit. Pushed into the built-in driver too. Default 65536.");

static int size_limit_mb = 4096;
module_param_cb(size_limit_mb, &ukv_limit_ops, &size_limit_mb, 0644);
MODULE_PARM_DESC(size_limit_mb,
	"Max size of a dmabuf, in megabytes. Default 4096 (clamped to 2047 when pushed into the built-in driver).");

/* LTO renaming escape hatch (see ukv_sym_named): the loader may pass the
 * kallsyms names it found for the built-in's static symbols. */
static char *sym_create = "";
module_param(sym_create, charp, 0444);
MODULE_PARM_DESC(sym_create,
	"kallsyms name of the built-in udmabuf_create when LTO renamed it (default: exact name).");
static char *sym_ioctl = "";
module_param(sym_ioctl, charp, 0444);
MODULE_PARM_DESC(sym_ioctl,
	"kallsyms name of the built-in udmabuf_ioctl when LTO renamed it (default: exact name).");

static char *force_mode = "auto";
module_param(force_mode, charp, 0444);
MODULE_PARM_DESC(force_mode,
	"Override mode selection: auto (default), native, override or paramonly.");

/* Settled mode, readable at /sys/module/<name>/parameters/mode. */
static char mode[16] = "unset";
module_param_string(mode, mode, sizeof(mode), 0444);
MODULE_PARM_DESC(mode, "Mode this module settled on: native, override or paramonly (read-only).");

static int stat_created;
module_param(stat_created, int, 0444);
MODULE_PARM_DESC(stat_created, "dma-bufs this module has exported (read-only).");

static int stat_failed;
module_param(stat_failed, int, 0444);
MODULE_PARM_DESC(stat_failed, "create attempts this module rejected (read-only).");

/* ------------------------------------------------------------------------- */
/* Runtime symbols (none of these are guaranteed by the GKI module KMI)       */
/* ------------------------------------------------------------------------- */

static unsigned long (*ukv_lookup_name)(const char *name);
static int (*ukv_lookup_size_offset)(unsigned long addr, unsigned long *symbolsize,
				     unsigned long *offset);

/* kallsyms_lookup_name has not been exported since 5.7; a kprobe on it yields
 * its address without needing the export. */
static void ukv_resolve_lookup_name(void)
{
	struct kprobe kp = { .symbol_name = "kallsyms_lookup_name" };

	if (register_kprobe(&kp) < 0) {
		pr_info("kallsyms_lookup_name is not probeable; detection limited\n");
		return;
	}
	ukv_lookup_name = (void *)kp.addr;
	unregister_kprobe(&kp);
}

/** ukv_sym - address of a kernel symbol, or 0 when it does not exist here. */
static unsigned long ukv_sym(const char *name)
{
	return ukv_lookup_name ? ukv_lookup_name(name) : 0;
}

/**
 * ukv_sym_named - resolve NAME, honouring a userspace-supplied override.
 * @name:    the symbol as written in the source (e.g. "udmabuf_create").
 * @override: module parameter carrying the name it really goes by ("" = none).
 * @actual:  buffer that receives the name that resolved; needed for
 *           register_kprobe(), whose .symbol_name does its own exact lookup.
 * @sz:      size of @actual.
 *
 * ThinLTO builds can rename a static function to "name.llvm.<hash>", making
 * the exact kallsyms lookup miss and a present built-in driver look absent --
 * which would silently demote this module to the wrong mode.  The module
 * cannot scan /proc/kallsyms itself (kernel_read is a protected GKI export;
 * filp_open is not exported at all on 6.12), but userspace can read it
 * freely: the loader greps for "name.<anything>" and passes what it found in
 * sym_create= / sym_ioctl=.  Exact lookup still runs first so a wrong or
 * stale override never masks a symbol that resolves by its real name.
 */
static unsigned long ukv_sym_named(const char *name, const char *override,
				   char *actual, size_t sz)
{
	unsigned long addr = ukv_sym(name);

	strscpy(actual, name, sz);
	if (!addr && override && override[0]) {
		addr = ukv_sym(override);
		if (addr) {
			strscpy(actual, override, sz);
			pr_info("%s resolved via loader override as \"%s\"\n",
				name, override);
		} else {
			pr_warn("loader override \"%s\" for %s does not resolve either\n",
				override, name);
		}
	}
	return addr;
}

static void ukv_resolve_optional(void)
{
	ukv_lookup_size_offset = (void *)ukv_sym("kallsyms_lookup_size_offset");
}

/* ------------------------------------------------------------------------- */
/* The driver (shared by native and override mode)                             */
/* ------------------------------------------------------------------------- */

struct udmabuf_kv {
	pgoff_t pagecount;
	struct page **pages;
	struct sg_table *sg;
	struct miscdevice *device;
};

static vm_fault_t ukv_vm_fault(struct vm_fault *vmf)
{
	struct vm_area_struct *vma = vmf->vma;
	struct udmabuf_kv *ubuf = vma->vm_private_data;
	pgoff_t pgoff = vmf->pgoff;
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 6, 0)
	unsigned long pfn;
#endif

	if (pgoff >= ubuf->pagecount)
		return VM_FAULT_SIGBUS;
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 6, 0)
	pfn = page_to_pfn(ubuf->pages[pgoff]);
	return vmf_insert_pfn(vma, vmf->address, pfn);
#else
	vmf->page = ubuf->pages[pgoff];
	get_page(vmf->page);
	return 0;
#endif
}

static const struct vm_operations_struct ukv_vm_ops = {
	.fault = ukv_vm_fault,
};

static int ukv_mmap(struct dma_buf *buf, struct vm_area_struct *vma)
{
	struct udmabuf_kv *ubuf = buf->priv;

	if ((vma->vm_flags & (VM_SHARED | VM_MAYSHARE)) == 0)
		return -EINVAL;

	vma->vm_ops = &ukv_vm_ops;
	vma->vm_private_data = ubuf;
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 6, 0)
	vm_flags_set(vma, VM_PFNMAP | VM_DONTEXPAND | VM_DONTDUMP);
#endif
	return 0;
}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 6, 0)
static int ukv_vmap(struct dma_buf *buf, struct iosys_map *map)
{
	struct udmabuf_kv *ubuf = buf->priv;
	void *vaddr;

	dma_resv_assert_held(buf->resv);
	vaddr = vm_map_ram(ubuf->pages, ubuf->pagecount, -1);
	if (!vaddr)
		return -EINVAL;

	iosys_map_set_vaddr(map, vaddr);
	return 0;
}

static void ukv_vunmap(struct dma_buf *buf, struct iosys_map *map)
{
	struct udmabuf_kv *ubuf = buf->priv;

	dma_resv_assert_held(buf->resv);
	vm_unmap_ram(map->vaddr, ubuf->pagecount);
}
#endif

static struct sg_table *ukv_get_sg_table(struct device *dev, struct dma_buf *buf,
					 enum dma_data_direction direction)
{
	struct udmabuf_kv *ubuf = buf->priv;
	struct sg_table *sg;
	int ret;

	sg = kzalloc(sizeof(*sg), GFP_KERNEL);
	if (!sg)
		return ERR_PTR(-ENOMEM);
	ret = sg_alloc_table_from_pages(sg, ubuf->pages, ubuf->pagecount,
					0, ubuf->pagecount << PAGE_SHIFT,
					GFP_KERNEL);
	if (ret < 0)
		goto err;
	ret = dma_map_sgtable(dev, sg, direction, 0);
	if (ret < 0)
		goto err;
	return sg;

err:
	sg_free_table(sg);
	kfree(sg);
	return ERR_PTR(ret);
}

static void ukv_put_sg_table(struct device *dev, struct sg_table *sg,
			     enum dma_data_direction direction)
{
	dma_unmap_sgtable(dev, sg, direction, 0);
	sg_free_table(sg);
	kfree(sg);
}

static struct sg_table *ukv_map(struct dma_buf_attachment *at,
				enum dma_data_direction direction)
{
	return ukv_get_sg_table(at->dev, at->dmabuf, direction);
}

static void ukv_unmap(struct dma_buf_attachment *at, struct sg_table *sg,
		      enum dma_data_direction direction)
{
	return ukv_put_sg_table(at->dev, sg, direction);
}

static void ukv_release(struct dma_buf *buf)
{
	struct udmabuf_kv *ubuf = buf->priv;
	struct device *dev = ubuf->device->this_device;
	pgoff_t pg;

	if (ubuf->sg)
		ukv_put_sg_table(dev, ubuf->sg, DMA_BIDIRECTIONAL);

	for (pg = 0; pg < ubuf->pagecount; pg++)
		put_page(ubuf->pages[pg]);
	kvfree(ubuf->pages);
	kfree(ubuf);
}

static int ukv_begin_cpu(struct dma_buf *buf, enum dma_data_direction direction)
{
	struct udmabuf_kv *ubuf = buf->priv;
	struct device *dev = ubuf->device->this_device;
	int ret = 0;

	if (!ubuf->sg) {
		ubuf->sg = ukv_get_sg_table(dev, buf, direction);
		if (IS_ERR(ubuf->sg)) {
			ret = PTR_ERR(ubuf->sg);
			ubuf->sg = NULL;
		}
	} else {
		dma_sync_sgtable_for_cpu(dev, ubuf->sg, direction);
	}

	return ret;
}

static int ukv_end_cpu(struct dma_buf *buf, enum dma_data_direction direction)
{
	struct udmabuf_kv *ubuf = buf->priv;
	struct device *dev = ubuf->device->this_device;

	if (!ubuf->sg)
		return -EINVAL;

	dma_sync_sgtable_for_device(dev, ubuf->sg, direction);
	return 0;
}

static const struct dma_buf_ops ukv_dma_buf_ops = {
	.cache_sgt_mapping = true,
	.map_dma_buf	   = ukv_map,
	.unmap_dma_buf	   = ukv_unmap,
	.release	   = ukv_release,
	.mmap		   = ukv_mmap,
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 6, 0)
	.vmap		   = ukv_vmap,
	.vunmap		   = ukv_vunmap,
#endif
	.begin_cpu_access  = ukv_begin_cpu,
	.end_cpu_access    = ukv_end_cpu,
};

#define SEALS_WANTED (F_SEAL_SHRINK)
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 6, 0)
#define SEALS_DENIED (F_SEAL_WRITE | F_SEAL_FUTURE_WRITE)
#else
#define SEALS_DENIED (F_SEAL_WRITE)
#endif

/**
 * ukv_is_memfd - is this file a tmpfs/shmem memfd we can take pages from?
 *
 * Not shmem_mapping(): since 6.4 that is a header inline comparing a_ops
 * against shmem_aops, and GKI's KMI trim drops shmem_aops on real devices
 * (insmod dies with "Unknown symbol shmem_aops") even though it is
 * EXPORT_SYMBOL in-tree.  Every memfd lives on the internal tmpfs mount, so the
 * superblock magic answers the same question with no symbol at all - and it
 * rejects hugetlbfs memfds, which we do not support.
 */
static bool ukv_is_memfd(struct file *file)
{
	struct inode *inode = file_inode(file);

	return S_ISREG(inode->i_mode) && inode->i_sb->s_magic == TMPFS_MAGIC;
}

/** ukv_seals - F_GET_SEALS for a file already known to be a shmem memfd.
 *
 * Deliberately NOT via a kallsyms pointer to memfd_fcntl().  Its third
 * parameter changed type upstream (unsigned long through 6.1, unsigned int
 * from 6.6 on -- measured on GKI 6.1.118 / 6.6.118 / 6.12), and under
 * CONFIG_CFI_CLANG an indirect call through the wrong prototype is a fatal
 * violation: a hard SoC reset with no bark.  BOTH directions were hit on
 * real devices -- the unsigned-int pointer reset SM8650 (6.1) on module
 * use, and the "corrected" unsigned-long pointer reset SM8850 (6.12) on
 * every VM launch.  SHMEM_I()->seals comes from this KMI's own headers at
 * compile time, so it can never disagree with the running kernel.
 * ukv_is_memfd() has already established the file is a shmem memfd. */
static long ukv_seals(struct file *memfd)
{
	return SHMEM_I(file_inode(memfd))->seals;
}

/**
 * ukv_create - build a dma-buf from a list of memfd ranges.
 * @device: miscdevice whose this_device is the DMA device for the sg table.
 *          Ours in native mode, the built-in driver's in override mode - both
 *          only ever used as a DMA device, never for its private data.
 *
 * Returns a new fd, or a negative errno.  Same contract as the in-tree
 * udmabuf_create(), which is what lets the override jump straight here.
 */
static long ukv_create(struct miscdevice *device,
		       struct udmabuf_create_list *head,
		       struct udmabuf_create_item *list)
{
	DEFINE_DMA_BUF_EXPORT_INFO(exp_info);
	struct file *memfd = NULL;
	struct address_space *mapping = NULL;
	struct udmabuf_kv *ubuf;
	struct dma_buf *buf;
	pgoff_t pgoff, pgcnt, pgidx, pgbuf = 0;
	struct page *page;
	u64 pglimit;
	long seals, ret = -EINVAL;
	u32 i, flags;

	ubuf = kzalloc(sizeof(*ubuf), GFP_KERNEL);
	if (!ubuf) {
		stat_failed++;
		return -ENOMEM;
	}

	pglimit = ((u64)READ_ONCE(size_limit_mb) * 1024 * 1024) >> PAGE_SHIFT;
	for (i = 0; i < head->count; i++) {
		pgoff_t pages = list[i].size >> PAGE_SHIFT;
		pgoff_t total;

		if (!IS_ALIGNED(list[i].offset, PAGE_SIZE))
			goto err;
		if (!IS_ALIGNED(list[i].size, PAGE_SIZE))
			goto err;
		if (check_add_overflow(ubuf->pagecount, pages, &total))
			goto err;
		ubuf->pagecount = total;
		if (ubuf->pagecount > pglimit)
			goto err;
	}

	if (!ubuf->pagecount)
		goto err;

	/* The whole point of this module: kvmalloc, not kmalloc_array.  A
	 * 128 MiB buffer needs 32768 pointers = a 256 KiB (order-6) contiguous
	 * allocation, which fails on a fragmented phone; vmalloc has no such
	 * requirement. */
	ubuf->pages = kvmalloc_array(ubuf->pagecount, sizeof(*ubuf->pages),
				     GFP_KERNEL);
	if (!ubuf->pages) {
		ret = -ENOMEM;
		goto err;
	}

	for (i = 0; i < head->count; i++) {
		ret = -EBADFD;
		memfd = fget(list[i].memfd);
		if (!memfd)
			goto err;
		if (!ukv_is_memfd(memfd))
			goto err;
		mapping = memfd->f_mapping;

		seals = ukv_seals(memfd);
		if (seals == -EINVAL)
			goto err;
		ret = -EINVAL;
		if ((seals & SEALS_WANTED) != SEALS_WANTED ||
		    (seals & SEALS_DENIED) != 0)
			goto err;

		pgoff = list[i].offset >> PAGE_SHIFT;
		pgcnt = list[i].size   >> PAGE_SHIFT;
		for (pgidx = 0; pgidx < pgcnt; pgidx++) {
			page = shmem_read_mapping_page(mapping, pgoff + pgidx);
			if (IS_ERR(page)) {
				ret = PTR_ERR(page);
				goto err;
			}
			ubuf->pages[pgbuf++] = page;
		}
		fput(memfd);
		memfd = NULL;
	}

	exp_info.ops  = &ukv_dma_buf_ops;
	exp_info.size = ubuf->pagecount << PAGE_SHIFT;
	exp_info.priv = ubuf;
	exp_info.flags = O_RDWR;

	ubuf->device = device;
	/* DEFINE_DMA_BUF_EXPORT_INFO set exp_info.owner = THIS_MODULE, so every
	 * live buffer holds a reference on us: rmmod is -EBUSY until userspace
	 * closes them, and our ops can never outlive the module. */
	buf = dma_buf_export(&exp_info);
	if (IS_ERR(buf)) {
		ret = PTR_ERR(buf);
		goto err;
	}

	flags = 0;
	if (head->flags & UDMABUF_FLAGS_CLOEXEC)
		flags |= O_CLOEXEC;
	ret = dma_buf_fd(buf, flags);
	if (ret < 0) {
		dma_buf_put(buf);
		stat_failed++;
		return ret;
	}
	stat_created++;
	return ret;

err:
	while (pgbuf > 0)
		put_page(ubuf->pages[--pgbuf]);
	if (memfd)
		fput(memfd);
	kvfree(ubuf->pages);
	kfree(ubuf);
	stat_failed++;
	return ret;
}

/* ------------------------------------------------------------------------- */
/* Native mode: our own /dev/udmabuf                                         */
/* ------------------------------------------------------------------------- */

static long ukv_ioctl_create(struct file *filp, unsigned long arg)
{
	struct udmabuf_create create;
	struct udmabuf_create_list head;
	struct udmabuf_create_item list;

	if (copy_from_user(&create, (void __user *)arg, sizeof(create)))
		return -EFAULT;

	head.flags  = create.flags;
	head.count  = 1;
	list.memfd  = create.memfd;
	list.offset = create.offset;
	list.size   = create.size;

	return ukv_create(filp->private_data, &head, &list);
}

static long ukv_ioctl_create_list(struct file *filp, unsigned long arg)
{
	struct udmabuf_create_list head;
	struct udmabuf_create_item *list;
	int ret = -EINVAL;
	u32 lsize;

	if (copy_from_user(&head, (void __user *)arg, sizeof(head)))
		return -EFAULT;
	if (head.count > list_limit)
		return -EINVAL;
	lsize = sizeof(struct udmabuf_create_item) * head.count;
	/*
	 * vmemdup_user, not memdup_user: the latter documents its result as physically contiguous
	 * and frees with kfree, i.e. it is a kmalloc. At 24 bytes an item, a long list is a large
	 * high-order allocation -- 16384 items is 384 KiB, order-7 -- which is the same failure
	 * mode this module exists to remove from the page array, just a different array. Fixing one
	 * and leaving the other only moves the fragmentation cliff one function earlier.
	 */
	list = vmemdup_user((void __user *)(arg + sizeof(head)), lsize);
	if (IS_ERR(list))
		return PTR_ERR(list);

	ret = ukv_create(filp->private_data, &head, list);
	kvfree(list);
	return ret;
}

static long ukv_ioctl(struct file *filp, unsigned int ioctl, unsigned long arg)
{
	switch (ioctl) {
	case UDMABUF_CREATE:
		return ukv_ioctl_create(filp, arg);
	case UDMABUF_CREATE_LIST:
		return ukv_ioctl_create_list(filp, arg);
	default:
		return -ENOTTY;
	}
}

static const struct file_operations ukv_fops = {
	.owner		= THIS_MODULE,
	.unlocked_ioctl = ukv_ioctl,
#ifdef CONFIG_COMPAT
	.compat_ioctl   = ukv_ioctl,
#endif
};

static struct miscdevice ukv_misc = {
	.minor	= MISC_DYNAMIC_MINOR,
	.name	= "udmabuf",
	.fops	= &ukv_fops,
};

static bool ukv_misc_registered;

static int ukv_native_start(void)
{
	int ret;

	ret = misc_register(&ukv_misc);
	if (ret < 0)
		return ret;

	/* DMA_BIT_MASK(64) trips clang's -Wshift-count-overflow in external
	 * module builds; ~0ULL is what it expands to for 64 bits. */
	ret = dma_coerce_mask_and_coherent(ukv_misc.this_device, ~0ULL);
	if (ret < 0) {
		misc_deregister(&ukv_misc);
		return ret;
	}

	ukv_misc_registered = true;
	return 0;
}

/* ------------------------------------------------------------------------- */
/* Hijack mode: redirect the built-in udmabuf_create() to ours               */
/* ------------------------------------------------------------------------- */

/*
 * Entered with x0..x2 already holding the built-in udmabuf_create()'s three
 * arguments (the kprobe fires at its first instruction, before the prologue
 * touches them), so the replacement just runs as if it had been called.
 */
static long ukv_create_redirected(struct miscdevice *device,
				struct udmabuf_create_list *head,
				struct udmabuf_create_item *list)
{
	long ret = ukv_create(device, head, list);

	/* Paired with try_module_get() in ukv_pre_create(): it kept us loaded
	 * across this call, which no dma_buf reference covers on the error
	 * paths. */
	module_put(THIS_MODULE);
	return ret;
}

static int ukv_pre_create(struct kprobe *p, struct pt_regs *regs)
{
	/* Fails only while the module is being unloaded; then we leave the PC
	 * alone and the built-in implementation runs, which is always safe. */
	if (!try_module_get(THIS_MODULE))
		return 0;

	instruction_pointer_set(regs, (unsigned long)ukv_create_redirected);
	return 1;	/* do not execute the probed instruction */
}

/* Filled by ukv_pick_mode(): the name udmabuf_create really goes by in this
 * kernel's kallsyms (LTO may have renamed it -- see ukv_sym_named). */
static char ukv_create_name[KSYM_NAME_LEN] = "udmabuf_create";
static struct kprobe ukv_kp_create = {
	.symbol_name = ukv_create_name,
	.pre_handler = ukv_pre_create,
};

/*
 * Hooking udmabuf_create() alone leaves the built-in ioctl in charge of copying the
 * UDMABUF_CREATE_LIST item array, and it does that with memdup_user() -- a physically contiguous
 * kmalloc. For a long list that is the very high-order allocation this module exists to avoid,
 * one function before the one we replaced, and no amount of raising list_limit helps because the
 * copy fails first. Redirecting the ioctl too puts both allocations under our own code, so the
 * limit means what it says.
 *
 * Same mechanism as above: the kprobe fires at the first instruction, x0..x2 still hold
 * (filp, ioctl, arg), so the replacement runs as if it had been called.
 */
static long ukv_ioctl(struct file *filp, unsigned int ioctl, unsigned long arg);

static long ukv_ioctl_redirected(struct file *filp, unsigned int ioctl, unsigned long arg)
{
	long ret = ukv_ioctl(filp, ioctl, arg);

	module_put(THIS_MODULE);
	return ret;
}

static int ukv_pre_ioctl(struct kprobe *p, struct pt_regs *regs)
{
	if (!try_module_get(THIS_MODULE))
		return 0;

	instruction_pointer_set(regs, (unsigned long)ukv_ioctl_redirected);
	return 1;
}

static char ukv_ioctl_name[KSYM_NAME_LEN] = "udmabuf_ioctl";
static struct kprobe ukv_kp_ioctl = {
	.symbol_name = ukv_ioctl_name,
	.pre_handler = ukv_pre_ioctl,
};

static bool ukv_hooked;
static bool ukv_ioctl_hooked;

/*
 * The built-in driver's own tunables, and what they held before we touched them.
 *
 * Two checks live in built-in code we do not replace:
 *
 *   list_limit    - the UDMABUF_CREATE_LIST count check is inlined into udmabuf_ioctl(), which
 *                   runs before the udmabuf_create() override mode redirects.  Rather than hook
 *                   a second, much larger function, raise the variable it reads.
 *   size_limit_mb - the per-buffer page limit, checked inside udmabuf_create().  Override mode
 *                   replaces that function outright, so this one only matters in paramonly mode,
 *                   where upstream's 64 MiB default is the whole reason the mode exists.
 *
 * Both names resolve uniquely in kallsyms on every kernel this module targets, so the lookups
 * are not ambiguous.  Restored on unload: leaving another driver's tunable moved after rmmod
 * would be a change nothing accounts for, and the next thing to hit the old value would have no
 * way to explain it.
 */
struct ukv_builtin_tunable {
	const char *name;
	int *addr;	/* the built-in's variable, NULL when it could not be resolved */
	int saved;	/* what it held before we first touched it */
	bool probed;	/* kallsyms lookup already done, hit or miss */
	bool managed;	/* this mode pushes our value into it */
};

static struct ukv_builtin_tunable ukv_builtin_list_limit = { .name = "list_limit" };
static struct ukv_builtin_tunable ukv_builtin_size_limit = { .name = "size_limit_mb" };

/*
 * Highest size_limit_mb the built-in driver's own arithmetic survives.
 *
 * Upstream computes `pglimit = (size_limit_mb * 1024 * 1024) >> PAGE_SHIFT` with size_limit_mb
 * an int, so the multiply is done in 32 bits: 2048 already reaches 2^31 and 4096 truncates to
 * zero, which rejects every buffer.  Writing this module's own 4096 straight into the built-in
 * would therefore turn "64 MiB cap" into "nothing works at all" -- a far worse failure, and one
 * that would look like the module broke udmabuf rather than fixed it.  2047 MiB is the largest
 * value whose product still fits, and it is ~32x the default we came to raise.
 */
#define UKV_BUILTIN_SIZE_LIMIT_MB_MAX	2047

static void ukv_push_builtin(struct ukv_builtin_tunable *t, int want)
{
	int now;

	if (!t->probed) {
		t->probed = true;
		t->addr = (int *)ukv_sym(t->name);
		if (!t->addr) {
			pr_info("built-in %s not in kallsyms; it stays at its default\n", t->name);
			return;
		}
		t->saved = READ_ONCE(*t->addr);
	}
	if (!t->addr)
		return;

	/* Never below what the kernel shipped with.  A later, smaller write from the daemon
	 * should still be followed -- the parameter has to mean what it says -- but not past
	 * the point where this module would be removing capability rather than adding it. */
	want = max(want, t->saved);
	now = READ_ONCE(*t->addr);
	if (now == want)
		return;
	WRITE_ONCE(*t->addr, want);
	pr_info("built-in %s %d -> %d\n", t->name, now, want);
}

static void ukv_restore_builtin(struct ukv_builtin_tunable *t)
{
	if (!t->addr || READ_ONCE(*t->addr) == t->saved)
		return;
	WRITE_ONCE(*t->addr, t->saved);
	pr_info("built-in %s restored to %d\n", t->name, t->saved);
}

/*
 * Apply this mode's policy to the built-in driver.  Called once at insmod and again on every
 * runtime write to either parameter.  `managed` is what makes it a no-op in the modes where the
 * built-in's copy of a limit is dead code -- override mode replaces the udmabuf_create() that
 * reads size_limit_mb, and when its second kprobe lands it replaces the ioctl reading list_limit
 * too, so writing those variables would move a number nothing consults.
 */
static void ukv_push_builtin_limits(void)
{
	if (ukv_builtin_size_limit.managed)
		ukv_push_builtin(&ukv_builtin_size_limit,
				 min(READ_ONCE(size_limit_mb), UKV_BUILTIN_SIZE_LIMIT_MB_MAX));
	if (ukv_builtin_list_limit.managed)
		ukv_push_builtin(&ukv_builtin_list_limit, READ_ONCE(list_limit));
}

static void ukv_restore_builtin_all(void)
{
	ukv_restore_builtin(&ukv_builtin_list_limit);
	ukv_restore_builtin(&ukv_builtin_size_limit);
}

/**
 * ukv_bl_target - absolute target of an arm64 "BL imm26", or 0 if not a BL.
 *
 * imm26 is a signed word offset; shifting it up to the sign bit and back down
 * arithmetically sign-extends it and multiplies by 4 in one step.
 */
static unsigned long ukv_bl_target(const u32 *at)
{
	u32 insn = READ_ONCE(*at);

	if ((insn & 0xfc000000) != 0x94000000)
		return 0;
	return (unsigned long)at + (((s32)(insn << 6)) >> 4);
}

/** ukv_calls - does the function at @fn contain a direct call to @target? */
static bool ukv_calls(unsigned long fn, unsigned long len, unsigned long target)
{
	const u32 *insn = (const u32 *)fn;
	unsigned long i;

	if (!fn || !len || !target)
		return false;
	for (i = 0; i < len / sizeof(*insn); i++)
		if (ukv_bl_target(&insn[i]) == target)
			return true;
	return false;
}

/** ukv_first_call - name of the first symbol in @names that @fn calls. */
static const char *ukv_first_call(unsigned long fn, unsigned long len,
				  const char * const *names)
{
	int i;

	for (i = 0; names[i]; i++)
		if (ukv_calls(fn, len, ukv_sym(names[i])))
			return names[i];
	return NULL;
}

/**
 * ukv_builtin_is_fixed - does the built-in udmabuf_create() already kvmalloc?
 *
 * The fix is one call site swapped from kmalloc_array() to kvmalloc_array(),
 * and kvmalloc_array() is an inline that always ends in a call to
 * kvmalloc_node(), so its presence in the function's own code is the test.
 * Inconclusive answers (no symbol, no size) report "not fixed": hooking a
 * kernel that turned out to be fixed costs nothing - the replacement does the
 * same work - while skipping a kernel that is broken costs the user the bug.
 *
 * The unfixed kernel's own allocator call is looked up too, purely so the
 * log line carries the evidence for the verdict: seeing "calls __kmalloc"
 * proves the scan can find a call at all, which is what makes its silence
 * about kvmalloc_node worth trusting.
 */
static bool ukv_builtin_is_fixed(unsigned long create)
{
	static const char * const kvmalloc[] = {
		"kvmalloc_node", "kvmalloc_node_noprof", NULL,
	};
	static const char * const kmalloc[] = {
		"__kmalloc", "__kmalloc_node", "__kmalloc_noprof",
		"__kmalloc_node_noprof", "kmalloc_trace", NULL,
	};
	unsigned long size = 0, off = 0;
	const char *hit;

	if (!ukv_lookup_size_offset || !create) {
		pr_info("cannot read udmabuf_create's extent; assuming unfixed\n");
		return false;
	}
	if (!ukv_lookup_size_offset(create, &size, &off) || !size || off) {
		pr_info("udmabuf_create has no usable size in kallsyms; assuming unfixed\n");
		return false;
	}

	hit = ukv_first_call(create, size, kvmalloc);
	if (hit) {
		pr_info("built-in udmabuf_create (%lu bytes) calls %s\n", size, hit);
		return true;
	}

	hit = ukv_first_call(create, size, kmalloc);
	pr_info("built-in udmabuf_create (%lu bytes) calls %s, no kvmalloc\n",
		size, hit ? hit : "no allocator this scan knows");
	return false;
}

/* ------------------------------------------------------------------------- */
/* Mode selection                                                            */
/* ------------------------------------------------------------------------- */

enum ukv_mode { UKV_PARAMONLY, UKV_NATIVE, UKV_OVERRIDE };

static void ukv_set_mode(enum ukv_mode m)
{
	strscpy(mode, m == UKV_NATIVE ? "native" :
		      m == UKV_OVERRIDE ? "override" : "paramonly", sizeof(mode));
}

/**
 * ukv_pick_mode - decide what this kernel needs.
 *
 * Anything unexpected lands on paramonly: this module exists to add a
 * capability or repair one, never to take a working /dev/udmabuf away from the
 * system.  Note that paramonly is not "do nothing" -- it still raises the
 * built-in's limits, which every kernel needs, fixed or not.
 */
static enum ukv_mode ukv_pick_mode(void)
{
	unsigned long create;

	/* The built-in driver's own static symbols.  Ours are all ukv_*, so
	 * these can only ever match the kernel's (or a loaded udmabuf.ko's). */
	create = ukv_sym_named("udmabuf_create", sym_create, ukv_create_name,
			       sizeof(ukv_create_name));
	if (create) {
		/* Resolve the ioctl hook's real name too while we are at it;
		 * a miss just keeps the exact name and the hook degrades as
		 * before (built-in list copy + its own list_limit). */
		ukv_sym_named("udmabuf_ioctl", sym_ioctl, ukv_ioctl_name,
			      sizeof(ukv_ioctl_name));
	} else {
		char opsbuf[KSYM_NAME_LEN];

		if (!ukv_sym_named("udmabuf_ops", "", opsbuf, sizeof(opsbuf))) {
			/* No provider we can see.  If one exists anyway
			 * (kallsyms is unavailable, say), misc_register will
			 * tell us by failing. */
			pr_info("no built-in udmabuf found\n");
			return UKV_NATIVE;
		}
	}


	if (UKV_FOLIO_ERA || ukv_sym("memfd_pin_folios")) {
		/* The folio-based built-in (>= 6.10) does carry the kvmalloc fix,
		 * but its memfd_pin_folios() page collection mis-binds large shmem
		 * folios: a udmabuf built over one of our order-9 reserve folios
		 * hands the GPU different pages than the CPU sees.  Measured on
		 * SM8850 (kernel 6.12, Adreno 840): the CP fetches zeros from a
		 * cmdstream BO that reads back correctly host-side -> opcode-0
		 * hard fault -> DEVICE_LOST for every second-and-later context,
		 * while the same stack works with our create path (force_mode=
		 * override).  So the folio era gets the same treatment as the
		 * unfixed kmalloc era: replace udmabuf_create outright.
		 */
		if (create) {
			pr_info("built-in udmabuf is the folio-based driver (>= 6.10); overriding: its large-folio page collection mis-binds 2MB reserve folios\n");
			return UKV_OVERRIDE;
		}
		pr_info("folio-based built-in udmabuf but udmabuf_create is not in kallsyms; cannot hook\n");
		return UKV_PARAMONLY;
	}

	if (!create) {
		pr_info("built-in udmabuf present but udmabuf_create is not in kallsyms; cannot hook\n");
		return UKV_PARAMONLY;
	}

	if (ukv_builtin_is_fixed(create)) {
		pr_info("built-in udmabuf already allocates with kvmalloc; its code needs nothing\n");
		return UKV_PARAMONLY;
	}

	pr_info("built-in udmabuf allocates its page array with kmalloc (unfixed)\n");
	return UKV_OVERRIDE;
}

static int __init ukv_init(void)
{
	enum ukv_mode m;
	bool forced = true;
	int ret;

	ukv_resolve_lookup_name();
	ukv_resolve_optional();

	if (!strcmp(force_mode, "native"))
		m = UKV_NATIVE;
	else if (!strcmp(force_mode, "override"))
		m = UKV_OVERRIDE;
	else if (!strcmp(force_mode, "paramonly"))
		m = UKV_PARAMONLY;
	else {
		if (strcmp(force_mode, "auto"))
			pr_warn("unknown force_mode \"%s\", using auto\n", force_mode);
		m = ukv_pick_mode();
		forced = false;
	}

	switch (m) {
	case UKV_NATIVE:
		ret = ukv_native_start();
		if (ret == -EEXIST) {
			/* Someone owns /dev/udmabuf after all. */
			pr_info("/dev/udmabuf already exists; standing down to paramonly\n");
			m = UKV_PARAMONLY;
			break;
		}
		if (ret < 0) {
			pr_err("could not register /dev/udmabuf: %d\n", ret);
			return ret;
		}
		pr_info("mode=native: /dev/udmabuf registered, size_limit_mb=%d\n",
			READ_ONCE(size_limit_mb));
		break;
	case UKV_OVERRIDE:
		ret = register_kprobe(&ukv_kp_create);
		if (ret < 0) {
			pr_err("could not hook udmabuf_create: %d\n", ret);
			if (forced)
				return ret;
			/* Its code stays broken, but its limits are still ours to raise. */
			m = UKV_PARAMONLY;
			break;
		}
		ukv_hooked = true;
		/* Optional: without it CREATE_LIST still works, it just keeps the built-in's
		 * contiguous item copy and its own list_limit. Report which one we got. */
		if (register_kprobe(&ukv_kp_ioctl) == 0)
			ukv_ioctl_hooked = true;
		else
			ukv_builtin_list_limit.managed = true;
		/* size_limit_mb stays unmanaged: it is checked inside the udmabuf_create()
		 * we just replaced, so the built-in's copy of it is dead code here. */
		ukv_push_builtin_limits();
		pr_info("mode=override: %s redirected, size_limit_mb=%d list_limit=%d\n",
			ukv_ioctl_hooked ? "udmabuf_ioctl + udmabuf_create"
					 : "udmabuf_create",
			READ_ONCE(size_limit_mb), READ_ONCE(list_limit));
		break;
	case UKV_PARAMONLY:
		break;
	}

	/*
	 * Reached either by choice or by demotion from the two cases above, so it sits after the
	 * switch rather than inside it.  The built-in driver keeps serving and we only lift its
	 * ceilings: a dma-buf per VkDeviceMemory blob does not fit under upstream's 64 MiB
	 * default, whether or not that driver also has the kmalloc bug.
	 */
	if (m == UKV_PARAMONLY) {
		ukv_builtin_size_limit.managed = true;
		ukv_builtin_list_limit.managed = true;
		ukv_push_builtin_limits();
		pr_info("mode=paramonly: built-in driver left in charge, its limits raised\n");
		/* Not just informational on a folio kernel: that built-in's page
		 * collection mis-binds large shmem folios (GPU imports read the
		 * wrong pages -- CP opcode-0 faults, measured on SM8850/6.12),
		 * and in this mode nothing stands in for it.  Reached only when
		 * the create hook failed or the mode was forced, so say it
		 * loudly enough to be found from a GPU-fault report. */
		if (UKV_FOLIO_ERA || ukv_sym("memfd_pin_folios"))
			pr_err("folio built-in left serving: GPU imports over large folios WILL mis-bind (known DEVICE_LOST source); override mode was not possible here\n");
	}

	ukv_set_mode(m);
	return 0;
}

static void __exit ukv_exit(void)
{
	if (ukv_ioctl_hooked)
		unregister_kprobe(&ukv_kp_ioctl);
	if (ukv_hooked)
		unregister_kprobe(&ukv_kp_create);
	/* Unconditional: paramonly raises the built-in's tunables without hooking anything. */
	ukv_restore_builtin_all();
	if (ukv_misc_registered)
		misc_deregister(&ukv_misc);
	pr_info("removed (mode=%s, created=%d)\n", mode, stat_created);
}

module_init(ukv_init);
module_exit(ukv_exit);

MODULE_AUTHOR("Gerd Hoffmann <kraxel@redhat.com>");
MODULE_DESCRIPTION("udmabuf provider/kvmalloc repair for hosts whose kernel lacks either");
MODULE_LICENSE("GPL v2");
MODULE_IMPORT_NS(DMA_BUF);
