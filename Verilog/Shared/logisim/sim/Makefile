###############################################################################
# Shared/logisim unit tests (iverilog)
#
# The logisim primitives are the leaf cells that everything else in the tree is
# built out of - the ndlib multiplexers, the decoders, the PAL wrappers. A
# silent break in one of these would be visible everywhere and obvious nowhere,
# so each is tested EXHAUSTIVELY over its whole input space against a reference
# model.
#
# Each testbench prints "TB_RESULT: PASS" or "TB_RESULT: FAIL" and every recipe
# greps for PASS, so a silent failure cannot be mistaken for a pass. The .vcd
# each one writes is a SHORT documentation window (the exhaustive sweep runs
# with $dumpoff).
#
# Run:  make test-all         (every primitive)
#       make test-mux2  ...   (one primitive)
#       make clean
###############################################################################

IVERILOG = iverilog
VVP      = vvp

LOGISIM = ..

TBS = Multiplexer_2 Multiplexer_2_w_enable Multiplexer_4 Multiplexer_8 Multiplexer_bus_2

.PHONY: test-all clean test-mux2 test-mux2en test-mux4 test-mux8 test-muxbus2

test-all: test-mux2 test-mux2en test-mux4 test-mux8 test-muxbus2
	@echo "logisim: all primitives PASS"

%_tb: %_tb.v $(LOGISIM)/%.v
	$(IVERILOG) -g2012 -o $@ $^

define RUN_TB
	$(VVP) $(1) | tee $(1)_result.tmp
	@grep -q "TB_RESULT: PASS" $(1)_result.tmp && rm -f $(1)_result.tmp
endef

# Plain 2-to-1 mux. All 8 combinations.
test-mux2: Multiplexer_2_tb
	$(call RUN_TB,Multiplexer_2_tb)

# 2-to-1 mux with an enable; disabled drives 0, not z (the repo-wide rule -
# inside the FPGA these outputs are OR-ed together). All 16 combinations.
test-mux2en: Multiplexer_2_w_enable_tb
	$(call RUN_TB,Multiplexer_2_w_enable_tb)

# 4-to-1 mux. All 64 combinations.
test-mux4: Multiplexer_4_tb
	$(call RUN_TB,Multiplexer_4_tb)

# 8-to-1 mux. All 2048 combinations.
test-mux8: Multiplexer_8_tb
	$(call RUN_TB,Multiplexer_8_tb)

# Parameterised bus-wide 2-to-1 mux: exhaustive at nrOfBits=1 (8) and
# nrOfBits=4 (512), directed patterns at nrOfBits=8 (17 bits is too wide).
test-muxbus2: Multiplexer_bus_2_tb
	$(call RUN_TB,Multiplexer_bus_2_tb)

clean:
	rm -f $(addsuffix _tb,$(TBS)) *.vcd *_result.tmp

###############################################################################
# SEQUENTIAL CELLS - flip-flops, latches, scan cells, registers, counters.
###############################################################################
# Shared/logisim unit tests (iverilog)
#
# Sequential primitives: D_FLIPFLOP, D_FLIPFLOP_SIMPLE, J_K_FLIPFLOP,
# T_FLIPFLOP. None of these read `FPGA_FF_MODE, so every target is built
# and run TWICE - plain and -DFPGA_FF_MODE - and both builds must pass.
#
# Run:  make test-dff | test-dffsimple | test-jkff | test-tff | test-seqcells-all
#       make clean-seqcells

IVERILOG = iverilog
VVP      = vvp
IVFLAGS  = -g2005
LOGISIM  = ..
NDLIB    = ../../ndlib

.PHONY: test-seqcells-all test-dff test-dffsimple test-jkff test-tff clean-seqcells

test-seqcells-all: test-dff test-dffsimple test-jkff test-tff
	@echo "all Shared/logisim sequential-cell testbenches passed"

