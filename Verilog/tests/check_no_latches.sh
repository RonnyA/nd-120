#!/usr/bin/env bash
# check_no_latches.sh - the silicon path must be flip-flop mode, always.
#
# Verilog/tests/check_no_latches.sh   (run by `make test` via run_all_tests.sh)
#
# WHY THIS EXISTS. "no fucking latches i fucking told you!!!!" - the same
# instruction had to be given repeatedly, and latch-mode runs on the silicon
# path invalidated whole investigations because the FPGA cannot reproduce
# transparent-latch behaviour. A rule that must be remembered is a rule that
# will eventually be forgotten, so it lives here instead.
#
# What is checked: every FPGA board's define file must establish FPGA_FF_MODE.
# What is NOT checked: the sim harness default. USE_LATCHES=1 is legitimate
# there - `make compare` deliberately builds BOTH modes to prove a refactor
# kept behaviour identical, and the golden latch trace is the reference. This
# script guards the SILICON path only.
set -uo pipefail

VERILOG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
checked=0

# Boards establish FF mode in DIFFERENT places: the Tang uses a defines .v,
# the Vivado boards append the define in their build .tcl. Check each board
# for ANY of them - and require that every board with a build flow is covered,
# so the sweep cannot pass by matching nothing (measured 24-AUG-2026: an
# earlier version of this check globbed only src/*defines*.v, found ONE board,
# and reported PASS while three others went unchecked).
for boarddir in "$VERILOG_ROOT"/fpga/*/; do
  board=$(basename "$boarddir")
  # only boards with an actual build flow
  if ! ls "$boarddir"/*.tcl "$boarddir"/*.ps1 "$boarddir"/Makefile >/dev/null 2>&1; then
    continue
  fi
  checked=$((checked + 1))
  # ONLY real build inputs: the build scripts and the board's own sources.
  # NOT logs, NOT .Xil caches, NOT markdown - an earlier version matched a
  # vivado log and a DEBUG-PLAN .md and reported PASS, which is a false green.
  hit=$(grep -lE 'FPGA_FF_MODE' \
          "$boarddir"/*.tcl "$boarddir"/*.ps1 "$boarddir"/Makefile \
          "$boarddir"/src/*.v 2>/dev/null | head -1)
  if [ -n "$hit" ]; then
    echo "  ok   $board: FPGA_FF_MODE established (${hit#$VERILOG_ROOT/})"
  else
    echo "  FAIL $board: nothing under fpga/$board establishes FPGA_FF_MODE"
    echo "       the silicon path would build in transparent-latch mode"
    fail=$((fail + 1))
  fi
done

# A board top that force-defines USE_LATCHES back on would defeat the above.
if grep -rnE '^\s*`define\s+USE_LATCHES' "$VERILOG_ROOT"/fpga/ 2>/dev/null; then
  echo "  FAIL a board file defines USE_LATCHES - the silicon path must not"
  fail=$((fail + 1))
fi

if [ "$checked" -eq 0 ]; then
  echo "  FAIL no board define files found - the check matched nothing"
  fail=1
fi

echo "--- $checked board(s) checked, $fail failure(s) ---"
if [ "$fail" -eq 0 ]; then echo "TB_RESULT: PASS ($checked boards in FF mode)"; exit 0
else echo "TB_RESULT: FAIL ($fail)"; exit 1; fi
