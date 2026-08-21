###############################################################################
# Shared/ndlib unit tests (iverilog)
#
# The ndlib parts are the small ND gate-array cells: 2/3/4/8-way multiplexers,
# the two 3-to-8 decoders, and the RMUX gate cluster. Every one of them has a
# small enough input space to be tested EXHAUSTIVELY, so each testbench sweeps
# its ENTIRE input space against a reference model - there is no sampling and
# no argument about whether the corner cases were hit.
#
# Each testbench prints "TB_RESULT: PASS" or "TB_RESULT: FAIL" and every recipe
# greps for PASS, so a silent failure cannot be mistaken for a pass. The .vcd
# each one writes is a SHORT documentation window (the exhaustive sweep runs
# with $dumpoff), kept as the committed timing diagram for the cell.
#
# Run:  make test-all            (every cell)
#       make test-mux21l  ...    (one cell)
#       make clean
###############################################################################

IVERILOG = iverilog
VVP      = vvp

NDLIB   = ..
LOGISIM = ../../logisim

# The ndlib cells are built from logisim primitives (Multiplexer_2/4/8,
# Decoder_8, AND_GATE, NOR_GATE ...). -y lets iverilog pull each one from the
# library directory by module name, so only the testbench is named explicitly.
LIBS = -y $(NDLIB) -y $(LOGISIM)

TBS = MUX21L MUX21LP MUX24P MUX31LP MUX34P MUX41P MUX81 ND38GHP ND38GLP RMUX_Gates

.PHONY: test-all clean \
        test-mux21l test-mux21lp test-mux24p test-mux31lp test-mux34p \
        test-mux41p test-mux81 test-nd38ghp test-nd38glp test-rmuxgates

test-all: test-mux21l test-mux21lp test-mux24p test-mux31lp test-mux34p \
          test-mux41p test-mux81 test-nd38ghp test-nd38glp test-rmuxgates
	@echo "ndlib: all cells PASS"

# Generic build rule: <Cell>_tb from <Cell>_tb.v plus the library search path.
%_tb: %_tb.v
	$(IVERILOG) -g2012 -o $@ $< $(LIBS)

define RUN_TB
	$(VVP) $(1) | tee $(1)_result.tmp
	@grep -q "TB_RESULT: PASS" $(1)_result.tmp && rm -f $(1)_result.tmp
endef

# 2-to-1 mux, NEGATED output (ZN = ~sel_result). All 8 combinations.
test-mux21l: MUX21L_tb
	$(call RUN_TB,MUX21L_tb)

# Same function as MUX21L by a different route - the tb checks that claim.
test-mux21lp: MUX21LP_tb
	$(call RUN_TB,MUX21LP_tb)

# Four independent 2-to-1 slices on one select. All 512 combinations.
test-mux24p: MUX24P_tb
	$(call RUN_TB,MUX24P_tb)

# 3-input mux on a 4-input primitive: D2 is wired to BOTH inputs 2 and 3, so
# select 3 must return the same as select 2. All 32 combinations.
test-mux31lp: MUX31LP_tb
	$(call RUN_TB,MUX31LP_tb)

# Four 3-input slices, same D2-tied-to-input-3 rule, plus slice independence.
# All 16,384 combinations.
test-mux34p: MUX34P_tb
	$(call RUN_TB,MUX34P_tb)

# 4-to-1 mux, sel = {B,A} with A as the LOW bit. All 64 combinations.
test-mux41p: MUX41P_tb
	$(call RUN_TB,MUX41P_tb)

# 8-to-1 mux, sel = {C,B,A}. All 2048 combinations.
test-mux81: MUX81_tb
	$(call RUN_TB,MUX81_tb)

# 3-to-8 decoder, GN active LOW enable, ACTIVE HIGH one-hot outputs.
# All 16 combinations. Disabled state here is all-ZERO.
test-nd38ghp: ND38GHP_tb
	$(call RUN_TB,ND38GHP_tb)

