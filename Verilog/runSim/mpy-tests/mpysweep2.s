# MPY sweep v2: rows of (opd1,opd2,sts,product)
.text
.globl _start
_start:
	lda t_addr
	copy sa dx
loop:
	lda ,x 0
	mpy ,x 1
	tra sts
	sta ,x 2
	lda ,x 0
	mpy ,x 1
	sta ,x 3
	aax 4
	min cntr
	jmp loop
done:
	jmp done
cntr:
	.word -10
t_addr:
	.word table+01000
table:
	.word 040000
	.word 040000
	.word 0
	.word 0
	.word 02
	.word 037777
	.word 0
	.word 0
	.word 02
	.word 040000
	.word 0
	.word 0
	.word 0177776
	.word 040000
	.word 0
	.word 0
	.word 0100000
	.word 01
	.word 0
	.word 0
	.word 0100000
	.word 0177777
	.word 0
	.word 0
	.word 0100000
	.word 0100000
	.word 0
	.word 0
	.word 0177777
	.word 0177777
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 037777
	.word 02
	.word 0
	.word 0
