# ---------------------------------------------------------------------------
# READ BACK the Nexys 4 DDR's QSPI config flash to a file. Nothing is written
# to the flash - this is the safety net you run BEFORE flash.tcl overwrites
# whatever the board shipped with (the Digilent demo application).
#
#   vivado -mode batch -source readback_qspi.tcl
#   vivado -mode batch -source readback_qspi.tcl -tclargs <outfile> <bytes>
#
# Defaults: qspi_backup.bin, 4 MiB. A full xc7a100t bitstream is 3,825,999
# bytes (~3.65 MiB), so 4 MiB captures one image. Pass 16777216 for the whole
# 128 Mbit device if you want everything including any data past the image -
# that takes far longer, because JTAG at 5 MHz TCK is the bottleneck.
#
# NOTE: reading the flash needs Vivado to load its own indirect-programming
# bitstream into the FPGA, so whatever the FPGA was running STOPS. Re-flash
# afterwards with program_only.tcl.
#
# Same rules as flash.tcl: board attached to Windows (not WSL), TCK held at
# 5 MHz because faster corrupts transfers on this board.
# ---------------------------------------------------------------------------

set srcdir [file dirname [file normalize [info script]]]
set outfile [file join $srcdir qspi_backup.bin]
set nbytes  4194304

if {[llength $argv] > 0} { set outfile [lindex $argv 0] }
if {[llength $argv] > 1} { set nbytes  [lindex $argv 1] }

puts "READBACK TO: $outfile"
puts "BYTES:       $nbytes"

open_hw_manager
connect_hw_server
open_hw_target
set_property PARAM.FREQUENCY 5000000 [current_hw_target]

set dev [lindex [get_hw_devices xc7a100t*] 0]
if {$dev eq ""} {
    puts "ERROR: no xc7a100t on the JTAG chain - powered? USB on Windows not WSL?"
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
puts "FLASH PART:  [get_property NAME $part]"

set cfgmem [create_hw_cfgmem -hw_device $dev $part]

# The FPGA needs the indirect-programming bitstream before the flash is
# reachable over JTAG. This is what stops whatever was running.
create_hw_bitstream -hw_device $dev [get_property PROGRAM.HW_CFGMEM_BITFILE $dev]
program_hw_devices $dev

readback_hw_cfgmem -force -file $outfile -format bin -offset 0 -datacount $nbytes $cfgmem

puts "READBACK COMPLETE: $outfile"
puts "The FPGA now holds Vivado's programming bitstream, NOT your design -"
puts "re-run program_only.tcl to put the ND-120 back."
close_hw_manager
