VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH
VERILATOR_FLAGS = --trace -Wall --cc ../circuit/CGA.v --exe test_cga.cpp $(SUPPRESS_FLAGS)  

CGA_COMPONENTS = --I../../CGA_ALU/circuit -I../../CGA_DCD/circuit -I../../CGA_IDBCTL/circuit -I../../CGA_INTR/circuit -I../../CGA_MAC/circuit -I../../CGA_MIC/circuit -I../../CGA_TESTMUX/circuit -I../../CGA_TRAP/circuit -I../../CGA_WRF/circuit
VERILATOR_DIRS = -I../circuit --I../../shared/ndlib --I../../shared/logisim --I../../shared/gates  $(CGA_COMPONENTS)
# Specify C++ source files here
CPP_SOURCES = test_cga.cpp

# Default target
all: test_cga run

test_cga: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA.mk VCGA

clean:
	rm -rf obj_dir

run: test_cga
	./obj_dir/VCGA

gtk: run
	gtkwave waveform.vcd cga.gtkw &

.PHONY: all clean
