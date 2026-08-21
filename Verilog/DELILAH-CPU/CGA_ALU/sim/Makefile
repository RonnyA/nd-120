# UPDATE NEXT 3 LINES PR TEST PROGRAM
TOP_FILE = CGA_ALU
TEST_PROGRAM = test_alu.cpp
TEST_FOLDER = ${TOP_FILE}

# This is the path to the root of the verilog directory
VERILOG_ROOT = ../../..


SHARED_COMPONENTS = -I${VERILOG_ROOT}/shared/ndlib --I${VERILOG_ROOT}/shared/logisim --I${VERILOG_ROOT}/shared/support

DELILAH_ROOT = ${VERILOG_ROOT}/DELILAH-CPU
COMPONENT_ROOT = ${DELILAH_ROOT}/${TEST_FOLDER}/circuit

SUPPRESS_FLAGS = -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH
VERILATOR_FLAGS = --trace -Wall --cc ${COMPONENT_ROOT}/${TOP_FILE}.v --exe ${TEST_PROGRAM} $(SUPPRESS_FLAGS)  

CGA_COMPONENTS = --I${COMPONENT_ROOT}  -I${DELILAH_ROOT}/CGA_DCD/circuit -I${DELILAH_ROOT}/CGA_IDBCTL/circuit -I${DELILAH_ROOT}/CGA_INTR/circuit -I${DELILAH_ROOT}/CGA_MAC/circuit -I${DELILAH_ROOT}/CGA_MIC/circuit -I${DELILAH_ROOT}/CGA_TESTMUX/circuit -I${DELILAH_ROOT}/CGA_TRAP/circuit -I${DELILAH_ROOT}/CGA_WRF/circuit
VERILATOR_DIRS = -I${COMPONENT_ROOT} ${SHARED_COMPONENTS} $(CGA_COMPONENTS)

VERILATOR = verilator

# Specify C++ source files here
CPP_SOURCES = ${TEST_PROGRAM}

# Default target
all: test_alu run gtk

test_alu: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA_ALU.mk VCGA_ALU

# --- iverilog gate-level testbenches (self-checking, TB_RESULT: PASS) --------
# Generic rule: `make iv-<MODULE>` compiles+runs <MODULE>_tb.v against the gate
# netlists (Shared libs + circuit/ resolved via -y). Registered per-tb in
# tests/run_all_tests.sh.
IV_LIB = -y ${VERILOG_ROOT}/Shared/logisim -y ${VERILOG_ROOT}/Shared/support -y ${VERILOG_ROOT}/Shared/ndlib
iv-%:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_$* $*_tb.v && vvp -N /tmp/ndtb_$*

# --- CGA_ALU_SWAP exhaustive swap-register verification, BOTH build modes ----
# 20 directed golden vectors + exhaustive 65536-value sweep vs the independent
# byte-swap model + hold-without-clock checks. Registered module (2x R81_EN):
# run twice, default latch/CP mode then FPGA_FF_MODE (ALUCLK_EN-gated sysclk
# capture). Registered in tests/run_all_tests.sh.
test-alu-swap:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_swap CGA_ALU_SWAP_tb.v && vvp -N /tmp/ndtb_alu_swap
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_swap_ff CGA_ALU_SWAP_tb.v && vvp -N /tmp/ndtb_alu_swap_ff

# --- CGA_CPU_ALU_OUTMUX_SEL7 exhaustive verification -------------------------
# All 16384 {SI,E} combinations vs an embedded independently generated golden
# table. Pure combinational (logisim gates only, no FF/latch primitives):
# a single build mode covers it. Registered in tests/run_all_tests.sh.
test-alu-sel7:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_sel7 CGA_CPU_ALU_OUTMUX_SEL7_tb.v && vvp -N /tmp/ndtb_alu_sel7

