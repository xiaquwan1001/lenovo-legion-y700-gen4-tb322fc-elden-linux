/* Minimal Gunyah guest payload: prove execution, then fault on unmapped phys. */
	.section .text
	.global _start
_start:
	movz	x1, #0xBEEF, lsl #16
	movk	x1, #0x1234
	movz	x2, #0x0F00, lsl #16		/* 0x0F000000: no memory lent */
	str	x1, [x2]			/* -> should surface as vCPU MMIO/page-fault exit */
1:	b	1b
