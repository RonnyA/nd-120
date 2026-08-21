# Program the existing nexys4ddr_sd_fat.bit over JTAG (volatile). No rebuild.
#   vivado -mode batch -source program.tcl
set srcdir [file dirname [file normalize [info script]]]
set bit [file join $srcdir nexys4ddr_sd_fat.bit]
if {![file exists $bit]} { puts "ERROR: $bit not found - build first"; exit 1 }
open_hw_manager
connect_hw_server
open_hw_target
set dev [lindex [get_hw_devices xc7a100t*] 0]
current_hw_device $dev
set_property PROGRAM.FILE $bit $dev
program_hw_devices $dev
puts "PROGRAMMED: $bit"
close_hw_manager
