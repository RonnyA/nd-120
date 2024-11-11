VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH -Wno-EOFNEWLINE -Wno-LATCH


VERILATOR_FLAGS = --trace -Wall --cc ../circuit/ND3202D.v --exe test_top_3202d.cpp $(SUPPRESS_FLAGS)  

TOP_3202D_COMPONENTS = --I../circuit -I../../Shared/logisim   -I../../Shared/ndlib  -I../../Shared/support

CGA_COMPONENTS = --I../../DELILAH-CPU/CGA_ALU/circuit -I../../DELILAH-CPU/CGA_DCD/circuit -I../../DELILAH-CPU/CGA_IDBCTL/circuit -I../../DELILAH-CPU/CGA_INTR/circuit -I../../DELILAH-CPU/CGA_MAC/circuit -I../../DELILAH-CPU/CGA_MIC/circuit -I../../DELILAH-CPU/CGA_TESTMUX/circuit -I../../DELILAH-CPU/CGA_TRAP/circuit -I../../DELILAH-CPU/CGA_WRF/circuit -I../../DELILAH-CPU/CGA/circuit
DGA_COMPONENTS = --I../../DECODE-GateArray/DGA/circuit

#SHARED_COMPONENTS =  -I../circuit --I../../shared/ndlib --I../../shared/logisim --I../../shared/gates   --I../../PAL

VERILATOR_DIRS = $(TOP_3202D_COMPONENTS) $(CGA_COMPONENTS) $(DGA_COMPONENTS)
# Specify C++ source files here
CPP_SOURCES = test_top_3202d.cpp

# Default target
all: test_top_3202d run gtk

test_top_3202d: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS) --I../../PAL
	cd obj_dir && make -f VND3202D.mk VND3202D

clean:
	rm -rf obj_dir

run: test_top_3202d
	./obj_dir/VND3202D

gtk: run
	gtkwave waveform.vcd top_3202d.gtkw &

.PHONY: all clean
