# Minimal in-memory Vivado flow for the Basys3 SD-FAT test (same pattern as
# ../mem-test/build.tcl). Synthesize, implement, write bitstream, JTAG-program
# (volatile).
#   vivado -mode batch -source build.tcl
# Skip programming (build only):
#   vivado -mode batch -source build.tcl -tclargs -noburn

set part xc7a35tcpg236-1
set srcdir [file dirname [file normalize [info script]]]
set vroot  [file normalize [file join $srcdir .. .. ..]]  ;# Verilog/

set sdfat  [file join $vroot SD-FAT circuit]
set tsrc   [file join $vroot fpga tang-nano-20k sd-fat-test src]

create_project -in_memory -part $part

# The test design + its UART/menu helpers live in the (board-independent)
# Tang sd-fat-test src dir - reused, not copied. Only the top wrapper and
# pins are Basys3-specific.
read_verilog [list \
    [file join $srcdir basys3_sd_fat_top.v] \
    [file join $tsrc sd_fat_test_top.v] \
    [file join $tsrc uart_tx.v] \
    [file join $tsrc uart_rx.v] \
    [file join $tsrc status_printer.v] \
    [file join $tsrc hex_dumper.v] \
    [file join $tsrc buf_text_printer.v] \
    [file join $sdfat sd_file_reader.v] \
    [file join $sdfat sd_writer.v] \
    [file join $sdfat sd_fat_rewrite.v] \
    [file join $sdfat sd_fat_check.v] \
    [file join $sdfat sd_fat_freescan.v] ]

read_xdc [file join $srcdir basys3_sd_fat.xdc]

# sd_fat_test_top does `include "sd_fat_features.vh" (lives in SD-FAT/circuit)
synth_design -top basys3_sd_fat_top -part $part -include_dirs $sdfat
opt_design
place_design
route_design

report_utilization    -file [file join $srcdir util.rpt]
report_timing_summary -file [file join $srcdir timing.rpt]

set bit [file join $srcdir basys3_sd_fat.bit]
write_bitstream -force $bit
puts "BITSTREAM: $bit"

if {[lsearch $argv "-noburn"] >= 0} {
    puts "=== SD-FAT BUILD COMPLETE (not programmed) ==="
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

puts "=== SD-FAT BUILD COMPLETE ==="
