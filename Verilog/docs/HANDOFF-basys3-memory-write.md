# Handoff: Basys3 FPGA memory (write) + sim write-break

---

## THIRD finding (8-JUL-2026 evening) - THE remaining FPGA write bug, both boards

Conclusively isolated on the Tang (which is now a fast test vehicle: rebuild
= minutes, working OPCOM console): **the write data NEVER reaches DD_17_0_IN
on silicon.** An OR-accumulating capture sampling DD on BOTH edges of the
13.5 MHz clock (37 ns granularity) across the entire access collected all
zeros - and since the AM29833A drives hard 0 when disabled, any real driven
bit would have been caught. (Earlier "partial data" reads were metastable
junk.) Reads, echo, boot, addressing: all work. Sim (latch AND FF mode):
deposits work. FPGA only: the AM29833A transceivers in MEM_DATA_46 never
enter TransmitMode.

**Prime suspect:** the transceiver enables `OET_n`/`OER_n` from
`PAL_45008B` (instance `PAL_45008_UDATA` in `MEM_DATA_46.v`, clocked on
s_osc; PAL_45008B is on the USE_TRANSPARENT_LATCHES list) - in FF mode on
real silicon the enable window apparently never opens (or opens as an
unsampleable glitch). This is upstream of BOTH memory backends and explains
the Basys3 "writes ignored" identically.

**LED debug build result (8-JUL evening, Tang):** sticky flags show MWRITE50
strobe = seen, undelayed MWRITE = seen, DD nonzero = seen - BUT the bridge's
window-qualified capture proves DD is all-zero INSIDE the RAS/CAS window. So
the data/MWRITE activity happens OUTSIDE the access window. Explanation that
fits everything: `MEM_ADEC_45.v:137`
  assign s_mwrite_n_out = (~bgnt & ~cgnt) ? 1 : (~bgnt & ub_mwrite_n) | (~cgnt & uc_mwrite_n);
asserts MWRITE (=0) whenever NO grant is active (idle) -> transceivers
transmit idle LBD junk (lights the DD flag), while during a real CPU write
grant MWRITE_n follows `s_uc_mwrite_n` (PAL_44446B Q3, registered) which on
silicon does NOT assert during the window. Zero-delay sim happens to overlap
the phases; FF-mode silicon does not.

**THE two targets now:**
- `PAL/PAL_44446B.v` (and `PAL_44445B.v` for the bus side): the Q3 MWRITE_n
  equation and what its FF/latch conversion does to its phase vs the
  RAS/CAS window from PAL_44902A.
- `CPU-BOARD-3202/circuit/MEM_ADEC_45.v:137`: the no-grant default drives
  MWRITE ACTIVE - check against the original PALASM (this polarity looks
  wrong and masks the real signal; original PAL likely had MWRITE_n=1 idle).
NOTE the project rule "never modify PAL files" - if the fix lands in a PAL,
mirror the pattern used for CYC_CC_D/CYC_TERM_D (derived _D module) or fix
at the ADEC/consumer level.

**ACCEPTANCE GATE for the PAL_44446B/44445B `_D` conversion (per Ronny):**
1. Equivalence tb (original PAL vs `_D`, CYC_CC_D-style) passes.
2. FF-mode Verilator (`runSim`, `USE_LATCHES=0`): boots to `#`, deposit
   `22/ 054321 CR 22/` -> `/054321`, AND the test program runs: `0!` (and/or
   `20!` for DEBUG.BPUN) must produce the EXPECTED TEXT OUTPUT, identical to
   latch mode / the known-good baseline. NOT just boot - full execution.
3. On the Tang: LEDs 1-3 + deposit readback + `0!`/`20!` expected text on
   the 9600 console.

