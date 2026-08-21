# UPDATE NEXT 3 LINES PR TEST PROGRAM
TOP_FILE = CGA_MIC
TEST_PROGRAM = test_mic.cpp
TEST_FOLDER = ${TOP_FILE}

# This is the path to the root of the verilog directory
VERILOG_ROOT = ../../..


SHARED_COMPONENTS = -I${VERILOG_ROOT}/shared/ndlib --I${VERILOG_ROOT}/shared/logisim --I${VERILOG_ROOT}/shared/support

DELILAH_ROOT = ${VERILOG_ROOT}/DELILAH-CPU
COMPONENT_ROOT = ${DELILAH_ROOT}/${TEST_FOLDER}/circuit

SUPPRESS_FLAGS = -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH  -Wno-LATCH
VERILATOR_FLAGS = --trace -Wall --cc ${COMPONENT_ROOT}/${TOP_FILE}.v --exe ${TEST_PROGRAM} $(SUPPRESS_FLAGS)  

CGA_COMPONENTS = --I${COMPONENT_ROOT} -I${DELILAH_ROOT}/CGA_ALU/circuit -I${DELILAH_ROOT}/CGA_DCD/circuit -I${DELILAH_ROOT}/CGA_IDBCTL/circuit -I${DELILAH_ROOT}/CGA_INTR/circuit -I${DELILAH_ROOT}/CGA_MAC/circuit -I${DELILAH_ROOT}/CGA_MIC/circuit -I${DELILAH_ROOT}/CGA_TESTMUX/circuit -I${DELILAH_ROOT}/CGA_TRAP/circuit -I${DELILAH_ROOT}/CGA_WRF/circuit
VERILATOR_DIRS = -I${COMPONENT_ROOT} ${SHARED_COMPONENTS} $(CGA_COMPONENTS)

VERILATOR = verilator

# Specify C++ source files here
CPP_SOURCES = ${TEST_PROGRAM}

# Default target
all: test_mic run gtk

test_mic: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_MIC.mk VCGA_MIC

clean:
	rm -rf obj_dir

run: test_mic
	./obj_dir/VCGA_MIC

gtk: run
	gtkwave waveform.vcd mic.gtkw &

# ---------------------------------------------------------------
# iverilog testbenches for MASEL submodule
# These test CGA_MIC_MASEL.v in isolation using iverilog (not Verilator).
# ---------------------------------------------------------------
IVERILOG = iverilog
INC_PATHS = -I${VERILOG_ROOT}/Shared/logisim \
            -I${VERILOG_ROOT}/Shared/ndlib \
            -I${VERILOG_ROOT}/Shared/support \
            -I${DELILAH_ROOT}/CGA_MIC/circuit

MASEL_SRC = ${DELILAH_ROOT}/CGA_MIC/circuit/CGA_MIC_MASEL.v

MASEL_cycle_tb: MASEL_cycle_tb.v $(MASEL_SRC)
	$(IVERILOG) -g2012 $(INC_PATHS) -o $@ $^

MASEL_iw_capture_tb: MASEL_iw_capture_tb.v $(MASEL_SRC)
	$(IVERILOG) -g2012 $(INC_PATHS) -o $@ $^

test-masel-cycle: MASEL_cycle_tb
	./MASEL_cycle_tb

test-masel-iw: MASEL_iw_capture_tb
	./MASEL_iw_capture_tb

CGA_MIC_MASEL_tb: CGA_MIC_MASEL_tb.v $(MASEL_SRC)
	$(IVERILOG) -g2012 $(INC_PATHS) -o $@ $^

test-masel-basic: CGA_MIC_MASEL_tb
	./CGA_MIC_MASEL_tb

test-masel: test-masel-cycle test-masel-iw test-masel-basic

# ---------------------------------------------------------------
# iverilog gate-level testbenches (self-checking, TB_RESULT: PASS)
# Generic rule: `make iv-<MODULE>` compiles+runs <MODULE>_tb.v against the
# gate netlists (Shared libs + circuit/ resolved via -y). Registered
# per-tb in tests/run_all_tests.sh.
# ---------------------------------------------------------------
IV_LIB = -y ${VERILOG_ROOT}/Shared/logisim -y ${VERILOG_ROOT}/Shared/support -y ${VERILOG_ROOT}/Shared/ndlib
iv-%:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_$* $*_tb.v && vvp -N /tmp/ndtb_$*

