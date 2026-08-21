# Nexys 4 DDR pins for the SD-FAT test (nexys4ddr_sd_fat_top)
# Pin source of truth: ../Nexys-4-DDR-Master.xdc (Digilent official, Rev. C).
# Part: xc7a100tcsg324-1.
#
# Pull-ups: the SD stack REQUIRES CMD and DAT0-3 to idle high when released
# (DAT3 high at CMD0 keeps the card out of SPI mode). The FPGA internal
# pull-ups are enabled on all five lines so the design does not depend on
# what the board fits - same reasoning as the Basys3 SD build.

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## 100 MHz oscillator
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk100]
create_clock -name sys_clk_pin -period 10.000 [get_ports clk100]

## Buttons
set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports cpu_resetn]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports btnc]

## USB-UART
set_property -dict {PACKAGE_PIN C4 IOSTANDARD LVCMOS33} [get_ports uart_txd_in]
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports uart_rxd_out]

## On-board microSD slot
set_property -dict {PACKAGE_PIN E2 IOSTANDARD LVCMOS33} [get_ports sd_reset]
set_property -dict {PACKAGE_PIN A1 IOSTANDARD LVCMOS33} [get_ports sd_cd]
set_property -dict {PACKAGE_PIN B1 IOSTANDARD LVCMOS33} [get_ports sd_clk]
set_property -dict {PACKAGE_PIN C1 IOSTANDARD LVCMOS33 PULLUP true} [get_ports sd_cmd]
set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVCMOS33 PULLUP true} [get_ports sd_dat0]
set_property -dict {PACKAGE_PIN E1 IOSTANDARD LVCMOS33 PULLUP true} [get_ports sd_dat1]
set_property -dict {PACKAGE_PIN F1 IOSTANDARD LVCMOS33 PULLUP true} [get_ports sd_dat2]
set_property -dict {PACKAGE_PIN D2 IOSTANDARD LVCMOS33 PULLUP true} [get_ports sd_dat3]

## LEDs LD0-LD7 (active high)
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {led[7]}]
