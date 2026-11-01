_Head:
	adr	x1, _Payload
	b	_Start
	.quad	0xff300000
	.quad	0x400000
	.quad	0
	.quad	0
	.quad	0
	.quad	0
	.ascii	"ARM\x64"
	.long	0
_Start:
	brk	#0x1
	b	.
.text
.align 4
_Payload:
