TOP_FILE = CPU_PROC_CGA_33

SUPPRESS_FLAGS = -Wno-WIDTH

VERILOG_ROOT = ../../../..

CGA_ROOT = ${VERILOG_ROOT}/DELILAH-CPU
CGA_COMPONENTS = --I${CGA_ROOT}/CGA/circuit --I${CGA_ROOT}/CGA_ALU/circuit -I${CGA_ROOT}/CGA_DCD/circuit -I${CGA_ROOT}/CGA_IDBCTL/circuit -I${CGA_ROOT}/CGA_INTR/circuit -I${CGA_ROOT}/CGA_MAC/circuit -I${CGA_ROOT}/CGA_MIC/circuit -I${CGA_ROOT}/CGA_TESTMUX/circuit -I${CGA_ROOT}/CGA_TRAP/circuit -I${CGA_ROOT}/CGA_WRF/circuit

#CPU_BOARD_ROOT = ${VERILOG_ROOT}/CPU-BOARD-3202
#CPU_BOARD_COMPONENTS = ${CPU_BOARD_ROOT}/circuit

SHARED_COMPONENTS = -I${VERILOG_ROOT}/shared/ndlib --I${VERILOG_ROOT}/shared/logisim --I${VERILOG_ROOT}/shared/gates --I${VERILOG_ROOT}/shared/Support-Chips
PAL_COMPONENTS = --I${VERILOG_ROOT}/PAL

TOP_3202D_COMPONENTS = --I${CGA_ROOT}/circuit  ${SHARED_COMPONENTS} ${PAL_COMPONENTS} $(CGA_COMPONENTS)

VERILATOR_FLAGS = --trace -Wall --cc ../../${TOP_FILE}.v --exe test_code.cpp $(SUPPRESS_FLAGS) 
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

