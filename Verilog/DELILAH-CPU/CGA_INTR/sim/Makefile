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

clean:
	rm -rf obj_dir

run: test_intr
	./obj_dir/VCGA_INTR

gtk: run
	gtkwave waveform.vcd intr.gtkw &

.PHONY: all clean
