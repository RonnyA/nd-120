VERILATOR = verilator

TOP_FILE = CPU_PROC_CGA_33

SUPPRESS_FLAGS = -Wno-WIDTH

VERILOG_ROOT = ../../../..

CGA_ROOT = ${VERILOG_ROOT}/DELILAH-CPU
CGA_COMPONENTS = --I${CGA_ROOT}/CGA/circuit --I${CGA_ROOT}/CGA_ALU/circuit -I${CGA_ROOT}/CGA_DCD/circuit -I${CGA_ROOT}/CGA_IDBCTL/circuit -I${CGA_ROOT}/CGA_INTR/circuit -I${CGA_ROOT}/CGA_MAC/circuit -I${CGA_ROOT}/CGA_MIC/circuit -I${CGA_ROOT}/CGA_TESTMUX/circuit -I${CGA_ROOT}/CGA_TRAP/circuit -I${CGA_ROOT}/CGA_WRF/circuit

SUPPORT_COMPONENTS = --I${VERILOG_ROOT}/Support-Chips

TOP_3202D_COMPONENTS = --I../../../circuit --I../../../logisim  --I../../../shared --I../../../../PAL $(SUPPORT_COMPONENTS) $(CGA_COMPONENTS)

VERILATOR_FLAGS = --trace -Wall --cc ../../${TOP_FILE}.v --exe test_code.cpp $(SUPPRESS_FLAGS) 
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

