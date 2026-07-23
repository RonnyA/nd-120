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

# SKIP_WCS: pre-load the WCS and skip the microcode load phase (docs/skip-wcs-load.md).
# Requires the 32 wcs_*.hex files in this dir (Code/Microcode/gen_wcs_image.py).
# CPP_DEFINES also forwards the flag to the C++ testbench so it can trace from
# tick 0 (no load phase to skip).
CPP_DEFINES =
ifeq ($(SKIP_WCS),1)
  SIM_DEFINES += -DSKIP_WCS_LOAD
  CPP_DEFINES += -DSKIP_WCS_LOAD
endif

VERILATOR_FLAGS = --trace-fst -Wall --cc ../ND120_TOP.v  $(SUPPRESS_FLAGS) $(SIM_DEFINES)

#TOP_3202D_COMPONENTS = --I../circuit -I../../Shared/logisim   -I../../Shared/ndlib  -I../../Shared/support
TOP_3202D_COMPONENTS =  -I../Shared/logisim   -I../Shared/ndlib  -I../Shared/support -I../CPU-BOARD-3202/circuit

CGA_COMPONENTS = -I../DELILAH-CPU/CGA_ALU/circuit -I../DELILAH-CPU/CGA_DCD/circuit -I../DELILAH-CPU/CGA_IDBCTL/circuit -I../DELILAH-CPU/CGA_INTR/circuit -I../DELILAH-CPU/CGA_MAC/circuit -I../DELILAH-CPU/CGA_MIC/circuit -I../DELILAH-CPU/CGA_TESTMUX/circuit -I../DELILAH-CPU/CGA_TRAP/circuit -I../DELILAH-CPU/CGA_WRF/circuit -I../DELILAH-CPU/CGA/circuit
DGA_COMPONENTS = -I../DECODE-GateArray/DGA/circuit

#SHARED_COMPONENTS =  -I../circuit --I../../shared/ndlib --I../../shared/logisim --I../../shared/gates   --I../../PAL

# -I.. = the Verilog root, where ND120_CORE.v (instantiated by ND120_TOP.v) lives
VERILATOR_DIRS = -I.. $(TOP_3202D_COMPONENTS) $(CGA_COMPONENTS) $(DGA_COMPONENTS) -I../PAL
# Specify C++ source files here
CPP_SOURCES = test_nd120.cpp ../simDevices/NDDevices.cpp ../simDevices/NDBus.cpp

# Default target
all: test_nd120 run gtk

test_nd120: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS) --exe $(CPP_SOURCES)  -CFLAGS "$(VERILATOR_DIRS)  -I../../simDevices $(CPP_DEFINES)"
	cd obj_dir && make -f VND120_TOP.mk VND120_TOP

clean:
	rm -rf obj_dir obj_dir_latch obj_dir_ff

run: test_nd120
	./obj_dir/VND120_TOP

gtk: run
	# FST format: compressed, indexed, much faster to load than VCD
	gtkwave waveform.fst top_3202d.gtkw &

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

# --- Generic scriptable PROBE (nd120_probe.cpp + nd120_probe.py) ---
# ADDITIVE target: a NEW reusable harness with runtime signal access, a rule
# engine, a PRE/POST CSV ring and a trigger-windowed FST. Built with
# --public-flat-rw (expose internal wires) and --vpi (resolve arbitrary signals
# by name at runtime). Both flags are NON-INVASIVE - no RTL is edited.
#   make probe                 # FF mode default (USE_LATCHES=0) for investigations
# NOTE: default USE_LATCHES for the probe is 0 (FF mode = shipped path).
PROBE_SOURCES = nd120_probe.cpp ../simDevices/NDDevices.cpp ../simDevices/NDBus.cpp
PROBE_DEFINES = -DVERILATOR_SIM
ifneq ($(USE_LATCHES),1)
  # Probe defaults to FF mode unless the caller explicitly sets USE_LATCHES=1.
  PROBE_DEFINES += -DFPGA_FF_MODE
