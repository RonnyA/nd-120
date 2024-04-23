TOP_FILE = CYC_36

SUPPRESS_FLAGS = -Wno-EOFNEWLINE 

# This is the path to the root of the verilog directory
VERILOG_ROOT = ../../../..

CPU_BOARD_ROOT = ${VERILOG_ROOT}/CPU-BOARD-3202/circuit

SHARED_COMPONENTS = -I${VERILOG_ROOT}/shared/ndlib --I${VERILOG_ROOT}/shared/logisim --I${VERILOG_ROOT}/shared/gates --I${VERILOG_ROOT}/shared/Support-Chips
PAL_COMPONENTS = --I${VERILOG_ROOT}/PAL

TOP_3202D_COMPONENTS = --I${CPU_BOARD_ROOT} ${SHARED_COMPONENTS} ${PAL_COMPONENTS}

VERILATOR_FLAGS = --trace -Wall --cc ${CPU_BOARD_ROOT}/${TOP_FILE}.v --exe test_code.cpp $(SUPPRESS_FLAGS) 

VERILATOR = verilator

# Specify C++ source files here
CPP_SOURCES = test_code.cpp

# Default target
all: test_code run

test_code: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(TOP_3202D_COMPONENTS)
	cd obj_dir && make -f V$(TOP_FILE).mk V$(TOP_FILE)

clean:
	rm -rf obj_dir

run: test_code
	./obj_dir/V$(TOP_FILE)
	
gtk: run
	gtkwave waveform.vcd pal.gtkw &

.PHONY: all clean

