VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH
VERILATOR_FLAGS = --trace -Wall --cc ../circuit/TOP_3202D.v --exe test_top_3202d.cpp $(SUPPRESS_FLAGS)  

TOP_3202D_COMPONENTS = --I../circuit --I../logisim  --I../shared 

# CGA_COMPONENTS = --I../../CGA_ALU/circuit -I../../CGA_DCD/circuit -I../../CGA_IDBCTL/circuit -I../../CGA_INTR/circuit -I../../CGA_MAC/circuit -I../../CGA_MIC/circuit -I../../CGA_TESTMUX/circuit -I../../CGA_TRAP/circuit -I../../CGA_WRF/circuit
SHARED_COMPONENTS =  -I../circuit --I../../shared/ndlib --I../../shared/logisim --I../../shared/gates   --I../../PAL
VERILATOR_DIRS = $(TOP_3202D_COMPONENTS)
# Specify C++ source files here
CPP_SOURCES = test_top_3202d.cpp

# Default target
all: test_top_3202d run

test_top_3202d: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS) --I../../PAL
	cd obj_dir && make -f VTOP_3202D.mk VTOP_3202D

clean:
	rm -rf obj_dir

run: test_top_3202d
	./obj_dir/VTOP_3202D

gtk: run
	gtkwave waveform.vcd top_3202d.gtkw &

.PHONY: all clean
