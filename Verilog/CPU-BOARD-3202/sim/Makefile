VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH -Wno-EOFNEWLINE -Wno-LATCH


VERILATOR_FLAGS = --trace -Wall --cc ../circuit/ND3202D.v --exe test_top_3202d.cpp $(SUPPRESS_FLAGS)  

TOP_3202D_COMPONENTS = --I../circuit -I../../Shared/logisim   -I../../Shared/ndlib  -I../../Shared/support

CGA_COMPONENTS = --I../../DELILAH-CPU/CGA_ALU/circuit -I../../DELILAH-CPU/CGA_DCD/circuit -I../../DELILAH-CPU/CGA_IDBCTL/circuit -I../../DELILAH-CPU/CGA_INTR/circuit -I../../DELILAH-CPU/CGA_MAC/circuit -I../../DELILAH-CPU/CGA_MIC/circuit -I../../DELILAH-CPU/CGA_TESTMUX/circuit -I../../DELILAH-CPU/CGA_TRAP/circuit -I../../DELILAH-CPU/CGA_WRF/circuit -I../../DELILAH-CPU/CGA/circuit
DGA_COMPONENTS = --I../../DECODE-GateArray/DGA/circuit

#SHARED_COMPONENTS =  -I../circuit -y ../../Shared/ndlib -y ../../Shared/logisim --I../../Shared/gates-tmp # (was shared/gates - dir never existed)   --I../../PAL

VERILATOR_DIRS = $(TOP_3202D_COMPONENTS) $(CGA_COMPONENTS) $(DGA_COMPONENTS)
# Specify C++ source files here
CPP_SOURCES = test_top_3202d.cpp

# Default target
all: test_top_3202d run gtk

test_top_3202d: $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_DIRS) --I../../PAL
	cd obj_dir && make -f VND3202D.mk VND3202D

clean:
	rm -rf obj_dir

run: test_top_3202d
	./obj_dir/VND3202D

gtk: run
	gtkwave waveform.vcd top_3202d.gtkw &

.PHONY: all clean

# P1b/P1c equivalence: request/grant flag - D_FLIPFLOP (async clear) vs the
# MEM_ADEC_45 FF-mode sysclk edge-capture (docs/plan-fix-unconstrained-clocks.md)
test-reqgnt: reqgnt_equiv_tb
	vvp reqgnt_equiv_tb | tee reqgnt_result.tmp
	@grep -q "TB_RESULT: PASS" reqgnt_result.tmp && rm -f reqgnt_result.tmp reqgnt_equiv_tb.vcd

reqgnt_equiv_tb: reqgnt_equiv_tb.v ../../Shared/logisim/D_FLIPFLOP.v
	iverilog -g2012 -o $@ reqgnt_equiv_tb.v ../../Shared/logisim/D_FLIPFLOP.v

###############################################################################
# Sheet-level unit testbenches (iverilog), added 20-AUG-2026.
#
# One target per sheet. Every target prints "TB_RESULT: PASS" or
# "TB_RESULT: FAIL" as its last line and is registered in
# Verilog/tests/run_all_tests.sh.
#
# Sheets whose RTL has an `FPGA_FF_MODE `ifdef are built and run TWICE, in
# latch mode and in FF mode, and BOTH must pass: test-<name>-latch and
# test-<name>-ff, with test-<name> running the pair.
#
# test-sheets runs all thirteen. Registered individually in run_all_tests.sh
# so a failure names the sheet.
###############################################################################

IV        = iverilog -g2005
CIRCUIT   = ../circuit
SUPPORT   = ../../Shared/support
LOGISIM   = ../../Shared/logisim
NDLIB     = ../../Shared/ndlib
PALDIR    = ../../PAL
DGADIR    = ../../DECODE-GateArray/DGA/circuit
LIBS      = -y $(CIRCUIT) -y $(SUPPORT) -y $(LOGISIM) -y $(NDLIB) -y $(PALDIR) -y $(DGADIR)

