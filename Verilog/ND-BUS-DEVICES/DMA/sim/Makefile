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

test: test-dma-master

nd_dma_master_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -o $@ $(SRCS)

test-dma-master: nd_dma_master_tb.vvp
	$(VVP) nd_dma_master_tb.vvp | tee dma_master_out.log
	@grep -q "TB_RESULT: PASS" dma_master_out.log

clean:
	rm -f *.vvp *.log *.vcd

.PHONY: all test test-dma-master clean
