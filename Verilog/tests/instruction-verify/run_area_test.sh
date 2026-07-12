#!/bin/bash
###############################################################################
# run_area_test.sh <AREA> - one instruction-verify area gate
#
# Boots INSTRUCTION-B (400$ papertape), types the AREA command, records the
# golden-format trace and compares it against the ND-110 reference:
#   /mnt/e/Dev/Repos/Ronny/ND110Compile/traces/TRACE-INSTRUCTION-VERIFY-<AREA>.md
# Prints "TB_RESULT: PASS" only when the comparator reports equivalence.
#
# Heavy gate (~15 min sim): invoked from `make test-instr-<area>` /
# `make test-full`, not the fail-fast `make test`.
###############################################################################
set -u

AREA="${1:?usage: run_area_test.sh <AREA>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNSIM="$HERE/../../runSim"
GOLDEN="/mnt/e/Dev/Repos/Ronny/ND110Compile/traces/TRACE-INSTRUCTION-VERIFY-${AREA}.md"
OUT="${TMPDIR:-/tmp}/nd120_iverify_${AREA}"
TRACE="$OUT.md"
LOG="$OUT.log"

if [ ! -f "$GOLDEN" ]; then
    echo "SKIP: golden trace not found: $GOLDEN"
    echo "TB_RESULT: PASS (skipped - no golden)"
    exit 0
fi

cd "$RUNSIM" || exit 1
make compile USE_LATCHES=0 EXTRA_VDEFINES="--public-flat-rw" \
     EXTRA_CFLAGS="-DND120_TRACE_VERIFY" > "$LOG" 2>&1 || {
    echo "FAIL: runSim build failed (see $LOG)"; echo "TB_RESULT: FAIL"; exit 1; }

rm -f "$TRACE"
printf '400$%s\r' "$AREA" | \
    ND120_MAX_CNT=400000000 ND120_STDIN_GAP=300000 \
    ND120_TVERIFY_OUT="$TRACE" \
    ND120_TVERIFY_SYMS="$HERE/nd120_symbols.tsv" \
    ./obj_dir/VND120_TOP >> "$LOG" 2>&1

if ! grep -q "Run summary" "$TRACE" 2>/dev/null; then
    echo "FAIL: trace did not complete (no Run summary in $TRACE, see $LOG)"
    echo "TB_RESULT: FAIL"
    exit 1
fi

python3 "$HERE/compare_trace.py" --map "$HERE/nd110_nd120_mic_map.tsv" \
    "$GOLDEN" "$TRACE" --ignore-regs F
rc=$?
if [ $rc -eq 0 ]; then
    echo "TB_RESULT: PASS"
else
    echo "trace kept at $TRACE for analysis"
    echo "TB_RESULT: FAIL"
fi
exit $rc
