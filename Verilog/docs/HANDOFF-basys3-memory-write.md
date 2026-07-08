# Handoff: Basys3 FPGA memory (write) + sim write-break

**Full path:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/HANDOFF-basys3-memory-write.md`
**Date:** 2026-07-08
**Goal:** OPCOM memory examine/deposit works on the Basys3 (write a value, read it back).

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
   cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog
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
