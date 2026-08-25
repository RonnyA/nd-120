# Nexys 4 DDR / Nexys A7-100T pins for the ND-120 build (nd120_nexys4ddr_top)
#
# Pin source of truth: Nexys-4-DDR-Master.xdc in this directory (Digilent
# official, Rev. C board). Every line below is that file's PACKAGE_PIN with
# the port renamed - nothing here is inferred.
# Part: xc7a100tcsg324-1.

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## 100 MHz oscillator
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk100]
create_clock -name sys_clk -period 10.000 [get_ports clk100]

## Buttons
set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports cpu_resetn]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports btnc]

## Slide switches (sw[0] selects the 7-segment source)
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVCMOS33} [get_ports {sw[1]}]
set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS33} [get_ports {sw[2]}]
set_property -dict {PACKAGE_PIN R15 IOSTANDARD LVCMOS33} [get_ports {sw[3]}]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports {sw[4]}]
set_property -dict {PACKAGE_PIN T18 IOSTANDARD LVCMOS33} [get_ports {sw[5]}]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports {sw[6]}]
set_property -dict {PACKAGE_PIN R13 IOSTANDARD LVCMOS33} [get_ports {sw[7]}]
set_property -dict {PACKAGE_PIN T8  IOSTANDARD LVCMOS18} [get_ports {sw[8]}]
set_property -dict {PACKAGE_PIN U8  IOSTANDARD LVCMOS18} [get_ports {sw[9]}]
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {sw[10]}]
set_property -dict {PACKAGE_PIN T13 IOSTANDARD LVCMOS33} [get_ports {sw[11]}]
set_property -dict {PACKAGE_PIN H6  IOSTANDARD LVCMOS33} [get_ports {sw[12]}]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports {sw[13]}]
set_property -dict {PACKAGE_PIN U11 IOSTANDARD LVCMOS33} [get_ports {sw[14]}]
set_property -dict {PACKAGE_PIN V10 IOSTANDARD LVCMOS33} [get_ports {sw[15]}]

## LEDs LD0-LD15 (active high)
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {led[7]}]
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {led[8]}]
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports {led[9]}]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {led[10]}]
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports {led[11]}]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports {led[12]}]
set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports {led[13]}]
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports {led[14]}]
set_property -dict {PACKAGE_PIN V11 IOSTANDARD LVCMOS33} [get_ports {led[15]}]

## Tri-colour LEDs LD16/LD17 (active high) - DDR2/arbiter health panel
set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS33} [get_ports {led16_r}]
set_property -dict {PACKAGE_PIN M16 IOSTANDARD LVCMOS33} [get_ports {led16_g}]
set_property -dict {PACKAGE_PIN R12 IOSTANDARD LVCMOS33} [get_ports {led16_b}]
set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports {led17_r}]
set_property -dict {PACKAGE_PIN R11 IOSTANDARD LVCMOS33} [get_ports {led17_g}]
set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS33} [get_ports {led17_b}]

## 7-segment display - segments (active low)
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports ca]
set_property -dict {PACKAGE_PIN R10 IOSTANDARD LVCMOS33} [get_ports cb]
set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS33} [get_ports cc]
set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVCMOS33} [get_ports cd]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports ce]
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports cf]
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS33} [get_ports cg]
set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVCMOS33} [get_ports dp]

## 7-segment display - digit anodes (active low); an[7:4] blanked by the wrapper
set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVCMOS33} [get_ports {an[0]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS33} [get_ports {an[1]}]
set_property -dict {PACKAGE_PIN T9  IOSTANDARD LVCMOS33} [get_ports {an[2]}]
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVCMOS33} [get_ports {an[3]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {an[4]}]
set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS33} [get_ports {an[5]}]
set_property -dict {PACKAGE_PIN K2  IOSTANDARD LVCMOS33} [get_ports {an[6]}]
set_property -dict {PACKAGE_PIN U13 IOSTANDARD LVCMOS33} [get_ports {an[7]}]

## USB-UART bridge (names from the master XDC: txd_in = PC -> FPGA)
set_property -dict {PACKAGE_PIN C4 IOSTANDARD LVCMOS33} [get_ports uart_txd_in]
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports uart_rxd_out]

## On-board microSD slot. The stack runs 1-bit (CMD + DAT0); DAT1-3 are
## parked high at the pads. Pull-ups: CMD and DAT0-3 must idle high when
## released, and DAT3 high at CMD0 is what keeps the card out of SPI mode.
## SD_RESET must be driven LOW or the slot has no power (reference manual
## section 12).
set_property -dict {PACKAGE_PIN E2 IOSTANDARD LVCMOS33} [get_ports sd_reset]
set_property -dict {PACKAGE_PIN A1 IOSTANDARD LVCMOS33} [get_ports sd_cd]
set_property -dict {PACKAGE_PIN B1 IOSTANDARD LVCMOS33} [get_ports sd_clk]
set_property -dict {PACKAGE_PIN C1 IOSTANDARD LVCMOS33 PULLUP true} [get_ports sd_cmd]
set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVCMOS33 PULLUP true} [get_ports sd_dat0]
set_property -dict {PACKAGE_PIN E1 IOSTANDARD LVCMOS33 PULLUP true} [get_ports sd_dat1]
set_property -dict {PACKAGE_PIN F1 IOSTANDARD LVCMOS33 PULLUP true} [get_ports sd_dat2]
set_property -dict {PACKAGE_PIN D2 IOSTANDARD LVCMOS33 PULLUP true} [get_ports sd_dat3]

## DDR2 pins are NOT here - the MIG core carries its own constraints for them.
