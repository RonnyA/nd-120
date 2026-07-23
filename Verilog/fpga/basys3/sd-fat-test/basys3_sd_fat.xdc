# Basys3 pins for the SD-FAT test (basys3_sd_fat_top)
# Pin sources: Basys 3 reference manual Table 6 (Pmod pin assignments) +
# the repo's mem-test XDC conventions. SD card sits on Pmod JB - the
# TOP-RIGHT Pmod connector - with the Digilent Pmod MicroSD / Pmod SD
# mapping (Pmod pin 1 = ~CS/DAT3, 2 = MOSI/CMD, 3 = MISO/DAT0, 4 = SCK,
# 7 = DAT1, 8 = DAT2, 9 = CD unused).
#
# Pull-ups: the SD stack REQUIRES CMD/DAT0-3 to idle high when released
# (DAT3 high at CMD0 keeps the card out of SPI mode - same reasoning as
# the Tang build, which relied on that board's external 10K pulls
# R53-R57). The Pmod module's own pulls are not guaranteed, so the FPGA
# internal pull-ups are enabled on all five lines; externals in parallel
# are harmless.

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## 100 MHz crystal
set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports clk100]
create_clock -name sys_clk_pin -period 10.000 [get_ports clk100]

## Buttons (active high)
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports btnC]
set_property -dict {PACKAGE_PIN T18 IOSTANDARD LVCMOS33} [get_ports btnU]

## FT2232 USB-UART
set_property -dict {PACKAGE_PIN B18 IOSTANDARD LVCMOS33} [get_ports RsRx]
set_property -dict {PACKAGE_PIN A18 IOSTANDARD LVCMOS33} [get_ports RsTx]

## Pmod JB (top right) - SD card
set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVCMOS33} [get_ports sd_clk]
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS33 PULLUP true} [get_ports sd_cmd]
set_property -dict {PACKAGE_PIN B15 IOSTANDARD LVCMOS33 PULLUP true} [get_ports sd_dat0]
set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS33 PULLUP true} [get_ports sd_dat1]
set_property -dict {PACKAGE_PIN A17 IOSTANDARD LVCMOS33 PULLUP true} [get_ports sd_dat2]
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33 PULLUP true} [get_ports sd_dat3]

## LEDs LD0-LD5 (active high)
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports {led[5]}]
