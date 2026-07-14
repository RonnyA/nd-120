VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH -Wno-EOFNEWLINE -Wno-LATCH -Wno-SYNCASYNCNET

# USE_LATCHES: Set to 1 (default) for transparent latch behavior (original hardware).
#              Set to 0 for edge-triggered flip-flop behavior (FPGA mode).
USE_LATCHES ?= 1

# Enable larger RAM (1MB) for Verilator simulation instead of FPGA's 4KB
# EXTRA_VDEFINES: extra Verilog-side defines, e.g.
#   EXTRA_VDEFINES="-DRTC_REAL_PERIOD -DBOARD_CLK_FREQ=16666667"
# to run the DGA real-time clock at the true FPGA period (OPCOM pacing repro).
SIM_DEFINES = -DVERILATOR_SIM $(EXTRA_VDEFINES)
ifeq ($(USE_LATCHES),0)
  SIM_DEFINES += -DFPGA_FF_MODE
endif

# Packed-memory contract (default ON, matching the Tang build): parity is
# never read from storage, MEM_RAM_49_SIM recomputes it from the data on
# every read. Set PACK16=0 to model classic stored-parity DRAM.
# See docs/nd120-parity-analysis.md.
PACK16 ?= 1
ifeq ($(PACK16),1)
  SIM_DEFINES += -DND_SDRAM_PACK16
endif

# SKIP_WCS: Set to 1 to pre-load the WCS and skip the microcode load phase.
#           Requires the 32 wcs_*.hex files in this dir (gen_wcs_image.py).
#           See docs/skip-wcs-load.md.
ifeq ($(SKIP_WCS),1)
  SIM_DEFINES += -DSKIP_WCS_LOAD
endif

# VERILOG_TAPE: Set to 1 to replace the C papertape model with the Verilog
#               device stack (ND-BUS-DEVICES: ND_BUS_SLAVE + ND_TAPE_400
#               instantiated inside ND120_TOP). The C harness then only
#               serves raw tape bytes through the TAPE_BYTE_* ports.
#               Gate: console output must stay byte-identical to golden.
VERILOG_TAPE ?= 0
ifeq ($(VERILOG_TAPE),1)
  SIM_DEFINES += -DND120_VERILOG_DEVICES
  # 'override' is required: EXTRA_CFLAGS is usually given on the make
  # command line, and a plain += on a command-line variable is silently
  # ignored - which would compile the C harness WITHOUT the define
  # (leaving the C papertape registered and the Verilog device starved).
  override EXTRA_CFLAGS += -DND120_VERILOG_DEVICES

# SD_STORAGE=1 (DEFAULT, Ronny 14-JUL-2026): the Verilog tape device is fed by
#            the REAL SD-FAT stack reading a simulated SD card - the same RTL
#            that runs on Tang - instead of the C file server in NDBus.cpp.
#            The card must carry BOOT.BPUN; build it with
#            ../SD-FAT/sim/make_boot_card.sh (SD_CARD_IMG points at it).
#            Implies TIMING=1: sd_card_model.v drives the SD bus from tasks.
# SD_STORAGE=0 falls back to the C tape file server (process_verilog_tape).
#            Both paths must build and pass - the C models also back the
#            sim/ latch-vs-FF trace goldens.
  SD_STORAGE  ?= 1
  SD_CARD_IMG ?= ../SD-FAT/sim/nd_boot_card.img
  ifeq ($(SD_STORAGE),1)
    SIM_DEFINES += -DND120_SD_STORAGE -DND120_SD_CARD_IMG='"$(SD_CARD_IMG)"'
    override EXTRA_CFLAGS += -DND120_SD_STORAGE
    TIMING := 1
    # Suppressions scoped to the SD_STORAGE build ONLY, so the CPU sources keep
    # their full -Wall. All four are pre-existing and benign in the SD-FAT
    # stack, and SD-FAT/sim/Makefile already suppresses them there:
    #   PINMISSING    BY DESIGN - nd_storage instantiates sd_writer without the
    #                 4-bit ports; unconnected use_4bit = the proven 1-bit engine
    #   DECLFILENAME  nds_sync.v / sd_file_reader.v hold >1 module (see -v above)
    #   BLKSEQ        blocking assigns in the card MODEL's sequential tasks
    #   TIMESCALEMOD  the SD-FAT sources carry a timescale, the CPU ones do not
    SDFAT_SUPPRESS = -Wno-PINMISSING -Wno-DECLFILENAME -Wno-BLKSEQ -Wno-TIMESCALEMOD
  endif
endif

