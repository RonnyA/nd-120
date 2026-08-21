# ND-120 on Nexys 4 DDR / Nexys A7-100T - self-contained in-memory Vivado flow
#
# Template: the Basys3 build (fpga/basys3/vivado_build.tcl) - same defines,
# same source set, same "fail loudly on negative slack" gate. The one
# deliberate difference: no out-of-repo .xpr GUI project (the Basys3 flow
# drives F:/Xilinx/ND120/ND3202D). Everything here is in-memory and lives in
# the repo, the way fpga/cmod-a7-35t/build.tcl already does it.
#
#   vivado -mode batch -source build.tcl                       # build + JTAG program
#   vivado -mode batch -source build.tcl -tclargs -noburn      # build only
#   vivado -mode batch -source build.tcl -tclargs clk=33       # 33.333 MHz CPU clock
#   vivado -mode batch -source build.tcl -tclargs -promload    # runtime PROM->WCS load
#
# Configuration: BRAM main memory (MAIN_RAM_BLOCKRAM), FF mode, WCS preloaded
# from the bitstream (SKIP_WCS_LOAD - the same choice the Tang makes), CPU
# clock 16.667 MHz. The ND-BUS device chain (tape, floppy, Winchester) is
# included and served from the microSD card, with the storage region in DDR2.

set part xc7a100tcsg324-1
set srcdir [file dirname [file normalize [info script]]]
set vroot  [file normalize [file join $srcdir .. ..]]   ;# Verilog/

########################################################################
# CPU clock selection
#  The board oscillator is 100 MHz; the MMCM in ND120_TOP.v (branch
#  TARGET_NEXYS4DDR) runs VCO = 100 x 10 = 1000 MHz and divides it down.
#  clk=<MHz> picks the divider AND the matching BOARD_CLK_FREQ - the two
#  MUST move together or every derived count (UART baud, RTC tick,
#  watchdogs) is wrong.
#
#  MEASURED 20-AUG-2026 with tape + floppy + Winchester in, at 16.667 MHz:
#  WNS -35.107 ns. The worst path runs from an interrupt mask bit
#  (INTR/CNTLR/IRQ_MASK/MASKBIT10) to the WCS BRAM address input over 181
#  logic levels / 94.4 ns, with NO register in between. Measured Fmax of the
#  CPU domain is therefore about 10.5 MHz, so clk=8 is the first entry that
#  can pass the gate and clk=10 is marginal.
#
#  Where the 94.4 ns goes, bucketed from timing.rpt:
#      CGA/ALU  (OUTMUX/RALU/STS)   58.8 ns   62%
#      CGA/MAC                      14.5 ns   15%
#      CGA/INTR                      8.2 ns    9%
#      MMU cache                     4.3 ns    5%
#  It is an ALU path, not an interrupt path and not a device-chain path.
#
#  TWO THINGS THIS COMMENT USED TO CLAIM, BOTH WRONG, both corrected after
#  reading the Tang's own Gowin report
#  (fpga/tang-nano-20k/build/nd120_tang20k_build/impl/pnr/*.tr):
#    - "the same RTL closes 27 MHz on the Tang". It does not. The Tang's CPU
#      domain is constrained at 6.75 MHz and its actual Fmax is 5.08 MHz with
#      1532 violating endpoints. The 27 MHz figure belongs to sys_clk, the
#      crystal INPUT PORT, which is the only clock its six-line .sdc
#      constrains. In absolute nanoseconds this board is about twice as fast
#      as the Tang has ever run.
#    - "the device chain explains the path". It does not. The Tang carries
#      the identical tape + floppy + Winchester set (SMD off).
#
#  Every setting is an EXPERIMENT until its own timing report is clean, and
#  the WNS gate below refuses to write a bitstream that misses. The Gowin
#  flow has no such gate, which is why the Tang has been writing bitstreams
#  over 1532 violating endpoints.
########################################################################
set clk_table {
    8   {125.0 8000000}
    10  {100.0 10000000}
    12  {80.0  12500000}
    16  {60.0 16666667}
    20  {50.0 20000000}
    25  {40.0 25000000}
    27  {37.0 27027027}
    33  {30.0 33333333}
    50  {20.0 50000000}
    100 {10.0 100000000}
}
# CPU clock argument. BOTH forms are accepted, and that is not politeness:
#
#   MEASURED 20-AUG-2026: invoked from WSL through cmd.exe, "clk=10" arrives
#   at Vivado as TWO separate arguments - argv becomes {-noburn} {clk} {10},
#   because cmd.exe treats '=' as an argument delimiter just like a space.
#   A regexp for '^clk=(\d+)$' therefore matches NOTHING and the build
#   silently runs at the default speed while looking like it obeyed. That
#   cost two full builds before it was measured with a tcl script that just
#   printed $argv.
#
#   So: accept "clk=10" (works when run from a real shell), accept "clk 10"
#   (what cmd.exe delivers), and FAIL LOUDLY on anything else.
set clk_sel 16
set _n [llength $argv]
for {set i 0} {$i < $_n} {incr i} {
    set a [lindex $argv $i]
    if {[regexp {^clk=(\w+)$} $a -> v]} {
        set clk_sel $v
    } elseif {$a eq "clk" && $i + 1 < $_n} {
        set clk_sel [lindex $argv [expr {$i + 1}]]
    }
}
puts "argv: $argv  -> clk_sel = $clk_sel"