# 3-to-8 decoder, G active HIGH enable, ACTIVE LOW outputs. Same Decoder_8
# underneath, but the disabled state is all-ONE - the opposite of ND38GHP.
test-nd38glp: ND38GLP_tb
	$(call RUN_TB,ND38GLP_tb)

# The RMUX gate cluster: RN = NOT((A AND RA) OR (D AND RD)). All 16 combos.
test-rmuxgates: RMUX_Gates_tb
	$(call RUN_TB,RMUX_Gates_tb)

clean:
	rm -f $(addsuffix _tb,$(TBS)) *.vcd *_result.tmp

###############################################################################
# SEQUENTIAL CELLS - flip-flops, latches, scan cells, registers, counters.
###############################################################################
# Shared/ndlib unit tests (iverilog)
#
# Sequential cells (flip-flops, latches, scan cells, registers, counters)
# plus the two combinational odds and ends that live in the same library.
#
# BUILD MODES
#   Only LATCH.v, L4.v and L8.v change behaviour with a `ifdef, and the
#   switch is USE_TRANSPARENT_LATCHES - NOT FPGA_FF_MODE. Their targets
#   run BOTH branches. Everything else is mode-independent and is run
#   twice, plain and -DFPGA_FF_MODE, to prove it.
#
# Run:  make test-seqcells-all
#       make clean-seqcells

IVERILOG = iverilog
VVP      = vvp
IVFLAGS  = -g2005
NDLIB    = ..
LOGISIM  = ../../logisim
DGACIRC  = ../../../DECODE-GateArray/DGA/circuit
LIBDIRS  = -y $(NDLIB) -y $(LOGISIM)

.PHONY: test-seqcells-all clean-seqcells \
        test-latch test-l4 test-a02 test-bd4tu \
        test-r41p test-r81p test-sr44 test-m169c \
        test-scanrst test-scanset \
        test-dffen test-jkffen test-scanffen \
        test-scanrsten test-scanseten \
        test-r41pen test-r81en test-sr44en test-m169cen test-f924en

test-seqcells-all: test-latch test-l4 test-a02 test-bd4tu \
          test-r41p test-r81p test-sr44 test-m169c \
          test-scanrst test-scanset \
          test-dffen test-jkffen test-scanffen \
          test-scanrsten test-scanseten \
          test-r41pen test-r81en test-sr44en test-m169cen test-f924en
	@echo "all Shared/ndlib sequential-cell testbenches passed"

# ---------------------------------------------------------------------------
# run_one <target-stem> <tb file> <extra sources> <defines>
# Expanded by hand below so each target reads plainly in the log.
# ---------------------------------------------------------------------------

# --- LATCH: the ONE-BIT transparent latch. Runs three ways. The default
#     and FPGA_FF_MODE builds must agree; USE_TRANSPARENT_LATCHES is the
#     genuinely different circuit and has its own expected values.
test-latch:
	$(IVERILOG) $(IVFLAGS) -o LATCH_tb.vvp LATCH_tb.v $(NDLIB)/LATCH.v
	$(VVP) LATCH_tb.vvp | tee latch.tmp
	@grep -q "TB_RESULT: PASS" latch.tmp
	$(IVERILOG) $(IVFLAGS) -DFPGA_FF_MODE -o LATCH_tb_ff.vvp LATCH_tb.v $(NDLIB)/LATCH.v
	$(VVP) LATCH_tb_ff.vvp | tee latch_ff.tmp
	@grep -q "TB_RESULT: PASS" latch_ff.tmp
	$(IVERILOG) $(IVFLAGS) -DUSE_TRANSPARENT_LATCHES -o LATCH_tb_tl.vvp LATCH_tb.v $(NDLIB)/LATCH.v
	$(VVP) LATCH_tb_tl.vvp | tee latch_tl.tmp
	@grep -q "TB_RESULT: PASS" latch_tl.tmp && rm -f latch.tmp latch_ff.tmp latch_tl.tmp

