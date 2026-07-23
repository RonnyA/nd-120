# SHIFT ROT/ZIN/LIN root cause: SSEL capture flops never saw the instruction

**Status: FIXED** in `Verilog/DELILAH-CPU/CGA_ALU/circuit/CGA_CPU_ALU_CONTR.v`
(MEMORY_46/47 rising-edge flip-flops replaced by the `SSEL_LATCH` transparent
latch, mirroring the MIC IR latch). Found 13-JUL-2026 during the
INSTRUCTION-B deep-validation campaign.

## Symptom

INSTRUCTION-B `SHIFT-INSTRUCTIONS` area reaches `== END OF TEST ==` with 3988
error lines: sub-tests `SHA5OP-8OP`, `SHD5OP-8OP`, `SHT5OP-8OP` (the
`ZIN SHR` / `ROT` / `ROT SHR` / `LIN` modes) fail **all 256 cases each**,
plus part of the `SAD*OP` (shift-double) family. Sub-tests 1OP-4OP (plain
arithmetic modes) pass. Confirmed **pre-existing**: a baseline binary built
without the CGA_ALU_QREG multiply fix shows the identical SHA/SHD/SHT
signatures (the QREG fix only changed the SAD family - it cured SAD3OP).

Golden-trace 400-instruction windows could not see this: the failing
sub-tests execute deeper in the area than the golden coverage reaches.

## Ground truth (deposit-BPUN, `Verilog/runSim/shift-tests/`)

`shiftcheck.s` runs 12 hand-encoded shift cases and stores (result, STS)
pairs. Against the nd100x reference (`ShiftReg()` in
`~/repos/nd100x/src/cpu/cpu_instr.c`: ROT re-enters the shifted-out bit,
ZIN enters 0, LIN enters M, M := last bit shifted out; M = STS bit 7):

Pre-fix, **every shift executed in plain arithmetic mode**:
- `SHA ROT 1` of 0100001 gave 000002 (plain SHL) instead of 000003
- `SHA ZIN SHR 1` of 0100001 gave 0140000 (sign copy) instead of 0040000
- `SHA LIN 1` with M=1 gave 000000 instead of 000001
- `SHT`/`SHD` identical; the M flag itself was correct in every case
  (the shift-out path and STS update work; only the serial INPUT was wrong).

## Root cause

The shift-type field is instruction bits 10:9 (00 plain, 01 ROT, 10 ZIN,
11 LIN). In `CGA_CPU_ALU_CONTR` it is captured from the CD bus on the LDIRV
strobe into MEMORY_46/47, muxed with the microcode `CSMIS` field
(`CSMIS*_MUX`, selected by `CSALUM=11` = "take serial-input select from the
instruction"), registered into `SSEL` by `CONTR_REG` on ALUCLK, and decoded
by GATES_20-24/31-37 into the ALU serial inputs `RRI`/`RLI`/`QLI`.

MEMORY_46/47 were **rising-edge D flip-flops** clocked by LDIRV. Probing
every LDIRV edge during a run (`ND120_PROBE_SHIFT` in `runSim/Run120.cpp`)
proved the phase relationship makes that capture impossible:

- at every LDIRV **rise**, CD = 000000 - the bus does not yet hold the
  instruction;
- at every LDIRV **fall**, CD holds the instruction word (155401, 156477,
  157401, ... each of the test's opcodes in program order, with the correct
  type bits present on the module's own `s_cd_10_9` input).

So MEMORY_46/47 captured 0 forever, `SSEL` decoded as 00, and every shift
ran plain. This is exactly why the MIC's own instruction register works: the
CGA_MIC `IRLATCH` is an `L8` **transparent latch** gated by LDIRV - it
tracks CD through the LDIRV-high window and holds the value present at the
fall. The same is required here. Both latch and FF builds were broken (the
latch build used a rising-edge flip-flop on LDIRV too).

## Fix

MEMORY_46/47 replaced with one `L8` (`SSEL_LATCH`) gated by LDIRV, wired
exactly like the MIC IRLATCH: transparent through the LDIRV-high window in
latch mode, sysclk-sampled while LDIRV is high in FF mode. No ifdefs, no
clock changes; the downstream mux/register/decode chain is untouched.

Post-fix shiftcheck: all ROT/ZIN/LIN single-bit and multi-bit cases match
the nd100x reference; `m46`/`m47` show the correct type bits after every
instruction load.

## Known semantics divergence vs nd100x (deliberate, hardware wins)

`SHA LIN SHR 2` with M=1 on A=0: nd100x samples M **once** per instruction
(gives 0140000); our microcode loop inserts the **live** M each microcycle
and updates M per step (gives 0040000 - a link-chain shift). The
INSTRUCTION-B deep run is the arbiter for which semantics the real ND-110/
ND-120 had; see the SHIFT-INSTRUCTIONS deep verdict.

## Logisim regeneration hazard

`CGA_CPU_ALU_CONTR.v` is Logisim-generated. If the Logisim CGA_ALU_ drawing
(schematic page 42) draws MEMORY_46/47 as D flip-flops on LDIRV, regenerating
the Verilog reintroduces this bug. The drawing needs the same latch fix as
the QREG D3 fix (tracked in `Verilog/TODO.md`). The original design PDF
should be checked for whether the SSEL capture is drawn as a latch there
(the IR capture on the MIC sheet is a latch).

## Probe recipe (reusable)

```
cd Verilog/runSim
make compile USE_LATCHES=0 EXTRA_CFLAGS="-DND120_PROBE_SHIFT" \
  VERILATOR_FLAGS="--trace -Wall --cc ../ND120_TOP.v --public-flat-rw \
  $(SUPPRESS_FLAGS) $(SIM_DEFINES)"
printf '1000!\r' | ND120_STDIN_GAP=300000 ND120_MAX_CNT=3300000 \
  ND120_BINLOAD_CHECK=1000:144 stdbuf -oL ./obj_dir/VND120_TOP \
  shift-tests/SHIFTCHECK.BPUN
```

`[shp-ir]` lines log LDIRV edges with the CD bus and captured bits;
`[shp]` lines log the SSEL/RRI/RLI/QLI decode whenever a shift-loop
microword (`CSALUM=11`) executes.
