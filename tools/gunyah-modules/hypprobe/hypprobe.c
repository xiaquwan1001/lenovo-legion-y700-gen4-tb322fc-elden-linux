// elden-hypprobe: query TZ SIP HYP_INFO_GET_HYP_DTB_ADDRESS (0x02000609) and dump
// the hyp boot info struct + provided DTBOs. Read-only probe (no writes to flash).
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/arm-smccc.h>
#include <linux/io.h>
#include <linux/slab.h>
#include <linux/debugfs.h>
#include <linux/uaccess.h>
#include <linux/mm.h>

#define SIP_HYP_INFO_GET_HYP_DTB_ADDR	0x02000609u
#define SIP_PARAM_ID_0			0u
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

static struct arm_smccc_res g_res;
static struct hyp_boot_info g_hbi;
static bool g_hbi_valid;
static phys_addr_t g_dtbo_pa[HYP_MAX_NUM_DTBOS];
static size_t g_dtbo_sz[HYP_MAX_NUM_DTBOS];
static int g_num_dtbo;

static bool plausible_ddr(u64 pa)
{
	return (pa >= 0x80000000ULL && pa < 0x100000000ULL && !(pa & 0x3));
}

static void *map_phys(u64 pa, size_t len)
{
	if (!plausible_ddr(pa))
		return NULL;
	return memremap(pa, len, MEMREMAP_WB);
}

static int __init hypprobe_init(void)
{
	u64 cand[4];
	void *p;
	int i, n = 0;

	arm_smccc_smc(SIP_HYP_INFO_GET_HYP_DTB_ADDR, SIP_PARAM_ID_0,
		      0, 0, 0, 0, 0, 0, &g_res);
	pr_info("hypprobe: sip a0=%#llx a1=%#llx a2=%#llx a3=%#llx\n",
		g_res.a0, g_res.a1, g_res.a2, g_res.a3);

	cand[n++] = g_res.a1;
	cand[n++] = g_res.a2;
	cand[n++] = g_res.a3;

	for (i = 0; i < n; i++) {
		u64 pa = cand[i];
		u32 magic;

		p = map_phys(pa, PAGE_SIZE);
		if (!p)
			continue;
		magic = *(u32 *)p;
		pr_info("hypprobe: cand[%d] pa=%#llx magic=%#x\n", i, pa, magic);
		if (magic == HYP_BOOTINFO_MAGIC) {
			memcpy(&g_hbi, p, sizeof(g_hbi));
			g_hbi_valid = true;
			memunmap(p);
			break;
		}
		memunmap(p);
	}

	if (!g_hbi_valid) {
		pr_warn("hypprobe: no hyp boot info found\n");
		return 0;
	}

	pr_info("hypprobe: HBI magic=%#x version=%u size=%u pil_enable=%u vm_type=%u num_dtbos=%u\n",
		g_hbi.magic, g_hbi.version, g_hbi.size, g_hbi.pil_enable,
		g_hbi.primary_vm_info.vm_type,
		g_hbi.primary_vm_info.num_dtbos);
	print_hex_dump(KERN_INFO, "hypprobe hbi: ", DUMP_PREFIX_OFFSET, 16, 4,
		       &g_hbi, sizeof(g_hbi), true);

	g_num_dtbo = min_t(u32, g_hbi.primary_vm_info.num_dtbos, HYP_MAX_NUM_DTBOS);
	for (i = 0; i < g_num_dtbo; i++) {
		u64 base = g_hbi.primary_vm_info.linux_aarch64[i].dtbo_base;
		u64 sz = g_hbi.primary_vm_info.linux_aarch64[i].dtbo_size;
		u32 fdt_magic = 0, total = 0;

		g_dtbo_pa[i] = base;
		g_dtbo_sz[i] = sz;
		p = map_phys(base, min_t(u64, sz, PAGE_SIZE));
		if (p) {
			fdt_magic = *(u32 *)p;
			total = be32_to_cpu(*(u32 *)((char *)p + 4));
			memunmap(p);
		}
		pr_info("hypprobe: dtbo[%d] base=%#llx size=%#llx fdt_magic=%#x totalsize=%u\n",
			i, base, sz, fdt_magic, total);
		p = map_phys(base, PAGE_ALIGN(sz));
		if (p) {
			print_hex_dump(KERN_INFO, "hypprobe dtbo: ", DUMP_PREFIX_OFFSET,
				       16, 4, p, min_t(u64, sz, 2048), true);
			memunmap(p);
		}
	}
	return 0;
}
module_init(hypprobe_init);

static void __exit hypprobe_exit(void)
{
}
module_exit(hypprobe_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("elden Gunyah hyp boot info probe (read-only)");