# --- L4: the FOUR-BIT transparent latch, same three builds.
test-l4:
	$(IVERILOG) $(IVFLAGS) -o L4_tb.vvp L4_tb.v $(NDLIB)/L4.v
	$(VVP) L4_tb.vvp | tee l4.tmp
	@grep -q "TB_RESULT: PASS" l4.tmp
	$(IVERILOG) $(IVFLAGS) -DFPGA_FF_MODE -o L4_tb_ff.vvp L4_tb.v $(NDLIB)/L4.v
	$(VVP) L4_tb_ff.vvp | tee l4_ff.tmp
	@grep -q "TB_RESULT: PASS" l4_ff.tmp
	$(IVERILOG) $(IVFLAGS) -DUSE_TRANSPARENT_LATCHES -o L4_tb_tl.vvp L4_tb.v $(NDLIB)/L4.v
	$(VVP) L4_tb_tl.vvp | tee l4_tl.tmp
	@grep -q "TB_RESULT: PASS" l4_tl.tmp && rm -f l4.tmp l4_ff.tmp l4_tl.tmp

# --- A02: AND-OR-INVERT, exhaustive (all 16 inputs).
test-a02:
	$(IVERILOG) $(IVFLAGS) -o A02_tb.vvp A02_tb.v $(NDLIB)/A02.v
	$(VVP) A02_tb.vvp | tee a02.tmp
	@grep -q "TB_RESULT: PASS" a02.tmp && rm -f a02.tmp

# --- BD4TU: bidirectional buffer. Its read path is DEAD (ZI_REG is never
#     assigned); the tb asserts the behaviour as it stands today.
test-bd4tu:
	$(IVERILOG) $(IVFLAGS) -o BD4TU_tb.vvp BD4TU_tb.v $(NDLIB)/BD4TU.v
	$(VVP) BD4TU_tb.vvp | tee bd4tu.tmp
	@grep -q "TB_RESULT: PASS" bd4tu.tmp && rm -f bd4tu.tmp

test-r41p:
	$(IVERILOG) $(IVFLAGS) -o R41P_tb.vvp R41P_tb.v $(NDLIB)/R41P.v
	$(VVP) R41P_tb.vvp | tee r41p.tmp
	@grep -q "TB_RESULT: PASS" r41p.tmp && rm -f r41p.tmp

test-r81p:
	$(IVERILOG) $(IVFLAGS) -o R81P_tb.vvp R81P_tb.v $(NDLIB)/R81P.v
	$(VVP) R81P_tb.vvp | tee r81p.tmp
	@grep -q "TB_RESULT: PASS" r81p.tmp && rm -f r81p.tmp

# --- SR44: 4-bit load/shift register. The serial walk pins the direction.
test-sr44:
	$(IVERILOG) $(IVFLAGS) -o SR44_tb.vvp SR44_tb.v $(LIBDIRS)
	$(VVP) SR44_tb.vvp | tee sr44.tmp
	@grep -q "TB_RESULT: PASS" sr44.tmp && rm -f sr44.tmp

# --- M169C: gate-level 74LS169, checked edge by edge against a datasheet
#     reference model.
test-m169c:
	$(IVERILOG) $(IVFLAGS) -o M169C_tb.vvp M169C_tb.v $(LIBDIRS)
	$(VVP) M169C_tb.vvp | tee m169c.tmp
	@grep -q "TB_RESULT: PASS" m169c.tmp && rm -f m169c.tmp

# --- SCAN_WITH_RESET_N: asserts that R_n does NOTHING (documented anomaly).
test-scanrst:
	$(IVERILOG) $(IVFLAGS) -o SCAN_WITH_RESET_N_tb.vvp SCAN_WITH_RESET_N_tb.v $(LIBDIRS)
	$(VVP) SCAN_WITH_RESET_N_tb.vvp | tee scanrst.tmp
	@grep -q "TB_RESULT: PASS" scanrst.tmp && rm -f scanrst.tmp

# --- SCAN_WITH_SET_N: the variant whose async S_n really works.
test-scanset:
	$(IVERILOG) $(IVFLAGS) -o SCAN_WITH_SET_N_tb.vvp SCAN_WITH_SET_N_tb.v $(LIBDIRS)
	$(VVP) SCAN_WITH_SET_N_tb.vvp | tee scanset.tmp
	@grep -q "TB_RESULT: PASS" scanset.tmp && rm -f scanset.tmp

