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
#  METHOD: build each testbench THREE times and diff the logged waveforms -   #
#  they must be byte-identical.                                               #
#    ref - the plain arm Vivado, Gowin, Verilator and iverilog all build      #
#    alt - -DQUARTUS_ALTSYNCRAM, the megafunction, against altsyncram_stub.v  #
#    inf - -DQUARTUS_RAM_INFER, plain Verilog restructured for Quartus        #
#                                                                            #
#  The `inf` arm needs NO stub: it is ordinary Verilog, so iverilog runs the   #
#  code Quartus will actually build rather than a model of it. That is the    #
#  reason to prefer it over the megafunction.                                 #
#                                                                            #
#  TEETH, checked 01-SEP-2026: giving the `inf` arm one extra clock of read   #
#  latency - the exact bug above - makes this script FAIL. Note that breaking #
#  its write-first BYPASS does NOT, and that is correct: during a write       #
#  regWE_n is low, so D_3_0_OUT is masked to 0 that cycle and the bypassed    #
#  value is overwritten before the mask lifts. It is unobservable at the pin. #
#############################################################################
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SUP="$HERE/.."
CIRC="$HERE/../../../CPU-BOARD-3202/circuit"
STUB="$HERE/altsyncram_stub.v"
IVERILOG=${IVERILOG:-iverilog}
VVP=${VVP:-vvp}
fail=0

# run one arm and leave its logged waveform in /tmp/eq_<label>_<arm>.txt
# $1=label $2=arm $3=tb $4=dut $5=logfile  (extra args: iverilog flags/files)
run_arm () {
    local label="$1" arm="$2" tb="$3" dut="$4" log="$5"; shift 5
    rm -f "$log"
    $IVERILOG -g2012 -o "/tmp/eq_${label}_${arm}" "$tb" "$dut" "$@" || return 1
    $VVP "/tmp/eq_${label}_${arm}" > /dev/null 2>&1
    cp "$log" "/tmp/eq_${label}_${arm}.txt" 2>/dev/null \
        || { echo "  $label/$arm: produced no log"; return 1; }
}

# compare one Quartus arm against the reference arm
cmp_arm () {            # $1 = label, $2 = arm, $3 = human name
    local label="$1" arm="$2" what="$3"
    local n; n=$(wc -l < "/tmp/eq_${label}_ref.txt")
    if diff -q "/tmp/eq_${label}_ref.txt" "/tmp/eq_${label}_${arm}.txt" > /dev/null; then
        echo "  $label / $what: MATCH ($n samples)"
        return 0
    fi
    echo "  $label / $what: MISMATCH - does not behave like the reference arm"
    diff "/tmp/eq_${label}_ref.txt" "/tmp/eq_${label}_${arm}.txt" | head -8
    return 1
}

check () {          # $1 = label, $2 = tb, $3 = dut, $4 = logfile, $5 = workdir
    local label="$1" tb="$2" dut="$3" log="$4" wd="$5" rc=0
    cd "$wd" || return 1

    # the reference arm - what Vivado, Gowin, Verilator and iverilog all build
    run_arm "$label" ref "$tb" "$dut" "$log" || return 1

    # QUARTUS_ALTSYNCRAM: the megafunction arm, against the stub model
    run_arm "$label" alt "$tb" "$dut" "$log" -DQUARTUS_ALTSYNCRAM=1 "$STUB" \
        && cmp_arm "$label" alt "altsyncram"  || rc=1

    # QUARTUS_RAM_INFER: the restructured plain-Verilog arm. NOTHING is stubbed
    # here - it is ordinary Verilog, so iverilog runs the real thing. That is
    # the whole point of preferring it to the megafunction: this comparison
    # tests the code Quartus will actually build, not a model of it.
    run_arm "$label" inf "$tb" "$dut" "$log" -DQUARTUS_RAM_INFER=1 \
        && cmp_arm "$label" inf "inference arm" || rc=1

    return $rc
}

echo "Quartus RAM arms vs the plain-Verilog reference arm:"
check wcs  "$HERE/IDT6168A_20_equiv_tb.v" "$SUP/IDT6168A_20.v" equiv_log.txt "$HERE" || fail=1
check mem  "$CIRC/sim/MEM_RAM_49_BLOCKRAM_equiv_tb.v" "$CIRC/MEM_RAM_49_BLOCKRAM.v" \
           mem_equiv_log.txt "$CIRC/sim" || fail=1

if [ "$fail" -eq 0 ]; then echo "TB_RESULT: PASS"; else echo "TB_RESULT: FAIL"; fi
exit $fail
