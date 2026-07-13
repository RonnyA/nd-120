# ND-120 on Cmod A7-35T - self-contained in-memory Vivado flow
# (mem-test/sd-fat-test pattern: no .xpr project needed, unlike the Basys3
# main build which drives a GUI project on F:).
#
#   vivado -mode batch -source build.tcl                    # build + JTAG program
#   vivado -mode batch -source build.tcl -tclargs -noburn   # build only
#
# Configuration: BRAM main memory (MAIN_RAM_BLOCKRAM, Basys3-equivalent),
# FF mode, runtime WCS load from the PROM images, clk_cpu = 27 MHz
# (TARGET_CMOD_A7 MMCM branch in ND120_TOP.v - the Tang Nano 20K's full
# CPU speed). If 27 MHz does not close timing, add
#   -verilog_define ND120_CMOD_MMCM_DIV=56.0
# to synth_design below for 13.5 MHz (and change BOARD_CLK_FREQ to match!).

set part xc7a35tcpg236-1
set srcdir [file dirname [file normalize [info script]]]
set vroot  [file normalize [file join $srcdir .. ..]]   ;# Verilog/

# Microcode PROM images: $readmemh("AM27256_4513xL.hex") in CPU_CS_PROM_19.v
# resolves against Vivado's working directory - copy them next to us and cd.
set uc [file join $vroot .. Code Microcode]
foreach hex {AM27256_45132L.hex AM27256_45133L.hex} {
    if {![file exists [file join $uc $hex]]} {
        puts "ERROR: microcode image missing: [file join $uc $hex]"
        exit 1
    }
    file copy -force [file join $uc $hex] [file join $srcdir $hex]
}
cd $srcdir
puts "Microcode PROM images copied (2 files)."

create_project -in_memory -part $part

# One source of truth for the CPU file list: the Tang project file, minus
# the Tang-specific files, plus the ND120_TOP stack and this board's top.
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

lappend srcs \
    [file join $vroot ND120_TOP.v] \
    [file join $vroot CPU-BOARD-3202 circuit MEM_RAM_49_BLOCKRAM.v] \
    [file join $vroot Shared support SevenSegDebug.v] \
    [file join $srcdir nd120_cmod_top.v]

read_verilog $srcs

read_xdc [file join $srcdir nd120_cmod.xdc]
read_xdc [file join $srcdir nd120_timing.xdc]

# Same harmless-warning suppressions as the Basys3 flow
set_msg_config -id {Synth 8-3936} -suppress
set_msg_config -id {Synth 8-5837} -suppress

synth_design -top nd120_cmod_top -part $part \
    -verilog_define TARGET_CMOD_A7 \
    -verilog_define FPGA_FF_MODE \
    -verilog_define MAIN_RAM_BLOCKRAM \
    -verilog_define BOARD_CLK_FREQ=27000000 \
    -verilog_define UART_BAUD_RATE=115200
opt_design
place_design
route_design

report_utilization    -file [file join $srcdir util.rpt]
report_timing_summary -file [file join $srcdir timing.rpt]

# Fail loudly on negative slack - a 27 MHz miss must not be flashed silently
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "WNS: $wns ns"
if {$wns < 0} {
    puts "ERROR: timing NOT met at 27 MHz (WNS $wns ns)."
    puts "Fallback: -verilog_define ND120_CMOD_MMCM_DIV=56.0 (13.5 MHz)"
    puts "and BOARD_CLK_FREQ=13500000. See README.md."
    exit 1
}

set bit [file join $srcdir nd120_cmod.bit]
write_bitstream -force $bit
puts "BITSTREAM: $bit"

if {[lsearch $argv "-noburn"] >= 0} {
    puts "=== ND120 CMOD BUILD COMPLETE (not programmed) ==="
    return
}

# ---- program over JTAG (volatile; power-cycle wipes it) ----
open_hw_manager
connect_hw_server
open_hw_target
set dev [lindex [get_hw_devices xc7a35t*] 0]
current_hw_device $dev
set_property PROGRAM.FILE $bit $dev
program_hw_devices $dev
puts "PROGRAMMED (JTAG)"
close_hw_manager

puts "=== ND120 CMOD BUILD COMPLETE ==="
