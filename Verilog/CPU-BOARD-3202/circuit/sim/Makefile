# Testbenches for CPU-BOARD-3202 circuit modules.
IVERILOG = iverilog
CIRCUIT  = ..
PAL      = ../../../PAL

# Exhaustive validation of CYC_TERM_D (TERM next-state mirror) vs PAL_44601B.
CYC_TERM_D_tb: CYC_TERM_D_tb.v $(CIRCUIT)/CYC_TERM_D.v $(PAL)/PAL_44601B.v
	$(IVERILOG) -g2012 -o $@ $^

test-cyctermd: CYC_TERM_D_tb
	./CYC_TERM_D_tb

# Exhaustive validation of CYC_CC_D (CC next-state mirror) vs PAL_44601B.
CYC_CC_D_tb: CYC_CC_D_tb.v $(CIRCUIT)/CYC_CC_D.v $(PAL)/PAL_44601B.v
	$(IVERILOG) -g2012 -o $@ $^

test-ccd: CYC_CC_D_tb
	./CYC_CC_D_tb

# MEM_ADDR_44 address-latch regression (BCGNT50 grant window + LBD
# address-then-data multiplex; catches level-enable capture bugs).
SUPPORT = ../../../Shared/support
MEM_ADDR_44_tb: MEM_ADDR_44_tb.v $(CIRCUIT)/MEM_ADDR_44.v $(SUPPORT)/AM29C821.v $(SUPPORT)/AM29861A.v
	$(IVERILOG) -g2012 -o $@ $^

test-memaddr: MEM_ADDR_44_tb
	./MEM_ADDR_44_tb | tee memaddr_out.log
	@grep -q "TB_RESULT: PASS" memaddr_out.log

# Address + RAM chain: full write/readback over the measured DRAM protocol
# through MEM_ADDR_44 -> MEM_RAM_49 (SIP1M9 FPGA BRAM path, ramSize=3).
MEM_CHAIN_tb: MEM_CHAIN_tb.v $(CIRCUIT)/MEM_ADDR_44.v $(CIRCUIT)/MEM_RAM_49.v $(SUPPORT)/AM29C821.v $(SUPPORT)/AM29861A.v $(SUPPORT)/SIP1M9.v
	$(IVERILOG) -g2012 -o $@ $^

test-memchain: MEM_CHAIN_tb
	./MEM_CHAIN_tb | tee memchain_out.log
	@grep -q "TB_RESULT: PASS" memchain_out.log

# Same chain against the other sheet-49 backends (shared interface,
# different internals): FPGA block-RAM and the Verilator zero-delay model.
MEM_CHAIN_BLOCKRAM_tb: MEM_CHAIN_tb.v $(CIRCUIT)/MEM_ADDR_44.v $(CIRCUIT)/MEM_RAM_49_BLOCKRAM.v $(SUPPORT)/AM29C821.v $(SUPPORT)/AM29861A.v
	$(IVERILOG) -g2012 -DCHAIN_USE_BLOCKRAM -o $@ $^

test-memchain-blockram: MEM_CHAIN_BLOCKRAM_tb
	./MEM_CHAIN_BLOCKRAM_tb | tee memchain_br_out.log
	@grep -q "TB_RESULT: PASS" memchain_br_out.log

MEM_CHAIN_SIM_tb: MEM_CHAIN_tb.v $(CIRCUIT)/MEM_ADDR_44.v $(CIRCUIT)/MEM_RAM_49_SIM.v $(SUPPORT)/AM29C821.v $(SUPPORT)/AM29861A.v
	$(IVERILOG) -g2012 -DCHAIN_USE_SIM -o $@ $^

test-memchain-sim: MEM_CHAIN_SIM_tb
	./MEM_CHAIN_SIM_tb | tee memchain_sim_out.log
	@grep -q "TB_RESULT: PASS" memchain_sim_out.log

test-all: test-cyctermd test-ccd test-memaddr test-memchain test-memchain-blockram test-memchain-sim

clean:
	rm -f CYC_TERM_D_tb CYC_CC_D_tb MEM_ADDR_44_tb MEM_CHAIN_tb MEM_CHAIN_BLOCKRAM_tb MEM_CHAIN_SIM_tb *.vcd *_out.log

.PHONY: test-cyctermd test-ccd test-memaddr test-memchain test-all clean

# MEM_RAM_49_BLOCKRAM: block-RAM sheet-49 backend, measured DRAM protocol
test-blockram: MEM_RAM_49_BLOCKRAM_tb
	./MEM_RAM_49_BLOCKRAM_tb | tee blockram_result.tmp
	@grep -q "TB_RESULT: PASS" blockram_result.tmp && rm -f blockram_result.tmp MEM_RAM_49_BLOCKRAM_tb.vcd

MEM_RAM_49_BLOCKRAM_tb: MEM_RAM_49_BLOCKRAM_tb.v $(CIRCUIT)/MEM_RAM_49_BLOCKRAM.v
	$(IVERILOG) -g2012 -o $@ MEM_RAM_49_BLOCKRAM_tb.v $(CIRCUIT)/MEM_RAM_49_BLOCKRAM.v

# BIF datapath sheets: run the same vectors in latch mode (plain) and FF
# mode (-DFPGA_FF_MODE, the P1c-2/P1d sysclk edge-captures). Both must pass.
BIF_SUPPORT = ../../../Shared/support

