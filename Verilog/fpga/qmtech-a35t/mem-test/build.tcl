# Minimal in-memory Vivado flow for the QMTECH XC7A35T standalone memory test.
# Synthesise, implement, generate + JTAG-program the bitstream (volatile).
#   vivado -mode batch -source build.tcl
# Reuses the Basys3 mem-test's msg_printer/uart_tx (TX is internal/ILA-only
# here - the board has no UART) and the shared MEM_RAM_49/SIP1M9 sources.

set part xc7a35tcsg325-1
set srcdir [file dirname [file normalize [info script]]]
set b3dir  [file join $srcdir .. .. basys3 mem-test]

create_project -in_memory -part $part

# msg_printer.v uses $bits -> needs SystemVerilog dialect
read_verilog -sv [file join $b3dir msg_printer.v]
read_verilog [list \
    [file join $srcdir qmtech_mem_test_top.v] \
    [file join $b3dir uart_tx.v] \
    [file join $srcdir .. .. .. CPU-BOARD-3202 circuit MEM_RAM_49.v] \
    [file join $srcdir .. .. .. Shared support SIP1M9.v] ]

read_xdc [file join $srcdir mem_test.xdc]

synth_design -top qmtech_mem_test_top -part $part
opt_design
place_design
route_design

report_utilization      -file [file join $srcdir util.rpt]
report_timing_summary   -file [file join $srcdir timing.rpt]

set bit [file join $srcdir qmtech_mem_test.bit]
write_bitstream -force $bit
puts "BITSTREAM: $bit"

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

puts "=== MEM-TEST BUILD COMPLETE ==="
