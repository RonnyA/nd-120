# ============================================================================
# QMTECH XC7A35T SDRAM core board (XC7A35T-1CSG325C) - reference pin map
#
# NOT used by any build directly - copy the ports you need into your
# project's XDC. Sources:
#   - vendor sample XDCs: Software/project_led_XC7A35T_CSG325.zip and
#     Software/project_SDRAM_XC7A35T_CSG325.zip in
#     https://github.com/ChinaQMTECH/QMTECH_XC7A15T_35T_CSG325_CORE_BOARD
#   - user manual QMTECH_XC7A35T_SDRAM-User_Manual_V01.pdf (sections 2.2.x)
#
# All board I/O is 3.3 V (banks powered at 3V3) -> IOSTANDARD LVCMOS33.
# ============================================================================

# ---- System ----------------------------------------------------------------
# 50 MHz oscillator (manual 2.2.3, SG-310SCN) on R2 = IO_L13P_T2_MRCC_34,
# a clock-capable (MRCC) pin - clean MMCM input (schematic sheet 2).
set_property PACKAGE_PIN R2 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
create_clock -period 20.000 -name sys_clk [get_ports sys_clk]

# User keys (active-low, 4.7k pull-ups; schematic sheet 2):
#   SW1 = USER_KEY0 = H18 (used as reset in the vendor samples)
#   SW2 = USER_KEY1 = H17
# (SW3 = PROG_B, hard-wired to the config pin - not user logic.)
set_property PACKAGE_PIN H18 [get_ports key_n]
set_property IOSTANDARD LVCMOS33 [get_ports key_n]
#set_property PACKAGE_PIN H17 [get_ports key1_n]
#set_property IOSTANDARD LVCMOS33 [get_ports key1_n]

# ---- User LEDs (manual 2.2.5, schematic sheet 2) ----------------------------
# ACTIVE-LOW: 3V3 -> 1k -> LED -> FPGA pin; drive 0 to light.
# Board nets: USER_LED0 = D8 (LED D1), USER_LED1 = C8 (LED D4).
# (Third LED = 3.3V power indicator, fourth = FPGA_DONE; not user-drivable.)
set_property PACKAGE_PIN C8 [get_ports {led_n[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_n[0]}]
set_property PACKAGE_PIN D8 [get_ports {led_n[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_n[1]}]

# ---- SDRAM: Winbond W9825G6KH-6, 32 MB, 16-bit bus (manual 2.2.8) ----------
# Port names follow the Tang sdram-bridge controller style; the vendor XDC
# uses SDCLK0/SDCKE0/SDCS0/RAS/CAS/SDWE/Bank/Address/Data/DQM.
set_property PACKAGE_PIN P16 [get_ports sdram_clk]
set_property PACKAGE_PIN R16 [get_ports sdram_cke]
set_property PACKAGE_PIN V13 [get_ports sdram_cs_n]
set_property PACKAGE_PIN V14 [get_ports sdram_ras_n]
set_property PACKAGE_PIN U14 [get_ports sdram_cas_n]
set_property PACKAGE_PIN U15 [get_ports sdram_we_n]
set_property PACKAGE_PIN V12 [get_ports {sdram_ba[0]}]
set_property PACKAGE_PIN U12 [get_ports {sdram_ba[1]}]
set_property PACKAGE_PIN V16 [get_ports {sdram_dqm[0]}]
set_property PACKAGE_PIN N16 [get_ports {sdram_dqm[1]}]

set_property PACKAGE_PIN U11 [get_ports {sdram_addr[0]}]
set_property PACKAGE_PIN U10 [get_ports {sdram_addr[1]}]
set_property PACKAGE_PIN V9  [get_ports {sdram_addr[2]}]
set_property PACKAGE_PIN U9  [get_ports {sdram_addr[3]}]
set_property PACKAGE_PIN T12 [get_ports {sdram_addr[4]}]
set_property PACKAGE_PIN R13 [get_ports {sdram_addr[5]}]
set_property PACKAGE_PIN T13 [get_ports {sdram_addr[6]}]
set_property PACKAGE_PIN T14 [get_ports {sdram_addr[7]}]
set_property PACKAGE_PIN P14 [get_ports {sdram_addr[8]}]
set_property PACKAGE_PIN T15 [get_ports {sdram_addr[9]}]
set_property PACKAGE_PIN V11 [get_ports {sdram_addr[10]}]
set_property PACKAGE_PIN R15 [get_ports {sdram_addr[11]}]
set_property PACKAGE_PIN P15 [get_ports {sdram_addr[12]}]

set_property PACKAGE_PIN P18 [get_ports {sdram_dq[0]}]
set_property PACKAGE_PIN R18 [get_ports {sdram_dq[1]}]
set_property PACKAGE_PIN R17 [get_ports {sdram_dq[2]}]
set_property PACKAGE_PIN T18 [get_ports {sdram_dq[3]}]
set_property PACKAGE_PIN T17 [get_ports {sdram_dq[4]}]
set_property PACKAGE_PIN U17 [get_ports {sdram_dq[5]}]
set_property PACKAGE_PIN V17 [get_ports {sdram_dq[6]}]
set_property PACKAGE_PIN U16 [get_ports {sdram_dq[7]}]
set_property PACKAGE_PIN N17 [get_ports {sdram_dq[8]}]
set_property PACKAGE_PIN N18 [get_ports {sdram_dq[9]}]
set_property PACKAGE_PIN M16 [get_ports {sdram_dq[10]}]
set_property PACKAGE_PIN M17 [get_ports {sdram_dq[11]}]
set_property PACKAGE_PIN K17 [get_ports {sdram_dq[12]}]
set_property PACKAGE_PIN L18 [get_ports {sdram_dq[13]}]
set_property PACKAGE_PIN K18 [get_ports {sdram_dq[14]}]
set_property PACKAGE_PIN J18 [get_ports {sdram_dq[15]}]

set_property IOSTANDARD LVCMOS33 [get_ports {sdram_clk sdram_cke sdram_cs_n sdram_ras_n sdram_cas_n sdram_we_n sdram_ba[*] sdram_dqm[*] sdram_addr[*] sdram_dq[*]}]

# ---- Extension headers JP2 / JP3 (manual 2.2.6) -----------------------------
# 2x25 headers; schematic net names are IO_<pin> (net name = FPGA pin), so
# any header pin's FPGA location is readable straight off the schematic.
# CAUTION: on BOTH headers pin 1 = USB_5V rail and pin 2 = 3V3 rail.
#
# Future OPCOM UART to an external 3.3 V USB-serial adapter goes on two
# header pins of your choice - uncomment and fill in after picking them on
# the schematic (Hardware/QMTECH_XC7A15T_35T_50T_CSG325_SDRAM_V1.pdf):
#set_property PACKAGE_PIN <pin> [get_ports uart_tx]
#set_property PACKAGE_PIN <pin> [get_ports uart_rx]
#set_property IOSTANDARD LVCMOS33 [get_ports {uart_tx uart_rx}]

# ---- Configuration ----------------------------------------------------------
# N25Q064A SPI flash, QSPI x4, board straps M0:M1:M2 = 1:0:0 (SPI boot).
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
