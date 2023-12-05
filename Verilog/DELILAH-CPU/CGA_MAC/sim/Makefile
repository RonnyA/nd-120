VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH
VERILATOR_FLAGS = --trace -Wall --cc ../circuit/CGA_MAC.v --exe test_mac.cpp $(SUPPRESS_FLAGS)  
VERILATOR_DIRS = -I../circuit --I../../shared/ndlib --I../../shared/logisim --I../../shared/gates
# Specify C++ source files here
CPP_SOURCES = test_mac.cpp

# Default target
all: test_mac run gtwave

test_mac: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_MAC.mk VCGA_MAC

clean:
	rm -rf obj_dir

run: test_mac
	./obj_dir/VCGA_MAC

gtk: run
	gtkwave waveform.vcd &

.PHONY: all clean