# --- CGA_MIC_CSEL exhaustive condition-select verification, BOTH modes ----
# 32 directed golden vectors (gen_mic_golden.py) + exhaustive 262144-value
# sweep vs the independent mux-tree model + latch hold checks. Contains the
# ndlib LATCH (switched by USE_TRANSPARENT_LATCHES, not FPGA_FF_MODE): run
# default mode then -DUSE_TRANSPARENT_LATCHES. Registered in
# tests/run_all_tests.sh.
test-mic-csel:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_csel CGA_MIC_CSEL_tb.v && vvp -N /tmp/ndtb_mic_csel
	iverilog -g2012 -DUSE_TRANSPARENT_LATCHES $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_csel_tl CGA_MIC_CSEL_tb.v && vvp -N /tmp/ndtb_mic_csel_tl

# --- CGA_MIC_INCOUNT exhaustive counter verification, BOTH build modes ----
# Async preset + inverting load + exhaustive 64-transition table (golden
# table from gen_mic_golden.py) + wrap sequence + hold-without-clock.
# Registered module (2x D_FLIPFLOP_EN on MCLK): run twice, default latch/CP
# mode then FPGA_FF_MODE (MCLK_EN-gated sysclk capture). Registered in
# tests/run_all_tests.sh.
test-mic-incount:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_incount CGA_MIC_INCOUNT_tb.v && vvp -N /tmp/ndtb_mic_incount
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_incount_ff CGA_MIC_INCOUNT_tb.v && vvp -N /tmp/ndtb_mic_incount_ff

# --- CGA_MIC_IINC exhaustive increment verification ------------------------
# All 16384 {CIN,IW} combinations vs the independent gate-level carry-skip
# model (re-derived from the _OLD_WAY_ schematic netlist) + 8 directed
# golden vectors. Pure combinational: a single build mode covers it.
# Registered in tests/run_all_tests.sh.
test-mic-iinc:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_iinc CGA_MIC_IINC_tb.v && vvp -N /tmp/ndtb_mic_iinc

# --- CGA_MIC_IPOS microcode-address selector verification ------------------
# 16 directed golden vectors (gate-equation Python model) + exhaustive 3-bit
# control cone x 44 walking/corner data patterns + 4096 fixed-seed LFSR
# full-width vectors vs the independent priority model. Pure combinational:
# a single build mode covers it. Registered in tests/run_all_tests.sh.
test-mic-ipos:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_ipos CGA_MIC_IPOS_tb.v && vvp -N /tmp/ndtb_mic_ipos

# --- CGA_MIC_STACK_BIT exhaustive stack-cell verification, BOTH modes -----
# Exhaustive 16-state x 64-input transition table with 3-pop readout of the
# hidden SR44 bits, golden checksum vs gen_mic_stack_golden.py, rise/fall
# clock-domain split + stale-ff + hold checks. Two derived-clock registers
# (D_FLIPFLOP_EN on MCLK rise, SR44_EN on MCLK fall): run default latch/CP
# mode then FPGA_FF_MODE. Registered in tests/run_all_tests.sh.
test-mic-stackbit:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_stackbit CGA_MIC_STACK_BIT_tb.v && vvp -N /tmp/ndtb_mic_stackbit
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_stackbit_ff CGA_MIC_STACK_BIT_tb.v && vvp -N /tmp/ndtb_mic_stackbit_ff

# --- CGA_MIC_STACK_BIT12 exhaustive stack-cell verification, BOTH modes ---
# Same exhaustive table as STACK_BIT (identical gate network) with the DEEP
# (=QD) output checked at every observation point. Run default latch/CP
# mode then FPGA_FF_MODE. Registered in tests/run_all_tests.sh.
test-mic-stackbit12:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_stackbit12 CGA_MIC_STACK_BIT12_tb.v && vvp -N /tmp/ndtb_mic_stackbit12
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_stackbit12_ff CGA_MIC_STACK_BIT12_tb.v && vvp -N /tmp/ndtb_mic_stackbit12_ff

