# MPY verification programs (deposit-BPUN harness)

Tiny hand-assembled programs used to find and verify the CGA_ALU_QREG
MUXQ15-D3 multiply bug (see docs/MPY-dynamic-overflow-rootcause.md).

Build (needs nd100-as/nd100-ld on PATH):

    nd100-as -u -o prog.o prog.s && nd100-ld -o prog prog.o
    python3 mk_bpun.py prog PROG.BPUN

Run against the FF-mode runSim build (~45 s, boots to MOPC then starts the
deposited program with "1000!"; results are read back from RAM at exit):

    printf '1000!\r' | ND120_STDIN_GAP=300000 ND120_MAX_CNT=3300000 \
      ND120_BINLOAD_CHECK=<addr>:<nwords> stdbuf -oL ./obj_dir/VND120_TOP PROG.BPUN

Programs:
- mpycheck.s  - one overflowing MPY (040000x040000), then TRA STS + BSKP ONE
                SSQ/SSO stored to RAM (results at 01021-01023, dump 1000:20).
- mpylvl.s    - same MPY plus a forced level-0->1->0 round trip before the
                STS checks; proves the per-level STS save/restore keeps the
                overflow bits (results at 01033-01035, handler marker 01040,
                dump 1000:40).
- mpysweep2.s - 10 operand pairs covering the signed-16 boundary cases; each
                row stores TRA-STS-after-MPY and the product (table at 01017,
                4 words per row, dump 1017:40). Expected behaviour matches the
                nd100x reference: O(040)+Q(020) set iff abs(product) > 32767 -
                including product exactly -32768 (the microcode multiplies
                negated-positive operands, so +32768 overflows internally).

BSKP ONE SSQ/SSO are hand-encoded as .word 0175240/0175250 (assembler lacks
the STS-flag mnemonics). Numeric literals: leading 0 = octal (C-style).
