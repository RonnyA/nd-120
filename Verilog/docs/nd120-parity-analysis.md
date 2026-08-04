# ND-120 memory-parity semantics: what the self-test and runtime actually require

**Full path:** `Verilog/docs/nd120-parity-analysis.md`
**Date:** 11-JUL-2026. Section-2 deliverable of
`Verilog/docs/nd120-parity-refactor-order.md` (the 18-bit -> 16-bit SDRAM
packing work order). Every claim below carries a microcode reference; the
semantics are pinned by testbench (see section 6), not by this prose.

---

## 1. Verdict

**The ND-120/ND-110 CPU self-test does NOT test memory parity.** It is a
pure CPU-core test (ALU, shifts, register file, STS, loop counter, SWAP,
PIC/PID). It never writes bad parity, never reads stored parity bits back,
and never waits for a parity-error flag or trap. Of the three cases in the
work order section 2 - (a) stored-parity readback, (b) error-flag-on-readback,
(c) datapath-only exercise - **none applies: the self-test does not exercise
memory parity at all.**

Runtime software (SINTRAN) consumes parity only through the **error
machinery**: internal interrupt level 14 with an IIC code, plus the
**PES** (Parity Error Status) and **PEA** (Parity Error Address) internal
registers read via `TRA`. **No code path reads stored parity bits as data.**

Consequence: implementation shape **(a) COMPUTED PARITY** from the work
order is sufficient. Store 16 data bits, two ND words per 32-bit SDRAM
location; generate parity on the read path so the AM29833A checkers always
see consistent parity. No stored-bad-parity shim, no side-band BRAM window,
no side-band SDRAM region is required.

## 2. Ground truth used

- **Clean ROM-validated ND-110 source** (same labels as ND-120; the
  authoritative semantic decode):
  `$ND_REPOS/ND110Compile/ND110Compile/uCode/ND-110-RASK.uc`,
  self-test at lines 4859-5199.
- **L-EPROM decode** (bit-exact):
  `/mnt/e/Dev/Ronny/nd120uc/source/nd-120-delilah.uc`, self-test at
  octal o2053-o2156. (Labels/comments in this range are OCR-polluted -
  trust the bits, not the labels.)
- **Address-annotated listing**:
  `Code/Microcode/ND-120-DELILAH-L.LISTING.txt`
  lines 5290 (self-test start), 5518 (o2123), 5676 (o2156 STERR).
- Token semantics: `nd120uc/scripts/nd120_tokens.json` (`IDBS,PEA` =
  "PEA-REGISTER -> IDB", `IDBS,PES` = "PES-REGISTER -> IDB"; no token
  forces bad parity or inhibits the parity generators).

## 3. The self-test, subtest by subtest

Entry `SELFT:` at octal **o2053** (RASK.uc:4862; listing line 5290). Eight
subtests; each preloads R2 with a fixed error code before running:

| # | RASK.uc line | Tests | Error code (R2, octal) |
|---|--------------|-------|------------------------|
| 1 | 4867 | ALU: 0-1+1=0 | 400 |
| 2 | 4887 | ALU add-loop: 0+1*5=5 | 1000 |
| 3 | 4917 | shift double left | 1400/2000 |
| 4 | 4966 | -1 -> R5, 0 -> Q | 2400/3000 |
| 5 | 4998 | 170(AARG) -> SWAP = 74000 | 3400 |
| 6 | 5023 | loop counter LC, shift-right-double via GPR | 4000/4400 |
| 7 | 5072 | STS + register file (COMM,EWRF) | 5000/5400/6000 |
| 8 | 5123 | PIC/PID register | 6400 |

No PARITY subtest. No `MOR`/`PEA`/`PES`/`ECC` **write** anywhere in the
program. A repo-wide microcode search for parity manipulation returned only
UART even-parity comments (o1724-o1761, o4090-o4096) - serial-line parity,
unrelated to memory.

**TEST 6 is the loop the Verilog boots into** (o2116-o2123; the
boot-golden-spec "Phase 4 self-test loop"). It is a shift/loop-counter
test, not a parity test.