if {![dict exists $clk_table $clk_sel]} {
    puts "ERROR: clk=$clk_sel not supported. Choose one of: [dict keys $clk_table]"
    exit 1
}
set mmcm_div  [lindex [dict get $clk_table $clk_sel] 0]
set board_clk [lindex [dict get $clk_table $clk_sel] 1]
puts "CPU clock: divider $mmcm_div -> BOARD_CLK_FREQ $board_clk Hz"

# WCS PRELOAD IS THE DEFAULT ON THIS BOARD, same as the Tang Nano 20K
# (fpga/tang-nano-20k/src/tang20k_defines.v defines SKIP_WCS_LOAD): the
# microcode is preloaded straight into the WCS from the 33 nibble images in
# Code/Microcode/wcs/, and the LCS latch is neutralised so the original
# machine's runtime PROM->WCS load phase never runs. The point is cost: with
# SKIP_WCS_LOAD the microcode PROM (CPU_CS_PROM_19) is never read, so its ROM
# arrays are compiled out entirely - no block RAM spent emulating an EPROM,
# and about 7,850 LUTs saved.
#
# -promload builds the other way (runtime load out of the emulated PROM), for
# comparison against the original machine's behaviour.
set skip_wcs [expr {[lsearch $argv "-promload"] < 0}]

cd $srcdir

if {$skip_wcs} {
    # $readmemh("wcs_*.hex") resolves against Vivado's working directory
    set wcs_src [file normalize [file join $vroot .. Code Microcode wcs]]
    set wcs_files [glob -nocomplain [file join $wcs_src wcs_*.hex]]
    if {[llength $wcs_files] != 33} {
        puts "ERROR: expected 33 WCS images in $wcs_src, found [llength $wcs_files]"
        exit 1
    }
    foreach f $wcs_files { file copy -force $f [file join $srcdir [file tail $f]] }
    puts "WCS preload: [llength $wcs_files] images copied (SKIP_WCS_LOAD)."
} else {
    set uc [file join $vroot .. Code Microcode]
    foreach hex {AM27256_45132L.hex AM27256_45133L.hex} {
        if {![file exists [file join $uc $hex]]} {
            puts "ERROR: microcode image missing: [file join $uc $hex]"
            exit 1
        }
        file copy -force [file join $uc $hex] [file join $srcdir $hex]
    }
    puts "-promload: microcode PROM images copied (2 files)."
}

create_project -in_memory -part $part

