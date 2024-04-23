TOP_FILE =  CPU_15

# Path from obj_dir to the microcode files
MCDIR=../../../../../Code/Microcode

SUPPRESS_FLAGS = -Wno-WIDTH -Wno-UNUSED -Wno-UNDRIVEN -Wno-PINCONNECTEMPTY -Wno-WIDTH -Wno-UNOPTFLAT -Wno-EOFNEWLINE  -Wno-LATCH  -Wno-MULTIDRIVEN 
#SUPPRESS_FLAGS = -Wno-WIDTH -Wno-PINCONNECTEMPTY

VERILOG_ROOT = ../../../..

DGA_ROOT = ${VERILOG_ROOT}/DECODE-GateArray/DGA/circuit
DGA_COMPONENTS = --I${DGA_ROOT}/

CPU_BOARD_ROOT = ${VERILOG_ROOT}/CPU-BOARD-3202
CPU_BOARD_COMPONENTS = --I${CPU_BOARD_ROOT}/circuit

CGA_ROOT = ${VERILOG_ROOT}/DELILAH-CPU
CGA_COMPONENTS = --I${CGA_ROOT}/CGA/circuit --I${CGA_ROOT}/CGA_ALU/circuit -I${CGA_ROOT}/CGA_DCD/circuit -I${CGA_ROOT}/CGA_IDBCTL/circuit -I${CGA_ROOT}/CGA_INTR/circuit -I${CGA_ROOT}/CGA_MAC/circuit -I${CGA_ROOT}/CGA_MIC/circuit -I${CGA_ROOT}/CGA_TESTMUX/circuit -I${CGA_ROOT}/CGA_TRAP/circuit -I${CGA_ROOT}/CGA_WRF/circuit


SHARED_COMPONENTS = -I${VERILOG_ROOT}/shared/ndlib --I${VERILOG_ROOT}/shared/logisim  --I${VERILOG_ROOT}/shared/support
PAL_COMPONENTS = --I${VERILOG_ROOT}/PAL

TOP_3202D_COMPONENTS = --I${CGA_ROOT}/circuit  ${SHARED_COMPONENTS} ${PAL_COMPONENTS} $(CGA_COMPONENTS) $(DGA_COMPONENTS) ${CPU_BOARD_COMPONENTS}

VERILATOR_FLAGS = --trace -Wall --cc ../../${TOP_FILE}.v --exe test_code.cpp $(SUPPRESS_FLAGS) 
VERILATOR = verilator

VERILATOR_FLAGS = --trace -Wall --cc ../../${TOP_FILE}.v --exe test_code.cpp $(SUPPRESS_FLAGS) 
# Specify C++ source files here
CPP_SOURCES = test_code.cpp

# Default target
all: test_code run gtk

test_code: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(TOP_3202D_COMPONENTS)
	cd obj_dir && make -f V$(TOP_FILE).mk V$(TOP_FILE)

# This is needed to get the miceode files in the right place so the simulation can find them. Used by CPO_CS_PROM_19.v
microcode:	
	rm -f AM27256_45132L.hex
	rm -f AM27256_45133L.hex
	ln -s $(MCDIR)/AM27256_45132L.hex AM27256_45132L.hex
	ln -s $(MCDIR)/AM27256_45133L.hex AM27256_45133L.hex
	
micro_clean:
	rm -f AM27256_45132L.hex
	rm -f AM27256_45133L.hex

clean: micro_clean
	rm -rf obj_dir

run: test_code microcode
	./obj_dir/V$(TOP_FILE)
	
gtk: run
	gtkwave waveform.vcd pal.gtkw &

.PHONY: all clean

