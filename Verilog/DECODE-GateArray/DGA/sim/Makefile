VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH
VERILATOR_FLAGS = --trace -Wall --cc ../circuit/DECODE_DGA.v --exe test_dga.cpp $(SUPPRESS_FLAGS)  

VERILOG_ROOT = ../../..

DGA_ROOT = ${VERILOG_ROOT}/DECODE-GateArray/DGA
DGA_COMPONENTS = -I${DGA_ROOT}/circuit

SHARED_COMPONENTS = -I${VERILOG_ROOT}/shared/ndlib --I${VERILOG_ROOT}/shared/logisim --I${VERILOG_ROOT}/shared/support

VERILATOR_DIRS = $(DGA_COMPONENTS) ${SHARED_COMPONENTS}
# Specify C++ source files here
CPP_SOURCES = test_dga.cpp

# Default target
all: test_dga run gtk

test_dga: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VDECODE_DGA.mk VDECODE_DGA

clean:
	rm -rf obj_dir

run: test_dga
	./obj_dir/VDECODE_DGA

gtk: run
	gtkwave waveform.vcd dga.gtkw &

.PHONY: all clean
