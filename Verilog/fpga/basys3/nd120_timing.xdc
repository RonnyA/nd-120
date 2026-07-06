# ND-120 FPGA timing constraints
# Added to the Vivado project by vivado_build.tcl (constrs_1 fileset), processed
# AFTER the project's pin/clock XDC so the primary clock 'sys_clk' already exists.
#
# Clock architecture (see ND120_TOP.v, 2026-07-06):
#   sys_clk  = 100 MHz Basys3 pin. Clocks ONLY the POR, 7-seg display, heartbeat
#              counter, and the ILA / debug hub.
#   clk_cpu  = MMCM CLKOUT0 (~16.67 MHz). Clocks the ENTIRE ND-120 CPU + bus core
#              (also feeds CLOCK_1/CLOCK_2 / the OSC inputs).
#
# The only paths that cross between these two domains are:
#   - CPU state -> ILA probes and 7-seg (pure observation)
#   - POR sys_rst_n -> CPU (reset; async-assert, held 256 cycles)
# None are functional synchronous datapaths, so the two domains are asynchronous
# for timing. Without this, the CPU's deep (~49 ns) paths get timed against the
# 100 MHz ILA capture clock and fail. (Reset-release synchronization into clk_cpu
# is a future robustness item.)

set_clock_groups -asynchronous \
  -group [get_clocks sys_clk] \
  -group [get_clocks -of_objects [get_pins mmcm_cpu_clk/CLKOUT0]]