# --- CGA_MIC_STACK integration verification, BOTH modes -------------------
# Full 4-deep 13-bit return stack: directed push/pop/load/hold sequences
# across the depth boundary (underflow duplication, 5-push overflow),
# rise-captured NEXT vs fall update, 2000-op fixed-seed LFSR soak with
# golden checksum vs gen_mic_stack_golden.py. Run default latch/CP mode
# then FPGA_FF_MODE. Registered in tests/run_all_tests.sh.
test-mic-stack:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_stack CGA_MIC_STACK_tb.v && vvp -N /tmp/ndtb_mic_stack
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_stack_ff CGA_MIC_STACK_tb.v && vvp -N /tmp/ndtb_mic_stack_ff

# --- CGA_MIC_WCAREG exhaustive register verification, BOTH modes ----------
# Exhaustive 65536-value CD load sweep (WCA=CD[14:2], WCSN=~CD15&LCSN for
# both LCSN values), golden checksum vs gen_mic_stack_golden.py, clocked
# hold + no-clock hold. 14x SCAN_FF_EN on MCLK: run default latch/CP mode
# then FPGA_FF_MODE. Registered in tests/run_all_tests.sh.
test-mic-wcareg:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_wcareg CGA_MIC_WCAREG_tb.v && vvp -N /tmp/ndtb_mic_wcareg
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_wcareg_ff CGA_MIC_WCAREG_tb.v && vvp -N /tmp/ndtb_mic_wcareg_ff

# --- CGA_MIC_MASEL_REPEAT register verification, BOTH modes ---------------
# Defining clear + exhaustive 8192-value REP load sweep + SC5/SC6 no-effect
# pin (dead s_hack wire) + synchronous-MPN-clear pin + no-clock hold + 4000
# fixed-seed LFSR soak vs the independent clocked golden model. Plain reg
# on MCLK switched by FPGA_FF_MODE: run default latch/CP mode then
# FPGA_FF_MODE. Registered in tests/run_all_tests.sh.
test-mic-repeat:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_repeat CGA_MIC_MASEL_REPEAT_tb.v && vvp -N /tmp/ndtb_mic_repeat
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_repeat_ff CGA_MIC_MASEL_REPEAT_tb.v && vvp -N /tmp/ndtb_mic_repeat_ff

# --- CGA_MIC_CONDREG exhaustive register verification, BOTH modes ---------
# Exhaustive 4096-value CSBIT load sweep with all four outputs (LCC, FS,
# TSEL, ACONDN) checked for both LCSN values, golden checksum vs
# gen_mic_stack_golden.py, clocked hold + no-clock hold. 12x SCAN_FF_EN on
# MCLK: run default latch/CP mode then FPGA_FF_MODE. Registered in
# tests/run_all_tests.sh.
test-mic-condreg:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_condreg CGA_MIC_CONDREG_tb.v && vvp -N /tmp/ndtb_mic_condreg
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_condreg_ff CGA_MIC_CONDREG_tb.v && vvp -N /tmp/ndtb_mic_condreg_ff

.PHONY: all clean test-masel test-masel-cycle test-masel-iw test-masel-basic \
        test-mic-csel test-mic-incount test-mic-iinc test-mic-ipos \
        test-mic-stackbit test-mic-stackbit12 test-mic-stack \
        test-mic-wcareg test-mic-condreg test-mic-repeat

# --- CGA_MIC top-level integration / wiring map, ALL FOUR build modes --------
# Asserts the port-to-port map of the eight sub-circuits and the output taps,
# and independently models the IR latch, the LAA/LBA operand select (exhaustive
# over CSRASEL x CSRBSEL) and the COND flip-flop. Does NOT re-model the
# next-address machine - see the header of CGA_MIC_tb.v.
# Registered in tests/run_all_tests.sh.
test-mic-top:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_top CGA_MIC_tb.v && vvp -N /tmp/ndtb_mic_top
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_top_ff CGA_MIC_tb.v && vvp -N /tmp/ndtb_mic_top_ff
	iverilog -g2012 -DUSE_TRANSPARENT_LATCHES $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_top_lat CGA_MIC_tb.v && vvp -N /tmp/ndtb_mic_top_lat
	iverilog -g2012 -DFPGA_FF_MODE -DUSE_TRANSPARENT_LATCHES $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_mic_top_fflat CGA_MIC_tb.v && vvp -N /tmp/ndtb_mic_top_fflat
