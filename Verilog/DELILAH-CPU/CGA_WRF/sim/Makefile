# UPDATE NEXT 3 LINES PR TEST PROGRAM
TOP_FILE = CGA_WRF
TEST_PROGRAM = test_wrf.cpp
TEST_FOLDER = ${TOP_FILE}

#SUPPRESS_FLAGS = -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH -Wno-LATCH
SUPPRESS_FLAGS = -Wno-LATCH -Wno-WIDTHEXPAND


# This is the path to the root of the verilog directory
VERILOG_ROOT = ../../..

SHARED_COMPONENTS = -I${VERILOG_ROOT}/shared/ndlib --I${VERILOG_ROOT}/shared/logisim --I${VERILOG_ROOT}/shared/support

DELILAH_ROOT = ${VERILOG_ROOT}/DELILAH-CPU
COMPONENT_ROOT = ${DELILAH_ROOT}/${TEST_FOLDER}/circuit

VERILATOR_FLAGS = --trace -Wall --cc ${COMPONENT_ROOT}/${TOP_FILE}.v --exe ${TEST_PROGRAM} $(SUPPRESS_FLAGS)  

CGA_COMPONENTS = --I${COMPONENT_ROOT} -I${DELILAH_ROOT}/CGA_ALU/circuit -I${DELILAH_ROOT}/CGA_DCD/circuit -I${DELILAH_ROOT}/CGA_IDBCTL/circuit -I${DELILAH_ROOT}/CGA_INTR/circuit -I${DELILAH_ROOT}/CGA_MAC/circuit -I${DELILAH_ROOT}/CGA_MIC/circuit -I${DELILAH_ROOT}/CGA_TESTMUX/circuit -I${DELILAH_ROOT}/CGA_TRAP/circuit -I${DELILAH_ROOT}/CGA_WRF/circuit
VERILATOR_DIRS = -I${COMPONENT_ROOT} ${SHARED_COMPONENTS} $(CGA_COMPONENTS)

VERILATOR = verilator

# Specify C++ source files here
CPP_SOURCES = ${TEST_PROGRAM}

# Default target
all: test_wrf run gtk

test_wrf: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_WRF.mk VCGA_WRF

# --- iverilog gate-level testbenches (self-checking, TB_RESULT: PASS) --------
# Generic rule: `make iv-<MODULE>` compiles+runs <MODULE>_tb.v against the gate
# netlists (Shared libs + circuit/ resolved via -y). Registered per-tb in
# tests/run_all_tests.sh.
IV_LIB = -y ${VERILOG_ROOT}/Shared/logisim -y ${VERILOG_ROOT}/Shared/support -y ${VERILOG_ROOT}/Shared/ndlib
iv-%:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_$* $*_tb.v && vvp -N /tmp/ndtb_$*

# --- CGA_WRF_RBLOCK_SEL16 verification ---------------------------------------
# 8 directed corners + per-A02-slice exhaustive (8 slices x 64 combos) + 4096
# fixed-seed LFSR full-width vectors vs the independent PA=|(SI&EA),
# PB=|(SI&EB) model (generator-cross-checked). Pure combinational: a single
# build mode covers it. Registered in tests/run_all_tests.sh.
test-wrf-sel16:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf_sel16 CGA_WRF_RBLOCK_SEL16_tb.v && vvp -N /tmp/ndtb_wrf_sel16

# --- CGA_WRF_RBLOCK_LR16 verification, ALL THREE build modes -----------------
# Defining load + walking-one/zero writes with WR=0 recirculation + hold +
# 256 fixed-seed LFSR steps vs the independent R-register/L-latch model.
# R81_EN switches on FPGA_FF_MODE, L8 switches on USE_TRANSPARENT_LATCHES:
# run default, FF mode, and transparent-latch mode. Registered in
# tests/run_all_tests.sh.
test-wrf-lr16:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf_lr16 CGA_WRF_RBLOCK_LR16_tb.v && vvp -N /tmp/ndtb_wrf_lr16
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf_lr16_ff CGA_WRF_RBLOCK_LR16_tb.v && vvp -N /tmp/ndtb_wrf_lr16_ff
	iverilog -g2012 -DUSE_TRANSPARENT_LATCHES $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf_lr16_lat CGA_WRF_RBLOCK_LR16_tb.v && vvp -N /tmp/ndtb_wrf_lr16_lat

