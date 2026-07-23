# Cmod A7-35T pins for the ND-120 build (nd120_cmod_top)
# Pin source of truth: Cmod-A7-Master.xdc in this directory (Digilent
# official, rev. B board). Part: xc7a35tcpg236-1 (same die AND package as
# the Basys3).

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## 12 MHz crystal
set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS33} [get_ports clk12]
create_clock -name sys_clk -period 83.333 [get_ports clk12]

## Buttons (active high)
set_property -dict {PACKAGE_PIN A18 IOSTANDARD LVCMOS33} [get_ports btn0]
set_property -dict {PACKAGE_PIN B18 IOSTANDARD LVCMOS33} [get_ports btn1]

## FT2232 USB-UART (names from the master XDC: txd_in = PC->FPGA)
set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVCMOS33} [get_ports uart_txd_in]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS33} [get_ports uart_rxd_out]

## LEDs
set_property -dict {PACKAGE_PIN A17 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN C16 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS33} [get_ports led0_r]
set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVCMOS33} [get_ports led0_g]
set_property -dict {PACKAGE_PIN B17 IOSTANDARD LVCMOS33} [get_ports led0_b]
