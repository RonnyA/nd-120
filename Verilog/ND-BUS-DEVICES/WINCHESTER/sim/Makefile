# Unit testbenches for the ND Winchester disc controller, 5 1/4 inch ST506
# (card 3041) and 8 inch (card 3038).
# (repo convention: sim/ next to the modules it tests)
#
# test-wd-iox - the IOX register / status / IDENT conformance matrix asserted
#   directly at the device IOX slave port (no BUS_SLAVE, no DMA backend):
#   the two-access memory address with its deliberately opposite read order,
#   ALL FOUR flip-flop reset conditions, the SINGLE-access word count that
#   distinguishes this card from the 15 MHz SMD, the block-address split,
#   the status constants, M4's relative step seek, M7, the address-mismatch
#   bound, and the section 4.1 interrupt / IDENT probe that TPE CONFIGURATION
#   uses to find the card.
#
# The same behaviour is cross-checked between the two C implementations
# (nd100x tests/wd_trace.c and the portable core's test/wd_trace.c walking a
# shared conformance sequence), so a divergence between RTL and C shows up
# here rather than on silicon.

# Shared include paths (Verilog/mk/iverilog.mk). Provides $(ND_INC),
# which covers SD-FAT/circuit - the controllers include
# nd_storage_status.vh from there.
VERILOG_ROOT = ../../..
include $(VERILOG_ROOT)/mk/iverilog.mk


IOX_SRCS = ../circuit/ND_WINCHESTER.v \
           nd_winchester_iox_tb.v

# test-wd-adapter: the Winchester BINDING of nd_storage_disc_adapter. There is
#   no nd_storage_wd_adapter.v: that adapter has nothing SMD-specific in it -
#   its CHS->LBA is driven by GEO_HEADS/GEO_SPT and its one hard assumption
#   (1024-byte sectors) holds for this card too. This bench proves the reuse
#   with Winchester geometry, and closes a real hole: the adapter's own bench
#   instantiates it twice and both times at the DEFAULT geometry, so the
#   parameterisation was never exercised.
AD_SRCS  = ../../../SD-FAT/circuit/nd_storage_disc_adapter.v \
           nd_winchester_adapter_tb.v

# test-wd-oracle: replay of the nd100x C model's own IOX trace for the
#   DISC-TEMA J02 "DU-DI-C" read that failed on silicon 05-AUG-2026. Holds
#   each IOX strobe for MANY card clocks, which is what the ND bus does and
#   what a 1-clock strobe hides, and requires iox_rdata to stay stable for
#   the whole access. Caught the level-vs-edge strobe bug in ND_WINCHESTER.v.
OR_SRCS  = ../circuit/ND_WINCHESTER.v \
           nd_winchester_oracle_tb.v

# RTZ observability: the guest must be able to SEE an operation running, not
# just see it finished. The oracle bench cannot catch this - it polls with
# zero latency and never exercises the M7 RTZ path.
RTZ_SRCS = ../circuit/ND_WINCHESTER.v \
           nd_winchester_rtz_tb.v

# test-wd-bus: the card behind the REAL ND_BUS_SLAVE. Every other bench
#   drives iox_rd/iox_wr directly, so the adapter that generates those
#   strobes on the board was never in the loop - and +0 is precisely the
#   register whose value depends on HOW MANY times the strobe fires.
BUS_SRCS = ../circuit/ND_WINCHESTER.v \
           ../../BUS-IF/circuit/ND_BUS_SLAVE.v \
           nd_winchester_bus_tb.v

# test-wd-storage: the WHOLE chain - ND_WINCHESTER -> nd_storage_disc_adapter
#   (client 6, Winchester geometry) -> nd_storage (mount + engine + Phase-4
#   cache) -> the behavioral SD card serving the real FAT16 image. Every
#   other Winchester bench fakes the backend, so the path from "the guest set
#   GO" to "bytes off the FAT volume" was never simulated - which is exactly
#   how a backend that answers done+no-error with a ZERO block stayed
#   invisible until it showed up on silicon (08-AUG-2026). Needs the shared
#   card image from ../../../SD-FAT/sim (make_storage_image.sh), which
#   carries WD0.IMG.
STOR_SRCS = ../circuit/ND_WINCHESTER.v \
            ../../../SD-FAT/circuit/nd_storage_devices.v \
            ../../../SD-FAT/circuit/nds_sync.v \
            ../../../SD-FAT/circuit/nd_storage_engine.v \
            ../../../SD-FAT/circuit/nd_storage_mount.v \
            ../../../SD-FAT/circuit/nd_storage_cache.v \
            ../../../SD-FAT/circuit/nd_storage_fatchk.v \
            ../../../SD-FAT/circuit/nd_storage.v \
            ../../../SD-FAT/circuit/nd_storage_tape_adapter.v \
            ../../../SD-FAT/circuit/nd_storage_floppy_adapter.v \
            ../../../SD-FAT/circuit/nd_storage_disc_adapter.v \
            ../../../SD-FAT/circuit/sd_file_reader.v \
            ../../../SD-FAT/circuit/sd_writer.v \
            ../../../SD-FAT/sim/nds_mem_model.v \
            ../../../SD-FAT/sim/sd_card_model.v \
            nd_winchester_storage_tb.v

