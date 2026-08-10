#!/bin/bash
###############################################################################
# audit_testbenches.sh - find testbenches that no gate will ever run
#
# Full path: Verilog/tests/audit_testbenches.sh
# Run with:  make test-audit    (from Verilog/)
#
# THE PROBLEM
#
# A testbench that nothing runs is worse than no testbench: it looks like
# coverage in a directory listing, it goes stale silently, and the thing it
# was written to protect regresses with nobody noticing. The tree has 185
# *_tb.v files and a 188-entry registry, and until this script existed there
# was no way to tell which of the 185 were actually reachable.
#
# WHAT COUNTS AS REACHABLE
#
# A testbench is reachable if ANY of these hold:
#   1. its own sim/Makefile names it,
#   2. its sim/Makefile has a pattern rule that can build it (iv-%, %_tb),
#   3. tests/run_all_tests.sh mentions it.
#
# Rule 2 matters: DELILAH-CPU/CGA_INTR/sim builds ~29 gate-level benches from
# a single `iv-%:` rule. A naive check reports all of them as orphans, which
# is how a first pass at this audit produced 34 false positives.
#
# EXIT STATUS
#   0 - every testbench is reachable
#   1 - one or more orphans (listed), or a sim dir has no Makefile at all
#
# Ronny Hansen, 09-AUG-2026
###############################################################################
set -u
cd "$(dirname "$0")/.."          # Verilog/

REGISTRY="tests/run_all_tests.sh"
orphans=0
nomake=0

# sim directories that hold a testbench but no Makefile - nothing there can
# ever run, whatever the registry says
for d in $(find . -name "*_tb.v" -not -path "./tests/vivado_warning_fixes/*" \
                  -exec dirname {} \; | sort -u); do
    if [ ! -f "$d/Makefile" ]; then
        echo "NO MAKEFILE: $d  (holds testbenches nothing can build)"
        nomake=$((nomake + 1))
    fi
done

for tb in $(find . -name "*_tb.v" -not -path "./tests/vivado_warning_fixes/*" \
            | sort); do
    b=$(basename "$tb" .v)
    d=$(dirname "$tb")

    # 1. named directly in its own Makefile
    grep -qs -- "$b" "$d/Makefile" 2>/dev/null && continue
    # 2. a pattern rule in that Makefile can build it
    grep -qsE 'iv-%|%_tb|\$\(wildcard' "$d/Makefile" 2>/dev/null && continue
    # 3. the registry mentions it (with or without the _tb suffix)
    grep -qs -- "${b%_tb}" "$REGISTRY" 2>/dev/null && continue

    echo "ORPHAN: $tb"
    echo "        no Makefile rule and no registry entry - nothing runs this"
    orphans=$((orphans + 1))
done

total=$(find . -name "*_tb.v" -not -path "./tests/vivado_warning_fixes/*" | wc -l)
echo ""
echo "testbenches: $total   orphans: $orphans   sim dirs without a Makefile: $nomake"

if [ "$orphans" -ne 0 ] || [ "$nomake" -ne 0 ]; then
    echo ""
    echo "Every testbench must be runnable from its own sim/Makefile AND"
    echo "registered in $REGISTRY with a strict pass pattern."
    echo "A test that can pass silently can fail silently."
    exit 1
fi
echo "all testbenches are reachable"