# --- CGA_ALU_OUTMUX_SEL8 exhaustive verification -----------------------------
# All 65536 {SI,E} combinations vs an embedded independently generated golden
# table. Pure combinational (logisim gates only, no FF/latch primitives):
# a single build mode covers it. Registered in tests/run_all_tests.sh.
test-alu-sel8:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_sel8 CGA_ALU_OUTMUX_SEL8_tb.v && vvp -N /tmp/ndtb_alu_sel8

# --- CGA_ALU_RALU_MUX216L verification ---------------------------------------
# 8 directed golden vectors + per-slice exhaustive (16 slices x 8 combos x 2
# backgrounds, full-width checked) + 4096 fixed-seed LFSR full-width vectors
# vs the independent O = S ? ~F : ~T model. Pure combinational (MUX21LP is
# assign-only): a single build mode covers it. Registered in
# tests/run_all_tests.sh.
test-alu-mux216l:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_mux216l CGA_ALU_RALU_MUX216L_tb.v && vvp -N /tmp/ndtb_alu_mux216l

# --- CGA_CPU_ALU_RMUX verification -------------------------------------------
# 10 directed golden vectors + per-slice exhaustive (16 slices x 16 combos x 2
# backgrounds, full-width checked) + 4096 fixed-seed LFSR vectors + Python
# checksum, vs the independent RN = ~((A&RA)|(D&RD)) model. Pure combinational
# (AND/NOR gates only): a single build mode covers it. Registered in
# tests/run_all_tests.sh.
test-alu-rmux:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_rmux CGA_CPU_ALU_RMUX_tb.v && vvp -N /tmp/ndtb_alu_rmux

# --- CGA_ALU_RALU_LOGOP verification -----------------------------------------
# 10 directed golden vectors + per-slice exhaustive (16 slices x 16 combos x 2
# backgrounds, full-width checked) + 4096 fixed-seed LFSR vectors + Python
# checksum, vs the independent LF = (S&A&FSEL)|((S^A)&ALU14) model. Pure
# combinational (MUX41P is assign-only): a single build mode covers it.
# Registered in tests/run_all_tests.sh.
test-alu-logop:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_logop CGA_ALU_RALU_LOGOP_tb.v && vvp -N /tmp/ndtb_alu_logop

# --- CGA_ALU_SMUX verification -----------------------------------------------
# 12 directed golden vectors + per-slice exhaustive (16 slices x 32 combos x 2
# backgrounds, full-width checked) + 4096 fixed-seed LFSR vectors + Python
# checksum, vs the independent {SB,SA}->Q/B/0/A model. Pure combinational
# (MUX41P is assign-only): a single build mode covers it. Registered in
# tests/run_all_tests.sh.
test-alu-smux:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_smux CGA_ALU_SMUX_tb.v && vvp -N /tmp/ndtb_alu_smux

# --- CGA_ALU_SHIFT EXHAUSTIVE verification -----------------------------------
# 12 directed golden vectors + the ENTIRE 2^20 input space (every {ALUI8N,
# ALUI7} select x every {RLI,RRI} serial-input combo x all 65536 F values) vs
# the independent right/left/pass model. Pure combinational (MUX31LP is
# assign-only): a single build mode covers it. Registered in
# tests/run_all_tests.sh.
test-alu-shift:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_shift CGA_ALU_SHIFT_tb.v && vvp -N /tmp/ndtb_alu_shift

# --- CGA_ALU_DBR exhaustive verification, BOTH build modes -------------------
# 24 directed golden vectors + exhaustive 65536-value load sweep + 256 hold
# events + no-clock hold checks + whole-sequence checksum vs the independent
# Python model (load CD when LDDBRN=0, else hold). Registered module (16x
# SCAN_FF_EN): run twice, default latch/CP mode then FPGA_FF_MODE.
test-alu-dbr:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_dbr CGA_ALU_DBR_tb.v && vvp -N /tmp/ndtb_alu_dbr
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_dbr_ff CGA_ALU_DBR_tb.v && vvp -N /tmp/ndtb_alu_dbr_ff

