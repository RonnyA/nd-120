VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH
VERILATOR_FLAGS = --trace -Wall --cc ../circuit/CGA_TESTMUX.v --exe test_testmux.cpp $(SUPPRESS_FLAGS)  
VERILATOR_DIRS = -I../circuit --I../../shared/ndlib --I../../shared/logisim --I../../shared/gates
# Specify C++ source files here
CPP_SOURCES = test_testmux.cpp

# Default target
all: test_testmux run

test_testmux: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_TESTMUX.mk VCGA_TESTMUX

clean:
	rm -rf obj_dir

run: test_testmux
	./obj_dir/VCGA_TESTMUX

gtk: run
	gtkwave waveform.vcd testmux.gtkw &

.PHONY: all clean
