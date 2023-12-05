VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH
VERILATOR_FLAGS = --trace -Wall --cc ../circuit/CGA_MIC.v --exe test_mic.cpp $(SUPPRESS_FLAGS)  
VERILATOR_DIRS = -I../circuit --I../../shared/ndlib --I../../shared/logisim --I../../shared/gates
# Specify C++ source files here
CPP_SOURCES = test_mic.cpp

# Default target
all: test_mic run

test_mic: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_MIC.mk VCGA_MIC

clean:
	rm -rf obj_dir

run: test_mic
	./obj_dir/VCGA_MIC

gtk: run
	gtkwave waveform.vcd mic.gtkw &

.PHONY: all clean
