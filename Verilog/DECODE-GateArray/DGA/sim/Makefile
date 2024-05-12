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
