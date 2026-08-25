# ND-120 on Nexys 4 DDR - timing constraints (processed AFTER
# nd120_nexys4ddr.xdc so the primary clock 'sys_clk' already exists).
# Same architecture as the Basys3 build (fpga/basys3/nd120_timing.xdc):
#
#   sys_clk     = 100 MHz oscillator pin (E3). Clocks ONLY the 7-segment
#                 display and the heartbeat counter inside ND120_TOP.
#   clk_cpu_pre = MMCM CLKOUT0 (TARGET_NEXYS4DDR branch, 16.667 MHz by
#                 default). The ENTIRE CPU + bus core runs on the BUFG'd
#                 clk_cpu, POR included.
#
# The only crossing left is CPU state -> 7-segment display: human-readable
# observation, timing-irrelevant. Declaring the two domains asynchronous
# makes that a non-timed path.
#
# Clocks are referenced BY NAME: the '-of_objects [get_pins .../CLKOUT0]'
# form returned an empty object at constraint-eval time on the Basys3, so
# the group silently never applied.
## The CPU/storage/DDR2 clock groups are declared in build.tcl AFTER
## synth_design - the DDR2 controller's user clock does not exist until the
## MIG core is elaborated, so a get_clocks for it here would match nothing
## and the constraint would silently do nothing.
set_clock_groups -asynchronous \
  -group [get_clocks sys_clk] \
  -group [get_clocks clk_cpu_pre]