**_D PAL conversion done - sim gate PASSED, board still FAILS (8-JUL 18:40):**
`PAL_44446B_D.v`/`PAL_44445B_D.v` created (sysclk + CK-edge enable, equations
verbatim), swapped in `MEM_ADEC_45` under `ifdef FPGA_FF_MODE` (sysclk ports
threaded via MEM_43). FF-mode runSim: boot + deposit + `0!` runs DEBUG.BPUN
to its monitor, BYTE-IDENTICAL to latch mode. On the Tang: deposits still
read back 000000 and `0!` is silent. So the DBAPR/ECREQ clock domains are
cleaned (keep the _D modules - correct hygiene) but were NOT the write-data
break. Gowin can now be built FROM WSL directly:
`/mnt/c/Utils/Gowin/Gowin_V1.9.10.02_x64/IDE/bin/gw_sh.exe 'E:\...\gowin_build.tcl'`.

**NEXT = STOP INFERRING, MEASURE: GAO capture** (Gowin IDE GUI, Windows):
sample clock clk2x; probes: s_ras, s_cas, s_mwrite_n (ADEC out),
s_mwrite50_n, s_uc_mwrite_n / s_ub_mwrite_n, s_cgnt_n, s_bcgnt50, s_dbapr,
s_ecreq, s_write, BINPUT_n at the PAL, and s_ram_dd_17_0_in; trigger on
s_mwrite50_n falling; depth 512. One deposit while armed shows the real
in-window phases. Open nd120_tang20k.gprj in the IDE, Tools->GAO. Also
check MEM_ADEC_45:137 idle-assert polarity vs the original PALASM while
waiting for synthesis.

**MEASURED ON SILICON (8-JUL 19:35, on-chip analyzer, 511-sample trace):**
The write path mystery is SOLVED one level up. Trace of a granted deposit
access (clk2x sampling, trigger mw50_n edge): ECREQ rises -> CGNT grant ->
clean RAS/CAS window - but **the CPU's `WRITE` input to MEM_ADEC_45 is 0 in
ALL 511 samples**, so MWRITE_n goes HIGH during the grant and the deposit
executes as a READ. Confirmed also: MWRITE idle-asserts between grants
(ADEC :137) and the DD "junk" exists only in idle. ALL downstream layers
(ADEC _D PALs, PAL_45008B, AM29833A, SDRAM bridge) are exonerated by
measurement.

**ROOT TARGET: the `WRITE` output of the DELILAH CPU core (CGA/MAC,
ND3202D `s_write`, CPU instance ~line 719) never asserts on silicon** while
working in both sim modes -> almost certainly another derived-clock capture
inside CGA/CYC (MCLK/UCLK domain - the clock-enable refactor territory,
same family as the CYC_36 fixes). Next: trace WRITE generation in the CGA
(microcode CSCOMM decode -> MAC write cycle), find the register that
launches it and what clocks it in FF mode.

