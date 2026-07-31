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
  # --- Shared support chips -------------------------------------------------
  "Shared/support/sim :: test-ram      :: ALL PASS"
  "Shared/support/sim :: test-uart     :: DONE"
  "Shared/support/sim :: test-am29833a :: TB_RESULT: PASS"
  "Shared/support/sim :: test-am29c821 :: TB_RESULT: PASS"
  "Shared/support/sim :: test-7464x    :: TB_RESULT: PASS"
  "Shared/support/sim :: test-ffen     :: TB_RESULT: PASS"
  "Shared/support/sim :: test-inrprom  :: TB_RESULT: PASS"
  # --- PALs -------------------------------------------------------------
  "PAL/sim :: test-all :: RESULT: PASS"
  # --- CPU board sheets -------------------------------------------------
  "CPU-BOARD-3202/sim         :: test-reqgnt   :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-cyctermd :: RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-ccd      :: RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-memaddr  :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-memchain :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-blockram :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-cdlbd    :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-bdlbd    :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-memdata  :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-cycen    :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-acal     :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-memparity :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-memerror  :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/sim :: test-mmupt-replay :: TB_RESULT: PASS"
  "CPU-BOARD-3202/circuit/CPU_CS_TCV_20/sim :: test-tcv :: Testbench Complete"
  # --- gate arrays --------------------------------------------------------
  "DECODE-GateArray/DGA/sim :: test-f595        :: Testbench Complete"
  "DELILAH-CPU/CGA/sim      :: test-busdriver16 :: Testbench Complete"
  "DELILAH-CPU/CGA_MIC/sim  :: test-masel-basic :: PASS"
  # --- CGA_MAC_DECODE exhaustive decode check (both build modes, Issue-C
  #     GATES_5 regression tooth: SPT/SAPT mutual exclusion) ---------------
  "DELILAH-CPU/CGA_MAC/sim  :: test-decode      :: TB_RESULT: PASS"
  "DELILAH-CPU/CGA_INTR/sim :: test-irsrc        :: TB_RESULT: PASS"
  # --- CGA_INTR gate-level unit tbs (iverilog, teeth-checked) -----------
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
  "SD-FAT/sim                         :: test-nds-fatchk-unit :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-nds-fatchk :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-storage   :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-nds-tape  :: TB_RESULT: PASS"
  "SD-FAT/sim                         :: test-nds-floppy :: TB_RESULT: PASS"
  "fpga/tang-nano-20k/sd-fat-test/sim :: test-dumper    :: TB_RESULT: PASS"
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
  "ND-BUS-DEVICES/SMD/sim    :: test-smd        :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/SMD/sim    :: test-smd-iox    :: TB_RESULT: PASS"
  "ND-BUS-DEVICES/SMD/sim    :: test-smd-p2     :: TB_RESULT: PASS"
)
# NOT in the registry (run manually, documented reasons):
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
