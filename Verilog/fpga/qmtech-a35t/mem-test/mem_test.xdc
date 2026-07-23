# QMTECH XC7A35T core board - standalone ND-120 BRAM memory test pins
# Subset of ../board-pins.xdc (see there for sources).

set_property PACKAGE_PIN R2 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
create_clock -period 20.000 -name sys_clk [get_ports sys_clk]

set_property PACKAGE_PIN H18 [get_ports key_n]
set_property IOSTANDARD LVCMOS33 [get_ports key_n]

set_property PACKAGE_PIN C8 [get_ports {led_n[0]}]
set_property PACKAGE_PIN D8 [get_ports {led_n[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_n[*]}]

set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
