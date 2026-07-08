# ND120_TANG20K_TOP timing constraints (Gowin)
# One rPLL: 27 MHz CPU/bus (clkoutd) + 54 MHz SDRAM pair (clkout/clkoutp).
# The PLL output clocks are related (same VCO); Gowin derives generated
# clocks from the rPLL automatically once the input clock is defined.

create_clock -name sys_clk -period 37.037 -waveform {0 18.518} [get_ports {sys_clk}]
