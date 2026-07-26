# dmaSim - standalone Verilator harness for the P3 DMA-master gate
#
# Its OWN harness + OWN obj_dir, deliberately separate from sim/ and runSim/
# (which another session owns). It Verilates the SAME ND120_TOP but with only
# this directory's tiny C++ main (dma_p3_main.cpp) - no NDBus/console/tape C++,
# because the RTL is pure Verilog (no DPI) so the model links against main alone.
#
# What it proves: the full-RTL DMA gate - ND_DMA_MASTER requesting the bus from
# the REAL arbiter (PAL_44801A via BIF) and running real memory cycles - moves
# fast back-to-back words correctly. See PLAN-P3-dma-master-validation.md and
# ND_DMA_MASTER.v's MIN_GAP_TICKS note ("every second read lost").
#
# Config is fixed here (no SD card, no --timing): VERILOG_TAPE devices are
# included (ND120_VERILOG_DEVICES) ONLY so ANY_DMA_MASTER is true and the DMA
# test-client master + DMA_* ports exist (ND120_CORE.v). The tape/floppy/SMD
# devices themselves sit idle - the CPU boots to its OPCOM idle loop, freeing
# the bus for clean DMA cycle-stealing.

VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN \
                 -Wno-WIDTH -Wno-EOFNEWLINE -Wno-LATCH -Wno-SYNCASYNCNET

# USE_LATCHES=0 (FF mode) - the default every build uses.
SIM_DEFINES = -DVERILATOR_SIM -DFPGA_FF_MODE -DND_SDRAM_PACK16 -DND120_VERILOG_DEVICES $(EXTRA_VDEFINES)

# TIMING=1 (default): Verilator --timing (event-driven scheduler). The green
# test-dma-rtl gate builds this way (SD_STORAGE=1 -> TIMING=1), and the DMA
# read-data window on BD resolves per intra-tick settling (see
# docs/nd100-bus-dma.md), so match it.
TIMING ?= 1
ifeq ($(TIMING),1)
  TIMING_FLAGS = --timing
  TIMING_CFLAGS = -std=gnu++20 -fcoroutines
endif

VERILATOR_FLAGS = -Wall --cc ../ND120_TOP.v $(SUPPRESS_FLAGS) $(TIMING_FLAGS) $(SIM_DEFINES)

TOP_3202D_COMPONENTS = -I../Shared/logisim -I../Shared/ndlib -I../Shared/support -I../CPU-BOARD-3202/circuit
CGA_COMPONENTS = -I../DELILAH-CPU/CGA_ALU/circuit -I../DELILAH-CPU/CGA_DCD/circuit \
                 -I../DELILAH-CPU/CGA_IDBCTL/circuit -I../DELILAH-CPU/CGA_INTR/circuit \
                 -I../DELILAH-CPU/CGA_MAC/circuit -I../DELILAH-CPU/CGA_MIC/circuit \
                 -I../DELILAH-CPU/CGA_TESTMUX/circuit -I../DELILAH-CPU/CGA_TRAP/circuit \
                 -I../DELILAH-CPU/CGA_WRF/circuit -I../DELILAH-CPU/CGA/circuit
DGA_COMPONENTS = -I../DECODE-GateArray/DGA/circuit
BUSDEV_COMPONENTS = -I../ND-BUS-DEVICES/BUS-IF/circuit -I../ND-BUS-DEVICES/TAPE-400/circuit \
                    -I../ND-BUS-DEVICES/DMA/circuit -I../ND-BUS-DEVICES/FLOPPY/circuit \
                    -I../ND-BUS-DEVICES/FLOPPY-DMA/circuit -I../ND-BUS-DEVICES/SMD/circuit

VERILATOR_DIRS = -I.. $(TOP_3202D_COMPONENTS) $(CGA_COMPONENTS) $(DGA_COMPONENTS) $(BUSDEV_COMPONENTS) -I../PAL

CPP_SOURCES = dma_p3_main.cpp

all: test-dma-p3

compile: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS) --exe $(CPP_SOURCES) -CFLAGS "$(VERILATOR_DIRS) $(TIMING_CFLAGS)"
	cd obj_dir && make -f VND120_TOP.mk VND120_TOP

run: compile
	./obj_dir/VND120_TOP

# Self-checking gate: the harness prints TB_RESULT: PASS/FAIL itself.
test-dma-p3: compile
	./obj_dir/VND120_TOP | tee dma_p3_out.log
	@grep -q "TB_RESULT: PASS" dma_p3_out.log

# ---- P3 "teeth": prove the recovery gap is load-bearing --------------------
# Reproduce the documented "every second read lost": EARLY_REREQ=1 re-asserts
# BREQ overlapping BDRY; MIN_GAP_TICKS=0 removes the recovery pace -> stale
# reads. Then show MIN_GAP_TICKS=32 (default) makes the SAME back-to-back
# pattern clean. These rebuild the RTL with the override defines (no normal
# build sets them). HAMMER addr matches the test-dma-rtl region.
HAMMER_ADDR ?= 010000

test-dma-p3-repro:
	$(MAKE) clean >/dev/null
	$(MAKE) compile EXTRA_VDEFINES="-DND_DMA_MIN_GAP_TICKS=0 -DND_DMA_EARLY_REREQ=1" >/dev/null
	ND120_DMA_HAMMER=$(HAMMER_ADDR) ./obj_dir/VND120_TOP | tee dma_p3_repro.log
	@grep -q "BUG REPRODUCED" dma_p3_repro.log \
	  && echo "TEETH: repro OK (bug seen with gap=0)" \
	  || (echo "TEETH: repro FAILED - no stale reads at gap=0 (expected the bug)"; exit 1)

test-dma-p3-recovery:
	$(MAKE) clean >/dev/null
	$(MAKE) compile >/dev/null                        # shipping default: EARLY_REREQ=0, MIN_GAP=32
	ND120_DMA_HAMMER=$(HAMMER_ADDR) ./obj_dir/VND120_TOP | tee dma_p3_recovery.log
	@grep -q "TB_RESULT: PASS" dma_p3_recovery.log

# Full teeth proof: bug reproduces at gap=0, gone at gap=32.
test-dma-p3-teeth: test-dma-p3-repro test-dma-p3-recovery
	@echo "TEETH PROVEN: back-to-back reads fail at MIN_GAP=0, pass at MIN_GAP=32"

clean:
	rm -rf obj_dir *.log

.PHONY: all compile run test-dma-p3 test-dma-p3-repro test-dma-p3-recovery test-dma-p3-teeth clean