**WRITE CHAIN TRACED IN RTL (8-JUL late) - it is the DGA, not the CGA:**
`WRITE` does NOT come from the DELILAH CGA. Path: `ND3202D` `s_write` <-
`IO_37` <- `IO_DCD_38` <- DGA `XWRI` <- `DECODE_DGA_COMM.v` **F924 A160
Q3** (4-bit FF, `.C_H05(s_clk2)` = board `CLK` from CYC_36, a generated
clock). D3 = `s_a167_nand_out` = NAND(A147, A144) = decode high when
`CSCOMM_4_0` in {5'b11010, 5'b11011, 5'b11101} AND `LCS_n`=1. The SAME
F924 also produces `MREQ` (Q2B) and `FETCH` (Q0) - and MREQ/FETCH visibly
work on silicon, so the suspect is specifically the D3 decode phase vs
the CLK edge in FF mode (CSCOMM comes from the microword pipeline in a
different clock family). Note `IO_DCD_38` is also where the FPGA-only
OSC clean-clock fix (0fb062b) landed - same module, same clocking family.

**ANALYZER RETARGETED (8-JUL late, this session):** `DBG_MEMW` is now
assembled in `ND3202D.v` (the MEM_43 bus moved to internal `s_dbg_mem43`,
RAS/MWRITE_n kept as bits [15:14]). New map:
[4:0]=CSCOMM_4_0 [5]=LCS_n [6]=WRITE [7]=wdec (the A167 decode recomputed
at board level = F924 D3 input) [8]=CLK (the F924 clock) [9]=UCLK
[10]=ECREQ [11]=CGNT_n [12]=MREQ_n [13]=DT_n [14]=MWRITE_n [15]=RAS.
Trigger = wdec RISING edge after the 2.5 s arm; 64 pre + 448 post samples.
LEDs: LED1=WRITE live, LED2=sticky WRITE-seen since arm, LED3=sticky
wdec-seen since arm, LED4=dump ran. Interpretation on the board:
- LED3 never ON after a deposit => the CSCOMM write decode NEVER fires on
  silicon => go upstream (microword pipeline / CSCOMM path in FF mode).
- LED3 ON, LED2 OFF => decode fires but the F924 misses it => D3-vs-CLK2
  phase in FF mode; the dump shows decode width vs CLK edges directly.
- LED2 ON => WRITE asserts after all => timing vs ECREQ/grant in the dump.

**Full-build pre-synth sim added:** `fpga/tang-nano-20k/sim/Makefile`
(`make test`) compiles the EXACT Gowin file list (parsed from
nd120_tang20k.gprj) + `lint/rpll_stub.v` + the behavioral SDRAM model with
the tang20k_defines set (UART sped to 16 clk_cpu/bit) and runs
`nd120_tang20k_tb` (boot -> '#' -> deposit/readback check). NOTE: at the
6.75 MHz TANG_SLOW_BRINGUP clock the boot needs SECONDS of sim time -
timeouts were raised to 3 s/4 s; a full run takes a long wall-clock time
with iverilog. Compile-check alone is still a useful fast gate.

**FOUR-GENERATION CAPTURE CAMPAIGN (8-JUL late evening) - the ND-120 side
is EXONERATED end to end; the bug is in the SDRAM backend.** Analyzer
retargeted three times (v2 data path, v3 address/bank, v4 bridge FSM; bit
maps live in the `DBG_MEMW` assign in `ND3202D.v`, method documented in
`fpga/tang-nano-20k/TRACE-CAPTURE-GUIDE.md`). Measured on silicon for one
deposit of 054321 to cell 22:
- v1: the CSCOMM write decode FIRES and `WRITE` asserts (F924 A160 captures
  D3 at the CLK edge) -> the 19:35 "WRITE never asserts" trace had caught
  the EXAMINE access, not the deposit. Theory dead.
- v2: `DD` carries 054321 (low bits 10001 verified) stably from RAS rise
  through the whole CAS window, `MWRITE_n` asserted -> MEM_DATA_46 /
  AM29833A / PAL_45008B all exonerated; the earlier "DD all-zero in
  window" OR-capture claim was wrong (also an examine, most likely).
- v3: `AA` row=0 at RAS, col=18 (=0o22) at CAS, BANK0=1, write mode
  latched -> MEM_ADDR_44 / MEM_ADEC_45 exonerated.
- v4: the bridge FSM walks IDLE->COLWAIT->COL->WRDATA->POST and ISSUES the
  write command (`s_wr` pulse) with the OR-accumulated data -> the
  MEM_RAM_49_SDRAM protocol bridge logic exonerated.
- Console repeatability probe (same bitstream): examine of cell 22 returns
  a STABLE wrong value (000201, five reads in a row, before AND after the
  deposit; very first read after power-up gave 000605 once). Neighbor cell
  reads stable 000000. Deposits never change the readback.

**=> Suspected `sdram18.v` (+ its clocking)... and then EXONERATED on
9-JUL by a dedicated hardware test.** `fpga/tang-nano-20k/sdram18-test/`
(new, OSS yosys/nextpnr flow, Linux-native ~2 min build) drives
`sdram18.v` with the FULL BUILD's exact clocking (Gowin_rPLL_ND120 with
TANG_SLOW_BRINGUP: 13.5 MHz + shifted chip clock, FREQ=13.5M): verbose
4-word demo (col[9:8] bits, bank bit, parity bits, last word) + full
2M-word write/verify. **PASSES ON HARDWARE.** (iverilog sim in its sim/
also passes.) Note: the bridge packs addr {bank,row[9:0],col[9:0]} vs
sdram18's {ba[1:0],row[10:0],col[7:0]} - a bijection, harmless, but know
it when reading SDRAM-side traces.

