VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH -Wno-EOFNEWLINE -Wno-LATCH


VERILATOR_FLAGS = --trace -Wall --cc ../ND120_TOP.v $(SUPPRESS_FLAGS)  

#TOP_3202D_COMPONENTS = -I../circuit -I../../Shared/logisim   -I../../Shared/ndlib  -I../../Shared/support
TOP_3202D_COMPONENTS =  -I../Shared/logisim   -I../Shared/ndlib  -I../Shared/support -I../CPU-BOARD-3202/circuit

CGA_COMPONENTS = -I../DELILAH-CPU/CGA_ALU/circuit -I../DELILAH-CPU/CGA_DCD/circuit -I../DELILAH-CPU/CGA_IDBCTL/circuit -I../DELILAH-CPU/CGA_INTR/circuit -I../DELILAH-CPU/CGA_MAC/circuit -I../DELILAH-CPU/CGA_MIC/circuit -I../DELILAH-CPU/CGA_TESTMUX/circuit -I../DELILAH-CPU/CGA_TRAP/circuit -I../DELILAH-CPU/CGA_WRF/circuit -I../DELILAH-CPU/CGA/circuit
DGA_COMPONENTS = -I../DECODE-GateArray/DGA/circuit

#SHARED_COMPONENTS =  -I../circuit -I../../shared/ndlib -I../../shared/logisim -I../../shared/gates   -I../../PAL

VERILATOR_DIRS = $(TOP_3202D_COMPONENTS) $(CGA_COMPONENTS) $(DGA_COMPONENTS) -I../PAL 
# Specify C++ source files here
CPP_SOURCES = Run120.cpp ../simDevices/NDDevices.cpp ../simDevices/NDBus.cpp

# Default target
all: compile run gtk

compile: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS) --exe $(CPP_SOURCES)  -CFLAGS "$(VERILATOR_DIRS)  -I../../simDevices"
	cd obj_dir && make -f VND120_TOP.mk VND120_TOP

clean:
	rm -rf obj_dir

run: compile
	./obj_dir/VND120_TOP


.PHONY: all clean
