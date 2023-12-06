VERILATOR = verilator


# Page 78 - CGA_INTR_CNTLR_IRQ_REG_RQBIT - Completed, not tested <=== NEEDS to be rewritten with flip-flop
# -Wno-UNOPTFLAT 

SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH
VERILATOR_FLAGS = --trace -Wall --cc ../circuit/CGA_INTR.v --exe test_intr.cpp $(SUPPRESS_FLAGS)  
VERILATOR_DIRS = -I../circuit --I../../shared/ndlib --I../../shared/logisim --I../../shared/gates
# Specify C++ source files here
CPP_SOURCES = test_intr.cpp

# Default target
all: test_intr run

test_intr: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_INTR.mk VCGA_INTR

clean:
	rm -rf obj_dir

run: test_intr
	./obj_dir/VCGA_INTR

gtk: run
	gtkwave waveform.vcd intr.gtkw &

.PHONY: all clean
