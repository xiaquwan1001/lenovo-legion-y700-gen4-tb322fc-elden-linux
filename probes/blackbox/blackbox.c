// blackbox.ko — 读/写一块物理地址窗口（UEFI 早期可见性「DDR 黑匣子」的设备侧窗口）。
//
// 为什么需要模块：arm64 的 devmem_is_allowed() 只看 page_is_ram()，CONFIG_STRICT_DEVMEM=y
// 时 /dev/mem 对 System RAM 一律 EPERM（iomem=relaxed 在 arm64 分支无效），本机又没开
// CONFIG_PROC_KCORE。载荷把 checkpoint 写进一块 no-map 保留区（DT carveout / memmap=），
// 内核永不触碰，但它不在 /dev/mem 的可读集合里 ⇒ 用一个最小 debugfs 窗口读回。
//
// 用法：insmod blackbox.ko pa=0xBFF00000 size=0x100000
//       cat /sys/kernel/debug/blackbox > /tmp/bb.bin
//       echo -n "EDENSENT" > /sys/kernel/debug/blackbox     # 只写开头（可选）
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/io.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/debugfs.h>
#include <linux/slab.h>
#include <linux/mm.h>

static unsigned long pa = 0xBFF00000UL;
static unsigned long size = 0x100000UL;
module_param(pa, ulong, 0444);
module_param(size, ulong, 0444);

static void __iomem *win;
static struct dentry *de;

static ssize_t bb_read(struct file *f, char __user *ubuf, size_t len, loff_t *off)
{
	loff_t p = *off;
	if (p >= size)
		return 0;
	if (len > size - p)
		len = size - p;
	if (copy_to_user(ubuf, (void __force *)win + p, len))
		return -EFAULT;
	*off = p + len;
	return len;
}

static ssize_t bb_write(struct file *f, const char __user *ubuf, size_t len, loff_t *off)
{
	loff_t p = *off;
	if (p >= size)
		return -ENOSPC;
	if (len > size - p)
		len = size - p;
	if (copy_from_user((void __force *)win + p, ubuf, len))
		return -EFAULT;
	/* 把脏行推到 DRAM：黑匣子的全部意义就是「复位后还在」，不能留在 cache 里等自然淘汰。 */
	{
		loff_t i;
		void __iomem *q = win + p;
		for (i = 0; i < len; i += 64)
			asm volatile("dc civac, %0" :: "r"(q + i) : "memory");
		asm volatile("dsb sy" ::: "memory");
	}
	*off = p + len;
	return len;
}

static const struct file_operations bb_fops = {
	.owner = THIS_MODULE,
	.read = bb_read,
	.write = bb_write,
	.llseek = default_llseek,
};

static int __init bb_init(void)
{
	if (!IS_ALIGNED(pa, PAGE_SIZE) || !IS_ALIGNED(size, PAGE_SIZE) || !size)
		return -EINVAL;
	/* 先试 memremap（在线性映射里就直接给 __va），否则退回 ioremap_cache（保留/no-map 区）。 */
	win = memremap(pa, size, MEMREMAP_WB);
	if (!win)
		win = ioremap_cache(pa, size);
	if (!win)
		win = ioremap(pa, size);
	if (!win)
		return -ENOMEM;
	de = debugfs_create_file("blackbox", 0600, NULL, NULL, &bb_fops);
	if (!de) {
		iounmap(win);
		return -ENOMEM;
	}
	pr_info("blackbox: pa=%#lx size=%#lx mapped\n", pa, size);
	return 0;
}

static void __exit bb_exit(void)
{
	debugfs_remove(de);
	iounmap(win);
}

module_init(bb_init);
module_exit(bb_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("DDR blackbox window for UEFI early-visibility forensics");
