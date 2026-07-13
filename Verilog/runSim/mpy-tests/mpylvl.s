# MPY overflow + level-switch round trip, then check STS.
# Level 0: set up level-1 handler P, PIE, ION; MPY (sets Q/O);
# MST PID bit1 -> switch to level 1; handler WAITs -> back to level 0;
# then TRA STS + BSKP checks. Program loads at octal 1000.
# res1=TRA STS, res2=Q set?, res3=O set?
.text
.globl _start
_start:
	lda h_addr
	irw 010 dp
	saa 3
	trr pie
	ion
	lda opd1
	mpy opd2
	saa 2
	mst pid
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
handler:
	saa 77
	sta h_ran
	wait
	jmp handler
h_addr:
	.word handler+01000
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
h_ran:
	.word 0
