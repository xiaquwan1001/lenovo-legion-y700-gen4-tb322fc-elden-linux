// elden-gunyah-dtbo: ask TZ (SIP 0x02000609) for the Gunyah hyp boot info,
// then apply the DTBOs it points at to the live device tree.
// Read-only: no flash writes. Gives /hypervisor/{qcom,gunyah-vm,qcom,gh-watchdog,
// qcom,resource-manager-rpc@<tx>} with the *per-boot* RM capids.
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/arm-smccc.h>
#include <linux/io.h>
#include <linux/slab.h>
#include <linux/mm.h>
#include <linux/of.h>
#include <linux/debugfs.h>

#define SIP_HYP_INFO_GET_DTB_ADDR	0x02000609u
#define HYP_BOOTINFO_MAGIC		0xC06B0071u
#define HYP_MAX_NUM_DTBOS		4

struct hyp_boot_info {
	u32 magic;
	u32 version;
	u32 size;
	u32 pil_enable;
	struct {
		u32 vm_type;
		u32 num_dtbos;
		struct {
			u64 dtbo_base;
			u64 dtbo_size;
		} linux_aarch64[HYP_MAX_NUM_DTBOS];
	} primary_vm_info;
} __packed;

/* keep alive: of_overlay_fdt_apply() references the buffer, does not copy it */
static void *dtbo_buf[HYP_MAX_NUM_DTBOS];
static int ovcs_id[HYP_MAX_NUM_DTBOS];
static int n_dtbo;

static struct dentry *dbg_root;
static struct debugfs_blob_wrapper blob[HYP_MAX_NUM_DTBOS];
static char blob_name[HYP_MAX_NUM_DTBOS][8];

static int __init gunyah_dtbo_init(void)
{
	struct arm_smccc_res res;
	struct hyp_boot_info *hbi;
	unsigned int i, num;
	int ret;

	arm_smccc_smc(SIP_HYP_INFO_GET_DTB_ADDR, 0, 0, 0, 0, 0, 0, 0, &res);
	if (!res.a1) {
		pr_err("gunyah-dtbo: SIP returned no hyp boot info\n");
		return -ENODEV;
	}

	hbi = memremap(res.a1, PAGE_SIZE, MEMREMAP_WB);
	if (!hbi)
		return -ENOMEM;
	if (hbi->magic != HYP_BOOTINFO_MAGIC) {
		pr_err("gunyah-dtbo: bad magic %#x at %#llx\n", hbi->magic,
		       (unsigned long long)res.a1);
		memunmap(hbi);
		return -EINVAL;
	}

	pr_info("gunyah-dtbo: hyp boot info v%u size=%u vm_type=%u num_dtbos=%u\n",
		hbi->version, hbi->size, hbi->primary_vm_info.vm_type,
		hbi->primary_vm_info.num_dtbos);

	num = min_t(u32, hbi->primary_vm_info.num_dtbos, HYP_MAX_NUM_DTBOS);
	for (i = 0; i < num; i++) {
		u64 base = hbi->primary_vm_info.linux_aarch64[i].dtbo_base;
		u64 size = hbi->primary_vm_info.linux_aarch64[i].dtbo_size;
		void *src;

		if (!base || !size || size > SZ_64K)
			continue;
		src = memremap(base, PAGE_ALIGN(size), MEMREMAP_WB);
		if (!src)
			continue;
		dtbo_buf[i] = kmemdup(src, size, GFP_KERNEL);
		memunmap(src);
		if (!dtbo_buf[i])
			continue;

		blob[i].data = dtbo_buf[i];
		blob[i].size = size;
		if (!dbg_root)
			dbg_root = debugfs_create_dir("elden-gunyah", NULL);
		if (dbg_root) {
			snprintf(blob_name[i], sizeof(blob_name[i]), "dtbo%u", i);
			debugfs_create_blob(blob_name[i], 0400, dbg_root, &blob[i]);
		}

		ret = of_overlay_fdt_apply(dtbo_buf[i], size, &ovcs_id[i], NULL);
		pr_info("gunyah-dtbo: dtbo[%u] %#llx/%llu apply -> %d (ovcs %d)\n",
			i, (unsigned long long)base, (unsigned long long)size,
			ret, ovcs_id[i]);
		if (!ret)
			n_dtbo++;
	}
	memunmap(hbi);

	if (of_find_node_by_path("/hypervisor"))
		pr_info("gunyah-dtbo: /hypervisor present, %d overlay(s) applied\n",
			n_dtbo);
	else
		pr_warn("gunyah-dtbo: /hypervisor still missing\n");

	return 0;
}
module_init(gunyah_dtbo_init);

static void __exit gunyah_dtbo_exit(void)
{
	while (n_dtbo-- > 0) {
		if (ovcs_id[n_dtbo])
			of_overlay_remove(&ovcs_id[n_dtbo]);
		kfree(dtbo_buf[n_dtbo]);
		dtbo_buf[n_dtbo] = NULL;
	}
}
module_exit(gunyah_dtbo_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Apply Qualcomm Gunyah hyp DTBOs to the live tree (read-only probe)");