endif

probe: nd120_probe.cpp
	$(VERILATOR) --trace-fst --vpi -Wall --cc ../ND120_TOP.v $(SUPPRESS_FLAGS) $(PROBE_DEFINES) --public-flat-rw $(VERILATOR_DIRS) --exe $(PROBE_SOURCES) -CFLAGS "$(VERILATOR_DIRS) -I../../simDevices" --Mdir obj_dir_probe
	cd obj_dir_probe && make -f VND120_TOP.mk VND120_TOP
	@echo "=== probe engine built: obj_dir_probe/VND120_TOP ==="

# --- PROBE variant WITH the Verilog ND bus devices + floppy (TPE boot) -------
# ADDITIVE target: same generic scriptable probe engine, but built so the
# `1560&` MOPC autoload boots TPE from a mounted floppy image - mirroring the
# proven runSim `test-floppy-stdin` recipe (VERILOG_TAPE=1 SD_STORAGE=0):
#   * -DND120_VERILOG_DEVICES to VERILATOR  -> instantiates the Verilog floppy
#     core inside ND120_TOP so IOX 1560-1567 is answered in-RTL (enables 1560&).
#   * -DND120_VERILOG_DEVICES to the C++    -> NDBus.cpp's process_verilog_floppy()
#     path compiles and serves the image named by env ND120_FLOPPY_IMG.
#   * NOT defining ND120_SD_STORAGE (SD_STORAGE=0) -> the floppy bytes come from
#     the host file (ND120_FLOPPY_IMG), not the in-RTL SD-FAT stack.
# Built into its OWN Mdir (obj_dir_probe_floppy) so it never clobbers `probe`.
# Run the engine with:  ND120_FLOPPY_IMG=/mnt/e/.../runSim/FLOPPY1.IMG ./obj_dir_probe_floppy/VND120_TOP
#   make probe-floppy            # FF mode default (USE_LATCHES=0), Verilog floppy on
PROBE_FLOPPY_DEFINES = $(PROBE_DEFINES) -DND120_VERILOG_DEVICES
# The Verilog ND bus device modules (ND_TAPE_400/ND_FLOPPY_DMA/ND_DMA_MASTER/
# ND_SMD) and their SD-FAT helpers live outside the CPU tree - add their include
# dirs so Verilator can find the modules that ND120_VERILOG_DEVICES instantiates.
# Mirrors runSim/Makefile's BUSDEV_COMPONENTS + SDFAT_COMPONENTS. SD_STORAGE=0
# here, so the -v SD-FAT files are NOT needed (the floppy is served from the host
# file via NDBus.cpp), only the -I search paths.
BUSDEV_COMPONENTS = -I../ND-BUS-DEVICES/BUS-IF/circuit -I../ND-BUS-DEVICES/TAPE-400/circuit -I../ND-BUS-DEVICES/DMA/circuit -I../ND-BUS-DEVICES/FLOPPY/circuit -I../ND-BUS-DEVICES/FLOPPY-DMA/circuit -I../ND-BUS-DEVICES/SMD/circuit
SDFAT_COMPONENTS  = -I../SD-FAT/circuit -I../SD-FAT/sim
PROBE_FLOPPY_DIRS = $(VERILATOR_DIRS) $(BUSDEV_COMPONENTS) $(SDFAT_COMPONENTS)

probe-floppy: nd120_probe.cpp
	$(VERILATOR) --trace-fst --vpi -Wall --cc ../ND120_TOP.v $(SUPPRESS_FLAGS) $(PROBE_FLOPPY_DEFINES) --public-flat-rw $(PROBE_FLOPPY_DIRS) --exe $(PROBE_SOURCES) -CFLAGS "$(VERILATOR_DIRS) -I../../simDevices -DND120_VERILOG_DEVICES" --Mdir obj_dir_probe_floppy
	cd obj_dir_probe_floppy && make -f VND120_TOP.mk VND120_TOP
	@echo "=== probe-floppy engine built: obj_dir_probe_floppy/VND120_TOP (mount ND120_FLOPPY_IMG) ==="