# --- D_FLIPFLOP: parameter matrix (clock polarity, ACTIVE_ASYNC), dead
#     preset/reset pins with the default parameters, and preset+reset
#     asserted in the same instant (preset wins).
test-dff:
	$(IVERILOG) $(IVFLAGS) -o D_FLIPFLOP_tb.vvp D_FLIPFLOP_tb.v $(LOGISIM)/D_FLIPFLOP.v
	$(VVP) D_FLIPFLOP_tb.vvp | tee dff.tmp
	@grep -q "TB_RESULT: PASS" dff.tmp
	$(IVERILOG) $(IVFLAGS) -DFPGA_FF_MODE -o D_FLIPFLOP_tb_ff.vvp D_FLIPFLOP_tb.v $(LOGISIM)/D_FLIPFLOP.v
	$(VVP) D_FLIPFLOP_tb_ff.vvp | tee dff_ff.tmp
	@grep -q "TB_RESULT: PASS" dff_ff.tmp && rm -f dff.tmp dff_ff.tmp

test-dffsimple:
	$(IVERILOG) $(IVFLAGS) -o D_FLIPFLOP_SIMPLE_tb.vvp D_FLIPFLOP_SIMPLE_tb.v $(LOGISIM)/D_FLIPFLOP_SIMPLE.v
	$(VVP) D_FLIPFLOP_SIMPLE_tb.vvp | tee dffs.tmp
	@grep -q "TB_RESULT: PASS" dffs.tmp
	$(IVERILOG) $(IVFLAGS) -DFPGA_FF_MODE -o D_FLIPFLOP_SIMPLE_tb_ff.vvp D_FLIPFLOP_SIMPLE_tb.v $(LOGISIM)/D_FLIPFLOP_SIMPLE.v
	$(VVP) D_FLIPFLOP_SIMPLE_tb_ff.vvp | tee dffs_ff.tmp
	@grep -q "TB_RESULT: PASS" dffs_ff.tmp && rm -f dffs.tmp dffs_ff.tmp

# --- J_K_FLIPFLOP: synchronous preset/reset, PRESET wins the conflict.
test-jkff:
	$(IVERILOG) $(IVFLAGS) -o J_K_FLIPFLOP_tb.vvp J_K_FLIPFLOP_tb.v $(LOGISIM)/J_K_FLIPFLOP.v
	$(VVP) J_K_FLIPFLOP_tb.vvp | tee jk.tmp
	@grep -q "TB_RESULT: PASS" jk.tmp
	$(IVERILOG) $(IVFLAGS) -DFPGA_FF_MODE -o J_K_FLIPFLOP_tb_ff.vvp J_K_FLIPFLOP_tb.v $(LOGISIM)/J_K_FLIPFLOP.v
	$(VVP) J_K_FLIPFLOP_tb_ff.vvp | tee jk_ff.tmp
	@grep -q "TB_RESULT: PASS" jk_ff.tmp && rm -f jk.tmp jk_ff.tmp

# --- T_FLIPFLOP: synchronous preset/reset, RESET wins the conflict -
#     the OPPOSITE of J_K_FLIPFLOP sitting next to it.
test-tff:
	$(IVERILOG) $(IVFLAGS) -o T_FLIPFLOP_tb.vvp T_FLIPFLOP_tb.v $(LOGISIM)/T_FLIPFLOP.v
	$(VVP) T_FLIPFLOP_tb.vvp | tee tff.tmp
	@grep -q "TB_RESULT: PASS" tff.tmp
	$(IVERILOG) $(IVFLAGS) -DFPGA_FF_MODE -o T_FLIPFLOP_tb_ff.vvp T_FLIPFLOP_tb.v $(LOGISIM)/T_FLIPFLOP.v
	$(VVP) T_FLIPFLOP_tb_ff.vvp | tee tff_ff.tmp
	@grep -q "TB_RESULT: PASS" tff_ff.tmp && rm -f tff.tmp tff_ff.tmp

clean-seqcells:
	rm -f *.vvp *.tmp *.vcd
