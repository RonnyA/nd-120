# ---------------------------------------------------------------------------
# Write a RAW flash image back into the Nexys 4 DDR's QSPI config flash.
# The counterpart to readback_qspi.tcl - used to put the board's factory
# Digilent demo back after it was lost (01-SEP-2026).
#
#   vivado -mode batch -source restore_qspi.tcl -tclargs <image.bin>
#
# Unlike flash.tcl this takes a RAW FLASH IMAGE, not a .bit: write_cfgmem is
# given -loaddata rather than -loadbit, so whatever bytes were read back go
# back at the same offsets.
#
# FLASH PART: s25fl128sxxxxxx0-spi-x1_x2_x4 - named explicitly. Do NOT go back
# to matching "s25fl128*": that also matches s25fl128l (the S25FL128L), a
# different device with a different command set, and issuing its opcodes at
# this board's S25FL128S is what destroyed the factory demo in the first place.
# ---------------------------------------------------------------------------

set srcdir [file dirname [file normalize [info script]]]
if {[llength $argv] < 1} {
    puts "usage: -tclargs <image.bin>"
    exit 1
}
set img [file normalize [lindex $argv 0]]
if {![file exists $img]} { puts "ERROR: no image at $img"; exit 1 }
puts "IMAGE: $img ([file size $img] bytes)"

# raw image -> .mcs the cfgmem flow can program
set mcs [file rootname $img].mcs
write_cfgmem -force -format mcs -size 16 -interface SPIx4 \
    -loaddata "up 0x0 $img" -file $mcs
puts "MCS: $mcs"

open_hw_manager
connect_hw_server
open_hw_target
set_property PARAM.FREQUENCY 5000000 [current_hw_target]

set dev [lindex [get_hw_devices xc7a100t*] 0]
if {$dev eq ""} { puts "ERROR: no xc7a100t on the JTAG chain."; close_hw_manager; exit 1 }
current_hw_device $dev

set parts [get_cfgmem_parts -filter {NAME == "s25fl128sxxxxxx0-spi-x1_x2_x4"}]
if {[llength $parts] == 0} {
    puts "ERROR: s25fl128sxxxxxx0-spi-x1_x2_x4 not in this Vivado."
    close_hw_manager
    exit 1
}
set part [lindex $parts 0]
puts "FLASH PART: [get_property NAME $part]"

set cfgmem [create_hw_cfgmem -hw_device $dev $part]
set_property PROGRAM.FILES [list $mcs] $cfgmem
set_property PROGRAM.ADDRESS_RANGE {use_file} $cfgmem
set_property PROGRAM.BLANK_CHECK 0 $cfgmem
set_property PROGRAM.ERASE 1 $cfgmem
set_property PROGRAM.CFG_PROGRAM 1 $cfgmem
set_property PROGRAM.VERIFY 1 $cfgmem
create_hw_bitstream -hw_device $dev [get_property PROGRAM.HW_CFGMEM_BITFILE $dev]
program_hw_devices $dev
program_hw_cfgmem $cfgmem

puts "RESTORED (QSPI) - power-cycle the board to run it"
close_hw_manager
