VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH
VERILATOR_FLAGS = --trace -Wall --cc ../circuit/CGA_ALU.v --exe test_alu.cpp $(SUPPRESS_FLAGS)  
VERILATOR_DIRS =  -I../circuit --I../../shared/ndlib --I../../shared/logisim --I../../shared/gates

# Specify C++ source files here
CPP_SOURCES = test_alu.cpp

# Default target
all: test_alu run gtwave

test_alu: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_ALU.mk VCGA_ALU

clean:
	rm -rf obj_dir

run: test_alu
	./obj_dir/VCGA_ALU

gtk:
	gtkwave waveform.vcd &

.PHONY: all clean

