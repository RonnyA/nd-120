# Unit testbenches for the SD-FAT library
# (repo convention: sim/ next to the modules it tests)
#
# test            - all library unit tests (used by the global test registry)
# test-writer     - sd_writer (CMD24/CMD17 single-sector + CMD25/CMD18
#                   bursts with ACMD23/CMD12) against the behavioral card
#                   model, at CLKDIV=2
# test-writer-div1 - the same testbench at CLKDIV=1 (13.5 MHz class:
#                   sdclk toggles every clk - the hardware setting)
# test-nds-cdc    - nd_storage CDC primitives (nds_sync.v) + word-bridge
#                   handshake across skewed 27/23 MHz clocks
# test-nds-engine - nd_storage_engine arbiter + read path against the
#                   behavioral mem-port model (nds_mem_model.v)
# test-nds-write  - nd_storage_engine WRITE path end-to-end: real sd_writer
#                   + behavioral card model (raw zero image) + mem model;
#                   card-first/SDRAM-second ordering, injected CMD24
#                   failure, out-of-range and recovery cases
# test-nds-mount  - nd_storage FULL STACK (top + mount FSM + reader +
#                   writer + engine) against a real FAT16 image
#                   (make_storage_image.sh): open/preload/size/n_blocks,
#                   missing file, oversize file, SMD v1 refusal, block
#                   read through the client port, reopen (rewind)
# test-nds-fatchk-unit - nd_storage_fatchk (mount-time contiguity checker)
#                   against a scripted sd_writer read stub: FAT16 + FAT32
#                   entry formats, EOC thresholds, sector-cache read
#                   counts, fragmented/missing-EOC verdicts, guard rails
#                   (size 0, bad first cluster, hop cap, engine err)
# test-nds-fatchk - fatchk through the FULL nd_storage stack against the
#                   image's deliberately fragmented FRAG.IMG: open_err /
#                   no open_ok, contiguous neighbor still opens, failed
#                   open cleanly retryable; also elaborates the whole
#                   stack with -DSDFAT_NO_STORAGE_CHECK (feature-off lint)
#
# The board-level system tests (menu, reader, dump, copy, block update)
# live in Verilog/fpga/tang-nano-20k/sd-fat-test/sim/.

IVERILOG = iverilog
VVP      = vvp

WRITER_SRCS = ../circuit/sd_writer.v \
              sd_card_model.v \
              sd_writer_tb.v

CDC_SRCS = ../circuit/nds_sync.v \
           nd_storage_cdc_tb.v

ENGINE_SRCS = ../circuit/nds_sync.v \
              ../circuit/nd_storage_engine.v \
              nds_mem_model.v \
              nd_storage_engine_tb.v

WRITE_SRCS = ../circuit/nds_sync.v \
             ../circuit/nd_storage_engine.v \
             ../circuit/sd_writer.v \
             nds_mem_model.v \
             sd_card_model.v \
             nd_storage_write_tb.v

STACK_SRCS = ../circuit/nds_sync.v \
             ../circuit/nd_storage_engine.v \
             ../circuit/nd_storage_mount.v \
             ../circuit/nd_storage_fatchk.v \
             ../circuit/nd_storage.v \
             ../circuit/sd_file_reader.v \
             ../circuit/sd_writer.v \
             nds_mem_model.v \
             sd_card_model.v

MOUNT_SRCS = $(STACK_SRCS) nd_storage_tb.v

FATCHK_UNIT_SRCS = ../circuit/nd_storage_fatchk.v \
                   nd_storage_fatchk_unit_tb.v

FATCHK_SRCS = $(STACK_SRCS) nd_storage_fatchk_tb.v

all: test

test: test-writer test-writer-div1 test-nds-cdc test-nds-engine test-nds-write test-nds-mount test-nds-fatchk-unit test-nds-fatchk

writer_test.img:
	dd if=/dev/zero of=$@ bs=1024 count=64 status=none

sd_writer_tb.vvp: $(WRITER_SRCS)
	$(IVERILOG) -g2005 -o $@ $(WRITER_SRCS)

sd_writer_div1_tb.vvp: $(WRITER_SRCS)
	$(IVERILOG) -g2005 -P sd_writer_tb.TB_CLKDIV=1 -o $@ $(WRITER_SRCS)

test-writer: sd_writer_tb.vvp writer_test.img
	$(VVP) sd_writer_tb.vvp | tee writer_out.log
	@grep -q "TB_RESULT: PASS" writer_out.log

test-writer-div1: sd_writer_div1_tb.vvp writer_test.img
	$(VVP) sd_writer_div1_tb.vvp | tee writer_div1_out.log
	@grep -q "TB_RESULT: PASS" writer_div1_out.log