# --- PROBE variant with the PORTABLE C FLOPPY CORE (real TPE-MON boot) --------
# ADDITIVE target: mirrors runSim's `run-tpe` device config
#   make compile VERILOG_TAPE=0 SD_STORAGE=0 DEVICECORE=1 DEVICECORE_FLOPPY=1
# i.e. the RTL has NO Verilog bus devices (VERILOG_TAPE=0 -> plain ND120_TOP),
# and the floppy at IOX 1560-1567 is served by the PORTABLE C99 core
# (NDDeviceCore nd_floppy_dma) via the C bus master (NDCoreShim). The Verilog
# floppy is documented to mis-serve real diskettes; the C core is the backend
# that boots the real ND-120/CX "TPE Monitor B01" from runSim/FLOPPY1.IMG.
# The probe engine's reused addDevices() calls addDevicesCore() under
# -DND120_DEVICECORE, and proccess_bif_signal() ticks the C bus master under
# -DND120_DEVICECORE_BUSMASTER, so no engine change is needed.
# Image is chosen at RUN time by env ND120_FLOPPYCORE_IMG (NOT ND120_FLOPPY_IMG).
# Built into its OWN Mdir so it never clobbers probe / probe-floppy.
#   make probe-floppycore        # FF mode default (USE_LATCHES=0)
NDDEVICECORE_DIR ?= $(abspath ../ND-BUS-DEVICES/portable)
# DEVICECORE source set for DEVICECORE=1 DEVICECORE_FLOPPY=1 (=> BUSMASTER=1),
# transcribed from runSim/Makefile so the two builds stay in lock-step.
DEVICECORE_SOURCES = \
  $(NDDEVICECORE_DIR)/src/nd_device.c \
  $(NDDEVICECORE_DIR)/src/nd_char.c \
  $(NDDEVICECORE_DIR)/src/nd_lineprinter.c \
  ../simDevices/NDDeviceCoreAdapter.cpp \
  ../simDevices/NDCoreCharBackend.cpp \
  ../simDevices/NDCoreTrace.cpp \
  $(NDDEVICECORE_DIR)/src/nd_trace.c \
  $(NDDEVICECORE_DIR)/src/nd_dma.c \
  $(NDDEVICECORE_DIR)/src/nd_storage.c \
  $(NDDEVICECORE_DIR)/src/nd_floppy_dma.c \
  ../simDevices/NDCoreBlockBackend.cpp \
  ../simDevices/NDCoreShim.cpp
DEVICECORE_CDEFS = -DND120_DEVICECORE -DND120_DEVICECORE_FLOPPY -DND120_DEVICECORE_BUSMASTER -I$(NDDEVICECORE_DIR)/include
PROBE_FC_SOURCES = $(PROBE_SOURCES) $(DEVICECORE_SOURCES)

probe-floppycore: nd120_probe.cpp
	$(VERILATOR) --trace-fst --vpi -Wall --cc ../ND120_TOP.v $(SUPPRESS_FLAGS) $(PROBE_DEFINES) --public-flat-rw $(VERILATOR_DIRS) --exe $(PROBE_FC_SOURCES) -CFLAGS "$(VERILATOR_DIRS) -I../../simDevices $(DEVICECORE_CDEFS)" --Mdir obj_dir_probe_floppycore
	cd obj_dir_probe_floppycore && make -f VND120_TOP.mk VND120_TOP
	@echo "=== probe-floppycore engine built: obj_dir_probe_floppycore/VND120_TOP (set ND120_FLOPPYCORE_IMG) ==="

.PHONY: all clean probe probe-floppy probe-floppycore compare compare_latch compare_ff
