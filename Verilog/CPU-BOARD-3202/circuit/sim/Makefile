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
