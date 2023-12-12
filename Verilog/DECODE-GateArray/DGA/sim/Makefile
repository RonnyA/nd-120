VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH
VERILATOR_FLAGS = --trace -Wall --cc ../circuit/DECODE_DGA.v --exe test_dga.cpp $(SUPPRESS_FLAGS)  

DGA_COMPONENTS = --I../circuit --I../logisim  --I../shared

CGA_COMPONENTS = --I../../CGA_ALU/circuit -I../../CGA_DCD/circuit -I../../CGA_IDBCTL/circuit -I../../CGA_INTR/circuit -I../../CGA_MAC/circuit -I../../CGA_MIC/circuit -I../../CGA_TESTMUX/circuit -I../../CGA_TRAP/circuit -I../../CGA_WRF/circuit
SHARED_COMPONENTS =  -I../circuit --I../../shared/ndlib --I../../shared/logisim --I../../shared/gates 
VERILATOR_DIRS = $(DGA_COMPONENTS)
# Specify C++ source files here
CPP_SOURCES = test_dga.cpp

# Default target
all: test_dga run

test_dga: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VDECODE_DGA.mk VDECODE_DGA

clean:
	rm -rf obj_dir

run: test_dga
	./obj_dir/VDECODE_DGA

gtk: run
	gtkwave waveform.vcd dga.gtkw &

.PHONY: all clean