# --- combinational / single-mode sheets ------------------------------------
test-wca31: CPU_MMU_WCA_31_tb.v $(CIRCUIT)/CPU_MMU_WCA_31.v
	$(IV) -o CPU_MMU_WCA_31_tb.vvp $^
	vvp CPU_MMU_WCA_31_tb.vvp

test-csr26: CPU_MMU_CSR_26_tb.v $(CIRCUIT)/CPU_MMU_CSR_26.v
	$(IV) -o CPU_MMU_CSR_26_tb.vvp $^
	vvp CPU_MMU_CSR_26_tb.vvp

test-ptidb30: CPU_MMU_PTIDB_30_tb.v $(CIRCUIT)/CPU_MMU_PTIDB_30.v
	$(IV) -o CPU_MMU_PTIDB_30_tb.vvp $^
	vvp CPU_MMU_PTIDB_30_tb.vvp

test-hit27: CPU_MMU_HIT_27_tb.v $(CIRCUIT)/CPU_MMU_HIT_27.v
	$(IV) -o CPU_MMU_HIT_27_tb.vvp $^
	vvp CPU_MMU_HIT_27_tb.vvp

test-csctl18: CPU_CS_CTL_18_tb.v $(CIRCUIT)/CPU_CS_CTL_18.v
	$(IV) -o CPU_CS_CTL_18_tb.vvp CPU_CS_CTL_18_tb.v $(CIRCUIT)/CPU_CS_CTL_18.v $(LIBS)
	vvp CPU_CS_CTL_18_tb.vvp

test-bifdpath9: BIF_DPATH_9_tb.v $(CIRCUIT)/BIF_DPATH_9.v
	$(IV) -o BIF_DPATH_9_tb.vvp BIF_DPATH_9_tb.v $(CIRCUIT)/BIF_DPATH_9.v $(LIBS)
	vvp BIF_DPATH_9_tb.vvp

# The RTL opens the two PROM images by BARE FILENAME, so they have to be
# reachable from the run directory. Symlink them in, run, take them away.
test-prom19: CPU_CS_PROM_19_tb.v $(CIRCUIT)/CPU_CS_PROM_19.v
	$(IV) -o CPU_CS_PROM_19_tb.vvp $^
	ln -sf ../../../Code/Microcode/AM27256_45132L.hex AM27256_45132L.hex
	ln -sf ../../../Code/Microcode/AM27256_45133L.hex AM27256_45133L.hex
	vvp CPU_CS_PROM_19_tb.vvp; rc=$$?; \
	  rm -f AM27256_45132L.hex AM27256_45133L.hex; exit $$rc

# --- sheets with an `FPGA_FF_MODE `ifdef: both modes must pass -------------
test-ppnlbd14: test-ppnlbd14-latch test-ppnlbd14-ff
test-ppnlbd14-latch: BIF_DPATH_PPNLBD_14_tb.v $(CIRCUIT)/BIF_DPATH_PPNLBD_14.v
	$(IV) -o BIF_DPATH_PPNLBD_14_tb.vvp $^
	vvp BIF_DPATH_PPNLBD_14_tb.vvp
test-ppnlbd14-ff: BIF_DPATH_PPNLBD_14_tb.v $(CIRCUIT)/BIF_DPATH_PPNLBD_14.v
	$(IV) -DFPGA_FF_MODE -o BIF_DPATH_PPNLBD_14_ff_tb.vvp $^
	vvp BIF_DPATH_PPNLBD_14_ff_tb.vvp

test-ioreg41: test-ioreg41-latch test-ioreg41-ff
test-ioreg41-latch: IO_REG_41_tb.v $(CIRCUIT)/IO_REG_41.v
	$(IV) -o IO_REG_41_tb.vvp IO_REG_41_tb.v $(CIRCUIT)/IO_REG_41.v $(LIBS)
	vvp IO_REG_41_tb.vvp
