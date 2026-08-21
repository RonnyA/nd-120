# UPDATE NEXT 3 LINES PR TEST PROGRAM
TOP_FILE = CGA_DCD
TEST_PROGRAM = test_dcd.cpp
TEST_FOLDER = ${TOP_FILE}

# This is the path to the root of the verilog directory
VERILOG_ROOT = ../../..


SHARED_COMPONENTS = -I${VERILOG_ROOT}/shared/ndlib --I${VERILOG_ROOT}/shared/logisim --I${VERILOG_ROOT}/shared/support

DELILAH_ROOT = ${VERILOG_ROOT}/DELILAH-CPU
COMPONENT_ROOT = ${DELILAH_ROOT}/${TEST_FOLDER}/circuit

SUPPRESS_FLAGS = -Wno-PINCONNECTEMPTY  -Wno-UNUSED  -Wno-WIDTH  #-Wno-UNDRIVEN  
VERILATOR_FLAGS = --trace -Wall --cc ${COMPONENT_ROOT}/${TOP_FILE}.v --exe ${TEST_PROGRAM} $(SUPPRESS_FLAGS)  

CGA_COMPONENTS = --I${COMPONENT_ROOT} -I${DELILAH_ROOT}/CGA_ALU/circuit -I${DELILAH_ROOT}/CGA_DCD/circuit -I${DELILAH_ROOT}/CGA_IDBCTL/circuit -I${DELILAH_ROOT}/CGA_INTR/circuit -I${DELILAH_ROOT}/CGA_MAC/circuit -I${DELILAH_ROOT}/CGA_MIC/circuit -I${DELILAH_ROOT}/CGA_TESTMUX/circuit -I${DELILAH_ROOT}/CGA_TRAP/circuit -I${DELILAH_ROOT}/CGA_WRF/circuit
VERILATOR_DIRS = -I${COMPONENT_ROOT} ${SHARED_COMPONENTS} $(CGA_COMPONENTS)

VERILATOR = verilator

# Specify C++ source files here
CPP_SOURCES = test_dcd.cpp

# Default target
all: test_dcd run gtk

test_dcd: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_DCD.mk VCGA_DCD

clean:
	rm -rf obj_dir

run: test_dcd
	./obj_dir/VCGA_DCD

gtk: run
	gtkwave waveform.vcd dcd.gtkw &

# --- iverilog gate-level testbenches (self-checking, TB_RESULT: PASS) --------
# Generic rule: `make iv-<MODULE>` compiles+runs <MODULE>_tb.v against the gate
# netlists (Shared libs + circuit/ resolved via -y). Registered per-tb in
# tests/run_all_tests.sh.
IV_LIB = -y ${VERILOG_ROOT}/Shared/logisim -y ${VERILOG_ROOT}/Shared/support -y ${VERILOG_ROOT}/Shared/ndlib
iv-%:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_$* $*_tb.v && vvp -N /tmp/ndtb_$*

# --- CGA_DCD sheet 10 (p.75) DVACCN + VACCN decode, TWO builds --------------
# Exhaustive sweep of CSCOMM x CSMIS x LCSN x PONI x VEX x LSHADOW x INTRQN,
# twice (EMCLN=0 and EMCLN=1), against a golden re-derived from the drawing's
# gate labels (34.3/35.3, 37.2/37.3, ND2) - not from the RTL gate expressions.
# Both build modes are run because the DVACC flip-flop is MCLK-clocked and
# FPGA_FF_MODE moves it onto sysclk+MCLK_EN.
VACC_MODES = "" "-DFPGA_FF_MODE"
test-dcd-vacc:
	for m in $(VACC_MODES); do \
	  iverilog -g2012 $$m $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_dcd_vacc CGA_DCD_VACC_tb.v && vvp -N /tmp/ndtb_dcd_vacc || exit 1; \
	done

# Teeth check: the golden is deliberately corrupted, so BOTH builds must print
# TB_RESULT: FAIL. A silent pass here means the checker is not checking.
test-dcd-vacc-teeth:
	for m in $(VACC_MODES); do \
	  iverilog -g2012 $$m -DTEETH_TEST $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_dcd_vacc_teeth CGA_DCD_VACC_tb.v && vvp -N /tmp/ndtb_dcd_vacc_teeth || exit 1; \
	done

# --- CGA_DCD sheet 8 (p.72) IDB source enables, TWO builds ------------------
# Sweeps CSIDBS_4_0 (32 codes) x LCSN and asserts the ONE-HOT property the
# CGA_IDBCTL source OR relies on: at most one of EPGSN/EPCRN/EPICSN/EPICVN
# active per code, each active for exactly one code, none active with LCSN=0.
# The decoded octal codes are DISCOVERED by the sweep and printed. Also
# reports that EPICMASKN comes from the CSCOMM field, a different microcode
# field, so it is NOT mutually exclusive with these four by construction.
test-dcd-idbs-enables:
	for m in $(VACC_MODES); do \
	  iverilog -g2012 $$m $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_dcd_idbs_en CGA_DCD_IDBS_ENABLES_tb.v && vvp -N /tmp/ndtb_dcd_idbs_en || exit 1; \
	done

.PHONY: all clean test-dcd-vacc test-dcd-vacc-teeth test-dcd-idbs-enables
