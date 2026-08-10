# UPDATE NEXT 3 LINES PR TEST PROGRAM
TOP_FILE = DECODE_DGA
TEST_PROGRAM = test_dga.cpp
TEST_FOLDER = DGA

#SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED #-Wno-UNDRIVEN -Wno-WIDTH
SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH


# This is the path to the root of the verilog directory
VERILOG_ROOT = ../../..

SHARED_COMPONENTS = -I${VERILOG_ROOT}/shared/ndlib --I${VERILOG_ROOT}/shared/logisim --I${VERILOG_ROOT}/shared/support

DGA_ROOT = ${VERILOG_ROOT}/DECODE-GateArray
COMPONENT_ROOT = ${DGA_ROOT}/${TEST_FOLDER}/circuit

#VERILATOR_FLAGS = --trace -Wall --cc ../circuit/DECODE_DGA.v --exe test_dga.cpp $(SUPPRESS_FLAGS)  
VERILATOR_FLAGS = --trace -Wall --cc ${COMPONENT_ROOT}/${TOP_FILE}.v --exe ${TEST_PROGRAM} $(SUPPRESS_FLAGS)  

DGA_COMPONENTS = -I${DGA_ROOT}
VERILATOR_DIRS = -I$(COMPONENT_ROOT) ${SHARED_COMPONENTS} $(DGA_COMPONENTS)

# Specify C++ source files here
CPP_SOURCES = ${TEST_PROGRAM}

VERILATOR = verilator
# Default target
all: test_dga run gtk

test_dga: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VDECODE_DGA.mk V$(TOP_FILE)

clean:
	rm -rf obj_dir

run: test_dga
	./obj_dir/VDECODE_DGA

gtk: run
	gtkwave waveform.vcd dga.gtkw &

.PHONY: all clean

# iverilog testbench for F595
IVERILOG = iverilog
VERILOG_ROOT = ../../..

F595_tb: F595_tb.v $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F595.v
	$(IVERILOG) -g2012 -I$(VERILOG_ROOT)/Shared/logisim -I$(VERILOG_ROOT)/Shared/ndlib -I$(VERILOG_ROOT)/Shared/support -o $@ $^

test-f595: F595_tb
	./F595_tb

# Transparency regression (Tang boot-hang class): F595 FPGA branch must be a
# zero-latency transparent latch, not a lagging FF. Compiled without
# VERILATOR_SIM so it exercises the FPGA (else) branch. FAILS on the old lagging
# FF, PASSES on the transparent-latch fix.
F595_transparency_tb: F595_transparency_tb.v $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F595.v
	$(IVERILOG) -g2012 -I$(VERILOG_ROOT)/Shared/logisim -I$(VERILOG_ROOT)/Shared/ndlib -I$(VERILOG_ROOT)/Shared/support -o $@ $^

test-f595-transparency: F595_transparency_tb
	./F595_transparency_tb | tee f595tr_result.tmp
	@grep -q "TB_RESULT: PASS" f595tr_result.tmp && rm -f f595tr_result.tmp

.PHONY: test-f595 test-f595-transparency

# Small pure-comb DGA standard cells (F091 level gen, F103 inverter,
# F571 2:1 mux w/ active-low enable) - exhaustive golden-table sweeps in
# one tb. No build-mode ifdefs in these cells; one build covers all paths.
FCELLS_SRCS = DGA_FCELLS_tb.v \
              $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F091.v \
              $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F103.v \
              $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F571.v \
              $(VERILOG_ROOT)/Shared/logisim/Multiplexer_2_w_enable.v

DGA_FCELLS_tb: $(FCELLS_SRCS)
	$(IVERILOG) -g2012 -o $@ $(FCELLS_SRCS)

test-fcells: DGA_FCELLS_tb
	./DGA_FCELLS_tb | tee fcells_result.tmp
	@grep -q "TB_RESULT: PASS" fcells_result.tmp && rm -f fcells_result.tmp

# F617 D-FF with async RB/SB: directed load/hold/set/reset/priority tests
# plus a 3000-step fixed-seed LFSR soak checked against checksums from an
# independent Python event model. Covers BOTH ACTIVE_ASYNC parameter
# values (0 = set-only repo default, 1 = dual async) in one binary; F617
# has no VERILATOR_SIM/FPGA_FF_MODE ifdefs, the parameter is its only
# behavior switch.
F617_SRCS = F617_tb.v $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F617.v

F617_tb: $(F617_SRCS)
	$(IVERILOG) -g2012 -o $@ $(F617_SRCS)

test-f617: F617_tb
	./F617_tb | tee f617_result.tmp
	@grep -q "TB_RESULT: PASS" f617_result.tmp && rm -f f617_result.tmp

.PHONY: test-fcells test-f617