# --- CGA_ALU_QREG exhaustive verification, BOTH build modes ------------------
# 26 directed golden vectors (incl. the MUXQ15 bit-15 mux battery guarding the
# historical MPY D3 bug: shift-right with F[0] != Q[0]) + walking-one
# shift-left/right flush loops + serial QLI/F[0] streams + 4096 fixed-seed
# LFSR steps + whole-sequence checksum vs the independent Python model.
# Registered module (2x R81_EN): run twice, default latch/CP mode then
# FPGA_FF_MODE.
test-alu-qreg:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_qreg CGA_ALU_QREG_tb.v && vvp -N /tmp/ndtb_alu_qreg
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_qreg_ff CGA_ALU_QREG_tb.v && vvp -N /tmp/ndtb_alu_qreg_ff

# --- CGA_ALU_STS exhaustive verification, BOTH build modes -------------------
# 22 directed golden vectors (every CSTS mode on both backgrounds, sticky-OVF
# bit-5 cases, byte-split LDPILN/CSTS loads) + 4096 fixed-seed LFSR steps +
# no-clock hold checks + whole-sequence checksum vs the independent Python
# model. Registered module (SCAN_FF_EN + R41P_EN): run twice, default latch/CP
# mode then FPGA_FF_MODE.
test-alu-sts:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_sts CGA_ALU_STS_tb.v && vvp -N /tmp/ndtb_alu_sts
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_sts_ff CGA_ALU_STS_tb.v && vvp -N /tmp/ndtb_alu_sts_ff

# --- CGA_ALU_ARG exhaustive register verification, BOTH build modes ----------
# Exhaustive 65536-value CSBIT load sweep (bit-for-bit, catches any output
# bus swap/inversion) + no-clock hold + 4000 fixed-seed LFSR soak vs the
# independent clocked golden model. Plain reg on ALUCLK switched by
# FPGA_FF_MODE: run default latch/CP mode then FPGA_FF_MODE. Registered in
# tests/run_all_tests.sh.
test-alu-arg:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_arg CGA_ALU_ARG_tb.v && vvp -N /tmp/ndtb_alu_arg
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_arg_ff CGA_ALU_ARG_tb.v && vvp -N /tmp/ndtb_alu_arg_ff

# --- CGA_ALU_OUTMUX parent-netlist verification, BOTH build modes ------------
# Verifies the selector wiring BETWEEN the submodules (16x SEL8/SEL7 D-mux,
# 16x MUX31LP G-mux, IDBS enable decoder) vs an independent golden model:
# exhaustive 32-rcs x 2-ALUD2N select sweep with distinct per-source
# constants, walking-1/0 per data bus, exhaustive LBA/LAA/AARG0 subspace,
# registered-vs-comb seam checks, 25000-step fixed-seed LFSR soak. The IDBS
# decoder is registered (2x R81_EN on ALUCLK): run twice, default latch/CP
# mode then FPGA_FF_MODE. Registered in tests/run_all_tests.sh.
test-alu-outmux:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_outmux CGA_ALU_OUTMUX_tb.v && vvp -N /tmp/ndtb_alu_outmux
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_outmux_ff CGA_ALU_OUTMUX_tb.v && vvp -N /tmp/ndtb_alu_outmux_ff

