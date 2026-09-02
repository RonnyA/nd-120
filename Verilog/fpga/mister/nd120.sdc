derive_pll_clocks
derive_clock_uncertainty

# core specific constraints

# ---------------------------------------------------------------------------
# The CPU clock, 20 MHz, generated in nd120.sv as a divide-by-2 toggle flop
# off clk_sys (the 40 MHz pixel clock).
#
# WITHOUT this, TimeQuest does not know clk_cpu_div is a clock at all: it
# analyses the core's registers against the 40 MHz source instead, and reports
# a timing failure the hardware does not actually have (or, worse, hides a
# real one). derive_pll_clocks only covers the PLL outputs themselves, not a
# clock made in fabric from one.
#
# Added 31-AUG-2026, when the CPU was measured missing timing at 40 MHz
# (Fmax 36.91 MHz) and moved to 20 MHz.
# ---------------------------------------------------------------------------
# NOTE (31-AUG-2026): clk_cpu is now a REAL PLL OUTPUT (rtl/pll_cpu.v), not a
# fabric divide-by-2, so derive_pll_clocks above already constrains it and no
# create_generated_clock is needed. The old divider put the CPU clock on
# ordinary routing ("Non-Global High Fan-Out Signals" in the fitter report),
# which simulation cannot see and TimeQuest did not object to.

# The console link between the two domains is an asynchronous SERIAL line
# (the CPU's TXD/RXD against the terminal's deserialiser), not a synchronous
# bus - so there is no real path to time between clk_cpu and clk_sys. Telling
# TimeQuest that keeps it from spending effort, and reporting failures, on
# transfers that are asynchronous by design.
# FPGA_CLK2_50 is the framework's HPS-side clock (sys_top: the mcp23009 LED
# expander driver, button timeouts, SPI). Build v50 (02-SEP-2026) reported a
# -1.9 ns setup miss on it, and the failing path was the CPU's own status-lamp
# register (IO_REG_41 TTL_74273 Q[5:4], clk_cpu) into mcp23009|din - i.e. the
# two CPU lamps on LED_DISK/LED_POWER, which the framework serialises out over
# I2C at leisure. That is not a synchronous transfer, and no other signal of
# the core reaches that clock. Declared asynchronous, same as the other two.
set_clock_groups -asynchronous \
    -group [get_clocks {emu|PLL_CPU|altera_pll_i|*divclk}] \
    -group [get_clocks {emu|pll|pll_inst|altera_pll_i|*divclk}] \
    -group [get_clocks {FPGA_CLK2_50}]