test-cdlbd: BIF_DPATH_CDLBD_11_tb BIF_DPATH_CDLBD_11_ff_tb
	./BIF_DPATH_CDLBD_11_tb    | tee cdlbd_result.tmp
	@grep -q "TB_RESULT: PASS" cdlbd_result.tmp
	./BIF_DPATH_CDLBD_11_ff_tb | tee cdlbd_result.tmp
	@grep -q "TB_RESULT: PASS" cdlbd_result.tmp && rm -f cdlbd_result.tmp BIF_DPATH_CDLBD_11_tb.vcd

BIF_DPATH_CDLBD_11_tb: BIF_DPATH_CDLBD_11_tb.v $(CIRCUIT)/BIF_DPATH_CDLBD_11.v $(BIF_SUPPORT)/TTL_74646.v
	$(IVERILOG) -g2012 -o $@ $^

BIF_DPATH_CDLBD_11_ff_tb: BIF_DPATH_CDLBD_11_tb.v $(CIRCUIT)/BIF_DPATH_CDLBD_11.v $(BIF_SUPPORT)/TTL_74646.v
	$(IVERILOG) -g2012 -DFPGA_FF_MODE -o $@ $^

test-bdlbd: BIF_DPATH_BDLBD_10_tb BIF_DPATH_BDLBD_10_ff_tb
	./BIF_DPATH_BDLBD_10_tb    | tee bdlbd_result.tmp
	@grep -q "TB_RESULT: PASS" bdlbd_result.tmp
	./BIF_DPATH_BDLBD_10_ff_tb | tee bdlbd_result.tmp
	@grep -q "TB_RESULT: PASS" bdlbd_result.tmp && rm -f bdlbd_result.tmp BIF_DPATH_BDLBD_10_tb.vcd

BIF_DPATH_BDLBD_10_tb: BIF_DPATH_BDLBD_10_tb.v $(CIRCUIT)/BIF_DPATH_BDLBD_10.v $(BIF_SUPPORT)/TTL_74648.v
	$(IVERILOG) -g2012 -o $@ $^

BIF_DPATH_BDLBD_10_ff_tb: BIF_DPATH_BDLBD_10_tb.v $(CIRCUIT)/BIF_DPATH_BDLBD_10.v $(BIF_SUPPORT)/TTL_74648.v
	$(IVERILOG) -g2012 -DFPGA_FF_MODE -o $@ $^

# MEM_DATA_46: parity transceivers + PAL_45008B, latch and FF modes
LOGISIM = ../../../Shared/logisim
MEMDATA_SRCS = MEM_DATA_46_tb.v $(CIRCUIT)/MEM_DATA_46.v $(BIF_SUPPORT)/AM29833A.v $(PAL)/PAL_45008B.v $(LOGISIM)/NOR_GATE.v $(LOGISIM)/J_K_FLIPFLOP.v

test-memdata: MEM_DATA_46_tb_bin MEM_DATA_46_ff_tb_bin
	./MEM_DATA_46_tb_bin    | tee memdata_result.tmp
	@grep -q "TB_RESULT: PASS" memdata_result.tmp
	./MEM_DATA_46_ff_tb_bin | tee memdata_result.tmp
	@grep -q "TB_RESULT: PASS" memdata_result.tmp && rm -f memdata_result.tmp MEM_DATA_46_tb.vcd

MEM_DATA_46_tb_bin: $(MEMDATA_SRCS)
	$(IVERILOG) -g2012 -o $@ $(MEMDATA_SRCS)

MEM_DATA_46_ff_tb_bin: $(MEMDATA_SRCS)
	$(IVERILOG) -g2012 -DFPGA_FF_MODE -o $@ $(MEMDATA_SRCS)

# CYC_36 clock-enable alignment (P2 foundation): EN pulse <=> pa-clock rise
CYCEN_SRCS = CYC_36_enables_tb.v $(CIRCUIT)/CYC_36.v $(CIRCUIT)/CYC_TERM_D.v $(CIRCUIT)/CYC_CC_D.v $(PAL)/PAL_44601B.v $(PAL)/PAL_44307C.v $(PAL)/PAL_44403C.v $(PAL)/PAL_44404C.v $(PAL)/PAL_44403C_EN.v $(PAL)/PAL_44404C_EN.v

test-cycen: CYC_36_enables_tb
	./CYC_36_enables_tb | tee cycen_result.tmp
	@grep -q "TB_RESULT: PASS" cycen_result.tmp && rm -f cycen_result.tmp CYC_36_enables_tb.vcd

CYC_36_enables_tb: $(CYCEN_SRCS)
	$(IVERILOG) -g2012 -DFPGA_FF_MODE -o $@ $(CYCEN_SRCS)

# CPU_CS_ACAL_17 LUA transparent-latch (Tang 06000 boot-hang root cause, 19-JUL).
# Compiled in FPGA mode (NO VERILATOR_SIM) so it exercises the FIXED `else`
# branch: LUA must track CSA with ZERO latency when MACLK=1. Fails on the old
# 1-cycle-lag FF, passes on the transparent-latch fix.
ACAL_SRCS = CPU_CS_ACAL_17_tb.v $(CIRCUIT)/CPU_CS_ACAL_17.v

test-acal: CPU_CS_ACAL_17_tb
	./CPU_CS_ACAL_17_tb | tee acal_result.tmp
	@grep -q "TB_RESULT: PASS" acal_result.tmp && rm -f acal_result.tmp

CPU_CS_ACAL_17_tb: $(ACAL_SRCS)
	$(IVERILOG) -g2012 -DFPGA_FF_MODE -o $@ $(ACAL_SRCS)