# --- CGA_CPU_ALU_CONTR verification, THREE build modes -----------------------
# ALU controller (page 42): exhaustive 2-tuple x 4-CSALUM x 512-CSALUI control
# sweep, 4-state x 1024-combo async/comb sweep with no clock event (hold
# proof), SSEL-latch late-data directed tests (locks in the FIXED transparent
# LDIRV capture - the historical bug ran every ROT/ZIN-right/LIN shift as a
# plain shift), 4000-step fixed-seed soak; all 21 outputs vs an independent
# behavioral golden model. Mixed ALUCLK registers + L8 LDIRV latch: run three
# builds - plain / FPGA_FF_MODE / USE_TRANSPARENT_LATCHES (SEGPT matrix).
# Registered in tests/run_all_tests.sh.
test-alu-contr:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_contr CGA_CPU_ALU_CONTR_tb.v && vvp -N /tmp/ndtb_alu_contr
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_contr_ff CGA_CPU_ALU_CONTR_tb.v && vvp -N /tmp/ndtb_alu_contr_ff
	iverilog -g2012 -DUSE_TRANSPARENT_LATCHES $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_contr_lat CGA_CPU_ALU_CONTR_tb.v && vvp -N /tmp/ndtb_alu_contr_lat

clean:
	rm -rf obj_dir

run: test_alu
	./obj_dir/VCGA_ALU

gtk:
	gtkwave waveform.vcd alu.gtkw &

.PHONY: all clean


# --- CGA_ALU_GPR verification, BOTH build modes ------------------------------
# Walking one/zero on FIDBO and CD, both shift directions incl. the GPRLI and
# zero fills, hold via GPRC[2], and 512 fixed-seed LFSR steps against the
# per-bit MUX41P map read off CGA_ALU_GPR.v. DGPR0N is checked on every step.
# Registered (SCAN_FF_EN + D_FLIPFLOP_EN switched by FPGA_FF_MODE): run twice.
# Registered in tests/run_all_tests.sh.
test-alu-gpr:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_gpr CGA_ALU_GPR_tb.v && vvp -N /tmp/ndtb_alu_gpr
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_gpr_ff CGA_ALU_GPR_tb.v && vvp -N /tmp/ndtb_alu_gpr_ff

# --- CGA_ALU_OUTMUX_IDBS exhaustive verification, BOTH build modes -----------
# All 32 CSIDBS codes x both ALUD2N phases against the two-decoder + NAND
# transcription, plus the combinational EA/EF steering and a register hold.
# Registered (2x R81_EN switched by FPGA_FF_MODE): run twice.
# Registered in tests/run_all_tests.sh.
test-alu-outmux-idbs:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_idbs CGA_ALU_OUTMUX_IDBS_tb.v && vvp -N /tmp/ndtb_alu_idbs
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_idbs_ff CGA_ALU_OUTMUX_IDBS_tb.v && vvp -N /tmp/ndtb_alu_idbs_ff

# --- CGA_CPU_ALU_RALU verification -------------------------------------------
# All 32 control combinations x walking one/zero on both operand buses x carry
# corners, plus 2048 LFSR vectors; F, CRY, ZF, SGR and OVF checked every time.
# Purely combinational - built both ways to prove FPGA_FF_MODE cannot reach it.
# Registered in tests/run_all_tests.sh.
test-cpu-alu-ralu:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_cpu_alu_ralu CGA_CPU_ALU_RALU_tb.v && vvp -N /tmp/ndtb_cpu_alu_ralu
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_cpu_alu_ralu_ff CGA_CPU_ALU_RALU_tb.v && vvp -N /tmp/ndtb_cpu_alu_ralu_ff

# --- CGA_ALU top-level integration / wiring map, BOTH build modes ------------
# Asserts the port-to-port map of the thirteen sub-circuits, the STS output
# taps, the FIDBO inversion and the registered AARG0 selector over 128
# pseudo-random microcode words. Does NOT re-model what the ALU computes -
# see the header of CGA_ALU_tb.v. Registered in tests/run_all_tests.sh.
test-alu-top:
	iverilog -g2012 $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_top CGA_ALU_tb.v && vvp -N /tmp/ndtb_alu_top
	iverilog -g2012 -DFPGA_FF_MODE $(IV_LIB) -y ${COMPONENT_ROOT} -o /tmp/ndtb_alu_top_ff CGA_ALU_tb.v && vvp -N /tmp/ndtb_alu_top_ff
