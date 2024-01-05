VERILATOR = verilator

PAL_CHIP = PAL_44307C
VERILATOR_FLAGS = --trace -Wall --cc ../${PAL_CHIP}.v --exe test_pal.cpp $(SUPPRESS_FLAGS)  
# Specify C++ source files here
CPP_SOURCES = test_pal.cpp

# Default target
all: test_pal run

test_pal: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f V$(PAL_CHIP).mk V$(PAL_CHIP)

clean:
	rm -rf obj_dir

run: test_pal
	./obj_dir/V$(PAL_CHIP)
	
gtk: run
	gtkwave waveform.vcd pal.gtkw &

.PHONY: all clean

