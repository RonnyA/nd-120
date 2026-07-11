# Unit testbench for the ND-100 floppy DMA controller
# (repo convention: sim/ next to the modules it tests)
#
# test / test-floppy-dma - the full DMA device stack: IOX slave shell,
#   command block DMA-fetched from the ND-memory model through
#   ND_DMA_MASTER, sector data disk<->memory by DMA, status writeback,
#   dualDensity bit, interrupt + IDENT

IVERILOG = iverilog
VVP      = vvp

SRCS = ../../BUS-IF/circuit/ND_BUS_SLAVE.v \
       ../../DMA/circuit/ND_DMA_MASTER.v \
       ../circuit/ND_FLOPPY_DMA.v \
       nd_floppy_dma_tb.v

all: test

test: test-floppy-dma

nd_floppy_dma_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -o $@ $(SRCS)

test-floppy-dma: nd_floppy_dma_tb.vvp
	$(VVP) nd_floppy_dma_tb.vvp | tee floppy_dma_out.log
	@grep -q "TB_RESULT: PASS" floppy_dma_out.log

clean:
	rm -f *.vvp *.log *.vcd

.PHONY: all test test-floppy-dma clean
