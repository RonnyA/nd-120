# Unit testbench for the ND-100 DMA bus master
# (repo convention: sim/ next to the modules it tests)
#
# test / test-dma-master - two chained ND_DMA_MASTER instances against
#   a BCU + memory model per ND-06.016.01 ch. V: word write/read, block
#   via re-requests, simultaneous requests (daisy-chain priority),
#   delayed grant, timeout + recovery

IVERILOG = iverilog
VVP      = vvp

SRCS = ../circuit/ND_DMA_MASTER.v \
       nd_dma_master_tb.v

all: test

test: test-dma-master test-dma-reset-pend test-dma-stale-capture

nd_dma_master_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -o $@ $(SRCS)

test-dma-master: nd_dma_master_tb.vvp
	$(VVP) nd_dma_master_tb.vvp | tee dma_master_out.log
	@grep -q "TB_RESULT: PASS" dma_master_out.log

# test-dma-reset-pend - the two questions the protocol bench does not cover:
#   s_pend liveness (EARLY_REREQ=0 vs 1: is the Vivado-deleted register really
#   dead?) and the async-reset / synchronous-timeout-set collision, swept over
#   64 single-cycle offsets around the cycle the hang guard fires.
ND_DMA_MASTER_RESET_PEND_tb.vvp: ../circuit/ND_DMA_MASTER.v ND_DMA_MASTER_RESET_PEND_tb.v
	$(IVERILOG) -g2012 -o $@ ND_DMA_MASTER_RESET_PEND_tb.v ../circuit/ND_DMA_MASTER.v

test-dma-reset-pend: ND_DMA_MASTER_RESET_PEND_tb.vvp
	$(VVP) ND_DMA_MASTER_RESET_PEND_tb.vvp | tee dma_reset_pend_out.log
	@grep -q "TB_RESULT: PASS" dma_reset_pend_out.log

# test-dma-stale-capture - regression for the 23-AUG-2026 Nexys floppy
#   root cause: a foreign 2-tick bus transient (a CPU instruction fetch
#   leaking through the BIF transceiver before the memory answer) must be
#   DISCARDED when the true read data is zero (~0 = idle pattern on the
#   inverted bus), while real data - which runs contiguously into the
#   BDRY edge, at most one release tick early - must never be discarded.
#   Waveform shapes are the ones measured in the failing system.
ND_DMA_MASTER_STALE_CAPTURE_tb.vvp: ../circuit/ND_DMA_MASTER.v ND_DMA_MASTER_STALE_CAPTURE_tb.v
	$(IVERILOG) -g2005 -o $@ ND_DMA_MASTER_STALE_CAPTURE_tb.v ../circuit/ND_DMA_MASTER.v

test-dma-stale-capture: ND_DMA_MASTER_STALE_CAPTURE_tb.vvp
	$(VVP) ND_DMA_MASTER_STALE_CAPTURE_tb.vvp | tee dma_stale_capture_out.log
	@grep -q "TB_RESULT: PASS" dma_stale_capture_out.log

clean:
	rm -f *.vvp *.log *.vcd

.PHONY: all test test-dma-master test-dma-reset-pend test-dma-stale-capture clean
