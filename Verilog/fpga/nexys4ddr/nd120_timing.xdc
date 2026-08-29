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

# ---------------------------------------------------------------------------
# The CGA IDB ring, cut EXPLICITLY (29-AUG-2026).
#
# Inside the DELILAH gate array the IDB is a ring: the ALU reads the bus
# (ALU/FIDBI_15_0) and the ALU's output mux drives it (ALU/FIDBO_15_0_OUT),
# and FIDBO feeds MAC/INTR/MMU readbacks that come back in on FIDBI. The
# one-hot CSIDBS source select makes "read IDB as an ALU operand AND drive
# the ALU result F onto IDB in the same cycle" impossible - that would be two
# drivers on one bus - but the timing tool cannot know that, so it sees the
# ring unrolled 16 times through the ALU carry chain (FIDBI[n] -> adder ->
# F[n+1] -> FIDBO[n+1] -> readback -> FIDBI[n+1] ...): 208 logic levels,
# 110 ns, WNS -50.7 ns at 60 ns.
#
# Until now synth_design broke the ring itself with auto-inserted false
# paths (Synth 8-326), at whatever node its heuristic picked. That choice
# moved with every netlist change: the 28-AUG "vgaconsole cache" build
# closed (32 cuts, CPU worst path 71 levels), the same RTL plus the panel
# clock did not (-50.7 ns, 3 new cuts at CPUi_6/O883), the cache-switch
# build failed differently (-10.4 ns, 127 levels).
#
# This constraint names the impossible edge instead: ordered -through
# ALU IDB input pins -> OUTMUX F (the ALU-result source) pins -> FIDBO pins.
# Only the F branch is cut, so the legitimate pass-through (external IDB ->
# FIDBI -> OUTMUX EFIDB -> FIDBO -> MAC/INTR register loads) stays timed.
# Measured on the routed checkpoints of both failed builds
# (timing-analysis/ring_fp_test.tcl): -10.4 -> +0.044 ns overall with the CPU
# domain at +27.6 ns / 39 levels, and -50.7 -> -0.19 ns (a keyboard path).
# Every path that the tool used to cut on its own is now covered by this
# one, so the auto-cuts should disappear; if Synth 8-326 lines come back,
# the ring has grown a new edge - look before adding a constraint.
#
# If synthesis renames these pins the constraint is dropped with a
# CRITICAL WARNING [Vivado 12-4739] and the -50 ns path returns: grep the
# build log for 12-4739 whenever the WNS gate fails.
set_false_path \
  -through [get_pins -hier -filter {NAME =~ *DELILAH/ALU/FIDBI_15_0[*]}] \
  -through [get_pins -hier -filter {NAME =~ *DELILAH/ALU/ALU_OUTMUX/OUTMUX_IDBS/IDBS_R*/F_15_0[*]}] \
  -through [get_pins -hier -filter {NAME =~ *DELILAH/ALU/FIDBO_15_0_OUT[*]}]
