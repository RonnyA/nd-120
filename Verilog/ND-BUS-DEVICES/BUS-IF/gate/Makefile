# ND-BUS SEAM GATE - the authoritative Verilog seam (ND_BUS_SLAVE.v) driven
# against the REAL portable C device cores, in Verilator. No CPU, no hardware.
# Prints "TB_RESULT: PASS" so it slots into the machine-checkable test convention.
#
#   make            - verilate + build + run the gate
#   make clean
#
# Toolchain: a normal `verilator` on PATH (WSL/Linux). On the Windows oss-cad-
# suite the perl `verilator` wrapper is broken - use the real binary + its
# bundled python + w64devkit gcc:
#   export VERILATOR_ROOT=/c/Utils/oss-cad-suite/share/verilator
#   export PATH="/c/Utils/oss-cad-suite/lib:/c/Utils/w64devkit/bin:/c/Utils/oss-cad-suite/bin:$PATH"
#   make VERILATOR=verilator_bin.exe NDDEVICECORE=/e/Dev/Ronny/NDModulE/lib/NDDeviceCore

VERILATOR ?= verilator

# The portable C device cores. INTENDED to be the nd-120 submodule at
# Verilog/ND-BUS-DEVICES/portable once it is wired; until then override to the
# populated NDModulE copy (see the header above).
NDDEVICECORE ?= ../../portable

RTL   := ../circuit/ND_BUS_SLAVE.v
CORES := $(NDDEVICECORE)/src/nd_device.c \
         $(NDDEVICECORE)/src/nd_char.c \
         $(NDDEVICECORE)/src/nd_lineprinter.c

.PHONY: test clean
test:
	$(VERILATOR) --cc --exe --build -j 4 \
	  -CFLAGS "-I$(NDDEVICECORE)/include" \
	  --top-module ND_BUS_SLAVE $(RTL) \
	  nd_bus_gate.cpp $(CORES) -o nd_bus_gate
	./obj_dir/nd_bus_gate

clean:
	rm -rf obj_dir
