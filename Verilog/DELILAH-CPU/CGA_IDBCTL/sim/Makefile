# UPDATE NEXT 3 LINES PR TEST PROGRAM
TOP_FILE = CGA_IDBCTL
TEST_PROGRAM = test_idbctl.cpp
TEST_FOLDER = ${TOP_FILE}

# This is the path to the root of the verilog directory
VERILOG_ROOT = ../../..


SHARED_COMPONENTS = -I${VERILOG_ROOT}/shared/ndlib --I${VERILOG_ROOT}/shared/logisim --I${VERILOG_ROOT}/shared/support

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

clean:
	rm -rf obj_dir

run: test_idbctl
	./obj_dir/VCGA_IDBCTL

gtk: run
	gtkwave waveform.vcd idbctl.gtkw &

.PHONY: all clean
