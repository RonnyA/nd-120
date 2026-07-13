# ND-120 on Cmod A7 - timing constraints (processed AFTER nd120_cmod.xdc so
# the primary clock 'sys_clk' exists). Same architecture as the Basys3
# build (fpga/basys3/nd120_timing.xdc):
#   sys_clk     = 12 MHz pin; clocks only POR/heartbeat inside ND120_TOP
#   clk_cpu_pre = MMCM CLKOUT0 (27 MHz, TARGET_CMOD_A7 branch); the ENTIRE
#                 CPU + bus core runs on the BUFG'd clk_cpu
# The only crossing is human-readable observation - declare the domains
# asynchronous, exactly like the Basys3 file.
set_clock_groups -asynchronous \
  -group [get_clocks sys_clk] \
  -group [get_clocks clk_cpu_pre]
