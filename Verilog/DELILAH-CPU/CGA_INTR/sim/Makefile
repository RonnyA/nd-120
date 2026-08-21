# UPDATE NEXT 3 LINES PR TEST PROGRAM
TOP_FILE = CGA_INTR
TEST_PROGRAM = test_intr.cpp
TEST_FOLDER = ${TOP_FILE}

# This is the path to the root of the verilog directory
VERILOG_ROOT = ../../..


SHARED_COMPONENTS = -I${VERILOG_ROOT}/shared/ndlib --I${VERILOG_ROOT}/shared/logisim --I${VERILOG_ROOT}/shared/support

DELILAH_ROOT = ${VERILOG_ROOT}/DELILAH-CPU
COMPONENT_ROOT = ${DELILAH_ROOT}/${TEST_FOLDER}/circuit

SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH
VERILATOR_FLAGS = --trace -Wall --cc ${COMPONENT_ROOT}/${TOP_FILE}.v --exe ${TEST_PROGRAM} $(SUPPRESS_FLAGS)  

CGA_COMPONENTS = --I${COMPONENT_ROOT} -I${DELILAH_ROOT}/CGA_ALU/circuit -I${DELILAH_ROOT}/CGA_DCD/circuit -I${DELILAH_ROOT}/CGA_IDBCTL/circuit -I${DELILAH_ROOT}/CGA_INTR/circuit -I${DELILAH_ROOT}/CGA_MAC/circuit -I${DELILAH_ROOT}/CGA_MIC/circuit -I${DELILAH_ROOT}/CGA_TESTMUX/circuit -I${DELILAH_ROOT}/CGA_TRAP/circuit -I${DELILAH_ROOT}/CGA_WRF/circuit
VERILATOR_DIRS = -I${COMPONENT_ROOT} ${SHARED_COMPONENTS} $(CGA_COMPONENTS)

VERILATOR = verilator


# Page 78 - CGA_INTR_CNTLR_IRQ_REG_RQBIT - Completed, not tested <=== NEEDS to be rewritten with flip-flop
# -Wno-UNOPTFLAT 

# Specify C++ source files here
CPP_SOURCES = test_intr.cpp

# Default target
all: test_intr run gtk

test_intr: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_INTR.mk VCGA_INTR

# --- CGA_INTR_IRSRC MOR/IOX interrupt-source unit test -----------------------
# Locks in the 14-JUL MOR wiring (MORN -> IREQ[12]). Separate --Mdir so it does
# not collide with the CGA_INTR build above. Self-checking (TB_RESULT: PASS).
test-irsrc:
	$(VERILATOR) --cc --exe -Wall $(SUPPRESS_FLAGS) $(VERILATOR_DIRS) \
	    --Mdir obj_dir_irsrc ${COMPONENT_ROOT}/CGA_INTR_IRSRC.v test_irsrc.cpp
	cd obj_dir_irsrc && make -f VCGA_INTR_IRSRC.mk VCGA_INTR_IRSRC
	./obj_dir_irsrc/VCGA_INTR_IRSRC

# --- iverilog gate-level testbenches (self-checking, TB_RESULT: PASS) --------
# Generic rule: `make iv-<MODULE>` compiles+runs <MODULE>_tb.v against the gate
# netlists (Shared libs + circuit/ resolved via -y). Registered per-tb in
# tests/run_all_tests.sh.
IV_LIB = -y ${VERILOG_ROOT}/Shared/logisim -y ${VERILOG_ROOT}/Shared/support -y ${VERILOG_ROOT}/Shared/ndlib
iv-%:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_$* $*_tb.v && vvp -N /tmp/ndtb_$*

# --- RQBIT vs RQBIT_V2 equivalence, BOTH build modes -------------------------
# Dual-instantiation tb (original async-latch RQBIT vs loop-free RQBIT_V2),
# run twice: default posedge-CP mode, then FPGA_FF_MODE (MCLK_EN-gated sysclk
# capture). Registered in tests/run_all_tests.sh; a FAIL line in either run
# fails the suite.
test-rqbitv2:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_rqbitv2 CGA_INTR_CNTLR_IRQ_REG_RQBIT_V2_tb.v && vvp -N /tmp/ndtb_rqbitv2
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_rqbitv2_ff CGA_INTR_CNTLR_IRQ_REG_RQBIT_V2_tb.v && vvp -N /tmp/ndtb_rqbitv2_ff

# --- CGA_INTR_CNTLR_VECGEN whole-block verification, BOTH build modes --------
# MCLR + exhaustive 65536 MIREQ priority sweep + LDSTAT/comparator exhaustive
# + enable sweep + vector+1 fence (incl. wrap and GPE blocking) + VHR + 512
# fixed-seed LFSR steps vs the independent behavioral model (generator-
# cross-checked). Registered module (SCAN_FF_EN + D_FLIPFLOP_EN switched by
# FPGA_FF_MODE): run twice, default latch/CP mode then FPGA_FF_MODE. Built
# with the fence-ON RTL default (no ND120_INTR_STATUS_FENCE_OFF). Registered
# in tests/run_all_tests.sh. (CGA_INTR_CNTLR_CLR_CLRBIT is pure comb - run
# via the generic rule: make iv-CGA_INTR_CNTLR_CLR_CLRBIT.)
test-intr-vecgen:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_intr_vecgen CGA_INTR_CNTLR_VECGEN_tb.v && vvp -N /tmp/ndtb_intr_vecgen
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_intr_vecgen_ff CGA_INTR_CNTLR_VECGEN_tb.v && vvp -N /tmp/ndtb_intr_vecgen_ff

clean:
	rm -rf obj_dir obj_dir_irsrc

run: test_intr
	./obj_dir/VCGA_INTR

gtk: run
	gtkwave waveform.vcd intr.gtkw &

.PHONY: all clean

# --- CGA_INTR_IRSRC verification ---------------------------------------------
# Walking one/zero on FIDBO x both EMPIDN phases, one hardware source at a
# time, EXHAUSTIVE over all 1024 hardware-source combinations and 1024 LFSR
# vectors, against the per-gate transcription of CGA_INTR_IRSRC.v.
# Purely combinational - built both ways to prove FPGA_FF_MODE cannot reach it.
# Registered in tests/run_all_tests.sh.
test-intr-irsrc:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_intr_irsrc CGA_INTR_IRSRC_tb.v && vvp -N /tmp/ndtb_intr_irsrc
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_intr_irsrc_ff CGA_INTR_IRSRC_tb.v && vvp -N /tmp/ndtb_intr_irsrc_ff
