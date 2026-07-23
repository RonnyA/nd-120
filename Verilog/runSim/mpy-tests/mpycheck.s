# MPY overflow macro-level check: MPY 040000*040000 (overflows),
# then read STS via TRA and test Q/O via BSKP, store results to memory.
# res1 = TRA STS value; res2 = 1 if BSKP ONE SSQ skipped (Q set); res3 = same for SSO.
.text
.globl _start
_start:
	lda opd1
	mpy opd2
	tra sts
	sta res1
	saa 0
	.word 0175240
	jmp qzero
	saa 1
qzero:
	sta res2
	saa 0
	.word 0175250
	jmp ozero
	saa 1
ozero:
	sta res3
loop:
	jmp loop
opd1:
	.word 040000
opd2:
	.word 040000
res1:
	.word 0
res2:
	.word 0
res3:
	.word 0
