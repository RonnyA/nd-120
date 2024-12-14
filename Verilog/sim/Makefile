VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH -Wno-EOFNEWLINE -Wno-LATCH


VERILATOR_FLAGS = --trace -Wall --cc ../ND120_TOP.v --exe test_nd120.cpp $(SUPPRESS_FLAGS)  

#TOP_3202D_COMPONENTS = --I../circuit -I../../Shared/logisim   -I../../Shared/ndlib  -I../../Shared/support
TOP_3202D_COMPONENTS =  -I../Shared/logisim   -I../Shared/ndlib  -I../Shared/support --I../CPU-BOARD-3202/circuit

CGA_COMPONENTS = --I../DELILAH-CPU/CGA_ALU/circuit -I../DELILAH-CPU/CGA_DCD/circuit -I../DELILAH-CPU/CGA_IDBCTL/circuit -I../DELILAH-CPU/CGA_INTR/circuit -I../DELILAH-CPU/CGA_MAC/circuit -I../DELILAH-CPU/CGA_MIC/circuit -I../DELILAH-CPU/CGA_TESTMUX/circuit -I../DELILAH-CPU/CGA_TRAP/circuit -I../DELILAH-CPU/CGA_WRF/circuit -I../DELILAH-CPU/CGA/circuit
DGA_COMPONENTS = --I../DECODE-GateArray/DGA/circuit

#SHARED_COMPONENTS =  -I../circuit --I../../shared/ndlib --I../../shared/logisim --I../../shared/gates   --I../../PAL

VERILATOR_DIRS = $(TOP_3202D_COMPONENTS) $(CGA_COMPONENTS) $(DGA_COMPONENTS)
# Specify C++ source files here
CPP_SOURCES = test_nd120.cpp

# Default target
all: test_nd120 run gtk

test_nd120: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS) --I../PAL
	cd obj_dir && make -f VND120_TOP.mk VND120_TOP

clean:
	rm -rf obj_dir

run: test_nd120
	./obj_dir/VND120_TOP

gtk: run
    # The signal file can be very big, >1GB so use optimizing.
    # Use the -g or --giga flag to enable dynamically compressed memory handling, which allows GTKWave to load large VCD files without running out of memory.
	# Use the -o or --optimize flag to convert VCD files to FST directly from the command line when opening them with GTKWave. (require 'vcd2fst' installed)
	gtkwave -g waveform.vcd top_3202d.gtkw &

.PHONY: all clean