# One source of truth for the CPU file list: the Tang project file, minus the
# Tang-specific files, plus the ND120_TOP stack and this board's top.
set gprj [file join $vroot fpga tang-nano-20k nd120_tang20k.gprj]
set fp [open $gprj r]
set xml [read $fp]
close $fp

set exclude {
    src/tang20k_defines.v
    src/gowin_rpll_27_54.v
    src/ND120_TANG20K_TOP.v
    sdram-test/src/uart_tx.v
    sdram-bridge/MEM_RAM_49_SDRAM.v
    sdram-bridge/sdram18.v
}
set srcs {}
foreach {full path} [regexp -all -inline {<File path="([^"]+)"[^>]*enable="1"/>} $xml] {
    if {![string match *.v $path]} { continue }
    if {[lsearch -exact $exclude $path] >= 0} { continue }
    lappend srcs [file normalize [file join $vroot fpga tang-nano-20k $path]]
}
puts "CPU sources from nd120_tang20k.gprj: [llength $srcs] files"

# ND120_TOP.v is deliberately NOT read: this board's top instantiates
# ND120_CORE directly, because the ND-BUS device chain (tape, floppy,
# Winchester) exists only on the core - the same reason the Tang top does it.
lappend srcs \
    [file join $vroot CPU-BOARD-3202 circuit MEM_RAM_49_BLOCKRAM.v] \
    [file join $vroot Shared support SevenSegDebug.v] \
    [file join $vroot fpga nexys4ddr ddr2 nd_ddr2_port.v] \
    [file join $vroot fpga nexys4ddr ddr2 nd_ddr2_storage.v] \
    [file join $srcdir nd120_nexys4ddr_top.v]

read_verilog $srcs

# The DDR2 controller, generated by ddr2-test/gen_mig.tcl. read_ip brings in
# the core AND its constraints, so the DDR2 pins are never hand-written.
set migxci [file join $srcdir ddr2-test ip ddr ddr.xci]
if {![file exists $migxci]} {
    puts "ERROR: MIG core not generated: $migxci"
    puts "Run: vivado -mode batch -source ddr2-test/gen_mig.tcl"
    exit 1
}
read_ip $migxci

read_xdc [file join $srcdir nd120_nexys4ddr.xdc]
read_xdc [file join $srcdir nd120_timing.xdc]

# Same harmless-warning suppressions as the Basys3 flow
#  Synth 8-3936: register trimming (R81/L4/L8/R41P narrower than the width)
#  Synth 8-5837: dual async set/reset (D_FLIPFLOP/F617/F714)
set_msg_config -id {Synth 8-3936} -suppress
set_msg_config -id {Synth 8-5837} -suppress

set defines [list \
    TARGET_NEXYS4DDR \
    FPGA_FF_MODE \
    MAIN_RAM_BLOCKRAM \
    ND120_N4DDR_MMCM_DIV=$mmcm_div \
    BOARD_CLK_FREQ=$board_clk \
    UART_BAUD_RATE=9600]
if {$skip_wcs} { lappend defines SKIP_WCS_LOAD }

set synth_args {}
foreach d $defines { lappend synth_args -verilog_define $d }
puts "Verilog defines: $defines"

# sd_fat_test_top / nd_storage `include "sd_fat_features.vh" from SD-FAT/circuit
# Include paths: nd_storage `include "sd_fat_features.vh" (SD-FAT/circuit) and
# ND120_CORE `include "nd120_backwiring_defaults.vh" (Shared/support)
lappend synth_args -include_dirs [list \
    [file join $vroot SD-FAT circuit] \
    [file join $vroot Shared support]]

