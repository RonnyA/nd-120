#!/bin/bash
###############################################################################
# ND120 - global unit-test runner
#
# Runs every self-checking testbench in the repo, FAIL-FAST: the first
# failing test aborts the whole run with a loud banner and exit code 1.
#
# Invoked by:   make test        (from Verilog/)
#               make test-full   (adds the heavy system-level gates)
#
# A test fails when ANY of these hold:
#   - its make target exits nonzero
#   - its output contains a FAIL line
#   - its output does not contain the required pass pattern
#
# Registry format:  <dir relative to Verilog/> :: <make target> :: <pass regex>
# Add every new testbench here (and keep the pass pattern strict - a test
# that can pass silently is a test that can fail silently).
###############################################################################
set -u

VERILOG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$VERILOG_ROOT" || exit 1

REGISTRY=(
  # --- meta: the suite checks itself first ---------------------------------
  # Every testbench in the tree must be reached by an entry below, or be
  # baselined in tests/tb_catalog.py with a reason. Fails when a new testbench
  # is written and never registered - the drift that left 9 testbenches
  # unreachable before 08-AUG-2026.
  "tests :: test-tb-catalog :: TB_RESULT: PASS"
  # --- Shared support chips -------------------------------------------------
  "Shared/support/sim :: test-ram      :: ALL PASS"
  "Shared/support/sim :: test-uart     :: DONE"
  "Shared/support/sim :: test-am29833a :: TB_RESULT: PASS"
  # parity CONVENTION gate: ~^data is what the chip calls correct, and the
  # inverted bit must always fault (policy: parity computed, never stored)
  "Shared/support/sim :: test-am29833a-parity :: TB_RESULT: PASS"
  "Shared/support/sim :: test-am29c821 :: TB_RESULT: PASS"
  "Shared/support/sim :: test-7464x    :: TB_RESULT: PASS"
  "Shared/support/sim :: test-ffen     :: TB_RESULT: PASS"
  # --- ndlib _EN clock-enable equivalence tbs (base vs _EN, late-EN teeth) -
  "Shared/support/sim :: test-scanrst-en :: TB_RESULT: PASS"
  "Shared/support/sim :: test-scanset-en :: TB_RESULT: PASS"
  "Shared/support/sim :: test-sr44-en    :: TB_RESULT: PASS"
  "Shared/support/sim :: test-m169c-en   :: TB_RESULT: PASS"
  "Shared/support/sim :: test-f924-en    :: TB_RESULT: PASS"
  "Shared/support/sim :: test-inrprom  :: TB_RESULT: PASS"
  "Shared/support/sim :: test-fifo     :: TB_RESULT: PASS"
  "Shared/support/sim :: test-idt6168a :: TB_RESULT: PASS"
  # --- PALs -------------------------------------------------------------
  "PAL/sim :: test-all :: RESULT: PASS"
  # provenance gate: no PAL may drive an output its PALASM listing does not
  # define, nor drop one it does (the "invented signal" detector)
  "PAL/sim :: test-pal-provenance :: TB_RESULT: PASS"
  # --- PAL _EN clock-enable equivalence tbs (base vs _EN, exhaustive+LFSR) -
  "PAL/sim :: test-44402d-en :: TB_RESULT: PASS"
  "PAL/sim :: test-44403c-en :: TB_RESULT: PASS"
  "PAL/sim :: test-44404c-en :: TB_RESULT: PASS"
  "PAL/sim :: test-44407a-en :: TB_RESULT: PASS"
  "PAL/sim :: test-44408b-en :: TB_RESULT: PASS"
  "PAL/sim :: test-44511a-en :: TB_RESULT: PASS"
  # --- sheet-45 address-decode PALs (base + _D mirror vs PALASM golden) ----
  "PAL/sim :: test-44445b-d :: TB_RESULT: PASS"
  "PAL/sim :: test-44446b-d :: TB_RESULT: PASS"
  # --- CPU board sheets -------------------------------------------------
  "CPU-BOARD-3202/sim         :: test-reqgnt   :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-cyctermd :: RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-ccd      :: RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-memaddr  :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-memchain :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-cs-rwcs  :: TB_RESULT: PASS"
  # microcycle timing golden gate: walks NORMAL/SHORT/SLOW/FETCH/FORM/TRAP/
  # RWCS/LCS/BRK through the real cycle PALs and diffs every clock and strobe
  # against CPU_CYCLE_TIMELINE.golden - a moved edge fails loudly
  "CPU-BOARD-3202/circuit/sim :: test-cycle-timeline :: TB_RESULT: PASS"
  # sheet-20 CS transceivers: the 74PCT373 capture on ECSL~'s falling edge.
  # Its checks 4 and 5 change the source data under a closed latch, so a
  # pass-through implementation (which is what the RTL had) fails loudly.
  "CPU-BOARD-3202/circuit/sim :: test-cs-tcv :: TB_RESULT: PASS"
  # full RWCS microcycle: the control-store word must still be on the IDB at
  # the TERM edge, where ALUCLK writes the A register. This was the TRA CS
  # (150017) reproducer and it went GREEN on 08-AUG-2026 when the sheet-20
  # capture was added - registered that same day, as promised.
  "CPU-BOARD-3202/circuit/sim :: test-cs-rwcs-cycle :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-blockram :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-cdlbd    :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-bdlbd    :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-memdata  :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-cycen    :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-acal     :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-memparity :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-memerror  :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-mmupt-replay :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-mmupt        :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/CPU_CS_TCV_20/sim :: test-tcv :: Testbench Complete"
  # --- gate arrays --------------------------------------------------------
  "DECODE-GateArray/DGA/sim :: test-f595        :: Testbench Complete"
  # --- DGA standard cells: F091/F103/F571 comb + F617 async-FF (both
  #     ACTIVE_ASYNC params) + CPU_STOC_35 exhaustive -----------------------
  "DECODE-GateArray/DGA/sim :: test-fcells      :: TB_RESULT: PASS"
  "DECODE-GateArray/DGA/sim :: test-f617        :: TB_RESULT: PASS"
  "DECODE-GateArray/DGA/sim :: test-f714        :: TB_RESULT: PASS"
  # DECODE_DGA_IDBS enable decoder + panel PRQ/VAL FSM (both build modes)
  "DECODE-GateArray/DGA/sim :: test-dga-idbs    :: TB_RESULT: PASS"
  # DECODE_DGA_POW power-up/MCL/RTC/TOUT sheet (5 builds: plain, VERILATOR_SIM,
  # +RTC_SIM_20MS, FPGA_FF_MODE+BOARD_CLK_FREQ, VERILATOR_SIM+FPGA_FF_MODE)
  "DECODE-GateArray/DGA/sim :: test-dga-pow     :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-stoc      :: TB_RESULT: PASS"
  # --- CPU-board Tier-3: RAMC grant chain / LBDIF delays (2 modes) /
  #     PANCAL stub contract / MMU cache HIT-gate (3 modes, teeth=ungated) --
  "CPU-BOARD-3202/circuit/sim :: test-ramc      :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-lbdif     :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-pancal    :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-mmucache  :: TB_RESULT: PASS"
  # BIF_BCTL_SYNC_8 delay-tap pipeline (AM29C821 x2 + PD1/PD3 kills)
  "CPU-BOARD-3202/circuit/sim :: test-bifsync   :: TB_RESULT: PASS"
  # BIF_DPATH_LDBCTL_12 LBC PAL trio (44303B/44302B/44304E, FF+latch modes)
  "CPU-BOARD-3202/circuit/sim :: test-ldbctl    :: TB_RESULT: PASS"
  # BIF_DPATH_PESPEA_13 PEA/PES error registers (plain + FF strobe modes)
  "CPU-BOARD-3202/circuit/sim :: test-pespea    :: TB_RESULT: PASS"
  # MEM_ADEC_45 real sheet-45 DUT (UCADEC/UBADEC PALs + BLRQ/RLRQ flags,
  # plain + FPGA_FF_MODE _D-mirror builds)
  "CPU-BOARD-3202/circuit/sim :: test-adec      :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA/sim      :: test-busdriver16 :: Testbench Complete"
  # CGA_TESTMUX Verilator tb: 25 directed vectors on the TM0-TM4 test mux
  "DELILAH-CPU/CGA_TESTMUX/sim :: test-testmux  :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_MIC/sim  :: test-masel-basic :: PASS"
  # --- CGA_MIC counter/select tbs (CSEL+INCOUNT dual build modes) ----------
  "DELILAH-CPU/CGA_MIC/sim  :: test-mic-csel    :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_MIC/sim  :: test-mic-incount :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_MIC/sim  :: test-mic-iinc    :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_MIC/sim  :: test-mic-ipos    :: TB_RESULT: PASS"
  # --- CGA_MIC Tier-3: return stack family + WCAREG/CONDREG (dual modes) ---
  "DELILAH-CPU/CGA_MIC/sim  :: test-mic-stackbit   :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_MIC/sim  :: test-mic-stackbit12 :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_MIC/sim  :: test-mic-stack      :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_MIC/sim  :: test-mic-wcareg     :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_MIC/sim  :: test-mic-condreg    :: TB_RESULT: PASS"
  # --- CGA_MIC Tier-5: MASEL repeat register (dual modes, SC5/SC6 pinned) --
  "DELILAH-CPU/CGA_MIC/sim  :: test-mic-repeat     :: TB_RESULT: PASS"
  # --- CGA_MAC_DECODE exhaustive decode check (both build modes, Issue-C
  #     GATES_5 regression tooth: SPT/SAPT mutual exclusion) ---------------
  "DELILAH-CPU/CGA_MAC/sim  :: test-decode      :: TB_RESULT: PASS"
  # --- CGA_MAC_FASTADD per-stage-exhaustive adder check (both build modes) -
  "DELILAH-CPU/CGA_MAC/sim  :: test-fastadd     :: TB_RESULT: PASS"
  # --- CGA_MAC_ADD Tier-4: PRP 4-way selector + CDS sign-extension + adder
  #     vs an independent golden model (both build modes) -------------------
  "DELILAH-CPU/CGA_MAC/sim  :: test-mac-add     :: TB_RESULT: PASS"
  # --- CGA_MAC_PTSEL exhaustive SELPTN table + JK set/clear/hold/toggle
  #     (Issue-C flop; both build modes) ------------------------------------
  "DELILAH-CPU/CGA_MAC/sim  :: test-ptsel       :: TB_RESULT: PASS"
  # --- CGA_MAC SEGPT family (three builds each: plain / FPGA_FF_MODE /
  #     USE_TRANSPARENT_LATCHES - the define that switches L4/L8) -----------
  "DELILAH-CPU/CGA_MAC/sim  :: test-segpt-seg   :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_MAC/sim  :: test-segpt-xpt   :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_MAC/sim  :: test-segpt-pcr   :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_MAC/sim  :: test-segpt       :: TB_RESULT: PASS"
  # --- CGA_MAC Tier-3: APOS increment/CALCA (3 modes) / LASEL 2^19 sweep ---
  "DELILAH-CPU/CGA_MAC/sim  :: test-apos-inc    :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_MAC/sim  :: test-apos-calca  :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_MAC/sim  :: test-lasel       :: TB_RESULT: PASS"
  # --- CGA_MAC Tier-4: AP09 ICA wired-OR mux + CALCA + incrementer (3 modes)
  "DELILAH-CPU/CGA_MAC/sim  :: test-mac-ap09    :: TB_RESULT: PASS"
  # --- CGA_MAC Tier-4: LA1025 LA23-10 wired-OR merge + ECCRHIN (3 modes) ---
  "DELILAH-CPU/CGA_MAC/sim  :: test-mac-la1025  :: TB_RESULT: PASS"
  # --- CGA_IDBCTL / CGA_WRF Tier-1 tbs (PGSREG dual, LR16 triple modes) ----
  "DELILAH-CPU/CGA_IDBCTL/sim :: test-idbctl-sel6   :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_IDBCTL/sim :: test-idbctl-pgsreg :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_WRF/sim    :: test-wrf-sel16     :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_WRF/sim    :: test-wrf-lr16      :: TB_RESULT: PASS"
  # --- CGA_WRF Tier-5: DR16 WR-qualified register (dual modes) -------------
  "DELILAH-CPU/CGA_WRF/sim    :: test-wrf-dr16      :: TB_RESULT: PASS"
  # --- CGA_WRF Tier-4: RBLOCK parent register-file wiring (triple modes) ---
  "DELILAH-CPU/CGA_WRF/sim    :: test-wrf-rblock    :: TB_RESULT: PASS"
  # --- CGA_ALU small mux/swap exhaustive tbs (SWAP dual build modes) -------
  "DELILAH-CPU/CGA_ALU/sim  :: test-alu-swap    :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_ALU/sim  :: test-alu-sel7    :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_ALU/sim  :: test-alu-sel8    :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_ALU/sim  :: test-alu-mux216l :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_ALU/sim  :: test-alu-rmux    :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_ALU/sim  :: test-alu-logop   :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_ALU/sim  :: test-alu-smux    :: TB_RESULT: PASS"
  # SHIFT: full 2^20 exhaustive incl. every serial-input combination
  "DELILAH-CPU/CGA_ALU/sim  :: test-alu-shift   :: TB_RESULT: PASS"
  # --- CGA_ALU Tier-3 register tbs (dual modes; QREG teeth = the MPY bug) --
  "DELILAH-CPU/CGA_ALU/sim  :: test-alu-dbr     :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_ALU/sim  :: test-alu-qreg    :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_ALU/sim  :: test-alu-sts     :: TB_RESULT: PASS"
  # --- CGA_ALU Tier-5: ARG register (dual modes, exhaustive load sweep) ----
  "DELILAH-CPU/CGA_ALU/sim  :: test-alu-arg     :: TB_RESULT: PASS"
  # --- CGA_ALU Tier-4: OUTMUX parent netlist (dual modes, selector wiring) -
  "DELILAH-CPU/CGA_ALU/sim  :: test-alu-outmux  :: TB_RESULT: PASS"
  # --- CGA_ALU Tier-4: ALU controller (3 modes; teeth = the historical
  #     SSEL edge-capture bug - ROT/ZIN-right/LIN shifts ran as plain) ------
  "DELILAH-CPU/CGA_ALU/sim  :: test-alu-contr   :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: test-irsrc        :: TB_RESULT: PASS"
  # --- CGA_INTR gate-level unit tbs (iverilog, teeth-checked) -----------
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_CLR_CLRBIT         :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: test-intr-vecgen                     :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_VECGEN_PTY_PTYENC  :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_VECGEN_PTY         :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_VECGEN_CMP_MAGCMP  :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_VECGEN_CMP         :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_VECGEN_STAT_SBIT   :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_VECGEN_STAT        :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_VECGEN_ISMUX       :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_VECGEN_OSMUX       :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_VECGEN_VHR         :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_IRQ_REG_RQBIT      :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: test-rqbitv2                         :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_IRQ_REG            :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_IRQ_MASK_MASKBIT   :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_IRQ_MASK           :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_IRQ_MREQ           :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_IRQ                :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_IRGEL_VMUX         :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_IRGEL_HIGEL        :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_IRGEL_LOGEL        :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_IRGEL_HIRL         :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_IRGEL_LORL         :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_IRGEL              :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_MDCD              :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_CLR               :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR                   :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: iv-CGA_INTR_CNTLR_seq               :: TB_RESULT: PASS"
  # --- CGA_TRAP gate-level unit tbs (iverilog, teeth-checked) -----------
  "DELILAH-CPU/CGA_TRAP/sim :: iv-CGA_TRAP_TBUF      :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_TRAP/sim :: iv-CGA_TRAP_BRKDET    :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_TRAP/sim :: iv-CGA_TRAP_TVGEN_P2  :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_TRAP/sim :: iv-CGA_TRAP_TVGEN     :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_TRAP/sim :: iv-CGA_TRAP           :: TB_RESULT: PASS"
  # --- Tang Nano 20K SDRAM stack ---------------------------------------
  "fpga/tang-nano-20k/sdram-bridge/sim :: test :: TB_RESULT: PASS"
  "fpga/tang-nano-20k/sdram-bridge/sim :: test-pack16 :: TB_RESULT: PASS"
  "fpga/tang-nano-20k/sdram-bridge/sim :: test-pack16-part :: TB_RESULT: PASS"
  "fpga/tang-nano-20k/sdram-bridge/sim :: test-storage-port :: TB_RESULT: PASS"
  "fpga/tang-nano-20k/sdram-test/sim   :: test :: TB_RESULT: PASS"
  "fpga/tang-nano-20k/sdram18-test/sim :: test :: TB_RESULT: PASS"
  # --- SD-FAT library + Tang Nano 20K SD test ---------------------------
  "SD-FAT/sim                         :: test-writer    :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-writer-div1 :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-nds-cdc   :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-nds-engine :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-nds-write :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-nds-mount :: TB_RESULT: PASS"
  # Client bus slice continuity. nd_storage_devices hands nd_storage its
  # per-client ports as five hand-written flat concatenations, and nothing
  # else checks that a client actually got a slice in each one - a forgotten
  # slice is a silent tie to zero that elaborates, simulates and synthesises
  # cleanly. That is exactly how the Winchester's buf_rdata went missing and
  # every disc WRITE quietly stored zeros (10-AUG-2026). Teeth-proven: with
  # the fix reverted this fails on client 6 and only client 6.
  "SD-FAT/sim                         :: test-nds-clientbus :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-nds-fatchk-unit :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-nds-fatchk :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-storage   :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-nds-tape  :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-nds-floppy :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-nds-smd   :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-nds-cache :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-nds-cachepath :: TB_RESULT: PASS"
  # Failure reporting: every way a storage op can fail must COMPLETE, with
  # err=1 and the right reason code (SD-FAT/circuit/nd_storage_status.vh).
  # No card, missing file, never-opened client, past end of image, broken
  # FAT chain, frozen mem port - read AND write. The eighth mode, "the card
  # goes silent", is in test-nds-errors-slow (run by `make test-full`): its
  # only terminator is sd_writer.v's TO_DATA watchdog, 148 ms of simulated
  # time for one case, and TO_DATA is a real device timeout that must not be
  # shortened to suit a testbench.
  "SD-FAT/sim                         :: test-nds-errors :: TB_RESULT: PASS"
  # --- board memory-test benches ---------------------------------------
  # Found by `make test-audit` 09-AUG-2026: both existed with no Makefile at
  # all, so nothing could run them. They build and pass; they were simply
  # invisible. Both boards are secondary targets (Basys3 has an open BLOCKRAM
  # item, the QMTECH A35T bring-up is paused), which is exactly why an
  # unattended gate is worth having - nobody is exercising them by hand.
  "fpga/basys3/mem-test/sim           :: test-basys3-memtest :: TB_RESULT: PASS"
  "fpga/qmtech-a35t/mem-test/sim      :: test-qmtech-memtest :: TB_RESULT: PASS"
  "fpga/tang-nano-20k/sd-fat-test/sim :: test-dumper    :: TB_RESULT: PASS"
  # Streaming diagnostics (menu 8 BLOCK / 9 SECTOR / R RANGE / N) on a
  # 327680-byte file - five times the tool's 64 KB dump buffer, so menu 2
  # cannot reach it. The RANGE case is the one that matters for SINTRAN
  # segment handling: 70 CONSECUTIVE blocks (280 sectors) read as one run,
  # with the reported block count, sector count and word checksum all
  # checked against the image model. Also the read-only gate: the DEFAULT
  # build must offer no writing command and put no CMD24/CMD25 on the
  # card. ~2 min under iverilog.
  "fpga/tang-nano-20k/sd-fat-test/sim :: test-block     :: TB_RESULT: PASS"
  "fpga/tang-nano-20k/sd-fat-test/sim :: test-verilator :: TB_RESULT: PASS"
  "fpga/tang-nano-20k/sd-fat-test/sim :: test-verilator-fat32 :: TB_RESULT: PASS"
  "fpga/tang-nano-20k/sd-fat-test/sim :: test-verilator-fat32big :: TB_RESULT: PASS"
  "fpga/tang-nano-20k/sd-fat-test/sim :: test-tristate  :: TB_RESULT: PASS"
  "fpga/tang-nano-20k/sd-fat-test/sim :: test-errtexts  :: TB_RESULT: PASS"
  # --- ND-100 external bus devices --------------------------------------
  "ND-BUS-DEVICES/BUS-IF/sim :: test-bus-slave :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/FLOPPY/sim :: test-floppy-pio :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/DMA/sim    :: test-dma-master :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/FLOPPY-DMA/sim :: test-floppy-dma :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/FLOPPY-DMA/sim :: test-floppy-boot :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/FLOPPY-DMA/sim :: test-floppy-iox :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/FLOPPY-DMA/sim :: test-floppy-p2 :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/FLOPPY-DMA/sim :: test-floppy-sdfat :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/TAPE-400/sim :: test-tape400  :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/SMD/sim    :: test-smd        :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/SMD/sim    :: test-smd-iox    :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/SMD/sim    :: test-smd-p2     :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/SMD/sim    :: test-smd-ecc    :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/SMD/sim    :: test-smd-err    :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/WINCHESTER/sim :: test-wd-iox :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/WINCHESTER/sim :: test-wd-adapter :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/WINCHESTER/sim :: test-wd-oracle :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/WINCHESTER/sim :: test-wd-bus :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/WINCHESTER/sim :: test-wd-storage :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/WINCHESTER/sim :: test-wd-storage-sdram :: TB_RESULT: PASS"
  # Same block read/write matrix with ND_STORAGE_DISCS_UNCACHED, which forces
  # CACHE_MASK to zero. A cached client enters the engine at C_LOOK, a direct
  # one jumps straight to C_SEC_GO - two different routes to the same 4-sector
  # split, so both need their own gate.
  "ND-BUS-DEVICES/WINCHESTER/sim :: test-wd-storage-uncached :: TB_RESULT: PASS"
  # An operation must stay readable as ACTIVE long enough for a guest to see
  # it. Guards the RTZ completion delay against being shortened back to the
  # 8-tick fast path, which made the File System Investigator read 060011
  # where the nd100x oracle reads 060005.
  "ND-BUS-DEVICES/WINCHESTER/sim :: test-wd-rtz :: TB_RESULT: PASS"
)
# NOT in the registry (run manually, documented reasons):
#   DECODE-GateArray/DGA/sim test-f595-transparency - FAILS BY DESIGN on the
#     current F595 FPGA branch (lagging FF; the transparent-latch fix was
#     REVERTED 19-JUL after a comb loop on silicon). It pinpoints the
#     divergence; register it only if/when F595's FPGA branch is made a
#     zero-latency transparent latch again.
#   DELILAH-CPU/CGA_MIC/sim test-masel-cycle / test-masel-iw - exploratory
#     race-documentation tbs with EXPECTED FAIL lines; not strict pass/fail.
#   Verilog/sim make compare, runSim golden, fpga vtest - heavy system gates,
#     run via `make test-full`.
#   Verilog make test-democore - the NDDeviceCore RTL EQUIVALENCE GATE
#     (portable C99 nd_lineprinter driven by the real ND-120 CPU + bus RTL,
#     verdict line "[democore] RESULT: PASS"). Deliberately NOT in this
#     registry: it is a ~12 min runSim compile+run, and this registry is the
#     fast per-testbench sweep behind plain `make test`. It is registered in
#     the heavy sweep instead - see `test-full` in Verilog/Makefile.
#   fpga/tang-nano-20k/sd-fat-test/sim test-system - pure-iverilog version of
#     the SD full-system test (same plan as the registered test-verilator);
#     iverilog needs 30-60 min for it, so it is a manual gate only.

