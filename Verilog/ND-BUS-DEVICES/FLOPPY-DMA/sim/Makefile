# Unit testbench for the ND-100 floppy DMA controller
# (repo convention: sim/ next to the modules it tests)
#
# test / test-floppy-dma - the full DMA device stack: IOX slave shell,
#   command block DMA-fetched from the ND-memory model through
#   ND_DMA_MASTER, sector data disk<->memory by DMA, status writeback,
#   dualDensity bit, interrupt + IDENT

IVERILOG = iverilog
VVP      = vvp
VERILATOR = verilator

SRCS = ../../BUS-IF/circuit/ND_BUS_SLAVE.v \
       ../../DMA/circuit/ND_DMA_MASTER.v \
       ../circuit/ND_FLOPPY_DMA.v \
       nd_floppy_dma_tb.v

# test-floppy-boot: the '1560&' AUTOLOAD byte-server - exact word stream
# across a chunk boundary, boot-mode entry/exit, and the boot_fail end-state
# (oct 50 + hard error + RFT release + boot-mode clear). Authority: the
# portable core nd_floppy_dma.c + the ND-120 microcode contract (the nd100x
# deviceFloppyDMA.c stubs autoload, so it is not the stream authority).
BOOT_SRCS = ../../BUS-IF/circuit/ND_BUS_SLAVE.v \
            ../../DMA/circuit/ND_DMA_MASTER.v \
            ../circuit/ND_FLOPPY_DMA.v \
            nd_floppy_boot_tb.v

# test-floppy-iox: floppy campaign phase P1 - the IOX register / status /
# control-word conformance matrix (CONFORMANCE.md sec 1-3, 6) asserted
# directly at the device IOX slave port. ND_FLOPPY_DMA only (no BUS_SLAVE);
# the bus-strobe / boot-consume interaction is P2.
IOX_SRCS = ../circuit/ND_FLOPPY_DMA.v \
           nd_floppy_iox_tb.v

# test-floppy-sdfat: the DMA-floppy backend seam served by the REAL SD-FAT
# stack (nd_tape_sdfat_source #(.INCLUDE_FLOPPY(1)) -> nd_storage -> floppy
# adapter -> sd_card_model with FLOPPY1.IMG). Verilator (--timing) because the
# SD stack + card model need it; proves the Tang floppy integration functionally.
SDFAT = ../../../SD-FAT
SHARED = ../../../Shared
VFLAGS = --binary --timing -j 4 -Wno-fatal -Wno-WIDTH -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE \
         -CFLAGS "-std=gnu++20 -fcoroutines"
VSDFAT_SRCS = $(wildcard $(SDFAT)/circuit/*.v) \
              $(SDFAT)/sim/sd_card_model.v $(SDFAT)/sim/nds_mem_model.v \
              ../../TAPE-400/circuit/nd_tape_sdfat_source.v

all: test

test: test-floppy-dma test-floppy-boot test-floppy-iox

nd_floppy_dma_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -o $@ $(SRCS)

test-floppy-dma: nd_floppy_dma_tb.vvp
	$(VVP) nd_floppy_dma_tb.vvp | tee floppy_dma_out.log
	@grep -q "TB_RESULT: PASS" floppy_dma_out.log

nd_floppy_boot_tb.vvp: $(BOOT_SRCS)
	$(IVERILOG) -g2005 -o $@ $(BOOT_SRCS)

test-floppy-boot: nd_floppy_boot_tb.vvp
	$(VVP) nd_floppy_boot_tb.vvp | tee floppy_boot_out.log
	@grep -q "TB_RESULT: PASS" floppy_boot_out.log

nd_floppy_iox_tb.vvp: $(IOX_SRCS)
	$(IVERILOG) -g2005 -o $@ $(IOX_SRCS)

test-floppy-iox: nd_floppy_iox_tb.vvp
	$(VVP) nd_floppy_iox_tb.vvp | tee floppy_iox_out.log
	@grep -q "TB_RESULT: PASS" floppy_iox_out.log

test-floppy-sdfat:
	cd $(SDFAT)/sim && bash make_storage_image.sh >/dev/null 2>&1
	$(VERILATOR) $(VFLAGS) --top-module nd_floppy_dma_sdfat_tb --Mdir obj_dir_sdfat \
	  +incdir+$(SDFAT)/circuit \
	  -y $(SHARED)/ndlib -y $(SHARED)/logisim -y $(SHARED)/support \
	  $(VSDFAT_SRCS) nd_floppy_dma_sdfat_tb.v
	cd $(SDFAT)/sim && $(CURDIR)/obj_dir_sdfat/Vnd_floppy_dma_sdfat_tb | tee $(CURDIR)/floppy_sdfat_out.log
	@grep -q "TB_RESULT: PASS" floppy_sdfat_out.log

clean:
	rm -f *.vvp *.log *.vcd
	rm -rf obj_dir_sdfat

.PHONY: all test test-floppy-dma test-floppy-boot test-floppy-sdfat clean
