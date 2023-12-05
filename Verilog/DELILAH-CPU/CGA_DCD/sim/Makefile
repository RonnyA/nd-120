VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH
VERILATOR_FLAGS = --trace -Wall --cc ../circuit/CGA_DCD.v --exe test_dcd.cpp $(SUPPRESS_FLAGS)  
VERILATOR_DIRS = -I../circuit --I../../shared/ndlib --I../../shared/logisim --I../../shared/gates
# Specify C++ source files here
CPP_SOURCES = test_dcd.cpp

# Default target
all: test_dcd run

test_dcd: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_DCD.mk VCGA_DCD

clean:
	rm -rf obj_dir

run: test_dcd
	./obj_dir/VCGA_DCD

gtk: run
	gtkwave waveform.vcd dcd.gtkw &

.PHONY: all clean
