/*
 * markspin.S — 最小「载荷可执行性」探针（2026-11-03，G1-29 线）
 *
 * 目的：判定 ABL 是否真的把 boot.img 的 kernel 段装载并跳进去执行。
 * 做法：**第一条指令**就把四块已知不被回落启动清零的 carveout 各填一页 0xFF
 *       （单调编码：整页 0xFF = 到达；见 reports/uefi-ddr-blackbox-20261101.md §2），
 *       然后 `b .` 永久自旋 —— 载荷内不再有任何依赖（不需要栈、不需要 UART、不需要 UEFI）。
 * 判据：复位回 Linux 后用 scripts/blackbox.py 读回；page0 popcount>=6 占比 >=50% ⇒ 执行过。
 *
 * 位置无关：不引用任何绝对符号，只用 movz/movk 造物理地址。
 * 构建：
 *   clang --target=aarch64-linux-gnu -c markspin.S -o markspin.o
 *   llvm-objcopy -O binary markspin.o markspin.bin        (本目录 build-markspin.sh)
 */
	.section .text
	.global _start
_start:
	movz	x9,  #0x84A0, lsl #16		// 0x84A00000 dsm1
	movz	x10, #0x9C30, lsl #16		// 0x9C300000 video
	movz	x11, #0x8930, lsl #16		// 0x89300000 dsm2
	movz	x12, #0xE3F0, lsl #16		// 0xE3F00000 sysram
	mov	x13, #-1
	mov	x14, x9
	mov	w15, #512
1:	str	x13, [x9], #8
	str	x13, [x10], #8
	str	x13, [x11], #8
	str	x13, [x12], #8
	subs	w15, w15, #1
	b.ne	1b
	/* 把标记清到 PoC（万一 ABL 交棒时 D-cache 是开的） */
	mov	w15, #64
2:	dc	civac, x14
	add	x14, x14, #64
	subs	w15, w15, #1
	b.ne	2b
	dsb	sy
	/* 标记已落 DRAM：主动 PSCI SYSTEM_RESET（SMC 约定），让设备自己回下一轮启动，
	   避免必须人工长按电源。失败则退化为自旋（标记仍然已经写下）。 */
	movz	w0, #0x0009
	movk	w0, #0x8400, lsl #16
	smc	#0
3:	b	3b
