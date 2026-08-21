# UPDATE NEXT 3 LINES PR TEST PROGRAM
TOP_FILE = CGA
TEST_PROGRAM = test_cga.cpp
TEST_FOLDER = ${TOP_FILE}

SUPPRESS_FLAGS = -Wno-WIDTH -Wno-UNUSED -Wno-UNDRIVEN -Wno-PINCONNECTEMPTY -Wno-WIDTH -Wno-UNOPTFLAT -Wno-LATCH -Wno-MULTIDRIVEN -Wno-EOFNEWLINE


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
all: test_cga run gtk

test_cga: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS)
	cd obj_dir && make -f VCGA.mk VCGA

clean:
	rm -rf obj_dir

run: test_cga
	./obj_dir/VCGA

gtk: run
	gtkwave waveform.vcd cga.gtkw &

.PHONY: all clean

# iverilog testbench for BusDriver16
IVERILOG = iverilog
VERILOG_ROOT = ../../..

BusDriver16_tb: BusDriver16_tb.v $(VERILOG_ROOT)/DELILAH-CPU/CGA/circuit/BusDriver16.v
	$(IVERILOG) -g2012 -I$(VERILOG_ROOT)/Shared/logisim -I$(VERILOG_ROOT)/Shared/ndlib -I$(VERILOG_ROOT)/Shared/support -o $@ $^

BusDriver16_full_tb: BusDriver16_full_tb.v $(VERILOG_ROOT)/DELILAH-CPU/CGA/circuit/BusDriver16.v
	iverilog -g2012 -o $@ BusDriver16_full_tb.v $(VERILOG_ROOT)/DELILAH-CPU/CGA/circuit/BusDriver16.v

# Pins the full BusDriver16 contract: all 4 EN/TN combinations, walking
# patterns, 500 random vectors, and the three properties a refactor is most
# likely to break (A_OUT ignores EN, A_OUT ignores TN, disabled drives 0 not z).
test-busdriver16-full: BusDriver16_full_tb
	vvp BusDriver16_full_tb | tee bd16full_result.tmp
	@grep -q "TB_RESULT: PASS" bd16full_result.tmp && rm -f bd16full_result.tmp

test-busdriver16: BusDriver16_tb
	./BusDriver16_tb

.PHONY: test-busdriver16

# --- first page-fault freeze register (21-AUG-2026) --------------------------
# ND120_PF_CAPTURE freezes the trap-logic inputs at the TCLK edge that latched
# a page-fault vector, then locks, so the evidence survives to be read out
# after the machine halts. It is only trustworthy if it lands on the RIGHT
# cycle - TVEC is registered, so the causing inputs have already moved on by
# the time the fault is visible. Both modes must pass: the capturing edge
# differs between them but the captured cycle must not.
test-pf-capture:
	iverilog -g2012 -o /tmp/nd_pfcap_latch.vvp \
	  ND120_PF_CAPTURE_tb.v ../circuit/ND120_PF_CAPTURE.v
	vvp -N /tmp/nd_pfcap_latch.vvp | tee pfcap_latch.tmp
	iverilog -g2012 -DFPGA_FF_MODE -o /tmp/nd_pfcap_ff.vvp \
	  ND120_PF_CAPTURE_tb.v ../circuit/ND120_PF_CAPTURE.v
	vvp -N /tmp/nd_pfcap_ff.vvp | tee pfcap_ff.tmp
	@grep -q "TB_RESULT: PASS" pfcap_latch.tmp \
	  && grep -q "TB_RESULT: PASS" pfcap_ff.tmp \
	  && echo "TB_RESULT: PASS" && rm -f pfcap_latch.tmp pfcap_ff.tmp

.PHONY: test-pf-capture