# TIMING=1  compile with Verilator --timing (event controls / delays).
#           Needed by the Verilog SD card model (sd_card_model.v drives the
#           SD bus from tasks with @(negedge sd_clk)), i.e. by SD_STORAGE.
#           It changes Verilator's scheduler for the WHOLE build, so it is a
#           variable and the golden gates must be re-proven under it.
TIMING ?= 0
ifeq ($(TIMING),1)
  TIMING_FLAGS = --timing
  override EXTRA_CFLAGS += -std=gnu++20 -fcoroutines
else
  TIMING_FLAGS =
endif

VERILATOR_FLAGS = --trace -Wall --cc ../ND120_TOP.v $(SUPPRESS_FLAGS) $(SDFAT_SUPPRESS) $(TIMING_FLAGS) $(SIM_DEFINES)

#TOP_3202D_COMPONENTS = -I../circuit -I../../Shared/logisim   -I../../Shared/ndlib  -I../../Shared/support
TOP_3202D_COMPONENTS =  -I../Shared/logisim   -I../Shared/ndlib  -I../Shared/support -I../CPU-BOARD-3202/circuit

CGA_COMPONENTS = -I../DELILAH-CPU/CGA_ALU/circuit -I../DELILAH-CPU/CGA_DCD/circuit -I../DELILAH-CPU/CGA_IDBCTL/circuit -I../DELILAH-CPU/CGA_INTR/circuit -I../DELILAH-CPU/CGA_MAC/circuit -I../DELILAH-CPU/CGA_MIC/circuit -I../DELILAH-CPU/CGA_TESTMUX/circuit -I../DELILAH-CPU/CGA_TRAP/circuit -I../DELILAH-CPU/CGA_WRF/circuit -I../DELILAH-CPU/CGA/circuit
DGA_COMPONENTS = -I../DECODE-GateArray/DGA/circuit

#SHARED_COMPONENTS =  -I../circuit -I../../shared/ndlib -I../../shared/logisim -I../../shared/gates   -I../../PAL

BUSDEV_COMPONENTS = -I../ND-BUS-DEVICES/BUS-IF/circuit -I../ND-BUS-DEVICES/TAPE-400/circuit -I../ND-BUS-DEVICES/DMA/circuit -I../ND-BUS-DEVICES/FLOPPY/circuit -I../ND-BUS-DEVICES/FLOPPY-DMA/circuit -I../ND-BUS-DEVICES/SMD/circuit
# SD-FAT stack (SD_STORAGE): circuit/ = the real RTL, sim/ = sd_card_model +
# nds_mem_model, the two SIM-ONLY models ND120_TOP instantiates under
# ND120_SD_STORAGE. Without these -I dirs Verilator cannot find nd_storage.
SDFAT_COMPONENTS = -I../SD-FAT/circuit -I../SD-FAT/sim
# LIBRARY files: -I resolves a module by FILENAME, and these two hold modules
# whose names differ from their file, so -I alone cannot find them:
#   nds_sync.v       -> nds_sync_pulse, nds_sync_level
#   sd_file_reader.v -> sd_card_ctrl (alongside sd_file_reader)
# Kept OUT of VERILATOR_DIRS on purpose: that variable is also handed to g++
# via -CFLAGS, which would try to LINK these .v files.
# Only fed to Verilator when SD_STORAGE=1: parsing them otherwise would drag
# their (suppressed-only-there) DECLFILENAME warnings into the C-path build.
ifeq ($(SD_STORAGE),1)
  SDFAT_VFILES = -v ../SD-FAT/circuit/nds_sync.v -v ../SD-FAT/circuit/sd_file_reader.v
endif

# -I.. = the Verilog root, where ND120_CORE.v (instantiated by ND120_TOP.v) lives
VERILATOR_DIRS = -I.. $(TOP_3202D_COMPONENTS) $(CGA_COMPONENTS) $(DGA_COMPONENTS) $(BUSDEV_COMPONENTS) $(SDFAT_COMPONENTS) -I../PAL
# Specify C++ source files here
CPP_SOURCES = Run120.cpp ../simDevices/NDDevices.cpp ../simDevices/NDBus.cpp

# Default target
all: compile run gtk