synth_design -top nd120_nexys4ddr_top -part $part {*}$synth_args
# clk_cpu, clk_stor and the DDR2 user clock are UNRELATED domains. Every
# crossing between them is a two-flop synchroniser or a toggle handshake.
# Without this Vivado times them as related clocks (they share one MMCM) and
# demands a fraction of a nanosecond, which no crossing can meet - measured
# on the SD build: -3.304 ns before, +1.460 ns after.
set _ccpu [get_clocks -quiet clk_cpu_pre]
set _cst  [get_clocks -quiet clk_stor_pre]
set _cui  [get_clocks -quiet clk_pll_i]
if {[llength $_ccpu] == 0 || [llength $_cst] == 0 || [llength $_cui] == 0} {
    puts "ERROR: expected clocks not found."
    puts "  clocks present: [get_clocks]"
    exit 1
}
set_clock_groups -asynchronous -group $_ccpu -group $_cst -group $_cui
puts "Declared clk_cpu_pre / clk_stor_pre / clk_pll_i asynchronous."

# ---------------------------------------------------------------------------
# KNOWN COMBINATIONAL LOOPS - acknowledged deliberately, not hidden.
#
# 12 loops remain in the CGA's internal data bus, one per IDB bit. The ring is
#   ALU_OUTMUX D_15_0[n] -> G_15_0[n] -> CGA.v FIDBO
#     -> MAC / INTR (CGA.v:614-615 feed FIDBO into their IDB inputs)
#     -> PCR / PGS / PICMASK -> CGA_IDBCTL_SEL6 -> back to FIDBO
# They are FUNCTIONALLY impossible: the IDB source select (CSIDBS_4_0) is
# one-hot, so the contributors are mutually exclusive - the tool simply cannot
# prove that across the module boundaries.
#
# EVIDENCE THAT THIS IS SAFE TO SHIP, not merely convenient:
#  - the SAME RTL with the SAME loops runs on the Tang Nano 20K and boots
#    SINTRAN. The Gowin flow has no loop DRC at all, so it has been producing
#    working bitstreams over them all along.
#  - instruction-verify against the ND-110 golden emulator passes with these
#    fixes in: "TRACES EQUIVALENT: 400 aligned instructions match exactly".
#
# WHAT THIS COSTS: Vivado's timing analysis through these paths is not
# trustworthy, so the WNS number below is a lower bound, not a guarantee.
# That is why the CPU clock stays conservative.
#
# THIS IS A PARKED DEBT, NOT A FIX. The real repair is to break the ring in
# RTL - see EXTENSIONS-PLAN.md and the 20-AUG analysis. Remove this block the
# day the loop count reaches zero, and let the DRC prove it.
# ---------------------------------------------------------------------------
set_property SEVERITY {Warning} [get_drc_checks LUTLP-1]
puts "NOTE: LUTLP-1 downgraded to Warning - 12 known CGA IDB loops, see build.tcl"

opt_design
place_design
route_design

report_utilization    -file [file join $srcdir util.rpt]
report_timing_summary -file [file join $srcdir timing.rpt]

# Fail loudly on negative slack - a missed clock target must not be flashed
# silently (the Basys3 board's whole history is a timing-closure problem).
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "WNS: $wns ns"
if {$wns < 0} {
    puts "ERROR: timing NOT met at the selected CPU clock (WNS $wns ns)."
    puts "Retry with a slower clock, e.g. -tclargs clk=16. See README.md."
    exit 1
}

set bit [file join $srcdir nd120_nexys4ddr.bit]
write_bitstream -force $bit
puts "BITSTREAM: $bit"

if {[lsearch $argv "-noburn"] >= 0} {
    puts "=== ND120 NEXYS4DDR BUILD COMPLETE (not programmed) ==="
    return
}

# ---- program over JTAG (volatile; power-cycle wipes it) ----
open_hw_manager
connect_hw_server
open_hw_target
set dev [lindex [get_hw_devices xc7a100t*] 0]
current_hw_device $dev
set_property PROGRAM.FILE $bit $dev
program_hw_devices $dev
puts "PROGRAMMED (JTAG)"
close_hw_manager

puts "=== ND120 NEXYS4DDR BUILD COMPLETE ==="
