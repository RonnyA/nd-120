VERILATOR = verilator



SUPPRESS_FLAGS = -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH
VERILATOR_FLAGS = --trace -Wall --cc ../circuit/CGA_TRAP.v --exe test_trap.cpp $(SUPPRESS_FLAGS)  
VERILATOR_DIRS = -I../circuit --I../../shared/ndlib --I../../shared/logisim --I../../shared/gates
# Specify C++ source files here
CPP_SOURCES = test_trap.cpp

# Default target
all: test_trap run

test_trap: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_TRAP.mk VCGA_TRAP

clean:
	rm -rf obj_dir

run: test_trap
	./obj_dir/VCGA_TRAP

gtk: run
	gtkwave waveform.vcd trap.gtkw &

.PHONY: all clean
