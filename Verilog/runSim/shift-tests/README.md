# SHIFT verification program (deposit-BPUN harness)

Tiny hand-assembled program used to find and verify the CGA_CPU_ALU_CONTR
SSEL-capture bug (see docs/SHIFT-serial-input-rootcause.md): the shift-type
bits (instruction bits 10:9) were captured by rising-edge flip-flops on
LDIRV, which never see the instruction on the CD bus, so every
SHA/SHD/SHT/SAD ROT / ZIN-right / LIN shift executed as a plain arithmetic
shift.

Build (needs nd100-as/nd100-ld on PATH):

    nd100-as -u -o shiftcheck.o shiftcheck.s && nd100-ld -o shiftcheck shiftcheck.o
    python3 ../mpy-tests/mk_bpun.py shiftcheck SHIFTCHECK.BPUN

Run against the FF-mode runSim build (~60 s):

    printf '1000!\r' | ND120_STDIN_GAP=300000 ND120_MAX_CNT=3300000 \
      ND120_BINLOAD_CHECK=1000:144 stdbuf -oL ./obj_dir/VND120_TOP \
      shift-tests/SHIFTCHECK.BPUN

The program is 100 (decimal) words; the last 27 words of the dump are
c8001 (0100001), czero, then r00-r24: twelve (result, STS-after) pairs and
the 0123 completion marker. Case list and expected values are commented in
shiftcheck.s. M is STS bit 7 (mask 0200).

Shift opcodes are hand-encoded .words (assembler has no SHT/SAD or
type-suffix syntax): SHT=0154000 SHD=0154200 SHA=0154400 SAD=0154600;
+01000 ROT, +02000 ZIN, +03000 LIN; right shift by n = offset field 0100-n.

Expected results (post-fix) match the nd100x ShiftReg reference on all
single-bit and multi-bit cases except multi-bit LIN, where the hardware
microcode inserts the LIVE M flag each step (link-chain) while nd100x
samples M once per instruction; see the root-cause doc.
