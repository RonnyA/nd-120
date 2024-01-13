VERILATOR = verilator

TOP_FILE = CPU_STOC_35

SUPPRESS_FLAGS = -Wno-WIDTH

TOP_3202D_COMPONENTS = --I../../../circuit --I../../../logisim  --I../../../shared --I../../../../PAL

VERILATOR_FLAGS = --trace -Wall --cc ../../${TOP_FILE}.v --exe test_code.cpp $(SUPPRESS_FLAGS) 
# Specify C++ source files here
CPP_SOURCES = test_code.cpp

# Default target
all: test_code run

test_code: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(TOP_3202D_COMPONENTS)
	cd obj_dir && make -f V$(TOP_FILE).mk V$(TOP_FILE)

clean:
	rm -rf obj_dir

run: test_code
	./obj_dir/V$(TOP_FILE)
	
gtk: run
	gtkwave waveform.vcd pal.gtkw &

.PHONY: all clean