**=> ONLY ONE BOX LEFT: full-build integration = cross-clock-domain
timing.** The bridge samples OSC-domain signals (RAS/CAS/AA/BANKx/
MWRITE50_n, registered on CLKOUTD = clk_cpu 6.75 MHz) directly in the
clk2x domain (CLKOUT 13.5 MHz) relying on PLL edge alignment - and the
Gowin build logs show **47x "WARN (TA1117) Can't calculate clocks'
relationship"** on register-as-clock domains (BCGNT50-clocked address
latches, s_rdata-clocked regs, DSTB_n, SPES...): those paths are
UNCONSTRAINED, so each PNR run is a timing lottery. Observed exactly
that: v1-v3 bitstreams read stable 000000, the v4 bitstream (same RTL,
debug tap added) reads stable-but-different junk (000605 once, then
000201 forever; deposits never land). The `nd120_tang20k.sdc` only
defines sys_clk and trusts Gowin to derive the rest - it cannot relate
the register-derived clocks.
**Next steps:** (1) this is the clock-enable-fix branch's thesis: convert
the remaining register-as-clock domains feeding the memory path to
clock-enables in the sysclk domain (CYC_36-style), which removes the
unconstrained domains outright; (2) shorter-term diagnostic: add
create_generated_clock / set_false_path+manual sync constraints for the
worst offenders and see if a constrained build deposits correctly - that
would confirm the mechanism cheaply before the big refactor.

**On-chip analyzer (KEEP - it works):** in ND120_TANG20K_TOP: 512x16 ring
at clk2x, 16-bit bus from MEM_43 DBG_MEMW ([0]ras [1]cas [2]mw50_n [3]mw_n
[4]dbapr [5]ecreq [6]write [7]cgnt_n [8]bgnt_n [9]bcg50 [10]ddnz
[15:11]dd[4:0]), trigger mw50_n fall after 2.5s arm, auto-dump 512 hex
lines over UART at 9600 (takes over TX; LED4 latches ON after dump; S1
re-arms). To retarget at the CGA WRITE chain, widen/repoint DBG_MEMW.
Gotchas: keep ONE listener attached across the whole cycle; never program
while listening (NUL junk); verify .fs timestamp before programming; a
`pkill cat /dev/ttyUSB1` inside a composite command kills its own shell.

**Next steps (in order):**
1. Read `PAL/PAL_45008B.v`: how are OET_n/OER_n formed, what do they depend
   on (MWRITE/QD_n/grant phases), and what does FF-mode conversion do to
   their phase vs the latch original.
2. The already-planned mem-test "option #3" (extend the standalone mem-test
   with MEM_DATA_46) is now THE experiment: drive a write through
   MEM_DATA_46 on hardware and watch OET_n/whether DD gets driven. On the
   Tang this can also be done with the working OPCOM + a debug register.
3. The Tang bridge keeps the OR-accumulation capture (harmless, robust) -
   once OET_n opens properly, writes will work without further bridge
   changes. Same for SIP1M9/MEM_RAM_49_BLOCKRAM (pre-CAS capture).

---

**Full path:** `Verilog/docs/HANDOFF-basys3-memory-write.md`
**Date:** 2026-07-08
**Goal:** OPCOM memory examine/deposit works on the Basys3 (write a value, read it back).

---

## RESOLVED (2026-07-08, later the same day)

