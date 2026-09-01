#!/bin/bash
#############################################################################
#  run_altsyncram_equiv.sh - the Quartus altsyncram path vs the reference    #
#                                                                            #
#  WHY THIS EXISTS (01-SEP-2026)                                             #
#  ------------------------------                                            #
#  Only the MiSTer build compiles the `ifdef QUARTUS_ALTSYNCRAM` sections of  #
#  IDT6168A_20.v (the WCS) and MEM_RAM_49_BLOCKRAM.v (main memory). Vivado,   #
#  Gowin and Verilator all compile the plain-Verilog model instead. So a      #
#  difference between the two is invisible to every normal simulation, and    #
#  shows up only as a board that does not boot.                              #
#                                                                            #
#  That is exactly what happened. The WCS was built with                      #
#  outdata_reg_a="CLOCK0", which gives a TWO-clock read because altsyncram    #
#  always registers the address as well (M10K cannot read asynchronously).    #
#  The plain model takes ONE clock. Every microinstruction therefore reached   #
#  the microsequencer a clock late on that board, the sequencer ran one step  #
#  out of step with the cycle controller, and a nested microsubroutine        #
#  T,RETURN popped the wrong address - so MACL never resumed and the CPU      #
#  looped in the interrupt-register microcode instead of reaching OPCOM.      #
#                                                                            #
#  It went unnoticed because the equivalence check used altsyncram_stub.v,    #
#  which was itself wrong by one clock in BOTH settings, so the comparison    #
#  passed. The stub is now faithful and this script is the gate.              #
#                                                                            #
#  METHOD: build each testbench twice - once plain, once with                 #
#  -DQUARTUS_ALTSYNCRAM plus the stub - run both, and diff the logged         #
#  waveforms. They must be byte-identical.                                    #
#############################################################################
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SUP="$HERE/.."
CIRC="$HERE/../../../CPU-BOARD-3202/circuit"
STUB="$HERE/altsyncram_stub.v"
IVERILOG=${IVERILOG:-iverilog}
VVP=${VVP:-vvp}
fail=0

check () {          # $1 = label, $2 = tb, $3 = dut, $4 = logfile, $5 = workdir
    local label="$1" tb="$2" dut="$3" log="$4" wd="$5"
    cd "$wd" || return 1

    rm -f "$log"
    $IVERILOG -g2012 -o "/tmp/eq_${label}_ref" "$tb" "$dut" || return 1
    $VVP "/tmp/eq_${label}_ref" > /dev/null 2>&1
    cp "$log" "/tmp/eq_${label}_ref.txt" 2>/dev/null || { echo "$label: no log"; return 1; }

    rm -f "$log"
    $IVERILOG -g2012 -DQUARTUS_ALTSYNCRAM=1 -o "/tmp/eq_${label}_alt" "$tb" "$dut" "$STUB" || return 1
    $VVP "/tmp/eq_${label}_alt" > /dev/null 2>&1
    cp "$log" "/tmp/eq_${label}_alt.txt" 2>/dev/null || { echo "$label: no alt log"; return 1; }

    local n; n=$(wc -l < "/tmp/eq_${label}_ref.txt")
    if diff -q "/tmp/eq_${label}_ref.txt" "/tmp/eq_${label}_alt.txt" > /dev/null; then
        echo "  $label: MATCH ($n samples)"
        return 0
    fi
    echo "  $label: MISMATCH - the Quartus path does not behave like the reference"
    diff "/tmp/eq_${label}_ref.txt" "/tmp/eq_${label}_alt.txt" | head -8
    return 1
}

echo "altsyncram (Quartus-only) vs plain-Verilog reference:"
check wcs  "$HERE/IDT6168A_20_equiv_tb.v" "$SUP/IDT6168A_20.v" equiv_log.txt "$HERE" || fail=1
check mem  "$CIRC/sim/MEM_RAM_49_BLOCKRAM_equiv_tb.v" "$CIRC/MEM_RAM_49_BLOCKRAM.v" \
           mem_equiv_log.txt "$CIRC/sim" || fail=1

if [ "$fail" -eq 0 ]; then echo "TB_RESULT: PASS"; else echo "TB_RESULT: FAIL"; fi
exit $fail