## 4. Where the folklore came from

Two artifacts:

1. **The `IDBS,PEA` word at o2123.** Decoded L-EPROM word:
   `ALUD,NONE ALUF,A+Q LCOUNT IDBS,PEA T,HOLD T,NEXT` (delilah.uc o2123;
   RASK.uc:5064-5066, whose comment literally reads `% LOOP BACK`).
   `ALUD,NONE` discards the ALU result; the word's real job is `LCOUNT`
   (decrement the loop counter) and fall-through for TEST 6. The IDB-source
   select is a **don't-care** - the PEA read is never consumed, never
   compared, never checked. This is loop plumbing, not a parity test.
2. **A stale RTL claim.** `Verilog/TODO.md` (lines ~142-153) and the work
   order describe `AM29833A.v` as stubbed (`ERR_n=1`, `PAR_OUT=0`). That is
   **no longer true**: `Verilog/Shared/support/AM29833A.v` implements real
   parity (PAR_OUT = ~(^R) on transmit, 9-bit receive-side check register
   driving ERR_n; reviewed 22-MAR-2025). The stub is history; the semantics
   below were derived from the actual module.

Also corrected: the note "self-test STERR increment = o1134" (nd120-fpga
skill / older notes) is wrong for the L EPROM. o1134 is unrelated
firmware-loop code (`FWLO3`, `IDBS,SWAP`). **`STERR:` is at o2156**
(delilah.uc o2156; RASK.uc:5193; listing line 5676) and it is not a
counter: it is the error *display/halt* routine - a failing subtest jumps
to STERR/STER1/STER2, which display error number R2/R2+1/R2+2 and then
`% LOOP ON ERROR` (RASK.uc:5197). A failing CPU parks displaying the
failing subtest's code.

**Implication for the 7/14 self-test baseline:** none of the 8 subtests
touches memory parity, so the parity path (stubbed or real) cannot be the
cause of any of the 7 failures. The hoped-for "parity fix improves the
baseline" side effect in the work order will not materialize via the
self-test; the real suspects remain the ones in TODO.md's
microcode-fidelity section (JMP0-3 vectored jump, IDB OR-bus merging).

## 5. Runtime (SINTRAN) parity surfacing

- **`TRA PES`** - handler `TAPES` reads `IDBS,PES` (RASK.uc:8864; L-EPROM
  o3673, delilah.uc line 10944). A second path `APES1` at o0514
  (delilah.uc line 2235) does `COMM,SIOC`, commented "TRA PES ... NEED TO
  CLEAR DOWN PARERR INTERRUPT FROM THE ON-BOARD MEMORY".
- **`TRA PEA`** - handler `TAPEA` reads `IDBS,PEA` (RASK.uc:8868; L-EPROM
  o3675, delilah.uc line 10954).
- **`TRA IIC`** - `AIIC1` (RASK.uc:2059; delilah.uc o0500) returns the
  internal interrupt code used on the level-14 dispatch to distinguish
  memory/parity errors from other internal faults.

All of these read **purpose-built error registers**, not parity bits as
data. Note also that in the current RTL the parity-error path is
switch-disabled: `MEM_DATA_46.v` ties the PAL_45008B `SWDIS_n` input to
GND ("SW4 - Parity disable ... HERE: Disabled!").

## 6. The pinned contract (what the testbench encodes)

For the packed 16-bit storage mode (`ND_SDRAM_PACK16`):

1. **Data round-trip:** all 16 data bits (DD[16:9], DD[7:0]) of every ND
   word are stored and read back exactly; two adjacent ND words (even/odd)
   sharing one 32-bit SDRAM location are fully independent - writing one
   never disturbs the other (DQM lane-masked single-access writes, no
   read-modify-write).
2. **Computed parity on read:** DD[8] and DD[17] are regenerated as odd
   parity (DD[8] = ~^DD[7:0], DD[17] = ~^DD[16:9]), so `CORR_n` = 1 and
   the AM29833A receive-side check always passes for stored data.
