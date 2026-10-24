// SPDX-License-Identifier: GPL-2.0-only
/*
 * gunyah_identify.c — 只读探测 Gunyah hypervisor 的 API 版本与 feature flags
 *
 * 背景（2026-10-24）：本机已确认运行在 Gunyah 下（`/sys/bus/platform/devices/gunyah-wdt`
 * 由 qcom_scm 的 SMCCC UUID 询问命中后注册），且主线 `gunyah_wdt` probe 通过。
 * 下一步要回答的是「Gunyah 的 msgq/doorbell 通道在不在」—— 这决定 RM RPC 能否可达，
 * 而 RM 可达是「Gunyah 上跑 Windows ARM64」的前置。
 *
 * 本模块只做一件事：调用 HYP_IDENTIFY（AOSP 定义 fn=0x8000，产品固件用 `hvc #0x6000` 形式），
 * 该调用无副作用、不需要 capability，返回 api_info + 3 个 feature flags。
 *
 * 用法：
 *   insmod gunyah_identify.ko      # 结果进 dmesg；模块自报一次后即卸载可
 *   rmmod gunyah_identify
 *
 * 参考：reference/gunyah-android15-6.6/arch/arm64/gunyah/gunyah_hypercall.c
 *       reference/gunyah-android15-6.6/include/linux/gunyah.h（api_info/flags 位定义）
 *       厂商模块 backup/stock-elden/vendor_ramdisk/gh_ctrl.ko（`hvc #0x6000` 实测在机固件用这种形式）
 */
#include <linux/arm-smccc.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/uuid.h>

#define GUNYAH_UUID_INIT UUID_INIT(0xc1d58fcd, 0xa453, 0x5fdb, 0x92, 0x65, 0xce, 0x36, 0x67, 0x3d, 0x5f, 0x14)

/* AOSP/上游形式：SMCCC 函数号 = FAST_CALL | SMC_64 | OWNER_VENDOR_HYP | fn */
#define GUNYAH_FN(fn) ARM_SMCCC_CALL_VAL(ARM_SMCCC_FAST_CALL, ARM_SMCCC_SMC_64, \
					 ARM_SMCCC_OWNER_VENDOR_HYP, fn)
#define GUNYAH_HYP_IDENTIFY GUNYAH_FN(0x8000)

#define API_VERSION_MASK GENMASK_ULL(13, 0)
#define API_BIG_ENDIAN    BIT_ULL(14)
#define API_IS_64BIT      BIT_ULL(15)

static void decode_flags(u64 f0, u64 f1, u64 f2)
{
	pr_info("gunyah_identify: flags = {0x%016llx, 0x%016llx, 0x%016llx}\n",
		f0, f1, f2);
	pr_info("gunyah_identify:   DOORBELL=%u MSGQUEUE=%u VCPU=%u MEMEXTENT=%u\n",
		!!(f0 & BIT_ULL(1)), !!(f0 & BIT_ULL(2)),
		!!(f0 & BIT_ULL(5)), !!(f0 & BIT_ULL(6)));
}

static int __init gunyah_identify_init(void)
{
	struct arm_smccc_res smc;
	const uuid_t gunyah_uuid = GUNYAH_UUID_INIT;
	u64 a0 = 0, a1 = 0, a2 = 0, a3 = 0;
	u64 v0 = 0, v1 = 0, v2 = 0, v3 = 0;

	/* 1) 先复核「我们确实是 Gunyah guest」——与 qcom_scm 用的是同一个 UUID 询问 */
	pr_info("gunyah_identify: smccc_hypervisor_has_uuid(gunyah) = %d\n",
		arm_smccc_hypervisor_has_uuid(&gunyah_uuid));

	/*
	 * 2) 产品固件形式：`hvc #0x6000`（x0..x7 清零，结果 x0..x3）。
	 *    该形式由厂商 gh_ctrl.ko 在本机型上实测使用，因此是已证明安全的调用。
	 */
	asm volatile(
		"mov x0, xzr\n\t"
		"mov x1, xzr\n\t"
		"mov x2, xzr\n\t"
		"mov x3, xzr\n\t"
		"hvc #0x6000\n\t"
		"mov %0, x0\n\t"
		"mov %1, x1\n\t"
		"mov %2, x2\n\t"
		"mov %3, x3\n\t"
		: "=r"(a0), "=r"(a1), "=r"(a2), "=r"(a3)
		:
		: "x0", "x1", "x2", "x3", "memory");

	pr_info("gunyah_identify: [hvc #0x6000] x0=0x%016llx x1=0x%016llx x2=0x%016llx x3=0x%016llx\n",
		a0, a1, a2, a3);
	pr_info("gunyah_identify:   api_version=%llu big_endian=%u is_64bit=%u variant=0x%llx\n",
		(unsigned long long)(a0 & API_VERSION_MASK),
		!!(a0 & API_BIG_ENDIAN), !!(a0 & API_IS_64BIT),
		(unsigned long long)(a0 >> 56));
	decode_flags(a1, a2, a3);

	/*
	 * 3) 对照 AOSP 形式（`hvc #0` + x0=SMCCC fnid）。仅作信息记录：
	 *    若固件只认 immediate 形式，这里会返回 GUNYAH_ERROR_UNIMPLEMENTED(-1) 之类，不影响结论。
	 */
	arm_smccc_1_1_hvc(GUNYAH_HYP_IDENTIFY, &smc);
	v0 = smc.a0; v1 = smc.a1; v2 = smc.a2; v3 = smc.a3;
	pr_info("gunyah_identify: [hvc #0 fn=0x%08lx] x0=0x%016llx x1=0x%016llx x2=0x%016llx x3=0x%016llx\n",
		(unsigned long)GUNYAH_HYP_IDENTIFY, v0, v1, v2, v3);
	if ((v0 & API_VERSION_MASK) == 1)
		decode_flags(v1, v2, v3);

	/* 4) 一句话结论 */
	pr_info("gunyah_identify: VERDICT api_v1=%s msgqueue=%s doorbell=%s\n",
		((a0 & API_VERSION_MASK) == 1) ? "yes" : "no",
		(a1 & BIT_ULL(2)) ? "yes" : "no",
		(a1 & BIT_ULL(1)) ? "yes" : "no");
	return 0; /* 探针不常驻 */
}

static void __exit gunyah_identify_exit(void) {}

module_init(gunyah_identify_init);
module_exit(gunyah_identify_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Read-only Gunyah HYP_IDENTIFY probe (api version + feature flags)");