**Root cause found by worktree bisection + fixed; sim deposits work again in
BOTH latch and FF modes** (`22/ 054321 CR 22/` -> `/054321`, and examine reads
the correct cell content `125005` again).

- **Breaking commit:** `9b005c2` (MEM_ADDR_44 `USE_SYSCLK=1`). The reasoning
  "address-only, read works, so it's fine" was wrong: `USE_SYSCLK=1` is a
  **LEVEL enable** - the row/col registers re-captured LBD on every sysclk
  while BCGNT50 stayed high across the grant window, so by the time a WRITE
  used the address, the registers held the WRITE DATA (LBD had moved on).
  Reads also silently shifted cells (examine returned 125025 instead of
  125005). Verified: parent commit `bbcb4d1` works, `9b005c2` broken.
- **Fix:** new `USE_SYSCLK=2` mode in `Shared/support/AM29C821.v` =
  sysclk-sampled **rising-edge** capture (one capture per CK rise, original
  chip semantics, still no routed clock net for FPGA); `MEM_ADDR_44` CHIP_3H /
  CHIP_4H switched to it. The FPGA intent of `9b005c2` is preserved.
- The Basys3 CPU memory bug should be retested on the board after this fix -
  the same wrong-address writes explain "read returns fixed value, writes
  ignored" there too.
- **Write-data timing ground truth** (DBG_MEM trace of a fixed deposit): with
  the address latches fixed, `DD` carries the correct write data **already at
  CAS-fall** and holds it through the window - both the Basys3 BRAM path
  (writes every window cycle) and the Tang SDRAM bridge (samples mid-window)
  are compatible. Both boards need only a rebuild.
- **Pre-synth testbenches added** (`CPU-BOARD-3202/circuit/sim/`,
  `make test-memaddr` / `test-memchain` / `test-all`):
  - `MEM_ADDR_44_tb.v` - address-latch regression: drives the real BCGNT50
    grant window with LBD switching address->data. **Verified to FAIL (9
    errors) against the 9b005c2 version and PASS on the fix.**
  - `MEM_CHAIN_tb.v` - MEM_ADDR_44 + MEM_RAM_49 (SIP1M9 FPGA BRAM path, what
    Basys3 synthesizes) full write/readback over the measured protocol.
- **SECOND write bug found on the Tang the same day - applies to Basys3
  too:** the DD write-data bus is driven BEFORE CAS and RELEASED around
  CAS-fall on silicon (zero-delay sim hides this). `SIP1M9`'s BRAM path now
  captures the data pre-CAS and writes ONCE at the first window edge; the
  old write-every-window-edge (last-write-wins) would have stored a dead
  bus. **Rebuild the Basys3 bitstream with both fixes before retesting.**
- **Backend family aligned (per Ronny):** `MEM_43.v` now selects the
  sheet-49 backend by define: `MAIN_RAM_SDRAM` (Tang) /
  `MAIN_RAM_BLOCKRAM` (`MEM_RAM_49_BLOCKRAM.v` - one clean parameterized
  BRAM, recommended for Basys3 instead of the six emulated chips; add the
  file + define to the Vivado project to opt in) / `VERILATOR_SIM`
  (`MEM_RAM_49_SIM.v`; C++ preload paths changed to `RAM.b0_lo` etc. -
  already updated in all three harnesses) / default = original chips.
  Pre-synth tbs: `CPU-BOARD-3202/circuit/sim` `make test-all`.
- Everything below is kept for history.

---

## TL;DR / current state

- **The RAM module is PROVEN GOOD on silicon.** The standalone test
  `Verilog/fpga/basys3/mem-test/` drives `MEM_RAM_49` (-> `SIP1M9` sync BRAM,
  ramSize=3) with the real DRAM RAS/CAS/AA protocol and **PASSES on the board**
  (all 8 addresses write+read, no aliasing, LEDs confirm last read = 0x42).
  So the memory bug is in the **CPU / MAC integration**, not the RAM.
