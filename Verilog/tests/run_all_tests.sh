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
  "CPU-BOARD-3202/circuit/CPU_CS_TCV_20/sim :: test-tcv :: Testbench Complete"
  # --- gate arrays --------------------------------------------------------
  "DECODE-GateArray/DGA/sim :: test-f595        :: Testbench Complete"
  "DELILAH-CPU/CGA/sim      :: test-busdriver16 :: Testbench Complete"
  "DELILAH-CPU/CGA_MIC/sim  :: test-masel-basic :: PASS"
  # --- Tang Nano 20K SDRAM stack ---------------------------------------
  "fpga/tang-nano-20k/sdram-bridge/sim :: test :: TB_RESULT: PASS"
  "fpga/tang-nano-20k/sdram-test/sim   :: test :: TB_RESULT: PASS"
  "fpga/tang-nano-20k/sdram18-test/sim :: test :: TB_RESULT: PASS"
)
# NOT in the registry (run manually, documented reasons):
#   DELILAH-CPU/CGA_MIC/sim test-masel-cycle / test-masel-iw - exploratory
#     race-documentation tbs with EXPECTED FAIL lines; not strict pass/fail.
#   Verilog/sim make compare, runSim golden, fpga vtest - heavy system gates,
#     run via `make test-full`.

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
