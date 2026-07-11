# Full-build pre-synth simulation for the Tang Nano 20K ND-120 port.
#
#   make test      compile + run nd120_tang20k_tb (boots the CPU, checks the
#                  OPCOM prompt and the examine/deposit echo sequence)
#   make clean
#
# Uses the SAME file list as the Gowin build (parsed out of
# ../nd120_tang20k.gprj) and the same defines as src/tang20k_defines.v,
# EXCEPT that the defines are passed on the command line so the UART can be
# sped up for simulation (16 clk_cpu per bit instead of real 9600 baud) -
# tang20k_defines.v itself is excluded from the compile.
#
# Run this BEFORE gowin_build.ps1 after any RTL change.

TOPDIR   = ..
TB       = nd120_tang20k_tb
VVP      = $(TB).vvp

# file list from the Gowin project (one source of truth), minus the
# defines file (replaced by -D below)
SRCS = $(shell grep -o '<File path="[^"]*"' $(TOPDIR)/nd120_tang20k.gprj \
        | sed 's/<File path="//;s/"//' | grep '\.v$$' \
        | grep -v tang20k_defines.v | sed 's|^|$(TOPDIR)/|')

# tang20k_defines.v equivalents + SIM (rPLL bypass) + fast sim UART:
# BOARD_CLK_FREQ/UART_BAUD_RATE = 6750000/421875 = 16 clk_cpu per bit,
# matching BITP in the testbench.
DEFS = -DGOWIN -DTARGET_TANG20K -DFPGA_FF_MODE -DSKIP_WCS_LOAD \
       -DMAIN_RAM_SDRAM -DND_SDRAM_PACK16 -DTANG_SLOW_BRINGUP \
       -DBOARD_CLK_FREQ=6750000 -DUART_BAUD_RATE=421875 -DSIM

test: $(VVP)
	cd $(TOPDIR) && vvp sim/$(VVP) | tee sim/$(TB).log
	@grep -q "TB_RESULT: PASS" $(TB).log

$(VVP): $(TB).v $(SRCS)
	iverilog -g2012 -o $(VVP) $(DEFS) \
	  $(TB).v ../sdram-test/sim/sdram_model.v ../lint/rpll_stub.v $(SRCS)

# Verilator timing-mode run of the SAME testbench (iverilog is far too slow
# to boot the CPU - seconds of sim time; Verilator --timing runs it in
# minutes). Same sources, same defines, same PASS criterion.
vtest: obj_dir/V$(TB)
	cd $(TOPDIR) && sim/obj_dir/V$(TB) | tee sim/$(TB)_verilator.log
	@grep -q "TB_RESULT: PASS" $(TB)_verilator.log

obj_dir/V$(TB): $(TB).v $(SRCS)
	verilator --binary --timing -j 4 -Wno-fatal --top-module $(TB) \
	  -CFLAGS "-std=gnu++20 -fcoroutines" \
	  $(DEFS) \
	  $(TB).v ../sdram-test/sim/sdram_model.v ../lint/rpll_stub.v $(SRCS)

clean:
	rm -f $(VVP) $(TB).log $(TB)_verilator.log
	rm -rf obj_dir

.PHONY: test vtest clean
