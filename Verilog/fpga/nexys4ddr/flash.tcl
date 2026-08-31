# ---------------------------------------------------------------------------
# Write an ALREADY-BUILT bitstream into the Nexys 4 DDR's QSPI config flash.
# PERMANENT: the image survives a power cycle - this is what "deploy" means.
#
#   vivado -mode batch -source flash.tcl
#   vivado -mode batch -source flash.tcl -tclargs <path-to-.bit>
#
# The volatile counterpart is program.tcl (JTAG into configuration RAM,
# seconds, gone at power-off). Use that while iterating; use this to leave an
# image on the board.
#
# FLASH PART: the Nexys 4 DDR carries a Spansion S25FL128S (128 Mbit, QSPI).
# The exact Vivado cfgmem part NAME varies between Vivado releases, so instead
# of hard-coding one this script asks the running Vivado for every cfgmem part
# matching s25fl128 and uses the first SPIx4 one - and prints what it picked,
# so a wrong pick is visible in the log rather than silent.
#
# After flashing, the FPGA is booted from the new image (boot_hw_device), so
# the board is running it immediately - no power cycle needed to check.
#
# The board must be attached to Windows, not WSL (usbipd) - same rule as
# program.tcl.
# ---------------------------------------------------------------------------

set srcdir [file dirname [file normalize [info script]]]
set bit [file join $srcdir nd120_nexys4ddr.bit]
if {[llength $argv] > 0} {
    set bit [lindex $argv 0]
}

if {![file exists $bit]} {
    puts "ERROR: no bitstream at $bit"
    puts "       build one first: make build   (or: vivado -mode batch -source build.tcl -tclargs -noburn)"
    exit 1
}

puts "BITSTREAM: $bit"
puts "MODIFIED:  [clock format [file mtime $bit] -format {%Y-%m-%d %H:%M:%S}]"

# --- 1. bitstream -> flash image (.mcs) ------------------------------------
set mcs [file rootname $bit].mcs
write_cfgmem -force -format mcs -size 16 -interface SPIx4 \
    -loadbit "up 0x0 $bit" -file $mcs
puts "FLASH IMAGE: $mcs"

# --- 2. find the board and the flash part ----------------------------------
open_hw_manager
connect_hw_server
open_hw_target
# Same 5 MHz TCK rule as program_only.tcl / ila_capture.tcl - faster TCK
# corrupts uploads on this board.
set_property PARAM.FREQUENCY 5000000 [current_hw_target]

set dev [lindex [get_hw_devices xc7a100t*] 0]
if {$dev eq ""} {
    puts "ERROR: no xc7a100t found on the JTAG chain."
    puts "       Is the board powered, and is its USB attached to Windows rather than WSL?"
    close_hw_manager
    exit 1
}
current_hw_device $dev

# The Nexys 4 DDR carries a Spansion S25FL128S at 3.3 V, and Vivado names that
# family "s25fl128sxxxxxx0-spi-x1_x2_x4" for 7-series (the "-qspi-...-single"
# spelling exists but is UltraScale-only: artix7 rejects it with
# [Labtoolstcl 44-655] "not supported for device artix7"). The trailing 0 vs 1
# is the sector architecture; the Nexys 4 DDR uses the 0 variant.
# Ask for it BY NAME: the old
# "first s25fl128* match" heuristic picked s25fl128l-spi-x1_x2_x4 - the
# S25FL128L, a DIFFERENT device with a different ID and command set - and the
# readback failed with [Labtools 27-3307] Readback CfgMem Error (31-AUG-2026).
# The S parts are never named "*x1_x2_x4*", so that filter could only ever
# match the wrong one.
set parts [get_cfgmem_parts -filter {NAME == "s25fl128sxxxxxx0-spi-x1_x2_x4"}]
if {[llength $parts] == 0} {
    set parts [get_cfgmem_parts -filter {NAME =~ "s25fl128sxxxxxx*-spi-x1_x2_x4"}]
}
if {[llength $parts] == 0} {
    puts "ERROR: no s25fl128s spi-x1_x2_x4 cfgmem part in this Vivado."
    close_hw_manager
    exit 1
}
set part [lindex $parts 0]
puts "FLASH PART: [get_property NAME $part]"

# --- 3. program the flash ---------------------------------------------------
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

# --- 4. boot the FPGA from the freshly written flash ------------------------
boot_hw_device $dev
puts "FLASHED (QSPI, permanent - survives power cycles; board is running it now)"
close_hw_manager
