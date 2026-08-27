# UPDATE NEXT 3 LINES PR TEST PROGRAM
TOP_FILE = CGA_TRAP
TEST_PROGRAM = test_trap.cpp
TEST_FOLDER = ${TOP_FILE}

SUPPRESS_FLAGS = -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH

# This is the path to the root of the verilog directory
VERILOG_ROOT = ../../..

SHARED_COMPONENTS = -y ${VERILOG_ROOT}/Shared/ndlib -y ${VERILOG_ROOT}/Shared/logisim -y ${VERILOG_ROOT}/Shared/support

DELILAH_ROOT = ${VERILOG_ROOT}/DELILAH-CPU
COMPONENT_ROOT = ${DELILAH_ROOT}/${TEST_FOLDER}/circuit

VERILATOR_FLAGS = --trace -Wall --cc ${COMPONENT_ROOT}/${TOP_FILE}.v --exe ${TEST_PROGRAM} $(SUPPRESS_FLAGS)  

CGA_COMPONENTS = --I${COMPONENT_ROOT} -I${DELILAH_ROOT}/CGA_ALU/circuit -I${DELILAH_ROOT}/CGA_DCD/circuit -I${DELILAH_ROOT}/CGA_IDBCTL/circuit -I${DELILAH_ROOT}/CGA_INTR/circuit -I${DELILAH_ROOT}/CGA_MAC/circuit -I${DELILAH_ROOT}/CGA_MIC/circuit -I${DELILAH_ROOT}/CGA_TESTMUX/circuit -I${DELILAH_ROOT}/CGA_TRAP/circuit -I${DELILAH_ROOT}/CGA_WRF/circuit
VERILATOR_DIRS = -I${COMPONENT_ROOT} ${SHARED_COMPONENTS} $(CGA_COMPONENTS)

VERILATOR = verilator

# Specify C++ source files here
CPP_SOURCES = ${TEST_PROGRAM}

# Default target
all: test_trap run gtk

test_trap: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_TRAP.mk VCGA_TRAP

# --- iverilog gate-level testbenches (self-checking, TB_RESULT: PASS) --------
# Generic rule: `make iv-<MODULE>` compiles+runs <MODULE>_tb.v against the gate
# netlists (Shared libs + circuit/ resolved via -y). Registered per-tb in
# tests/run_all_tests.sh.
IV_LIB = -y ${VERILOG_ROOT}/Shared/logisim -y ${VERILOG_ROOT}/Shared/support -y ${VERILOG_ROOT}/Shared/ndlib
iv-%:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_$* $*_tb.v && vvp -N /tmp/ndtb_$*

# --- paging protection: trap vector AND paging status (PGS) together --------
# CGA_TRAP (p.100/101/102/104) driven together with CGA_IDBCTL_PGSREG (p.98),
# wired as CGA.v wires them (shared FETCHN/VACCN, PVIOL straight across). Every
# case asserts BOTH the trap vector raised AND the resulting PGS word, against
# the ND-110 page-protection semantics (page fault vs protect violation, PGS PM
# and FETCH bits, PGS[11:0] = pagetable<<6 | VPN, ring violation vs ring-down).
# Needs the CGA_IDBCTL circuit directory on the search path as well.
test-trap-pgs-paging:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} \
	  -y ${DELILAH_ROOT}/CGA_IDBCTL/circuit \
	  -o /tmp/ndtb_trap_pgs_paging CGA_TRAP_PGS_paging_tb.v \
	  && vvp -N /tmp/ndtb_trap_pgs_paging

clean:
	rm -rf obj_dir

run: test_trap
	./obj_dir/VCGA_TRAP

gtk: run
	gtkwave waveform.vcd trap.gtkw &

.PHONY: all clean
