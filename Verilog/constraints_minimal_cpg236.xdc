# Minimal XDC constraints for xc7a35tcpg236
# Only maps essential pins - leaves debug signals internal

## Clock
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports sysclk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports sysclk]

## Buttons (Active Low)
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports btn1]
# btn2 not mapped - comment in if needed
# set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports btn2]

## UART
set_property -dict { PACKAGE_PIN B18  IOSTANDARD LVCMOS33 } [get_ports uartRx]
set_property -dict { PACKAGE_PIN A18  IOSTANDARD LVCMOS33 } [get_ports uartTx]

## LEDs (7 bits)
set_property -dict { PACKAGE_PIN U3   IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN V3   IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN W3   IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN U4   IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN V4   IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN W4   IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports {led[6]}]

## DEBUG SIGNALS - NOT MAPPED to physical pins (kept internal for simulation)
## These signals exist in the design but won't use physical pins:
## - CSA_12_0[12:0]       (Microcode address - use ILA to probe internally)
## - BD_23_0_n_OUT[23:0]  (Bus output - use ILA to probe internally)
## - BD_23_0_n_IN[23:0]   (Bus input - tie to internal values or floating)

## All other I/O signals - comment in only the ones you physically connect
## Otherwise they'll be optimized away or left internal

# Configuration
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
