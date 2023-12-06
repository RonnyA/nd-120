VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH
VERILATOR_FLAGS = --trace -Wall --cc ../circuit/CGA_IDBCTL.v --exe test_idbctl.cpp $(SUPPRESS_FLAGS)  
VERILATOR_DIRS = -I../circuit --I../../shared/ndlib --I../../shared/logisim --I../../shared/gates
# Specify C++ source files here
CPP_SOURCES = test_idbctl.cpp

# Default target
all: test_idbctl run

test_idbctl: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_IDBCTL.mk VCGA_IDBCTL

clean:
	rm -rf obj_dir

run: test_idbctl
	./obj_dir/VCGA_IDBCTL

gtk: run
	gtkwave waveform.vcd idbctl.gtkw &

.PHONY: all clean
