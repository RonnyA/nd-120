# NLZ/DNZ ground-truth: 8 cases, results stored as (T,A,D,STS) quads at res
# NLZ +16 = .word 0151420 ; DNZ -16 = .word 0152360 (scaling in low byte)
# 48-bit float: T = sign(b15)+exponent(bias 16384), A:D = mantissa (A15=1)
# Expected (nd100x float.c DoNLZ/DoDNZ):
#  c1 NLZ+16 A=1      -> T=040001 A=100000 D=0
#  c2 NLZ+16 A=177777 -> T=140001 A=100000 D=0
#  c3 NLZ+16 A=0      -> T=0 A=0 D=0
#  c4 NLZ+16 A=077777 -> T=040017 A=177776 D=0
#  c5 DNZ-16 T=040001 A=100000 D=0 -> A=1 T=0 D=0
#  c6 DNZ-16 T=140001 A=100000 D=0 -> A=177777 T=0 D=0
#  c7 DNZ-16 T=040017 A=177776 D=0 -> A=077777 T=0 D=0
#  c8 NLZ+16 A=012345 then DNZ-16 -> A=012345 T=0 D=0
.text
.globl _start
_start:
	lda vone
	.word 0151420
	jpl savetad
	lda vm1
	.word 0151420
	jpl savetad
	lda vzer
	.word 0151420
	jpl savetad
	lda vmax
	.word 0151420
	jpl savetad
	lda ve1
	copy sa dt
	lda vm8
	rclr dd
	.word 0152360
	jpl savetad
	lda ve1n
	copy sa dt
	lda vm8
	rclr dd
	.word 0152360
	jpl savetad
	lda ve15
	copy sa dt
	lda vmant
	rclr dd
	.word 0152360
	jpl savetad
	lda vpat
	.word 0151420
	.word 0152360
	jpl savetad
	saa 0123
	sta mark
done:
	jmp done
# save T,A,D,STS to [pptr], pptr += 4; clobbers X
savetad:
	ldx pptr
	sta ,x 1
	copy st da
	sta ,x 0
	copy sd da
	sta ,x 2
	tra sts
	sta ,x 3
	lda pptr
	aaa 4
	sta pptr
	exit
vone:
	.word 01
vm1:
	.word 0177777
vzer:
	.word 0
vmax:
	.word 077777
ve1:
	.word 040001
ve1n:
	.word 0140001
vm8:
	.word 0100000
ve15:
	.word 040017
vmant:
	.word 0177776
vpat:
	.word 012345
pptr:
	.word res+01000
res:
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
mark:
	.word 0