- **FPGA CPU symptom (via OPCOM):** memory read returns a fixed value, writes
  ignored. The value *changed with each fix*: `0` -> `214` (oct) -> `0`. Symptom
  moving = we are in the right subsystem but not converged.
- **NEW and important:** `runSim` (Verilator, `Verilog/runSim`) now **reads OK
  but does NOT write RAM**. This is recent breakage. Because the sim reproduces
  a *write* failure, the write bug is now **debuggable in the sim** (full
  `$display`/DBG_MEM visibility) instead of blind 90-min synths. **Another LLM is
  already analyzing the sim write-break** (coordinate, don't duplicate).

---

## Key diagnostic logic (read this first)

1. **Read works, write doesn't (sim)** => the **address path is correct**
   (read and write use the same row/col latches). So the bug is in the
   **write-only** path: the **write strobe `MWRITE50_n`** (from `MEM_LBDIF_48`
   `CHIP_14F`, clocked by OSC) or the **write-data path `MEM_DATA_46`**.
2. **My two committed fixes are therefore NOT the write-break:**
   - `9b005c2` `MEM_ADDR_44`: address latches `USE_SYSCLK=1` (sysclk + BCGNT50
     enable, was `posedge BCGNT50`). Address-only; read working proves it's fine.
     FF sim was STERR=0 + seqcheck PASS when committed.
   - `0fb062b` `IO_DCD_38`: OSC driven from clean `clk_cpu` on FPGA. Guarded by
     `` `ifdef VERILATOR_SIM `` -> **the sim does not see this change at all.**
3. **Prime suspect for the sim write-break:** the **uncommitted `MEM_43.v`**
   (visible in `git status` -- the other agent's in-flight `MAIN_RAM_SDRAM` port
   threading). First action below bisects this in ~2 min.

---

## First actions for whoever picks this up

1. **Bisect the sim write-break (fast):**
   ```
   cd Verilog
   git stash push CPU-BOARD-3202/circuit/MEM_43.v      # park the uncommitted edit
   cd runSim && make clean && make compile && make run # does RAM write work now?
   ```
   - Write returns -> the uncommitted `MEM_43.v` broke it (tell the other agent).
   - Still broken -> a committed change or the other agent's committed work;
     `git log --oneline -15` and bisect the memory commits.
2. **If the sim reproduces the write bug, debug it there** using the `DBG_MEM`
   hook in `Shared/support/SIP1M9.v` (define `DBG_MEM`) and `$display` on
   `MWRITE50_n`, `DD_17_0_IN`, `AA_9_0`, `RAS`, `CAS`. Watch a known write
   (deposit) and confirm whether `MWRITE50_n` asserts and `DD_17_0_IN` carries
   the data at the CAS-active cycles. This is the fast path -- do NOT go back to
   blind FPGA synths until the sim write works.
3. **The write-only failure => inspect these two, in order:**
   - `MEM_LBDIF_48.v` `CHIP_14F` (produces `MWRITE50_n`, clocked by `s_osc`).
   - `MEM_DATA_46.v` -- the write-data path (`LBD_15_0_IN` -> `DD_17_0_OUT` to
     RAM) and the `AM29833A` transceivers (`CHIP_1H`/`CHIP_2H`, clocked by
     combinational `RDATA`). Watch for the FPGA tri-state rule (z must drive 0)
     and derived-clock capture.

---

## Chosen-but-unbuilt next step (option #3)

The user picked: **extend the standalone `mem-test` to include the real MAC
data path (`MEM_DATA_46`)** rather than driving `DD` directly -- isolates the
write/read *data path* in a ~5-min build, no `MEM_43`/CPU, no coordination.
`MEM_DATA_46` port list (already captured):
```
input  OSC, sys_rst_n, BCGNT50R_n, BIOXL_n, ECCR, HIEN_n, MR_n, MWRITE_n,
       PA_n, QD_n, RDATA
input  [15:0] LBD_15_0_IN     output [15:0] LBD_15_0_OUT   (CPU side)
input  [17:0] DD_17_0_IN      output [17:0] DD_17_0_OUT     (RAM side)
output HIERR, LOERR, LERR_n, LPERR_n, LED4, LED5
```
Plan: in the mem-test top, route write data through `MEM_DATA_46`
(`LBD_15_0_IN` -> `DD_17_0_OUT` -> RAM `DD_17_0_IN`) and read back
(RAM `DD_17_0_OUT` -> `MEM_DATA_46 DD_17_0_IN` -> `LBD_15_0_OUT`, captured on
`RDATA`), driving `MWRITE_n`/`RDATA`/direction like the MAC does. If it fails
like the CPU, the data path is isolated in a fast build. **NOTE:** the sim
write-break may make this redundant -- prefer the sim debug (step 2) first.

---

## The standalone mem-test (proven tool -- reuse it)

- `Verilog/fpga/basys3/mem-test/` : `basys3_mem_test_top.v` (DRAM-protocol FSM +
  `MEM_RAM_49` + `msg_printer`/`uart_tx`), `sim/basys3_mem_test_tb.v` (iverilog,
  decodes UART -> ASCII), `build.tcl` (in-memory Vivado synth+JTAG program),
  `basys3_mem_test.xdc`.
- Sim run:
  ```
  cd Verilog/fpga/basys3/mem-test/sim
  iverilog -g2012 -o tb basys3_mem_test_tb.v ../basys3_mem_test_top.v \
    ../msg_printer.v ../uart_tx.v \
    ../../../../CPU-BOARD-3202/circuit/MEM_RAM_49.v \
    ../../../../Shared/support/SIP1M9.v && vvp tb
  ```
- Board build/program: `vivado -mode batch -source build.tcl` (from mem-test/).
- **GOTCHA:** in this test, `btn1=SW0=V17` is the reset and is **active-high**,
  so **SW0 must be DOWN to run** (opposite of the main CPU's "SW0 up = run").
  If rebuilt, flip the reset polarity to match the CPU (`!btn1` = reset).

---

## Coordination (two agents + another LLM on shared memory files)

- Another agent is building the **Tang Nano 20K** top + SDRAM backend and is
  threading `` `ifdef MAIN_RAM_SDRAM `` ports through `MEM_43.v` and `ND3202D.v`
  (default Basys3/Verilator builds unaffected). **`MEM_43.v` is currently
  modified/uncommitted by them.** Do not clobber it; coordinate before editing
  `MEM_43.v` / `ND3202D.v`.
- Another LLM is analyzing the **sim write-break** -- same code area.
- Comprehensive memory analysis (protocol ground truth, 25,008 traced accesses,
  the 6-cycle signature, per-board backends): `Verilog/docs/nd120-dram-memory.md`.
- Issue tracker: `Verilog/docs/fpga-bringup-issues.md` (issue #3 updated with the
  "memory module proven good -> bug is MAC integration" finding).

## Hard constraints (project rules)

- Never mention Claude/AI in git commits or docs.
- Never modify the PAL files (`Verilog/PAL/PAL_*.v` -- hand-converted PALASM).
- No unicode in code/comments (late-80s C/asm toolchain).
- OSC clean-clock fix is FPGA-only (`` `ifdef VERILATOR_SIM `` keeps sim decode).

## My commits this session (Basys3 memory)
```
0fb062b IO_DCD_38: drive OSC from clean clk_cpu net on FPGA (214 -> 0 on board)
9b005c2 MEM_ADDR_44: address latches on sysclk not BCGNT50 (0 -> 214 on board)
aa6fbdf mem-test: read msg_printer.v as SystemVerilog
d8ff270 Add standalone Basys3 memory test (PASSES on hardware)
bbcb4d1 SIP1M9: capture DRAM row on RAS falling edge
0feeb2f/8af52e1/49c6b08 SIP1M9 sync BRAM for FPGA (ramSize=3)
```
