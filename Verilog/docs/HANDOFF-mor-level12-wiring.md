# HANDOFF — MOR (Memory Out of Range) / level-12 interrupt wiring

Date: 14-JUL-2026. Branch: `clock-enable-fix`. All changes below are **uncommitted** in the working tree. Nothing was committed, no branch was created, no merge done.

## TL;DR

- The MOR (Memory Out of Range) interrupt input was tied off inside the interrupt controller. I **wired it up** and did the `s_nor_n`→`s_mor_n` spelling rename. **4 files changed, compiles clean (runSim FF, exit 0), but behaviorally UNVERIFIED** (no self-test / instruction-verify run).
- **Important:** wiring MOR does **NOT** fix the RUN failure. RUN aborts on a *separate* bug — a vector→IIC decode error (an IOX error is decoded as "Memory Out of Range"). See "The real RUN blocker" below. That bug is owned by the devices/microcode workstream and I did not touch it.

## Files I changed (exactly these 4 — full absolute paths)

1. `Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR.v`
   - Line ~73: `wire s_nor_n;` → `wire s_mor_n;`
   - Line 114: `assign s_nor_n = 1; //TODO: Fix MORN;` → `assign s_mor_n = MORN;` (connects the existing `MORN` input port, previously dangling).
   - Line ~208: IRSRC instantiation `.NORN(s_nor_n)` → `.MORN(s_mor_n)`.

2. `Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_IRSRC.v`
   - Port `input NORN` → `input MORN`; `wire s_nor_n` → `wire s_mor_n`; `assign s_nor_n = NORN` → `assign s_mor_n = MORN`; `GATES_21` (NOR→level 12) input `.input2(s_nor_n)` → `.input2(s_mor_n)`.

3. `Verilog/CPU-BOARD-3202/circuit/CPU_PROC_CGA_33.v`
   - Line 37 comment fix only: `//! Memory Operation Ready` → `//! Memory Out of Range` (the port was mislabeled; it is MOR).

