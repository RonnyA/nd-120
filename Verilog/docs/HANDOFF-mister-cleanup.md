# HANDOFF - MiSTer cleanup after the RAM-inference fix

> Written 01-SEP-2026. Board state: the DE10-Nano runs build v47
> (commit `7d27939` + `f4d71f6`), boots to the OPCOM `#` prompt,
> MIPS 00.43, CPU green lamp lit.

## Next

Strip the debug scaffolding (item 1 below). The altsyncram path is gone
(01-SEP-2026): `QUARTUS_RAM_INFER` is the sole Quartus RAM arm, the
register file's separate `QUARTUS_REGBLOCK_ALTSYNCRAM` arm and its orphan
testbench went with it, and no altsyncram is left anywhere in the ND-120
RTL (the only instance remaining is MiSTer's own `sys/sd_card.sv`). The
gate is now `Shared/support/sim/run_quartus_ram_equiv.sh`
(`test-quartus-ram-equiv`, registered) and passes: wcs 557 samples, mem
1936 samples, both MATCH. Verilator lint is clean on both RAM modules in
both arms and `sim/make test_nd120` compiles the top. What the deletion has
NOT had yet, by Ronny's choice ("skip for now, one combined build after the
scaffolding strip"): a Quartus rebuild and a board check that it still
reaches `#`. The RTL Quartus compiles is unchanged by the deletion (the
surviving arms are what built v47), but that is a claim until the build
says so.

## Outstanding work (the agreed cleanup list, in order)

1. **Strip the debug scaffolding.** Debug ports `XWRFB_DBG_19_0` and
   `XCYC_DBG_7_0` threaded through `CGA.v`, `CYC_36.v`, `CPU_PROC_CGA_33.v`,
   `CPU_PROC_32.v`, `CPU_15.v`, `ND3202D.v`, `ND120_CORE.v`, `ND120_TOP.v`;
   probe modules `Verilog/fpga/mister/rtl/nd120_diag_print.v`,
   `nd120_csa_trace.v`, `nd120_sterr_catch.v` (KEEP `pll_cpu.v`); four
   testbenches; their Makefile targets and `run_all_tests.sh` registry
   entries; and the probes in `Verilog/runSim/Run120.cpp`.
2. **Fix the 4 inferred latches.** `ND_DMA_MASTER.v:163` (`s_pend_addr`,
   `s_pend_wdata`, `s_pend_wr`) and `ND_WINCHESTER.v:625` (`s_rw_gate`).

## Queued after the cleanup

- **128 MB SDRAM main memory** for MiSTer - BRAM aliases above 0o200000 and
  forbids SINTRAN (`memory` file: mister-memory-alignment). Nexys4 is the
  reference model; PDP2011_MiSTer is SPEC ONLY, clean-room, never copy code.
- **WD0-3 + floppy in the MiSTer OSD** via `sys/sd_card.sv` presenting an
  OSD-mounted image as a virtual SPI SD card.
- **Keyboard echo at the `#` prompt is NOT yet verified** on the MiSTer.
- `wcs_28C.hex` differs between `Shared/support`/`runSim`/`sim` and canonical
  `Code/Microcode/wcs` at microcode address 0o2002 (a 6 where hardware has
  0); `test-microcode-sync` does not cover the 32 WCS images.
- ~64 M10K wasted on the unreachable 4th bank quarter of main memory.

## Board access

- Deploy: `Verilog/fpga/mister/tools/deploy_and_look.sh` - needs
  `MISTER_PASS` in the environment (deliberately NOT stored in the repo;
  Ronny supplies it). Host `MisterPi.HackerCorp.no`; `MISTER_SETTLE`
  seconds before the screenshot; RBF goes to
  `/media/fat/_Computer/ND120.rbf`; screenshots land in
  `Verilog/fpga/mister/tools/shots/`.
- Quartus 17.0.2 runs in Docker (`raetro/quartus:17.0`), ~25 min a build.
- NEVER edit a source file while a Quartus build is reading it - two builds
  (v42, v43) were discarded for exactly that.
