# HANDOFF - TRA 17 (control-store readback) blocks the SINTRAN boot

Date: 08-AUG-2026. Nothing below is speculation unless it says so.
Paths are relative to the repo root.

## 1. Why this matters

Booting the Winchester now gets all the way into SINTRAN's own startup, and
SINTRAN stops with

    Micro-code not loaded. CPU revision too low !!

Its test (NDInsight `SINTRAN/NPL-SOURCE/NPL/PH-P2-RESTART.NPL:1049-1055`) is

    X := 100 ; *150017 ; A =: MICVER ; IF A<<13 THEN <fatal>

`150017` is TRA CS. On this machine it returns **000000**, so the compare
fails. Everything else in the Winchester boot chain works: the mass load runs,
the bootstrap executes from address 20, and it reads hundreds of blocks off
the disc before reaching this test.

For reference, the same `WD0-M.IMG` boots to `SINTRAN III RUNNING` under
nd100x - but nd100x does NOT model a control store: it fakes TRA CS
(`src/cpu/cpu_instr.c`, case 017 returns `0x13 | 0x8000`). So the oracle
cannot tell us what the hardware does here; only the microcode and the
schematics can.

## 2. What TRA CS actually does

Microcode (`/mnt/e/Dev/Ronny/nd120uc/source/nd-120-delilah-L-from-K.uc`,
routine `ACS`; addresses confirmed against the OCR'd listing
`ND-120 Mikroprogramlisting-L-ocr.md` lines 3200/3203):

    000746   A,X ALUF,ANDAQ ALUD,NONE   IDBS,ALU   COMM,ADCS   T,NEXT
    000747   B,A ALUF,PASSD ALUD,B      IDBS,RCS   COMM,RWCS   T,RETURN

so: ADCS latches the control-store address (A AND X), then the NEXT microword
reads that control-store word onto the IDB and writes it to A.

`IDBS,RCS` is CSIDBS code **030**. It is deliberately NOT decoded as an IDB
source - both the Microprogrammer's Guide (ND-06.031.1, IDB source table:
"30 RCS Read control store (see also command decode 36,1 - RWCS)") and the
DELILAH Hardware Introduction ("Does not directly enable onto IDB except via
Command RWCS (36.1)") say so. Our DGA correctly has no gate for 030 (nor for
031 PICV, same rule). **There is no missing decode - an earlier version of
this document said there was; that was wrong.**

## 3. Measurements (Verilator, FF and latch mode, both identical)

Test program, deposited at 01000 and started with `1000!`:

    01000  150017   TRA CS
    01001  004002   STA 01003
    01002  124000   JMP *
    01003  177777   sentinel

Result: `01003` reads back **000000** in FF mode AND in latch mode, so this is
NOT a clock-enable/FF-conversion artifact.

Waveform (`scratchpad/simwd/tra17b.fst`, extracted with the streaming helper
`fstfollow.py` - the full VCD of this design is 4.2 GB, do not write it):

    t=565785  COMM=36 MIS=1  RWCS=0             <- the RWCS microword executes
    t=565795  WRFSTB=1                          <- register-file write strobe
    t=565855  ECSL=0 EW=16  IDB=142001  FIDBO=142001   <- data finally arrives
    t=565875  (data still held)
    t=565885  data gone, A still 000000

`142001` is exactly the low 16-bit slice of `wcs_image.hex` word 0 - the right
value for the address this program selects (A AND X = 0). So the control store
reads correctly and the word reaches the CGA's internal bus (FIDBO). It is
simply LATE relative to the write strobe.

## 4. Why it is late

`Verilog/Shared/support/IDT6168A_20.v` models the WCS SRAM as a SYNCHRONOUS,
registered-read block RAM ("Read latency is 1 sysclk"), deliberately, for FPGA
block-RAM inference. The real IDT6168A is an ASYNCHRONOUS 20 ns SRAM whose data
is valid inside the same microcycle. `DECODE_DGA_IDBS.v` already carries a
hand-written compensation for the same deviation on another signal ("Our
simulated WCS has 1-cycle registered output, causing CSIDBS to appear one
instruction late").

The RWCS path cannot tolerate that, because one microword both requests and
consumes the data.

## 5. Fix already applied (keep it)

`Verilog/CPU-BOARD-3202/circuit/CPU_CS_CTL_18.v`:

    -assign s_ecsd_n = s_lcs_n & s_ewca_n;
    +assign s_ecsd_n = s_lcs_n & s_ewca_n & s_ecsl_n;

ECSD enables the 74139 that drives EW_3_0_n (the control-store word select).
It was gated only by EWCA, which drops as the cycle enters CC3, so the slice
deselected while ECSL still held the read window open - measured: the data was
on the IDB for ONE sample before, three samples after. Cannot create a
spurious drive (the transceiver needs ECSL_n low AND WCS_n high to source the
IDB, and ECSL requires WCS_n high, so the write direction is untouched).
Necessary but NOT sufficient on its own.

## 6. Open question for Ronny (this is where it is stuck)

`WRFSTB` (PAL_44307C: `~(CC3|CC2|CC1|CC0_n|TERM)`) pulses in cycle state `b` -
EARLY in the microcycle - while `EWCA` (which puts the ADCS address onto MA)
needs CC2 or CC1, i.e. LATER. So even on real hardware the state-`b` strobe
cannot be capturing the data requested in the same state. Two readings, and
picking wrong here means changing shared microcode-fetch timing:

  (a) The register-file write for a microword happens in state `b` of the
      FOLLOWING microcycle (a pipelined write-back). Then our RWCS data
      (arriving at t=565855) SHOULD be captured by the next state-`b` strobe -
      and something else is preventing it. Nothing measured yet shows a second
      WRFSTB pulse in the window, so this needs a longer capture.

  (b) The RWCS microcycle is stretched by the RWCS-only MCLK/MACLK terms in
      PAL_44307C ("BECAUSE THE CONTROL STORE ADDRESS IS PRESENTED ONTO MA ...
      CAPTURE MICROADDRESS AFTER EWCA TURNED OFF"), and on real hardware the
      async SRAM answers inside that stretched cycle, before the write. Then
      the fix is to make our synchronous read complete earlier - the ADCS
      address is latched a full microword ahead, so the information exists in
      time - WITHOUT breaking normal microcode fetch or BRAM inference.

Making the whole WCS asynchronous is NOT an option: it is 8192 x 64 bits, and
losing block-RAM inference would not fit the Tang (the current build is at
96% logic).

## 7. New regression gate added

`Verilog/CPU-BOARD-3202/circuit/sim/CPU_CS_RWCS_tb.v`, target `test-cs-rwcs`,
registered in `Verilog/tests/run_all_tests.sh`. 18 checks, all passing: RWCS
command decode (PAL_44408B), the ECSL read window (PAL_44305D), transceiver
slice select, read-direction-only, and writable-control-store storage and
readback at addresses 0100 / 0777 / 3777 plus an end-to-end RWCS read. It
proves the HARDWARE path below the microcode is sound, so any fix for the
timing must keep this green.

## 8. Repro recipe

    cd Verilog/sim
    make probe-wd USE_LATCHES=0 EXTRA_WD_DEFINES=-DND120_DEV_DELAY_TICKS=135
    # then, from the session scratchpad:
    python3 simwd/tra17_trace.py         # prints "A after TRA CS = ..."
    python3 simwd/tra_fst.py 150017 x.fst && python3 simwd/fstfollow.py x.fst 746 900

`TRA 12` (TRA ALD) returns 020500 on the same engine, which also confirms the
new ALD default (bootstrap load from the Winchester, run from address 20).