help:
	@echo "runSim - full CPU simulation (microcode load + self-test + OPCOM console)"
	@echo ""
	@echo "Targets:"
	@echo "  make compile      build the simulator (C models for the bus devices)"
	@echo "  make run          compile + run interactively (OPCOM on stdin/stdout)"
	@echo "  make run-floppy   Verilog-device build (DMA floppy at 1560) + run with"
	@echo "                    a bootable diskette image; type 1560& at the '#'"
	@echo "                    prompt to boot it - the loaded program then owns the"
	@echo "                    console (type help etc. at ITS prompt)"
	@echo "  make clean        remove obj_dir (do this when switching build flags)"
	@echo ""
	@echo "Variables:"
	@echo "  USE_LATCHES=0     FPGA flip-flop mode (default 1 = transparent latches)"
	@echo "  VERILOG_TAPE=1    replace the C papertape/floppy models with the Verilog"
	@echo "                    device stack inside ND120_TOP (tape-400 + DMA floppy"
	@echo "                    at 1560 + SMD at 1540)"
	@echo "  SD_STORAGE=1      (DEFAULT when VERILOG_TAPE=1) feed the tape from the"
	@echo "                    REAL Verilog SD-FAT stack reading a simulated SD"
	@echo "                    card - the same RTL that runs on Tang. The card must"
	@echo "                    carry BOOT.BPUN: build it with"
	@echo "                      ../SD-FAT/sim/make_boot_card.sh"
	@echo "                    Implies TIMING=1 (the card model drives the SD bus"
	@echo "                    from tasks). 400\$$ then boots BOOT.BPUN off the card."
	@echo "  SD_STORAGE=0      fall back to the C tape file server in NDBus.cpp"
	@echo "                    (process_verilog_tape, reads INSTRUCTION-B.BPUN"
	@echo "                    directly). Both paths must build and pass."
	@echo "  SD_CARD_IMG=path  card image for SD_STORAGE"
	@echo "                    (default ../SD-FAT/sim/nd_boot_card.img)"
	@echo "  TIMING=1          Verilator --timing (event controls). Forced on by"
	@echo "                    SD_STORAGE=1; measured behaviour-neutral and free"
	@echo "                    (console byte-identical to golden, same runtime)."
	@echo "  FLOPPY_IMG=path   diskette image for run-floppy (default: the 210523I01"
	@echo "                    test-program diskette in ND-BUS-DEVICES/testdata)"
	@echo "  SKIP_WCS=1        preload the WCS, skip the microcode load phase"
	@echo ""
	@echo "Environment at run time:"
	@echo "  ND120_FLOPPY_IMG  floppy image file (what run-floppy sets for you)"
	@echo "  ND120_SMD_IMG     SMD disk-0 image file (no default = drive not ready)"
	@echo ""
	@echo "System gates live in the top-level Verilog/Makefile: make test,"
	@echo "test-full, test-tape, test-dma-rtl, test-floppy-boot, test-smd-boot."
	@echo "See runSim/README.md for the full story."

.PHONY: help

# Build-flags stamp: make does not rebuild C++ objects when only -D flags
# change, so switching VERILOG_TAPE / USE_LATCHES / EXTRA_CFLAGS between
# builds would silently link stale harness objects (e.g. NDBus.o still
# registering the C devices next to the Verilog ones). If the flag set
# differs from the last build, wipe obj_dir first.
BUILD_FLAGS = $(SIM_DEFINES) | $(EXTRA_CFLAGS)
FLAGS_STAMP = obj_dir/.buildflags

compile: $(CPP_SOURCES)
	@if [ -d obj_dir ] && [ "`cat $(FLAGS_STAMP) 2>/dev/null`" != "$(BUILD_FLAGS)" ]; then \
	  echo "Build flags changed (or unknown) since last build - cleaning obj_dir"; \
	  rm -rf obj_dir; \
	fi
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS) $(SDFAT_VFILES) --exe $(CPP_SOURCES)  -CFLAGS "$(VERILATOR_DIRS)  -I../../simDevices $(EXTRA_CFLAGS)"
	@echo "$(BUILD_FLAGS)" > $(FLAGS_STAMP)
	cd obj_dir && make -f VND120_TOP.mk VND120_TOP

clean:
	rm -rf obj_dir

run: compile
	./obj_dir/VND120_TOP

# Interactive floppy-boot session: Verilog device build (DMA floppy at
# 1560) with a bootable diskette image behind it. At the '#' prompt
# type 1560& - the BPUN loader boots the diskette's program, which
# then owns the console (type help etc. at ITS prompt).
# Override the image with: make run-floppy FLOPPY_IMG=path/to.img
FLOPPY_IMG ?= ../ND-BUS-DEVICES/testdata/210523I01-XX-01D.img

run-floppy:
	$(MAKE) compile VERILOG_TAPE=1 USE_LATCHES=0
	ND120_FLOPPY_IMG=$(FLOPPY_IMG) ./obj_dir/VND120_TOP


.PHONY: all clean run-floppy
