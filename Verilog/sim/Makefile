VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH -Wno-EOFNEWLINE -Wno-LATCH -Wno-SYNCASYNCNET

# USE_LATCHES: Set to 1 (default) for transparent latch behavior (original hardware).
#              Set to 0 for edge-triggered flip-flop behavior (FPGA mode).
USE_LATCHES ?= 1

# VERILATOR_SIM is always defined for Verilator builds (enables bus ports, fast UART, sim RAM size).
# USE_LATCHES controls latch vs FF behavior independently.
SIM_DEFINES = -DVERILATOR_SIM
ifeq ($(USE_LATCHES),0)
  # Add FPGA_FF_MODE to override latch behavior while keeping VERILATOR_SIM for bus ports
  SIM_DEFINES += -DFPGA_FF_MODE
endif

VERILATOR_FLAGS = --trace -Wall --cc ../ND120_TOP.v  $(SUPPRESS_FLAGS) $(SIM_DEFINES)

#TOP_3202D_COMPONENTS = --I../circuit -I../../Shared/logisim   -I../../Shared/ndlib  -I../../Shared/support
TOP_3202D_COMPONENTS =  -I../Shared/logisim   -I../Shared/ndlib  -I../Shared/support -I../CPU-BOARD-3202/circuit

CGA_COMPONENTS = -I../DELILAH-CPU/CGA_ALU/circuit -I../DELILAH-CPU/CGA_DCD/circuit -I../DELILAH-CPU/CGA_IDBCTL/circuit -I../DELILAH-CPU/CGA_INTR/circuit -I../DELILAH-CPU/CGA_MAC/circuit -I../DELILAH-CPU/CGA_MIC/circuit -I../DELILAH-CPU/CGA_TESTMUX/circuit -I../DELILAH-CPU/CGA_TRAP/circuit -I../DELILAH-CPU/CGA_WRF/circuit -I../DELILAH-CPU/CGA/circuit
DGA_COMPONENTS = -I../DECODE-GateArray/DGA/circuit

#SHARED_COMPONENTS =  -I../circuit --I../../shared/ndlib --I../../shared/logisim --I../../shared/gates   --I../../PAL

VERILATOR_DIRS = $(TOP_3202D_COMPONENTS) $(CGA_COMPONENTS) $(DGA_COMPONENTS) -I../PAL 
# Specify C++ source files here
CPP_SOURCES = test_nd120.cpp ../simDevices/NDDevices.cpp ../simDevices/NDBus.cpp

# Default target
all: test_nd120 run gtk

test_nd120: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS) --exe $(CPP_SOURCES)  -CFLAGS "$(VERILATOR_DIRS)  -I../../simDevices"
	cd obj_dir && make -f VND120_TOP.mk VND120_TOP

clean:
	rm -rf obj_dir obj_dir_latch obj_dir_ff

run: test_nd120
	./obj_dir/VND120_TOP

gtk: run
    # The signal file can be very big, >1GB so use optimizing.
    # Use the -g or --giga flag to enable dynamically compressed memory handling, which allows GTKWave to load large VCD files without running out of memory.
	# Use the -o or --optimize flag to convert VCD files to FST directly from the command line when opening them with GTKWave. (require 'vcd2fst' installed)
	gtkwave -g waveform.vcd top_3202d.gtkw &

# --- Latch vs FF comparison targets ---
COMPARE_SOURCES = latch_ff_compare.cpp ../simDevices/NDDevices.cpp ../simDevices/NDBus.cpp
COMPARE_VFLAGS = -Wall --cc ../ND120_TOP.v $(SUPPRESS_FLAGS) -Wno-SYNCASYNCNET

compare_latch: latch_ff_compare.cpp
	$(VERILATOR) $(COMPARE_VFLAGS) -DVERILATOR_SIM $(VERILATOR_DIRS) --exe $(COMPARE_SOURCES) -CFLAGS "$(VERILATOR_DIRS) -I../../simDevices" --Mdir obj_dir_latch
	cd obj_dir_latch && make -f VND120_TOP.mk VND120_TOP
	./obj_dir_latch/VND120_TOP > trace_latch.csv
	@echo "=== Latch trace written to trace_latch.csv ==="

compare_ff: latch_ff_compare.cpp
	$(VERILATOR) $(COMPARE_VFLAGS) -DVERILATOR_SIM -DFPGA_FF_MODE $(VERILATOR_DIRS) --exe $(COMPARE_SOURCES) -CFLAGS "$(VERILATOR_DIRS) -I../../simDevices" --Mdir obj_dir_ff
	cd obj_dir_ff && make -f VND120_TOP.mk VND120_TOP
	./obj_dir_ff/VND120_TOP > trace_ff.csv
	@echo "=== FF trace written to trace_ff.csv ==="

compare: compare_latch compare_ff
	@echo "=== Comparing latch vs FF traces ==="
	@diff trace_latch.csv trace_ff.csv > trace_diff.txt 2>&1 && echo "IDENTICAL - no divergence!" || (echo "DIVERGENCE FOUND - see trace_diff.txt" && head -20 trace_diff.txt)

.PHONY: all clean compare compare_latch compare_ff