3. **Bad-parity writes are absorbed:** a write with deliberately wrong
   DD[8]/DD[17] stores the 16 data bits; readback returns the data with
   CORRECT (computed) parity. This is a deliberate, documented semantic
   change from stored-parity 18-bit mode, licensed by sections 3-5: no
   self-test or runtime path observes it.
4. **Legacy mode untouched:** without `ND_SDRAM_PACK16` the 18-bit
   one-word-per-location behavior (including stored-bad-parity round-trip)
   is bit-identical to before; Verilator/Basys3 builds are unaffected
   entirely (the define only exists inside the Tang SDRAM backend).

Testbench: `Verilog/fpga/tang-nano-20k/sdram-bridge/sim/` - the 18-bit tb
(`test`) plus the packed-mode tb (`test-pack16`), both registered in
`Verilog/tests/run_all_tests.sh` and emitting `TB_RESULT: PASS`.

## 6b. POLICY (Ronny, 3-AUG-2026): no FPGA target ever STORES parity

Section 6's contract was written for the Tang SDRAM backend only. It is now
the rule for **every** sheet-49 memory backend, by decision, not by build
flag: **FPGA block RAM is never spent on parity bits.** One bit per word costs
a whole RAMB18 per chip (the smallest block the tools allocate) to hold data
nothing reads back.

Every backend therefore drops DD[8] / DD[17] on write and regenerates them on
read as odd parity of the byte returned - `PAR = ~^data`, the Am29833A
convention:

| Backend | Target | Before 3-AUG-2026 | Now |
|---|---|---|---|
| `MEM_RAM_49_SDRAM` (`ND_SDRAM_PACK16`) | Tang | regenerated | unchanged |
| `SIP1M9` `ramSize=3` | Basys3 | **returned constant 0** | regenerated |
| `SIP1M9` `ramSize=2` | Verilator | stored | regenerated |
| `MEM_RAM_49_BLOCKRAM` | FPGA variant | stored, 18-bit array | regenerated, 16-bit array |
| `MEM_RAM_49_SIM` | Verilator | regenerated only under `ND_SDRAM_PACK16` | regenerated always |

The old Basys3 behaviour was not merely "not stored" - constant 0 is the
WRONG parity for every byte of even population, i.e. **128 of 256 values**
(measured, see the tb below). It survived only because `MEM_43.v` masks
`LPERR_n`. The sim backends were changed too, deliberately: a backend that
stores parity in Verilator while the FPGA regenerates it is the sim-vs-silicon
split that the golden reference exists to prevent.

`RAM_PARITY_STORAGE` is gone. There is no way to switch storage back on, which
is the point.

Gates:

- `Shared/support/sim :: test-am29833a-parity` - drives the chip that actually
  checks parity over all 256 byte values: regenerated parity must never fault,
  the inverted bit must always fault, and constant 0 faults exactly 128/256.
  This is what makes unmasking `LPERR_n` a safe future step.
- `CPU-BOARD-3202/circuit/sim :: test-memchain{,-blockram,-sim}` - the same
  chain testbench against three backends. Its parity sweep writes 16 patterns
  **with deliberately wrong parity** and requires correct regenerated parity
  back, so storing, zeroing or inverting all fail. Teeth-proven 3-AUG-2026: a
  build with Q9 forced back to 0 fails 35 checks.

Still open, and NOT fixed by this work: `MEM_43.v` masks `LPERR_n`, and
`AM29833A.v` evaluates its parity check only when `!ReceiveMode` while
`MEM_DATA_46` wires the memory bus to T and LBD to R - so a memory READ is
receive mode and the board's check does not evaluate there at all. See
`Verilog/TODO.md`.

## 7. References

- Work order: `Verilog/docs/nd120-parity-refactor-order.md`
- Bridge design: `Verilog/docs/nd120-dram-memory.md` (section 6's "rejected
  for now: recompute parity" note is superseded by this analysis)
- Storage consumer of the freed half: `Verilog/docs/nd-storage-design.md`
- Parity transceiver RTL: `Verilog/Shared/support/AM29833A.v`;
  instantiation `Verilog/CPU-BOARD-3202/circuit/MEM_DATA_46.v`