all: test

test: test-wd-iox test-wd-adapter test-wd-oracle test-wd-bus test-wd-storage \
      test-wd-storage-sdram test-wd-rtz

nd_winchester_storage_tb.vvp: $(STOR_SRCS)
	$(IVERILOG) -g2005 $(ND_INC) -o $@ $(STOR_SRCS)

../../../SD-FAT/sim/nds_storage.img:
	../../../SD-FAT/sim/make_storage_image.sh

test-wd-storage: nd_winchester_storage_tb.vvp ../../../SD-FAT/sim/nds_storage.img
	$(VVP) nd_winchester_storage_tb.vvp | tee wd_storage_out.log
	@grep -q "TB_RESULT: PASS" wd_storage_out.log

# test-wd-storage-sdram: the SAME bench with the region served by the REAL
#   MEM_RAM_49_SDRAM (ND_SDRAM_PACK16 + ND_STORAGE_PORT) and the behavioral
#   SDRAM chip, instead of nds_mem_model. nd_storage and MEM_RAM_49_SDRAM
#   each had a passing bench but had never been COMPOSED - nd_storage's
#   benches all use nds_mem_model and the bridge's bench drives the device
#   port from a synthetic task - so a disagreement between the two mem-port
#   contracts would pass both and lose the data on the board.
SDRAM_STOR_SRCS = $(STOR_SRCS) \
                  ../../../fpga/tang-nano-20k/sdram-bridge/MEM_RAM_49_SDRAM.v \
                  ../../../fpga/tang-nano-20k/sdram-bridge/sdram18.v \
                  ../../../fpga/tang-nano-20k/sdram-test/sim/sdram_model.v

nd_winchester_storage_sdram_tb.vvp: $(SDRAM_STOR_SRCS)
	$(IVERILOG) -g2005 -DWD_TB_REAL_SDRAM -DND_SDRAM_PACK16 -DND_STORAGE_PORT \
	  $(ND_INC) -o $@ $(SDRAM_STOR_SRCS)

test-wd-storage-sdram: nd_winchester_storage_sdram_tb.vvp ../../../SD-FAT/sim/nds_storage.img
	$(VVP) nd_winchester_storage_sdram_tb.vvp | tee wd_storage_sdram_out.log
	@grep -q "TB_RESULT: PASS" wd_storage_sdram_out.log

nd_winchester_iox_tb.vvp: $(IOX_SRCS)
	$(IVERILOG) -g2005 $(ND_INC) -o $@ $(IOX_SRCS)

test-wd-iox: nd_winchester_iox_tb.vvp
	$(VVP) nd_winchester_iox_tb.vvp | tee wd_iox_out.log
	@grep -q "TB_RESULT: PASS" wd_iox_out.log

nd_winchester_adapter_tb.vvp: $(AD_SRCS)
	$(IVERILOG) -g2005 $(ND_INC) -o $@ $(AD_SRCS)

test-wd-adapter: nd_winchester_adapter_tb.vvp
	$(VVP) nd_winchester_adapter_tb.vvp | tee wd_adapter_out.log
	@grep -q "TB_RESULT: PASS" wd_adapter_out.log

clean:
	rm -f *.vvp *.log *.vcd *.fst

.PHONY: all test test-wd-iox test-wd-adapter clean

nd_winchester_oracle_tb.vvp: $(OR_SRCS)
	$(IVERILOG) -g2005 $(ND_INC) -o $@ $(OR_SRCS)

test-wd-oracle: nd_winchester_oracle_tb.vvp
	$(VVP) nd_winchester_oracle_tb.vvp | tee wd_oracle_out.log
	@grep -q "TB_RESULT: PASS" wd_oracle_out.log

.PHONY: test-wd-oracle

nd_winchester_rtz_tb.vvp: $(RTZ_SRCS)
	$(IVERILOG) -g2005 $(ND_INC) -o $@ $(RTZ_SRCS)

test-wd-rtz: nd_winchester_rtz_tb.vvp
	$(VVP) nd_winchester_rtz_tb.vvp | tee wd_rtz_out.log
	@grep -q "TB_RESULT: PASS" wd_rtz_out.log

.PHONY: test-wd-rtz

nd_winchester_bus_tb.vvp: $(BUS_SRCS)
	$(IVERILOG) -g2005 $(ND_INC) -o $@ $(BUS_SRCS)

test-wd-bus: nd_winchester_bus_tb.vvp
	$(VVP) nd_winchester_bus_tb.vvp | tee wd_bus_out.log
	@grep -q "TB_RESULT: PASS" wd_bus_out.log

.PHONY: test-wd-bus