# F714 T-FF with async R/S: directed truth-table walk incl. the RTL
# reset-priority behavior on the R=S=1 prohibition row (see tb header).
F714_SRCS = F714_tb.v $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F714.v

F714_tb: $(F714_SRCS)
	$(IVERILOG) -g2012 -o $@ $(F714_SRCS)

test-f714: F714_tb
	./F714_tb | tee f714_result.tmp
	@grep -q "TB_RESULT: PASS" f714_result.tmp && rm -f f714_result.tmp

.PHONY: test-f714

# DECODE_DGA_IDBS - IDB source enable decoder + panel PRQ/VAL handshake.
# Sequential (4x F924 on CLK0/CLK1): built+run in BOTH modes - default
# posedge-CLK capture and -DFPGA_FF_MODE (sysclk+CLK_EN capture). No
# latch primitives, so USE_TRANSPARENT_LATCHES does not apply. Exhaustive
# decode sweep + directed panel-FSM walk + clock-group routing (default
# build) + 4000-step fixed-seed soak vs an independent behavioral model.
IDBS_SRCS = $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/DECODE_DGA_IDBS.v \
            $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F924.v \
            $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F091.v \
            $(VERILOG_ROOT)/Shared/ndlib/F924_EN.v \
            $(VERILOG_ROOT)/Shared/ndlib/D_FLIPFLOP_EN.v \
            $(VERILOG_ROOT)/Shared/logisim/D_FLIPFLOP.v

test-dga-idbs:
	$(IVERILOG) -g2012 -o DECODE_DGA_IDBS_tb DECODE_DGA_IDBS_tb.v $(IDBS_SRCS)
	./DECODE_DGA_IDBS_tb | tee idbs_result.tmp
	@grep -q "TB_RESULT: PASS" idbs_result.tmp && rm -f idbs_result.tmp
	$(IVERILOG) -g2012 -DFPGA_FF_MODE -o DECODE_DGA_IDBS_tb_ff DECODE_DGA_IDBS_tb.v $(IDBS_SRCS)
	./DECODE_DGA_IDBS_tb_ff | tee idbs_result.tmp
	@grep -q "TB_RESULT: PASS" idbs_result.tmp && rm -f idbs_result.tmp

.PHONY: test-dga-idbs

# DECODE_DGA_POW - power-up/master-clear/RTC/bus-timeout sheet. Sequential
# (F595 RS latches, A572 capture FF, sysclk RTC counter, RTOSC ripple
# chain + F617 TOUT pair). FIVE builds cover every ifdef path: plain
# (sync F595 + ripple chain, default 100MHz-derived RTC limit checked
# statically), VERILATOR_SIM (transparent F595, 8192/2048 RTC + runtime
# period pokes), VERILATOR_SIM+RTC_SIM_20MS=600 (build-knob override -
# the tb hard-codes 600/150, keep the -D value paired), FPGA_FF_MODE+
# BOARD_CLK_FREQ=25600 (synchronous chain, derived limit 511/127 run
# dynamically - keep the -D value paired with the tb constants), and
# VERILATOR_SIM+FPGA_FF_MODE (the sim FF-mode combination).
POW_SRCS = $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/DECODE_DGA_POW.v \
           $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F595.v \
           $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F714.v \
           $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F617.v \
           $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F571.v \
           $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F103.v \
           $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F091.v \
           $(VERILOG_ROOT)/Shared/logisim/Multiplexer_2_w_enable.v \
           $(VERILOG_ROOT)/Shared/logisim/J_K_FLIPFLOP.v \
           $(VERILOG_ROOT)/Shared/logisim/D_FLIPFLOP.v

test-dga-pow:
	$(IVERILOG) -g2012 -o DECODE_DGA_POW_tb DECODE_DGA_POW_tb.v $(POW_SRCS)
	./DECODE_DGA_POW_tb | tee pow_result.tmp
	@grep -q "TB_RESULT: PASS" pow_result.tmp && rm -f pow_result.tmp
	$(IVERILOG) -g2012 -DVERILATOR_SIM -o DECODE_DGA_POW_tb_vs DECODE_DGA_POW_tb.v $(POW_SRCS)
	./DECODE_DGA_POW_tb_vs | tee pow_result.tmp
	@grep -q "TB_RESULT: PASS" pow_result.tmp && rm -f pow_result.tmp
	$(IVERILOG) -g2012 -DVERILATOR_SIM -DRTC_SIM_20MS=600 -o DECODE_DGA_POW_tb_vs20 DECODE_DGA_POW_tb.v $(POW_SRCS)
	./DECODE_DGA_POW_tb_vs20 | tee pow_result.tmp
	@grep -q "TB_RESULT: PASS" pow_result.tmp && rm -f pow_result.tmp
	$(IVERILOG) -g2012 -DFPGA_FF_MODE -DBOARD_CLK_FREQ=25600 -o DECODE_DGA_POW_tb_ff DECODE_DGA_POW_tb.v $(POW_SRCS)
	./DECODE_DGA_POW_tb_ff | tee pow_result.tmp
	@grep -q "TB_RESULT: PASS" pow_result.tmp && rm -f pow_result.tmp
	$(IVERILOG) -g2012 -DVERILATOR_SIM -DFPGA_FF_MODE -o DECODE_DGA_POW_tb_vsff DECODE_DGA_POW_tb.v $(POW_SRCS)
	./DECODE_DGA_POW_tb_vsff | tee pow_result.tmp
	@grep -q "TB_RESULT: PASS" pow_result.tmp && rm -f pow_result.tmp