# --- CGA_WRF_RBLOCK_DR16 verification, BOTH build modes ----------------------
# Exhaustive 65536-value RB load sweep (WR=1, bit-for-bit) + clocked WR=0
# hold + no-clock hold + sys_rst_n no-op pin + 4000 fixed-seed LFSR soak
# with random WR vs the independent clocked golden model. Plain reg on
# ALUCLK switched by FPGA_FF_MODE: run default latch/CP mode then
# FPGA_FF_MODE. Registered in tests/run_all_tests.sh.
test-wrf-dr16:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf_dr16 CGA_WRF_RBLOCK_DR16_tb.v && vvp -N /tmp/ndtb_wrf_dr16
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf_dr16_ff CGA_WRF_RBLOCK_DR16_tb.v && vvp -N /tmp/ndtb_wrf_dr16_ff

# --- CGA_WRF_RBLOCK verification (PARENT level), ALL THREE build modes -------
# Register-file addressing/selection wiring between the already-covered
# SEL16/LR16/DR16 submodules: defining load + full read-back on both ports,
# write-strobe gating, XFETCH-only P load, WR2-over-XFETCH priority,
# read-select corners (0/multi/all enable wired-OR), exhaustive 16x16x2
# walking-1/0 crossbar, PR/BR/XR latch-close semantics, no-clock hold and
# a 4200-step fixed-seed LFSR soak vs an independent register-array model.
# R81_EN/DR16 switch on FPGA_FF_MODE, L8 switches on USE_TRANSPARENT_LATCHES:
# run default, FF mode, and transparent-latch mode. Registered in
# tests/run_all_tests.sh.
test-wrf-rblock:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf_rblock CGA_WRF_RBLOCK_tb.v && vvp -N /tmp/ndtb_wrf_rblock
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf_rblock_ff CGA_WRF_RBLOCK_tb.v && vvp -N /tmp/ndtb_wrf_rblock_ff
	iverilog -g2012 -DUSE_TRANSPARENT_LATCHES $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf_rblock_lat CGA_WRF_RBLOCK_tb.v && vvp -N /tmp/ndtb_wrf_rblock_lat

clean:
	rm -rf obj_dir

run: test_wrf
	./obj_dir/VCGA_WRF

gtk: run
	gtkwave waveform.vcd cga_wrf.gtkw &

.PHONY: all clean


# --- CGA_WRF_RBLOCK_PREG verification, ALL FOUR build modes ------------------
# Walking one/zero on RB and NLCA, recirculate hold, WR2-over-XFETCH priority
# and the PR latch transparency window, against the MUX31LP + R81 + L8
# transcription. FPGA_FF_MODE switches the register, USE_TRANSPARENT_LATCHES
# switches the latch: all four combinations must agree.
# Registered in tests/run_all_tests.sh.
test-wrf-preg:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf_preg CGA_WRF_RBLOCK_PREG_tb.v && vvp -N /tmp/ndtb_wrf_preg
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf_preg_ff CGA_WRF_RBLOCK_PREG_tb.v && vvp -N /tmp/ndtb_wrf_preg_ff
	iverilog -g2012 -DUSE_TRANSPARENT_LATCHES $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf_preg_lat CGA_WRF_RBLOCK_PREG_tb.v && vvp -N /tmp/ndtb_wrf_preg_lat
	iverilog -g2012 -DFPGA_FF_MODE -DUSE_TRANSPARENT_LATCHES $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf_preg_fflat CGA_WRF_RBLOCK_PREG_tb.v && vvp -N /tmp/ndtb_wrf_preg_fflat

# --- CGA_WRF top-level verification, ALL FOUR build modes --------------------
# Address-decoder sweep (16x16xBDEST), a walking one written into every bit of
# every one of the 16 registers with a full 16-register read-back after each
# write, the P register source paths, the PR/BR/XR latch windows and 256 LFSR
# steps. Registered in tests/run_all_tests.sh.
test-wrf:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf CGA_WRF_tb.v && vvp -N /tmp/ndtb_wrf
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf_ff CGA_WRF_tb.v && vvp -N /tmp/ndtb_wrf_ff
	iverilog -g2012 -DUSE_TRANSPARENT_LATCHES $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf_lat CGA_WRF_tb.v && vvp -N /tmp/ndtb_wrf_lat
	iverilog -g2012 -DFPGA_FF_MODE -DUSE_TRANSPARENT_LATCHES $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_wrf_fflat CGA_WRF_tb.v && vvp -N /tmp/ndtb_wrf_fflat