4. `Verilog/CPU-BOARD-3202/circuit/MEM_43.v`
   - **Comments only** (no RTL). Rewrote the RAM-backend selection comments so the `else`/SIP1M9 branch is clearly marked "historical, used by no current build", and corrected the `VERILATOR_SIM` comment (it wrongly referenced `FORCE_SMALL_RAM`).
   - NOTE / pitfall that bit us here: a Verilog comment whose first word is `verilator` is lexed by Verilator as a metacomment and hard-errors (`Unknown verilator comment`), breaking every runSim/sim build. Never start a comment with "verilator". Recorded in `/home/ronny/.claude/skills/nd120-fpga/SKILL.md` (Critical Rule #8).

**NOT mine** (also uncommitted, belongs to the status-fence workstream — do not attribute to this handoff): `Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_STAT.v` and `.../CGA_INTR_CNTLR_VECGEN_STAT_SBIT.v`.

## How MOR actually works (verified by source trace — so you don't re-derive it)

MOR is a **bus-timeout** interrupt, level 12. Full chain, source → CPU:

- **Timeout generator** `Verilog/DECODE-GateArray/DGA/circuit/DECODE_DGA_POW.v`:
  - `:248 s_tout = ~(s_a631_q | s_rfclk)`. The A631 watchdog (`:450 if (!s_bdry50_n) r_a631_q <= 1'b1;`) is re-armed every time BDRY (Bus Data Ready) returns. If no BDRY comes back within ~1–2 `rfclk` periods → TOUT fires. This timer IS implemented and live.
- **Split into MOR vs IOXERR** `Verilog/CPU-BOARD-3202/circuit/BIF_BCTL_BDRV_7.v`:
  - `:251 s_ioxerr_n = s_tout ? s_iod_n : 1'b1;` (timeout on I/O ref → IOXERR, level 10)
  - `:252 s_mor_n = s_tout ? s_mem_n : 1'b1;` (timeout on memory ref → MOR, level 12)
  - Same watchdog, steered by MEM vs I/O. **IOXERR is already wired to the interrupt controller from this exact source and is quiet**, so the timer is not spuriously firing today — useful cross-check.
- **Up to the CPU:** `BIF_BCTL_6.v` → `BIF_5.v` → `ND3202D.v:1094` → `CPU_PROC_CGA_33.v:258 .XMORN(MOR_n)` → `CGA.v:57 XMORN` → `CGA.v:543 sx_mor_n` → `CGA.v:864 .MORN(sx_mor_n)` → (previously dropped at `CGA_INTR.v:114`, now connected).
- **Level-12 gate** `Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_IRSRC.v`: `GATES_5` NAND(`FIDBO[12]`,EMPID) + `GATES_21` NOR(...,`s_mor_n`) → `IREQ_15_0_N[12]`. Asserts on either a software `FIDBO[12]` write or MOR active.

## Onboard-vs-bus decode (why MOR means "address doesn't exist")

The ND-120 has RAM ON the CPU board; addresses above the onboard size go to the ND bus. The size is a PAL decode, **hardwired to 4 MB**:
- `Verilog/PAL/PAL_44445B.v:85` (CPU side, `CLRQ_n`) and `Verilog/PAL/PAL_44446B.v:85` (bus side, `AOK = ~(BMEM_n|BD23|BD22|BD21|MOFF)`): onboard only when `PPN[23:21]=000` / `BD[23:21]=000` = bottom 2M words = 4 MB.
- Address < 4 MB → onboard, `PAL_44310D` (in `MEM_LBDIF_48.v`) always returns BDRY → never times out.
- Address ≥ 4 MB → routed to the ND bus; if no device answers → TOUT → MOR. Ronny confirmed **4 MB matches the Tang Nano 20K's 4 MB SDRAM**, so the decode is correct for that target.

## Sim RAM reality (corrected — earlier "~1 MB" was WRONG)

The Verilator build does **not** use the SIP1M9 chip model. `Verilog/CPU-BOARD-3202/circuit/MEM_43.v` selects, for `VERILATOR_SIM`, `Verilog/CPU-BOARD-3202/circuit/MEM_RAM_49_SIM.v` — a flat behavioral model, 3 banks × 1M × 18 bits = **6 MB**, onboard 4 MB window fully backed. So MOR is testable in sim with a clean boundary (< 4 MB never fires; ≥ 4 MB, no responder, fires). The C++ harnesses preload via its `b0_*` arrays (e.g. `Verilog/runSim/Run120.cpp:498`). **No RAM change is needed.** (SIP1M9 path `MEM_RAM_49.v` is the historical `else` fallback, compiled by no current build.)

Bus-ack path: `Verilog/ND120_TOP.v:180 BDRY_n_IN = 1'b1` and `:714 s_bus_bdry_in_n = BDRY_n_IN & s_dev_bdry_n` — only the device model (`simDevices/NDBus.cpp` / `NDDevices.cpp`) can ack a bus cycle. An address no device claims leaves BDRY deasserted → timeout → MOR. (Not runtime-confirmed that NDBus withholds BDRY for unmapped addresses — see open questions.)

## The real RUN blocker (do NOT expect the MOR wiring to fix this)

Per `Verilog/docs/RUN-level14-livelock-analysis.md:120-139`: with the status fence now working, RUN reaches the level-14 handler and INSTRUCTION-B aborts with `Internal Interrupt. IIC: 11 - Memory Out of Range`. But the measured hardware vector is 2 = IREQ bit 10 = **IOX error** (the reference ND-110 prints "IOX-ERROR STARTED"). So the **vector→IIC decode path is wrong** — an IOX error is being reported as MOR. Suspects named in that doc: the PICV/PICS→IDB path (`CGA_IDBCTL` SEL6 muxes, IDBS, PICVC) and the AIIC / `TRA IIC` microcode expectations (csa 00725–00731). Probe suggested: capture the IDB value the microcode reads at AIIC together with `PICV_2_0`/`PICS_2_0` and compare to the IIC code INSTRUCTION-B expects for IOX. This is the actual RUN work and is separate from the MOR tie-off.

## Verification status (be honest with Ronny)

- **Compiles:** yes — `make -C runSim compile USE_LATCHES=0` → exit 0 with the wiring in.
- **Unit test:** `Verilog/DELILAH-CPU/CGA_INTR/sim/test_intr.cpp` prints "Passed" but its output checks are compiled out behind `#ifdef ___later___` — it drives MORN but asserts nothing. **Not real verification.** (Also not registered in `Verilog/tests/run_all_tests.sh`.)
- **NOT run:** self-test STERR gate, instruction-verify (`make test-instr`, ~15–25 min/area × 13), `make test`. These are the real behavioral gates and are Ronny's call to authorize (long / interactive).

## Suggested next steps

1. Decide keep vs revert the MOR wiring given it's unverified and in the fragile RUN/interrupt zone.
2. If keeping: run a real gate (self-test STERR = 0, and/or an instruction-verify area) and watch for NEW level-12 activity during RUN's stressors (MOR can now fire on a ≥4 MB bus timeout).
3. The RUN failure itself = the vector→IIC decode bug above (IOX mis-decoded as MOR). That is the high-value item.
4. Confirm `simDevices/NDBus.cpp` withholds BDRY for unmapped bus addresses (so MOR can actually fire ≥ 4 MB), before relying on the signal.

## Do-not / process notes for whoever continues

- Do NOT run two `runSim`/`sim` builds against the same `obj_dir` concurrently — it corrupts the archive (`file too short`). Serial builds only.
- Ronny's standing rules (reinforced 14-JUL): make ONLY the change asked; do NOT self-initiate builds/sims/refactors or anything that wipes build state; and **never create git branches/commits or any git state change without explicit permission.**