nd_storage_cdc_tb.vvp: $(CDC_SRCS)
	$(IVERILOG) -g2005 -o $@ $(CDC_SRCS)

test-nds-cdc: nd_storage_cdc_tb.vvp
	$(VVP) nd_storage_cdc_tb.vvp | tee nds_cdc_out.log
	@grep -q "TB_RESULT: PASS" nds_cdc_out.log

nd_storage_engine_tb.vvp: $(ENGINE_SRCS)
	$(IVERILOG) -g2005 -o $@ $(ENGINE_SRCS)

test-nds-engine: nd_storage_engine_tb.vvp
	$(VVP) nd_storage_engine_tb.vvp | tee nds_engine_out.log
	@grep -q "TB_RESULT: PASS" nds_engine_out.log

nds_write_test.img:
	dd if=/dev/zero of=$@ bs=1024 count=128 status=none

nd_storage_write_tb.vvp: $(WRITE_SRCS)
	$(IVERILOG) -g2005 -o $@ $(WRITE_SRCS)

test-nds-write: nd_storage_write_tb.vvp nds_write_test.img
	$(VVP) nd_storage_write_tb.vvp | tee nds_write_out.log
	@grep -q "TB_RESULT: PASS" nds_write_out.log

nds_storage.img: make_storage_image.sh
	./make_storage_image.sh

nd_storage_tb.vvp: $(MOUNT_SRCS)
	$(IVERILOG) -g2005 -I../circuit -o $@ $(MOUNT_SRCS)

test-nds-mount: nd_storage_tb.vvp nds_storage.img
	$(VVP) nd_storage_tb.vvp | tee nds_mount_out.log
	@grep -q "TB_RESULT: PASS" nds_mount_out.log

nd_storage_fatchk_unit_tb.vvp: $(FATCHK_UNIT_SRCS)
	$(IVERILOG) -g2005 -o $@ $(FATCHK_UNIT_SRCS)

test-nds-fatchk-unit: nd_storage_fatchk_unit_tb.vvp
	$(VVP) nd_storage_fatchk_unit_tb.vvp | tee nds_fatchk_unit_out.log
	@grep -q "TB_RESULT: PASS" nds_fatchk_unit_out.log

nd_storage_fatchk_tb.vvp: $(FATCHK_SRCS)
	$(IVERILOG) -g2005 -I../circuit -o $@ $(FATCHK_SRCS)

# feature-off elaboration check: the whole stack must still build with the
# contiguity gate stripped (mount M_CHK passes through, no fatchk instance)
nd_storage_nocheck.vvp: $(MOUNT_SRCS)
	$(IVERILOG) -g2005 -I../circuit -DSDFAT_NO_STORAGE_CHECK -o $@ $(MOUNT_SRCS)

test-nds-fatchk: nd_storage_fatchk_tb.vvp nds_storage.img nd_storage_nocheck.vvp
	$(VVP) nd_storage_fatchk_tb.vvp | tee nds_fatchk_out.log
	@grep -q "TB_RESULT: PASS" nds_fatchk_out.log

clean:
	rm -f *.vvp *.log writer_test.img nds_write_test.img \
	      nds_storage.img nds_tape.bin nds_flp1.bin nds_frag.bin \
	      nds_storage_full.img nds_storage_full_post.img \
	      nds_flp1full.bin nds_flp2.bin
	rm -rf obj_dir_storage

.PHONY: all test test-writer test-writer-div1 test-nds-cdc test-nds-engine test-nds-write test-nds-mount test-nds-fatchk-unit test-nds-fatchk clean

# ---------------------------------------------------------------------------
# test-storage - the step-6 Verilator SYSTEM GATE (run before hardware):
#   nd_storage_vtop.v (full stack) + test_nd_storage.cpp (C++ SD card model
#   with the always-on illegal-write assertion + C++ behavioral mem model)
#   against nds_storage_full.img. Acceptance tests 1 (open/preload), 2
#   (block reads + post-run fsck), 3 (concurrency + write-through with
#   card-first/SDRAM-second ordering) and 5 (injected CMD24 failure,
#   missing file, out-of-range) in one program; the post-run card image is
#   additionally checked with fsck.vfat -n.
# Verilator recipe follows fpga/tang-nano-20k/sd-fat-test/sim/Makefile.
# ---------------------------------------------------------------------------
VERILATOR = verilator

STORAGE_SUPPRESS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN \
                   -Wno-WIDTH -Wno-EOFNEWLINE -Wno-BLKSEQ -Wno-SYNCASYNCNET \
                   -Wno-LATCH -Wno-DECLFILENAME -Wno-VARHIDDEN -Wno-CASEINCOMPLETE \
                   -Wno-PINMISSING
