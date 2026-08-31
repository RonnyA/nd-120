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
# The Synth 8-326 auto-cuts do NOT go away: synthesis breaks loops
# structurally on its own, before any XDC applies. Measured on the first
# build with this file (29-AUG, build-ringcut.log): 3 x CPUi_6/O883 and
# 16 x MMUi_5/O880 still inferred, and the CPU worst path was 40 levels /
# 42.8 ns, WNS +0.261 ns - the checkpoint test predicted 39 levels. So the
# 8-326 lines are noise; this constraint is what makes the result stable.
#
# At the pre-synthesis read Vivado reports [Vivado 12-508] "No pins matched"
# for the F_15_0 pins and [Project 1-498] "constraints failed evaluation";
# that is expected - the pins exist only after elaboration and the file is
# re-read after synth_design, where all three patterns resolve. What must
# NOT appear is [Vivado 12-4739] after synthesis: that means a pattern was
# dropped and the -50 ns path is back. Grep the build log for 12-4739
# whenever the WNS gate fails.
set_false_path \
  -through [get_pins -hier -filter {NAME =~ *DELILAH/ALU/FIDBI_15_0[*]}] \
  -through [get_pins -hier -filter {NAME =~ *DELILAH/ALU/ALU_OUTMUX/OUTMUX_IDBS/IDBS_R*/F_15_0[*]}] \
  -through [get_pins -hier -filter {NAME =~ *DELILAH/ALU/FIDBO_15_0_OUT[*]}]

# ---------------------------------------------------------------------------
# Multicycle: MIC operand-address registers -> control-store address (30-AUG-2026).
#
# Full derivation with file:line evidence: docs/wcs-multicycle-analysis.md
# (written for the clk=45 attempt; summarised here).
#
# The build-10 (clk=45) worst path was
#   MIC/LAA_REG/gen_enable.q_r_reg[*] (+replicas)
#     -> WRF read -> ALU carry chain -> TRAP/TVGEN + BRKDET
#     -> IPOS trap-vector override of MA_12_0 -> ACAL (transparent on MACLK)
#     -> CS/WCS CHIP_* BRAM ADDRARDADDR      (27.986 ns, 36 levels)
#
# Why 2 cycles is safe (proof from PAL_44601B.v, PAL_44307C.v,
# CGA_MIC_IPOS.v, CGA_TRAP_BRKDET.v GATES_16, CPU_CS_ACAL_17.v):
#  - LAA_REG/LBA_REG capture ONLY on MCLK_EN, i.e. at the edge entering the
#    1-clk TERM pulse (or, in RWCS cycles, entering state a=0000).
#  - The WCS address can only take new data at posedges that close a
#    MACLK-high cycle. The only such capture 1 clk after an MCLK_EN launch
#    closes the TERM pulse (or RWCS state a).
#  - In BOTH those states the machine's own fences pin the IPOS mux away
#    from every route these registers can reach:
#      ETRAP_n = ~(TERM_n & VEX_n & (CC3|CC2|CC1|CC0)) = 1  ("UNSTABLE TRAP
#        IN THIS PERIOD CAN DESTROY MA !") -> TRAPN=1 -> TVEC deselected;
#      MAP_n = ~(FORM & BRK_n & CC2 & TERM_n) = 1 -> CD branch deselected,
#        BRK_n cannot move the selector;
#      the MAC's MCA latch (UUA/CSCA side) is opaque while MCLK is high.
#    The surviving W/WCA branches come from regREP/regIW/WCAREG - all
#    registered, all OUTSIDE the -from set below, all still single-cycle.
#  - Captures 2 clks after a launch are real (RWCS window, trap fence open
#    from state b), so the exception must be exactly 2, no more.
#
# Deliberately NOT relaxed (would corrupt the machine):
#  - anything from MIC/MASEL regREP/regW/regIW - the microcode-JUMP
#    same-cycle route; a 1-cycle lag there was the Tang o06000 boot hang;
#  - WRF register outputs - WRFSTB writes land in state b, 1 clk before an
#    open RWCS capture window with traps enabled: no masking proof.
#
# Style matches the ring cut above: bare commands, wildcard cell/pin
# patterns (placement replicas ..._replica_N and BRAM splitting stay
# covered), evaluated for real after synth_design. Expect [Vivado 12-508] /
# [Project 1-498] at the pre-synth read; what must NOT appear post-synth is
# [Vivado 12-4739] - that means a pattern was dropped and the family is
# single-cycle again. The -hold 1 lines return the hold check to the launch
# edge (the default relationship), so hold closure is unchanged.
set_multicycle_path 2 -setup \
  -from [get_cells -hier -filter {NAME =~ */DELILAH/MIC/LAA_REG/*q_r_reg* || NAME =~ */DELILAH/MIC/LBA_REG/*q_r_reg*}] \
  -to [get_pins -hier -filter {(NAME =~ */CPU/CS/WCS/CHIP_*/idt_memory_array_reg*/ADDR*) || (NAME =~ */CPU/CS/PROM/rom_lo_reg*/ADDR*) || (NAME =~ */CPU/CS/PROM/rom_hi_reg*/ADDR*)}]
set_multicycle_path 1 -hold \
  -from [get_cells -hier -filter {NAME =~ */DELILAH/MIC/LAA_REG/*q_r_reg* || NAME =~ */DELILAH/MIC/LBA_REG/*q_r_reg*}] \
  -to [get_pins -hier -filter {(NAME =~ */CPU/CS/WCS/CHIP_*/idt_memory_array_reg*/ADDR*) || (NAME =~ */CPU/CS/PROM/rom_lo_reg*/ADDR*) || (NAME =~ */CPU/CS/PROM/rom_hi_reg*/ADDR*)}]
# Same exception to the ACAL hold FFs on the CSA side - they capture on the
# same MACLK-window edges as the BRAM address pins and would otherwise
# become the new worst endpoints. The CSCA-fed r_uua_31g_hold is NOT
# included (different source route, no proof).
set_multicycle_path 2 -setup \
  -from [get_cells -hier -filter {NAME =~ */DELILAH/MIC/LAA_REG/*q_r_reg* || NAME =~ */DELILAH/MIC/LBA_REG/*q_r_reg*}] \
  -to [get_cells -hier -filter {NAME =~ */CPU/CS/ACAL/r_chip30h_hold_reg* || NAME =~ */CPU/CS/ACAL/r_lua_9_0_hold_reg* || NAME =~ */CPU/CS/ACAL/r_uua_32g_hold_reg*}]
set_multicycle_path 1 -hold \
  -from [get_cells -hier -filter {NAME =~ */DELILAH/MIC/LAA_REG/*q_r_reg* || NAME =~ */DELILAH/MIC/LBA_REG/*q_r_reg*}] \
  -to [get_cells -hier -filter {NAME =~ */CPU/CS/ACAL/r_chip30h_hold_reg* || NAME =~ */CPU/CS/ACAL/r_lua_9_0_hold_reg* || NAME =~ */CPU/CS/ACAL/r_uua_32g_hold_reg*}]
