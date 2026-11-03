/*
 * markspin3.S — 「ABL 是否真的跳到我们的载荷」探针 v3（2026-11-03）
 *
 * v2 失败的关键教训：v2 是裸二进制，**没有 arm64 Image 头**（offset 0 无 `b`，
 * offset 56 无 "ARM\x64"），ABL 认不出就不会跳 —— 表现是「卡 logo + 标记全 0」。
 * v3 = 真正的 arm64 Image 头（text_offset = 0）+ 魔数 + 自旋。
 *
 * 判据：四窗第 25 页出现连续 ≥64 个 0xA5A5A5A5（scripts/bb-magic-scan.py）。
 */
	.section .text
	.global _start
_start:
	b	_code
	.long	0			// code1 (reserved)
	.quad	0			// text_offset = 0（关键：ABL 按 load+text_offset 跳）
	.quad	_end - _start		// image_size
	.quad	0xa			// flags = ARM64_IMAGE_FLAG_PAGE_SIZE_4K | LE
	.quad	0			// res2
	.quad	0			// res3
	.quad	0			// res4
	.ascii	"ARM\x64"		// offset 56：magic
	.long	0			// res5
_code:
	movz	w19, #0xA5A5
	movk	w19, #0xA5A5, lsl #16
	movz	x9,  #0x84A0, lsl #16
	movz	x10, #0x9C30, lsl #16
	movz	x11, #0x8930, lsl #16
	movz	x12, #0xE3F0, lsl #16
	movz	x20, #0x0001, lsl #16
	movk	x20, #0x9000
	add	x9,  x9,  x20
	add	x10, x10, x20
	add	x11, x11, x20
	add	x12, x12, x20
	mov	x14, x9
	mov	w15, #512
1:	str	w19, [x9],  #4
	str	w19, [x10], #4
	str	w19, [x11], #4
	str	w19, [x12], #4
	subs	w15, w15, #1
	b.ne	1b
	mov	w15, #32
2:	dc	civac, x14
	add	x14, x14, #64
	subs	w15, w15, #1
	b.ne	2b
	dsb	sy
3:	b	3b
_end:
