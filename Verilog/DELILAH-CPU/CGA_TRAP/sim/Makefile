# UPDATE NEXT 3 LINES PR TEST PROGRAM
TOP_FILE = CGA_TRAP
TEST_PROGRAM = test_trap.cpp
TEST_FOLDER = ${TOP_FILE}

SUPPRESS_FLAGS = -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH

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
all: test_trap run gtk

test_trap: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_TRAP.mk VCGA_TRAP

clean:
	rm -rf obj_dir

run: test_trap
	./obj_dir/VCGA_TRAP

gtk: run
	gtkwave waveform.vcd trap.gtkw &

.PHONY: all clean
