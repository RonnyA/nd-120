# UPDATE NEXT 3 LINES PR TEST PROGRAM
TOP_FILE = CGA_TESTMUX
TEST_PROGRAM = test_testmux.cpp
TEST_FOLDER = ${TOP_FILE}

SUPPRESS_FLAGS =  -Wno-UNUSED -Wno-WIDTH

# This is the path to the root of the verilog directory
VERILOG_ROOT = ../../..


SHARED_COMPONENTS = -I${VERILOG_ROOT}/shared/ndlib --I${VERILOG_ROOT}/shared/logisim --I${VERILOG_ROOT}/shared/support

DELILAH_ROOT = ${VERILOG_ROOT}/DELILAH-CPU
COMPONENT_ROOT = ${DELILAH_ROOT}/${TEST_FOLDER}/circuit


VERILATOR_FLAGS = --trace -Wall --cc ${COMPONENT_ROOT}/${TOP_FILE}.v --exe ${TEST_PROGRAM} $(SUPPRESS_FLAGS)  

CGA_COMPONENTS = --I${COMPONENT_ROOT} -I${DELILAH_ROOT}/CGA_ALU/circuit -I${DELILAH_ROOT}/CGA_DCD/circuit -I${DELILAH_ROOT}/CGA_IDBCTL/circuit -I${DELILAH_ROOT}/CGA_INTR/circuit -I${DELILAH_ROOT}/CGA_MAC/circuit -I${DELILAH_ROOT}/CGA_MIC/circuit -I${DELILAH_ROOT}/CGA_TESTMUX/circuit -I${DELILAH_ROOT}/CGA_TRAP/circuit -I${DELILAH_ROOT}/CGA_WRF/circuit
VERILATOR_DIRS = -I${COMPONENT_ROOT} ${SHARED_COMPONENTS} $(CGA_COMPONENTS)

VERILATOR = verilator

# Specify C++ source files here
CPP_SOURCES = ${TEST_PROGRAM}

# Default target
all: test_testmux run gtk

test_testmux: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_TESTMUX.mk VCGA_TESTMUX

clean:
	rm -rf obj_dir

run: test_testmux
	./obj_dir/VCGA_TESTMUX

gtk: run
	gtkwave waveform.vcd testmux.gtkw &

# Registry target: build (Verilator) + run + strict verdict check.
test-testmux: test_testmux
	./obj_dir/VCGA_TESTMUX | tee testmux_result.tmp
	@grep -q "TB_RESULT: PASS" testmux_result.tmp && rm -f testmux_result.tmp

.PHONY: all clean run test-testmux

# --- iverilog gate-level testbenches (self-checking, TB_RESULT: PASS) --------
IV_LIB = -y ${VERILOG_ROOT}/Shared/logisim -y ${VERILOG_ROOT}/Shared/support -y ${VERILOG_ROOT}/Shared/ndlib
iv-%:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_$* $*_tb.v && vvp -N /tmp/ndtb_$*

# --- CGA_TESTMUX verification ------------------------------------------------
# Exhaustive TSEL sweep (all 8 selects x both PTSTN values) with a walking one
# across all 36 data inputs, the PTSTN select-collapse override and 512 LFSR
# vectors, against the five-slice MUX81 source map read off CGA_TESTMUX.v.
# Purely combinational - built both ways to prove FPGA_FF_MODE cannot reach it.
# Registered in tests/run_all_tests.sh.
test-testmux-iv:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_testmux CGA_TESTMUX_tb.v && vvp -N /tmp/ndtb_testmux
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_testmux_ff CGA_TESTMUX_tb.v && vvp -N /tmp/ndtb_testmux_ff
