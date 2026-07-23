# SHIFT ground-truth: 12 cases, each stores (result, STS-after) word pair
# Shift opcodes hand-encoded (.word): SHT=0154000 SHD=0154200 SHA=0154400
# type bits 10-9: plain=0 ROT=01000 ZIN=02000 LIN=03000; SHR n = offset 0100-n
# Expected results (nd100x ShiftReg): see README.md
.text
.globl _start
_start:
# case 1: SHA ROT 1, A=0100001 -> A=000003, M(bit7 of STS)=1
	lda c8001
	.word 0155401
	sta r00
	tra sts
	sta r01
# case 2: SHA ROT SHR 1, A=0100001 -> A=0140000, M=1
	lda c8001
	.word 0155477
	sta r02
	tra sts
	sta r03
# case 3: SHA ZIN SHR 1, A=0100001 -> A=0040000, M=1
	lda c8001
	.word 0156477
	sta r04
	tra sts
	sta r05
# case 4: SHA ZIN 1, A=0100001 -> A=000002, M=1
	lda c8001
	.word 0156401
	sta r06
	tra sts
	sta r07
# case 5: preset M=1 (ROT 1 of 0100001), then SHA LIN 1 of 0 -> A=000001, M=0
	lda c8001
	.word 0155401
	lda czero
	.word 0157401
	sta r08
	tra sts
	sta r09
# case 6: preset M=1, SHA LIN SHR 1 of 0 -> A=0100000, M=0
	lda c8001
	.word 0155401
	lda czero
	.word 0157477
	sta r10
	tra sts
	sta r11
# case 7: preset M=1, SHA LIN SHR 2 of 0 -> A=0140000 (M sampled once), M=0
	lda c8001
	.word 0155401
	lda czero
	.word 0157476
	sta r12
	tra sts
	sta r13
# case 8: SHA plain SHR 1 of 0100001 -> A=0140000, M=1 (control: passes deep test)
	lda c8001
	.word 0154477
	sta r14
	tra sts
	sta r15
# case 9: SHA ROT 3 of 0100001 -> A=000014, M=0
	lda c8001
	.word 0155403
	sta r16
	tra sts
	sta r17
# case 10: SHA ZIN SHR 3 of 0100001 -> A=0010000, M=0
	lda c8001
	.word 0156475
	sta r18
	tra sts
	sta r19
# case 11: SHT ROT 1 of 0100001 -> T=000003 (copied to A), M=1
	lda c8001
	copy sa dt
	.word 0155001
	copy st da
	sta r20
	tra sts
	sta r21
# case 12: SHD ROT 1 of 0100001 -> D=000003 (copied to A), M=1
	lda c8001
	copy sa dd
	.word 0155201
	copy sd da
	sta r22
	tra sts
	sta r23
# marker: 0123 proves straight-line completion
	saa 0123
	sta r24
done:
	jmp done
c8001:
	.word 0100001
czero:
	.word 0
r00:
	.word 0
r01:
	.word 0
r02:
	.word 0
r03:
	.word 0
r04:
	.word 0
r05:
	.word 0
r06:
	.word 0
r07:
	.word 0
r08:
	.word 0
r09:
	.word 0
r10:
	.word 0
r11:
	.word 0
r12:
	.word 0
r13:
	.word 0
r14:
	.word 0
r15:
	.word 0
r16:
	.word 0
r17:
	.word 0
r18:
	.word 0
r19:
	.word 0
r20:
	.word 0
r21:
	.word 0
r22:
	.word 0
r23:
	.word 0
r24:
	.word 0