# PINMISSING: nd_storage.v instantiates sd_writer without the 4-bit ports
# (sd_dat1-3/use_4bit) - by design: unconnected use_4bit = the original
# 1-bit engine, and nd_storage stays on the proven 1-bit path.

STORAGE_VSRCS = nd_storage_vtop.v \
                ../circuit/nds_sync.v \
                ../circuit/nd_storage_engine.v \
                ../circuit/nd_storage_mount.v \
                ../circuit/nd_storage_fatchk.v \
                ../circuit/nd_storage.v \
                ../circuit/sd_file_reader.v \
                ../circuit/sd_writer.v

nds_storage_full.img: make_storage_image.sh
	./make_storage_image.sh

compile-storage: test_nd_storage.cpp $(STORAGE_VSRCS)
	$(VERILATOR) -Wall --cc $(STORAGE_VSRCS) --top-module nd_storage_vtop \
	    $(STORAGE_SUPPRESS) \
	    -I../circuit --Mdir obj_dir_storage \
	    --exe test_nd_storage.cpp
	cd obj_dir_storage && $(MAKE) -f Vnd_storage_vtop.mk Vnd_storage_vtop

test-storage: compile-storage nds_storage_full.img
	./obj_dir_storage/Vnd_storage_vtop | tee nds_storage_out.log
	@grep -q "TB_RESULT: PASS" nds_storage_out.log
	fsck.vfat -n nds_storage_full_post.img
	@echo "FSCK: post-write FAT16 filesystem is clean"

.PHONY: compile-storage test-storage

# ---------------------------------------------------------------------------
# test-nds-tape - step-7 tape byte-stream adapter (spec acceptance test 4):
#   tier A: nd_storage_tape_adapter against a SCRIPTED client-port stub
#           (byte order across the full block, block-boundary fetch,
#           mid-stream rewind, EOF silence on a non-2048-multiple size
#           with a poisoned tail, c_err no-wedge/retry, rewind during an
#           in-flight fetch)
#   tier B: the adapter on client 0 of the REAL nd_storage stack against
#           nds_storage.img (TAPE.BPUN streamed whole and byte-compared,
#           rewind + re-read, EOF silence with zero req/mem traffic)
# ---------------------------------------------------------------------------
TAPE_ADAPTER_SRCS = $(STACK_SRCS) \
                    ../circuit/nd_storage_tape_adapter.v \
                    nd_storage_tape_adapter_tb.v

nd_storage_tape_adapter_tb.vvp: $(TAPE_ADAPTER_SRCS)
	$(IVERILOG) -g2005 -I../circuit -o $@ $(TAPE_ADAPTER_SRCS)

test-nds-tape: nd_storage_tape_adapter_tb.vvp nds_storage.img
	$(VVP) nd_storage_tape_adapter_tb.vvp | tee nds_tape_out.log
	@grep -q "TB_RESULT: PASS" nds_tape_out.log

.PHONY: test-nds-tape

# ---------------------------------------------------------------------------
# test-nds-floppy - step-8 DMA-floppy block adapter (spec acceptance test 6):
#   tier A: nd_storage_floppy_adapter against a SCRIPTED client-port stub
#           and a scripted disk-port driver replaying ND_FLOPPY_DMA's
#           backend handshake (full/partial sector reads, block-cache hit
#           counting, full-block direct write, RMW partial writes with a
#           full expectation-shadow compare, out-of-range, the step-6
#           tail-block write rule, c_err on fetch AND commit, drive
#           mismatch silence)
#   tier B: the adapter on client 1 of the REAL nd_storage stack against
#           nds_storage.img (FLOPPY1.IMG read byte-exact, sector write
#           verified IN THE CARD IMAGE at first_sector + read back through
#           the disk port, RMW partial write, out-of-range silence,
#           whole-card shadow compare against stray writes)
# ---------------------------------------------------------------------------
FLOPPY_ADAPTER_SRCS = $(STACK_SRCS) \
                      ../circuit/nd_storage_floppy_adapter.v \
                      nd_storage_floppy_adapter_tb.v

nd_storage_floppy_adapter_tb.vvp: $(FLOPPY_ADAPTER_SRCS)
	$(IVERILOG) -g2005 -I../circuit -o $@ $(FLOPPY_ADAPTER_SRCS)

test-nds-floppy: nd_storage_floppy_adapter_tb.vvp nds_storage.img
	$(VVP) nd_storage_floppy_adapter_tb.vvp | tee nds_floppy_out.log
	@grep -q "TB_RESULT: PASS" nds_floppy_out.log

.PHONY: test-nds-floppy