.PHONY: test-dga-pow

# ---------------------------------------------------------------------------
# DECODE_DGA_COMM - microcode COMM command decode sheet (DGA pages 16-19).
#
# NOT in the registry, and deliberately so. The bench was written 01-AUG-2026
# and had no make rule at all until 09-AUG; `make test-audit` found it. It
# now BUILDS AND RUNS in all four ifdef modes, and every functional check
# passes - errors=0 in all four. What fails is its own CHECK-COUNT guard:
#
#     mode                       expected   actual
#     plain / VERILATOR_SIM        219100   240865
#     FPGA_FF_MODE (both)          218781   240596
#
# The bench file is unchanged in git, so the extra checks come from the DUT:
# `checks` is incremented inside conditionals that depend on COMM's outputs,
# and DECODE_DGA_COMM.v was last touched by 2cde8e1 (the P2 conversion of
# every CPU clock domain to sysclk clock-enables). More checks executing with
# zero mismatches is consistent with the sheet doing MORE work, not wrong
# work - but that has to be established, not assumed.
#
# DO NOT simply raise the two constants to the observed numbers. The count
# guard exists to catch a bench that silently stops checking; bumping it to
# whatever today prints removes the only thing protecting against that. The
# drift needs explaining against the P2 change first, and then the constants
# get set deliberately.
# ---------------------------------------------------------------------------
COMM_SRCS = $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/DECODE_DGA_COMM.v \
            $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F091.v \
            $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F571.v \
            $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F595.v \
            $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F924.v \
            $(VERILOG_ROOT)/Shared/ndlib/D_FLIPFLOP_EN.v \
            $(VERILOG_ROOT)/Shared/ndlib/F924_EN.v \
            $(VERILOG_ROOT)/Shared/logisim/AND_GATE.v \
            $(VERILOG_ROOT)/Shared/logisim/AND_GATE_3_INPUTS.v \
            $(VERILOG_ROOT)/Shared/logisim/NAND_GATE.v \
            $(VERILOG_ROOT)/Shared/logisim/NAND_GATE_3_INPUTS.v \
            $(VERILOG_ROOT)/Shared/logisim/NAND_GATE_4_INPUTS.v \
            $(VERILOG_ROOT)/Shared/logisim/NAND_GATE_5_INPUTS.v \
            $(VERILOG_ROOT)/Shared/logisim/NAND_GATE_6_INPUTS.v \
            $(VERILOG_ROOT)/Shared/logisim/NAND_GATE_8_INPUTS.v \
            $(VERILOG_ROOT)/Shared/logisim/NOR_GATE.v \
            $(VERILOG_ROOT)/Shared/logisim/D_FLIPFLOP.v \
            $(VERILOG_ROOT)/Shared/logisim/Multiplexer_2_w_enable.v

# Runs all four ifdef modes and REPORTS; does not gate. Once the count drift
# is explained, drop the `-` prefixes and register it.
test-dga-comm:
	$(IVERILOG) -g2012 -o DECODE_DGA_COMM_tb DECODE_DGA_COMM_tb.v $(COMM_SRCS)
	-./DECODE_DGA_COMM_tb | tail -3
	$(IVERILOG) -g2012 -DVERILATOR_SIM -o DECODE_DGA_COMM_tb_vs DECODE_DGA_COMM_tb.v $(COMM_SRCS)
	-./DECODE_DGA_COMM_tb_vs | tail -3
	$(IVERILOG) -g2012 -DFPGA_FF_MODE -o DECODE_DGA_COMM_tb_ff DECODE_DGA_COMM_tb.v $(COMM_SRCS)
	-./DECODE_DGA_COMM_tb_ff | tail -3
	$(IVERILOG) -g2012 -DVERILATOR_SIM -DFPGA_FF_MODE -o DECODE_DGA_COMM_tb_vsff DECODE_DGA_COMM_tb.v $(COMM_SRCS)
	-./DECODE_DGA_COMM_tb_vsff | tail -3

.PHONY: test-dga-comm
