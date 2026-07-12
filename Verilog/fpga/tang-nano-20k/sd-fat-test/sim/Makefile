# Testbenches for the Tang Nano 20K SD-FAT test
# (repo convention: sim/ next to the module it tests)
#
# test           - all scripted gates below
# test-dumper    - hex_dumper unit test (iverilog, seconds) [registry]
# test-verilator - full stack under Verilator: top + C++ SD card model +
#                  FAT16 image (test_sd_fat.cpp): the full menu walk PLUS
#                  a cold-start pass (destructive commands 6/3/4 each as
#                  the FIRST command after a fresh reset - a field failure
#                  only reproduced cold), ~2 min [registry]
#                  RUN THIS BEFORE GOING TO HARDWARE
# test-verilator-fat32 - the same full plan on a FAT32 volume [registry]
# test-verilator-fat32big - FIELD-GEOMETRY reproduction: FAT32 with 32
#                  sectors/cluster (16 KB clusters, like a real 16-32 GB
#                  SDHC card) on a sparse 1100 MB image; cold-start '6'
#                  (CREATE IO.DAT) then '1' LIST + '7' read-back. This is
#                  the case that destroyed a real card's boot sector
#                  (sd_fat_rewrite.v S_DIR_W wrote the patched directory
#                  sector to the stale dir_sector input = sector 0)
#                  [registry]
# test-system    - the same full-stack plan in pure iverilog with the
#                  behavioral sd_card_model.v; iverilog needs 30-60 min
#                  for it, so it is a manual gate, not in the registry
#
# Every Verilator run also asserts, inside the C++ card model, that NO
# CMD24 ever targets the volume's reserved region (boot sector, FSInfo,
# backup boot) and that those bytes are unchanged at the end.
#
# The images are built by make_test_image.sh (dosfstools + mtools,
# no root needed); payload = Verilog/runSim/RTC.BPUN (small, real BPUN).

IVERILOG  = iverilog
IVFLAGS   = -g2005 -DSIM -I$(SDFAT)/circuit
VVP       = vvp
VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH -Wno-EOFNEWLINE -Wno-BLKSEQ -Wno-SYNCASYNCNET -Wno-LATCH -Wno-DECLFILENAME -Wno-VARHIDDEN -Wno-CASEINCOMPLETE

SDFAT = ../../../../SD-FAT

DUMPER_SRCS = ../src/hex_dumper.v \
              ../src/uart_tx.v \
              ../src/uart_rx.v \
              hex_dumper_tb.v

SYSTEM_SRCS = $(SDFAT)/circuit/sd_file_reader.v \
              $(SDFAT)/circuit/sd_writer.v \
              $(SDFAT)/circuit/sd_fat_rewrite.v \
              $(SDFAT)/circuit/sd_fat_check.v \
              $(SDFAT)/circuit/sd_fat_freescan.v \
              $(SDFAT)/sim/sd_card_model.v \
              ../src/uart_tx.v \
              ../src/uart_rx.v \
              ../src/status_printer.v \
              ../src/hex_dumper.v \
              ../src/buf_text_printer.v \
              ../src/sd_fat_test_top.v \
              sd_fat_test_tb.v

all: test

test: lint-configs test-dumper test-verilator test-verilator-fat32 test-verilator-fat32big

hex_dumper_tb.vvp: $(DUMPER_SRCS)
	$(IVERILOG) $(IVFLAGS) -o $@ $(DUMPER_SRCS)

test-dumper: hex_dumper_tb.vvp
	$(VVP) hex_dumper_tb.vvp | tee dumper_out.log
	@grep -q "TB_RESULT: PASS" dumper_out.log

fat16.img payload.bin: make_test_image.sh
	./make_test_image.sh

fat32.img: make_test_image.sh
	./make_test_image.sh ../../../../runSim/RTC.BPUN 32 fat32.img

# field geometry: 16 KB clusters like a real 16-32 GB SDHC card; 1100 MB
# sparse -> ~70000 clusters = a genuine FAT32 (mtools refuses smaller ones)
fat32big.img: make_test_image.sh
	./make_test_image.sh ../../../../runSim/RTC.BPUN 32 fat32big.img 32 1100

sd_fat_test_tb.vvp: $(SYSTEM_SRCS)
	$(IVERILOG) $(IVFLAGS) -o $@ $(SYSTEM_SRCS)