scream() {
  echo ""
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "!!!                                                              !!!"
  echo "!!!   TEST FAILED - RUN ABORTED                                  !!!"
  echo "!!!   dir:    $1"
  echo "!!!   target: $2"
  echo "!!!   reason: $3"
  echo "!!!                                                              !!!"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo ""
  echo "--- last 40 lines of output -------------------------------------"
  tail -40 "$LOG"
  echo "------------------------------------------------------------------"
  exit 1
}

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

total=0
t0=$SECONDS
for entry in "${REGISTRY[@]}"; do
  dir="$(echo "$entry"  | awk -F' *:: *' '{print $1}')"
  tgt="$(echo "$entry"  | awk -F' *:: *' '{print $2}')"
  pat="$(echo "$entry"  | awk -F' *:: *' '{print $3}')"
  total=$((total+1))
  printf "%-46s %-16s " "$dir" "$tgt"

  if ! make -s -C "$dir" "$tgt" >"$LOG" 2>&1; then
    echo "FAILED (exit code)"
    scream "$dir" "$tgt" "make target exited nonzero"
  fi
  if grep -qE '(^|[^A-Za-z])FAIL' "$LOG"; then
    echo "FAILED (FAIL in output)"
    scream "$dir" "$tgt" "output contains a FAIL line"
  fi
  if ! grep -q "$pat" "$LOG"; then
    echo "FAILED (no pass marker)"
    scream "$dir" "$tgt" "required pass pattern not found: '$pat'"
  fi
  echo "ok"
done

echo ""
echo "===================================================================="
echo "  ALL $total TESTS PASSED   ($((SECONDS-t0)) s)"
echo "===================================================================="
