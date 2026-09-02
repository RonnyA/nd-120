# ND120_TANG20K_TOP timing constraints (Gowin)
# One rPLL: 27 MHz CPU/bus (clkoutd) + 54 MHz SDRAM pair (clkout/clkoutp).
# The PLL output clocks are related (same VCO); Gowin derives generated
# clocks from the rPLL automatically once the input clock is defined.

create_clock -name sys_clk -period 37.037 -waveform {0 18.518} [get_ports {sys_clk}]

# ---------------------------------------------------------------------------
# Storage-block clock-domain crossings (31-AUG-2026)
#
# nd_storage runs its card side on clk_stor (the 27 MHz sys_clk domain) and
# its client side on clk_cpu (the PLL's CLKOUTD). Those are unrelated in the
# design's own terms - every control signal between them goes through an
# nds_sync_pulse synchroniser (nds_sync.v). With only the create_clock line
# above, Gowin analysed the DATA buses between them as same-edge synchronous
# paths with a required time of 0.000 ns.
#
# MEASURED cost of that omission, fast20, same tree, sdc the only variable:
#   without these two lines : CPU-clock TNS -260.076 ns over 398 endpoints
#   with them              : CPU-clock TNS   -6.489 ns over  24 endpoints
# The reported CPU Fmax was largely a statement about an unconstrained
# crossing, not about how fast the CPU can run.
#
# Both buses are the standard safe formulation - data held stable for many
# cycles, sampled only when a SYNCHRONISED valid says it may be, so there is
# no edge relationship to meet:
#
#   size_bytes_stor -> u_engine r_size
#     nd_storage_engine.v: "size_bytes is stable long before open_ok rises
#     (mount rule)"; captured on the rising edge of c_open_ok_sync.
#
#   s_bridge_rd_data -> u_engine r_buf_wdata
#     nd_storage_engine.v: "stable one clk_stor before the flip" / "stable
#     while the flip crosses"; captured only when the synchronised
#     c_rd_have_pulse is high and c_grant_sync selects this client.
#
# Scoped deliberately to the two capture registers proven safe by reading
# the RTL. NOT a blanket set_clock_groups -asynchronous between the two
# domains: that would also excuse every crossing nobody has checked, and
# would hide a real fault the day someone adds one.
#
# Wider exception sets were tried and REJECTED on measurement: adding the
# synchroniser-input and LED-stretcher exceptions is equally correct as a
# description of the hardware, but excluding a path also removes the
# placer's reason to close it - on an identical tree that variant measured
# -35.352 ns over 90 endpoints, worse than the two lines below.
# ---------------------------------------------------------------------------
set_false_path -from [get_clocks {sys_clk}] -to [get_regs {*u_nd_storage/u_engine/*r_size*}]
set_false_path -from [get_clocks {sys_clk}] -to [get_regs {*u_nd_storage/u_engine/*r_buf_wdata*}]

# ---------------------------------------------------------------------------
# WCS -> ... -> CSCA -> ACAL CHIP_31G -> WCS address  (01-SEP-2026)
#
# The control store's own data output cannot reach its own address input
# through the MAC in one cycle. Two TRANSPARENT LATCHES sit on that route
# and their enable windows are strictly complementary:
#
#   CHIP_31G  (CPU_CS_ACAL_17.v:174-175) enable = CLK && !lua12
#             CLK = ~TERM_n            (CYC_36.v:293)
#             -> transparent only while TERM is asserted
#
#   L_HI      (CGA_MAC_APOS_CALCA.v:264) enable = ~MCLK
#             MCLK = ~(TERM_n & MCLK_n) (CYC_36.v:268)
#             MCLK_n carries ONLY RWCS product terms (PAL_44307C.v:85-88),
#             so TERM_n = 0 forces MCLK = 1 unconditionally
#             -> transparent only while MCLK is LOW
#
# CHIP_31G open => TERM high => MCLK high => L_HI closed. The two are never
# open together, so a value launched combinationally from the WCS/ALU/MAC
# can never cross both in one cycle. What 31G samples is always the value
# L_HI captured in an earlier phase. Gowin sees the path only because a
# transparent latch is modelled as a mux (L ? D : reg) and static analysis
# cannot see phase exclusivity.
#
# The original machine also gave this cone a WHOLE MICROCYCLE - minimum
# 50 ns, typically 75-100 ns (cycle_clock.md:526-538) - not one clock.
#
# SCOPED BY LAUNCH POINT, deliberately. `-through [get_nets {*s_csca*}]`
# alone would be WRONG: the path L_HI's register -> s_csca -> 31G -> WCS
# address IS real and must stay timed. Only the leg launched by the WCS
# BSRAM in the same cycle is impossible, so the exception names that launch.
#
# NOT relaxed here, both deliberately:
#   - MIC/MASEL regREP/regW/regIW -> CSA -> LUA -> WCS. The microcode JUMP
#     route, genuinely single-cycle; a 1-cycle lag there was the Tang
#     o06000 boot hang (CPU_CS_ACAL_17.v:55-59, commit d076580).
#   - WRF -> ALU -> TVGEN -> ACAL -> WCS. WRFSTB fires in state b, so no
#     masking proof exists (see nexys4ddr/nd120_timing.xdc:108-113).
#
# This is the leg nexys4ddr/nd120_timing.xdc:120-123 left out for lack of
# proof ("the CSCA-fed r_uua_31g_hold is NOT included ... no proof"). The
# proof is the PAL equations cited above.
#
# STILL UNVERIFIED: the RWCS case is inferred from MCLK_n's product terms,
# not simulated. TERM high forces MCLK high there too, so the exclusivity
# appears to hold, but no simulation has confirmed it.
# ---------------------------------------------------------------------------
set_false_path -from [get_regs {*CS/WCS/CHIP_*}] -through [get_pins {*CALCA/L_HI/s_csca_9_0_*_s/F}]
