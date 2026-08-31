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