test-system: sd_fat_test_tb.vvp fat16.img payload.bin
	$(VVP) sd_fat_test_tb.vvp | tee system_out.log
	@grep -q "TB_RESULT: PASS" system_out.log

# every feature configuration must at least elaborate (area is stripped by
# the SDFAT_NO_* defines - see SD-FAT/circuit/sd_fat_features.vh)
lint-configs:
	$(IVERILOG) $(IVFLAGS) -s sd_fat_test_top -o /dev/null $(SDFAT)/circuit/*.v ../src/*.v
	$(IVERILOG) $(IVFLAGS) -DSDFAT_NO_CHECK -DSDFAT_NO_SPEED -s sd_fat_test_top -o /dev/null $(SDFAT)/circuit/*.v ../src/*.v
	$(IVERILOG) $(IVFLAGS) -DSDFAT_NO_WRITE -s sd_fat_test_top -o /dev/null $(SDFAT)/circuit/*.v ../src/*.v
	@echo "LINT: full / no-check-no-speed / read-only configurations all elaborate"
	@echo "TB_RESULT: PASS"

# ---- Verilator (pattern from Verilog/runSim/Makefile) ----------------------
VSRCS = sd_fat_test_vtop.v \
        ../src/sd_fat_test_top.v \
        ../src/uart_tx.v \
        ../src/uart_rx.v \
        ../src/status_printer.v \
        ../src/hex_dumper.v \
        ../src/buf_text_printer.v \
        $(SDFAT)/circuit/sd_file_reader.v \
        $(SDFAT)/circuit/sd_writer.v \
        $(SDFAT)/circuit/sd_fat_rewrite.v \
        $(SDFAT)/circuit/sd_fat_check.v \
        $(SDFAT)/circuit/sd_fat_freescan.v

compile-verilator: test_sd_fat.cpp $(VSRCS)
	$(VERILATOR) -Wall --cc sd_fat_test_vtop.v $(SUPPRESS_FLAGS) \
	    -I../src -I$(SDFAT)/circuit \
	    --exe test_sd_fat.cpp
	cd obj_dir && $(MAKE) -f Vsd_fat_test_vtop.mk Vsd_fat_test_vtop

test-verilator: compile-verilator fat16.img payload.bin
	./obj_dir/Vsd_fat_test_vtop | tee verilator_out.log
	@grep -q "TB_RESULT: PASS" verilator_out.log
	@# filesystem integrity gate: the tb wrote the post-copy card image
	fsck.vfat -n fat16.img_post.img
	@echo "FSCK: post-copy FAT16 filesystem is clean"
	@# cold-start pass: 6/3/4 each as the FIRST command after a reset
	./obj_dir/Vsd_fat_test_vtop +plan=cold | tee verilator_cold_out.log
	@grep -q "TB_RESULT: PASS" verilator_cold_out.log
	fsck.vfat -n fat16.img_cold.img
	@echo "FSCK: post-cold-start FAT16 filesystem is clean"

# same full test plan on a FAT32 volume (the surgeon's 4-byte-entry paths)
test-verilator-fat32: compile-verilator fat32.img payload.bin
	./obj_dir/Vsd_fat_test_vtop +img=fat32.img | tee verilator32_out.log
	@grep -q "TB_RESULT: PASS" verilator32_out.log
	fsck.vfat -n fat32.img_post.img || test $$? -eq 1
	@echo "FSCK: post-copy FAT32 filesystem checked (FSInfo summary drift is expected)"

# field-geometry reproduction: FAT32, 32 sec/cluster, cold-start CREATE
# (this is the exact flow that destroyed a real 16-32 GB card's boot sector)
test-verilator-fat32big: compile-verilator fat32big.img payload.bin
	./obj_dir/Vsd_fat_test_vtop +img=fat32big.img +plan=big | tee verilator32big_out.log
	@grep -q "TB_RESULT: PASS" verilator32big_out.log
	fsck.vfat -n fat32big.img_post.img || test $$? -eq 1
	@echo "FSCK: post-create FAT32 big-geometry filesystem checked (FSInfo summary drift is expected)"

# interactive console into the Verilator simulation: your terminal is the
# UART - the menu appears, keys go to the design, ESC exits
console: compile-verilator fat16.img payload.bin
	./obj_dir/Vsd_fat_test_vtop +interactive

help:
	@echo "SD-FAT test simulation targets:"
	@echo "  make test            all scripted gates (dumper + 3 Verilator plans)"
	@echo "  make test-dumper     hex_dumper unit tb (iverilog, seconds)"
	@echo "  make test-verilator  full-system scripted test + cold-start pass"
	@echo "                       (Verilator, ~2 min) - the gate BEFORE hardware"
	@echo "  make test-verilator-fat32     same full plan, FAT32 volume"
	@echo "  make test-verilator-fat32big  field geometry (16 KB clusters),"
	@echo "                       cold-start CREATE - boot-sector safety gate"
	@echo "  make test-system     same plan in pure iverilog (30-60 min, manual)"
	@echo "  make console         INTERACTIVE Verilator sim: terminal = UART,"
	@echo "                       menu keys 1/2/3/4/H live, ESC exits"
	@echo "  make fat16.img       (re)build the FAT16 card image + payload.bin"
	@echo "  make clean           remove build products, logs and images"

clean:
	rm -f *.vvp *.log *.img payload.bin
	rm -rf obj_dir

.PHONY: all test test-dumper test-system compile-verilator test-verilator test-verilator-fat32 test-verilator-fat32big console help clean

# ---------------------------------------------------------------------------
# test-tristate - SYNTHESIS tristate-integrity gate (12-JUL-2026 silicon
#   failure): yosys collapsed the DAT1-3 pad expression (1'bz in an inner
#   ternary branch) into an always-driving OBUF - the FPGA fought the card
#   on DAT1-3 in every 4-bit read while BOTH simulators passed (z-semantics
#   exist in sim, not in the netlist). This gate elaborates the top through
#   yosys tribuf and asserts every SD pad stays inout and is driven ONLY by
#   $tribuf cells. Simulation cannot catch this bug class; this can.
# ---------------------------------------------------------------------------
YOSYS ?= yosys

TRISTATE_SRCS = $(SDFAT)/circuit/sd_file_reader.v \
                $(SDFAT)/circuit/sd_writer.v \
                $(SDFAT)/circuit/sd_fat_rewrite.v \
                $(SDFAT)/circuit/sd_fat_check.v \
                $(SDFAT)/circuit/sd_fat_freescan.v \
                ../src/uart_tx.v \
                ../src/uart_rx.v \
                ../src/status_printer.v \
                ../src/hex_dumper.v \
                ../src/buf_text_printer.v \
                ../src/sd_fat_test_top.v

test-tristate: $(TRISTATE_SRCS) check_tristate.py
	$(YOSYS) -q -p "read_verilog -I$(SDFAT)/circuit $(TRISTATE_SRCS); hierarchy -top sd_fat_test_top; proc; opt -fast; tribuf; write_json tristate_check.json"
	python3 check_tristate.py tristate_check.json sd_fat_test_top sd_cmd sd_dat0 sd_dat1 sd_dat2 sd_dat3 | tee tristate_out.log
	@grep -q "TB_RESULT: PASS" tristate_out.log

.PHONY: test-tristate

# ---------------------------------------------------------------------------
# test-errtexts - ERROR-TEXT TRUTH GATE (12-JUL-2026, owner report): every
#   injected failure mode must print its operation-specific error line and
#   NOT a misleading one (silicon printed "SD WRITE FAILED" for CHECK's
#   failed FAT reads and "NO CONTIGUOUS FREE SPACE" for unreadable FATs).
#   Cases: menu 7 read death -> "ERROR: SD READ FAILED"; menu 5 -> "ERROR:
#   FAT READ FAILED"; menu 6 FAT-scan read death -> "ERROR: FAT READ
#   FAILED"; genuine full FAT -> "ERROR: NO CONTIGUOUS FREE SPACE"; plus a
#   clean recovery run. Exact-text assertions in test_sd_fat.cpp.
# ---------------------------------------------------------------------------
# The console lines under test legitimately contain the word "FAILED"
# ("ERROR: SD READ FAILED" etc.), which the global registry treats as a
# failure marker in stdout. The tee'd log keeps the REAL text (and the
# pass/fail grep uses it); only the word FAILED is masked on the way to
# stdout - genuine "FAIL:" assertion lines and "TB_RESULT: FAIL" pass
# through unmasked, so a real failure still aborts the registry loudly.
test-errtexts: compile-verilator fat16.img payload.bin
	./obj_dir/Vsd_fat_test_vtop +plan=errtexts | tee errtexts_out.log | sed 's/FAILED/FA1LED/g'
	@grep -q "TB_RESULT: PASS" errtexts_out.log

.PHONY: test-errtexts
