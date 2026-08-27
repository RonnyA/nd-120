# UPDATE NEXT 3 LINES PR TEST PROGRAM
TOP_FILE = CGA_IDBCTL
TEST_PROGRAM = test_idbctl.cpp
TEST_FOLDER = ${TOP_FILE}

# This is the path to the root of the verilog directory
VERILOG_ROOT = ../../..


SHARED_COMPONENTS = -y ${VERILOG_ROOT}/Shared/ndlib -y ${VERILOG_ROOT}/Shared/logisim -y ${VERILOG_ROOT}/Shared/support

DELILAH_ROOT = ${VERILOG_ROOT}/DELILAH-CPU
COMPONENT_ROOT = ${DELILAH_ROOT}/${TEST_FOLDER}/circuit

SUPPRESS_FLAGS = -Wno-PINCONNECTEMPTY -Wno-UNUSED  -Wno-WIDTH #-Wno-UNDRIVEN
VERILATOR_FLAGS = --trace -Wall --cc ${COMPONENT_ROOT}/${TOP_FILE}.v --exe ${TEST_PROGRAM} $(SUPPRESS_FLAGS)  

CGA_COMPONENTS = --I${COMPONENT_ROOT} -I${DELILAH_ROOT}/CGA_ALU/circuit -I${DELILAH_ROOT}/CGA_DCD/circuit -I${DELILAH_ROOT}/CGA_IDBCTL/circuit -I${DELILAH_ROOT}/CGA_INTR/circuit -I${DELILAH_ROOT}/CGA_MAC/circuit -I${DELILAH_ROOT}/CGA_MIC/circuit -I${DELILAH_ROOT}/CGA_TESTMUX/circuit -I${DELILAH_ROOT}/CGA_TRAP/circuit -I${DELILAH_ROOT}/CGA_WRF/circuit
VERILATOR_DIRS = -I${COMPONENT_ROOT} ${SHARED_COMPONENTS} $(CGA_COMPONENTS)

VERILATOR = verilator


# Specify C++ source files here
CPP_SOURCES = test_idbctl.cpp

# Default target
all: test_idbctl run gtk

test_idbctl: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_IDBCTL.mk VCGA_IDBCTL

# --- iverilog gate-level testbenches (self-checking, TB_RESULT: PASS) --------
# Generic rule: `make iv-<MODULE>` compiles+runs <MODULE>_tb.v against the gate
# netlists (Shared libs + circuit/ resolved via -y). Registered per-tb in
# tests/run_all_tests.sh.
IV_LIB = -y ${VERILOG_ROOT}/Shared/logisim -y ${VERILOG_ROOT}/Shared/support -y ${VERILOG_ROOT}/Shared/ndlib
iv-%:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_$* $*_tb.v && vvp -N /tmp/ndtb_$*

# --- CGA_IDBCTL_SEL6 exhaustive verification ---------------------------------
# All 4096 {data,enable} combinations vs the independent sum-of-products
# model (generator-cross-checked). Pure combinational (assign-only): a single
# build mode covers it. Registered in tests/run_all_tests.sh.
test-idbctl-sel6:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_idbctl_sel6 CGA_IDBCTL_SEL6_tb.v && vvp -N /tmp/ndtb_idbctl_sel6

# --- CGA_IDBCTL_PGSREG verification, BOTH build modes ------------------------
# Defining loads + walking-one + hold (with and without clock) + 256
# fixed-seed LFSR steps vs the independent 14-bit register model (note the
# PGS15 output is taken from QN). Registered module (14x SCAN_FF_EN switched
# by FPGA_FF_MODE): run twice, default latch/CP mode then FPGA_FF_MODE
# (MCLK_EN-gated sysclk capture). Registered in tests/run_all_tests.sh.
test-idbctl-pgsreg:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_idbctl_pgsreg CGA_IDBCTL_PGSREG_tb.v && vvp -N /tmp/ndtb_idbctl_pgsreg
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_idbctl_pgsreg_ff CGA_IDBCTL_PGSREG_tb.v && vvp -N /tmp/ndtb_idbctl_pgsreg_ff

# --- CGA_IDBCTL top-level IDB source select verification, BOTH build modes ---
# Walking-one per source, all 32 enable combinations x 16 random vectors
# against the per-slice wiring map read off CGA_IDBCTL.v, an explicit RING
# check (XFIDBI must not move the output while any internal source is
# enabled) and a printed multi-hot characterisation. Contains PGSREG
# (SCAN_FF_EN switched by FPGA_FF_MODE): run twice. Registered in
# tests/run_all_tests.sh.
test-idbctl:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_idbctl CGA_IDBCTL_tb.v && vvp -N /tmp/ndtb_idbctl
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_idbctl_ff CGA_IDBCTL_tb.v && vvp -N /tmp/ndtb_idbctl_ff

clean:
	rm -rf obj_dir

run: test_idbctl
	./obj_dir/VCGA_IDBCTL

gtk: run
	gtkwave waveform.vcd idbctl.gtkw &

.PHONY: all clean
