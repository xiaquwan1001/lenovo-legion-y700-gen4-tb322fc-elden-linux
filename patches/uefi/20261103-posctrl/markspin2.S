/*
 * markspin2.S — 「载荷可执行性」探针 v2（2026-11-03，G1-29 线）
 *
 * 为什么不用 v1（整页 0xFF）：整页 0xFF 与「DC 屏保/图像数据/衰减」难以区分，
 * 2026-11-03 15:1x 那一发的四窗读回是 19%–37%（干净正控是 95% + 0%），判据被污染。
 *
 * v2 判据 = **魔数**：向四块 carveout 的 **第 25 页**（+0x19000，远离会被 splash/DSM 使用的头部）
 * 写 512 个连续 `0xA5A5A5A5` 字（2 KiB），然后 dc civac。
 * 读回时在整个 1 MiB 窗口里数「连续 ≥64 个 0xA5A5A5A5」的段：出现 ⇒ 载荷执行过（图像/日志数据
 * 造不出 512 个交替位模式的连续字）。
 *
 * 收尾顺序：HVC PSCI SYSTEM_RESET → SMC PSCI SYSTEM_RESET → 自旋。
 * 目的：让设备**自己**马上重启，避免「卡 logo 数分钟」期间窗口被其它读者/写者污染。
 *
 * 构建：patches/uefi/20261103-posctrl/build-markspin.sh
 */
	.section .text
	.global _start
_start:
	/* w19 = 魔数 */
	movz	w19, #0xA5A5
	movk	w19, #0xA5A5, lsl #16
	/* 四块窗口基址 + 0x19000 */
	movz	x9,  #0x84A0, lsl #16
	movz	x10, #0x9C30, lsl #16
	movz	x11, #0x8930, lsl #16
	movz	x12, #0xE3F0, lsl #16
	movz	x20, #0x0001, lsl #16
	movk	x20, #0x9000			// 0x19000
	add	x9,  x9,  x20
	add	x10, x10, x20
	add	x11, x11, x20
	add	x12, x12, x20
	/* 512 个连续字 × 4 窗 */
	mov	x14, x9
	mov	w15, #512
1:	str	w19, [x9],  #4
	str	w19, [x10], #4
	str	w19, [x11], #4
	str	w19, [x12], #4
	subs	w15, w15, #1
	b.ne	1b
	/* clean 到 PoC：4 窗 × 2 KiB = 32 行/窗 */
	mov	w15, #32
2:	dc	civac, x14
	add	x14, x14, #64
	subs	w15, w15, #1
	b.ne	2b
	dsb	sy

	/* 收尾 1：PSCI SYSTEM_RESET via HVC（Gunyah 在场时的常见 conduit） */
	movz	w0, #0x0009
	movk	w0, #0x8400, lsl #16
	hvc	#0
	/* 收尾 2：同一功能号走 SMC */
	movz	w0, #0x0009
	movk	w0, #0x8400, lsl #16
	smc	#0
	/* 收尾 3：都不行就自旋（此时标记已落 DRAM，人工断电后仍可读） */
3:	b	3b