test-ioreg41-ff: IO_REG_41_tb.v $(CIRCUIT)/IO_REG_41.v
	$(IV) -DFPGA_FF_MODE -o IO_REG_41_ff_tb.vvp IO_REG_41_tb.v $(CIRCUIT)/IO_REG_41.v $(LIBS)
	vvp IO_REG_41_ff_tb.vvp

test-iouart42: test-iouart42-latch test-iouart42-ff
test-iouart42-latch: IO_UART_42_tb.v $(CIRCUIT)/IO_UART_42.v
	$(IV) -o IO_UART_42_tb.vvp IO_UART_42_tb.v $(CIRCUIT)/IO_UART_42.v $(LIBS)
	vvp IO_UART_42_tb.vvp
test-iouart42-ff: IO_UART_42_tb.v $(CIRCUIT)/IO_UART_42.v
	$(IV) -DFPGA_FF_MODE -o IO_UART_42_ff_tb.vvp IO_UART_42_tb.v $(CIRCUIT)/IO_UART_42.v $(LIBS)
	vvp IO_UART_42_ff_tb.vvp

test-cmddec34: test-cmddec34-latch test-cmddec34-ff
test-cmddec34-latch: CPU_PROC_CMDDEC_34_tb.v $(CIRCUIT)/CPU_PROC_CMDDEC_34.v
	$(IV) -o CPU_PROC_CMDDEC_34_tb.vvp CPU_PROC_CMDDEC_34_tb.v $(CIRCUIT)/CPU_PROC_CMDDEC_34.v $(LIBS)
	vvp CPU_PROC_CMDDEC_34_tb.vvp
test-cmddec34-ff: CPU_PROC_CMDDEC_34_tb.v $(CIRCUIT)/CPU_PROC_CMDDEC_34.v
	$(IV) -DFPGA_FF_MODE -o CPU_PROC_CMDDEC_34_ff_tb.vvp CPU_PROC_CMDDEC_34_tb.v $(CIRCUIT)/CPU_PROC_CMDDEC_34.v $(LIBS)
	vvp CPU_PROC_CMDDEC_34_ff_tb.vvp

test-iodcd38: test-iodcd38-latch test-iodcd38-ff
test-iodcd38-latch: IO_DCD_38_tb.v $(CIRCUIT)/IO_DCD_38.v
	$(IV) -o IO_DCD_38_tb.vvp IO_DCD_38_tb.v $(CIRCUIT)/IO_DCD_38.v $(LIBS)
	vvp IO_DCD_38_tb.vvp
test-iodcd38-ff: IO_DCD_38_tb.v $(CIRCUIT)/IO_DCD_38.v
	$(IV) -DFPGA_FF_MODE -o IO_DCD_38_ff_tb.vvp IO_DCD_38_tb.v $(CIRCUIT)/IO_DCD_38.v $(LIBS)
	vvp IO_DCD_38_ff_tb.vvp

test-sheets: test-wca31 test-csr26 test-ptidb30 test-hit27 test-csctl18 \
             test-prom19 test-bdrv7 test-bifdpath9 test-ppnlbd14 \
             test-ioreg41 test-iouart42 test-cmddec34 test-iodcd38

clean-sheets:
	rm -f *_tb.vvp *_tb.vcd AM27256_4513*.hex

.PHONY: test-sheets clean-sheets $(addprefix test-,wca31 csr26 ptidb30 hit27 csctl18 prom19 bdrv7 bifdpath9 ppnlbd14 ioreg41 iouart42 cmddec34 iodcd38)

test-bdrv7: BIF_BCTL_BDRV_7_tb.v $(CIRCUIT)/BIF_BCTL_BDRV_7.v
	$(IV) -o BIF_BCTL_BDRV_7_tb.vvp BIF_BCTL_BDRV_7_tb.v $(CIRCUIT)/BIF_BCTL_BDRV_7.v $(LIBS)
	vvp BIF_BCTL_BDRV_7_tb.vvp