# --- the P2/P3 clock-enable wrappers, each tested in every mode it has.
test-dffen:
	$(IVERILOG) $(IVFLAGS) -o D_FLIPFLOP_EN_tb.vvp D_FLIPFLOP_EN_tb.v $(LIBDIRS)
	$(VVP) D_FLIPFLOP_EN_tb.vvp | tee dffen.tmp
	@grep -q "TB_RESULT: PASS" dffen.tmp && rm -f dffen.tmp

test-jkffen:
	$(IVERILOG) $(IVFLAGS) -o J_K_FLIPFLOP_EN_tb.vvp J_K_FLIPFLOP_EN_tb.v $(LIBDIRS)
	$(VVP) J_K_FLIPFLOP_EN_tb.vvp | tee jkffen.tmp
	@grep -q "TB_RESULT: PASS" jkffen.tmp && rm -f jkffen.tmp

test-scanffen:
	$(IVERILOG) $(IVFLAGS) -o SCAN_FF_EN_tb.vvp SCAN_FF_EN_tb.v $(LIBDIRS)
	$(VVP) SCAN_FF_EN_tb.vvp | tee scanffen.tmp
	@grep -q "TB_RESULT: PASS" scanffen.tmp && rm -f scanffen.tmp

test-scanrsten:
	$(IVERILOG) $(IVFLAGS) -o SCAN_WITH_RESET_N_EN_tb.vvp SCAN_WITH_RESET_N_EN_tb.v $(LIBDIRS)
	$(VVP) SCAN_WITH_RESET_N_EN_tb.vvp | tee scanrsten.tmp
	@grep -q "TB_RESULT: PASS" scanrsten.tmp && rm -f scanrsten.tmp

test-scanseten:
	$(IVERILOG) $(IVFLAGS) -o SCAN_WITH_SET_N_EN_tb.vvp SCAN_WITH_SET_N_EN_tb.v $(LIBDIRS)
	$(VVP) SCAN_WITH_SET_N_EN_tb.vvp | tee scanseten.tmp
	@grep -q "TB_RESULT: PASS" scanseten.tmp && rm -f scanseten.tmp

test-r41pen:
	$(IVERILOG) $(IVFLAGS) -o R41P_EN_tb.vvp R41P_EN_tb.v $(LIBDIRS)
	$(VVP) R41P_EN_tb.vvp | tee r41pen.tmp
	@grep -q "TB_RESULT: PASS" r41pen.tmp && rm -f r41pen.tmp

test-r81en:
	$(IVERILOG) $(IVFLAGS) -o R81_EN_tb.vvp R81_EN_tb.v $(LIBDIRS)
	$(VVP) R81_EN_tb.vvp | tee r81en.tmp
	@grep -q "TB_RESULT: PASS" r81en.tmp && rm -f r81en.tmp

test-sr44en:
	$(IVERILOG) $(IVFLAGS) -o SR44_EN_tb.vvp SR44_EN_tb.v $(LIBDIRS)
	$(VVP) SR44_EN_tb.vvp | tee sr44en.tmp
	@grep -q "TB_RESULT: PASS" sr44en.tmp && rm -f sr44en.tmp

test-m169cen:
	$(IVERILOG) $(IVFLAGS) -o M169C_EN_tb.vvp M169C_EN_tb.v $(LIBDIRS)
	$(VVP) M169C_EN_tb.vvp | tee m169cen.tmp
	@grep -q "TB_RESULT: PASS" m169cen.tmp && rm -f m169cen.tmp

# F924 lives in the DGA, not in ndlib, so it is named explicitly.
test-f924en:
	$(IVERILOG) $(IVFLAGS) -o F924_EN_tb.vvp F924_EN_tb.v $(DGACIRC)/F924.v $(LIBDIRS)
	$(VVP) F924_EN_tb.vvp | tee f924en.tmp
	@grep -q "TB_RESULT: PASS" f924en.tmp && rm -f f924en.tmp

clean-seqcells:
	rm -f *.vvp *.tmp *.vcd
