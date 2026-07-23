# UPDATE NEXT 3 LINES PR TEST PROGRAM
TOP_FILE = CGA_MIC
TEST_PROGRAM = test_mic.cpp
TEST_FOLDER = ${TOP_FILE}

# This is the path to the root of the verilog directory
VERILOG_ROOT = ../../..


SHARED_COMPONENTS = -I${VERILOG_ROOT}/shared/ndlib --I${VERILOG_ROOT}/shared/logisim --I${VERILOG_ROOT}/shared/support

DELILAH_ROOT = ${VERILOG_ROOT}/DELILAH-CPU
COMPONENT_ROOT = ${DELILAH_ROOT}/${TEST_FOLDER}/circuit

SUPPRESS_FLAGS = -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH  -Wno-LATCH
VERILATOR_FLAGS = --trace -Wall --cc ${COMPONENT_ROOT}/${TOP_FILE}.v --exe ${TEST_PROGRAM} $(SUPPRESS_FLAGS)  

CGA_COMPONENTS = --I${COMPONENT_ROOT} -I${DELILAH_ROOT}/CGA_ALU/circuit -I${DELILAH_ROOT}/CGA_DCD/circuit -I${DELILAH_ROOT}/CGA_IDBCTL/circuit -I${DELILAH_ROOT}/CGA_INTR/circuit -I${DELILAH_ROOT}/CGA_MAC/circuit -I${DELILAH_ROOT}/CGA_MIC/circuit -I${DELILAH_ROOT}/CGA_TESTMUX/circuit -I${DELILAH_ROOT}/CGA_TRAP/circuit -I${DELILAH_ROOT}/CGA_WRF/circuit
VERILATOR_DIRS = -I${COMPONENT_ROOT} ${SHARED_COMPONENTS} $(CGA_COMPONENTS)

VERILATOR = verilator

# Specify C++ source files here
CPP_SOURCES = ${TEST_PROGRAM}

# Default target
all: test_mic run gtk

test_mic: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_MIC.mk VCGA_MIC

clean:
	rm -rf obj_dir

run: test_mic
	./obj_dir/VCGA_MIC

gtk: run
	gtkwave waveform.vcd mic.gtkw &

# ---------------------------------------------------------------
# iverilog testbenches for MASEL submodule
# These test CGA_MIC_MASEL.v in isolation using iverilog (not Verilator).
# ---------------------------------------------------------------
IVERILOG = iverilog
INC_PATHS = -I${VERILOG_ROOT}/Shared/logisim \
            -I${VERILOG_ROOT}/Shared/ndlib \
            -I${VERILOG_ROOT}/Shared/support \
            -I${DELILAH_ROOT}/CGA_MIC/circuit

MASEL_SRC = ${DELILAH_ROOT}/CGA_MIC/circuit/CGA_MIC_MASEL.v

MASEL_cycle_tb: MASEL_cycle_tb.v $(MASEL_SRC)
	$(IVERILOG) -g2012 $(INC_PATHS) -o $@ $^

MASEL_iw_capture_tb: MASEL_iw_capture_tb.v $(MASEL_SRC)
	$(IVERILOG) -g2012 $(INC_PATHS) -o $@ $^

test-masel-cycle: MASEL_cycle_tb
	./MASEL_cycle_tb

test-masel-iw: MASEL_iw_capture_tb
	./MASEL_iw_capture_tb

CGA_MIC_MASEL_tb: CGA_MIC_MASEL_tb.v $(MASEL_SRC)
	$(IVERILOG) -g2012 $(INC_PATHS) -o $@ $^

test-masel-basic: CGA_MIC_MASEL_tb
	./CGA_MIC_MASEL_tb

test-masel: test-masel-cycle test-masel-iw test-masel-basic

.PHONY: all clean test-masel test-masel-cycle test-masel-iw test-masel-basic
