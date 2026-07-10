# Testbenches for the Tang Nano 20K SD-FAT test
# (repo convention: sim/ next to the module it tests)
#
# test           - both iverilog testbenches
# test-dumper    - hex_dumper unit test (iverilog, seconds) [registry]
# test-verilator - full stack under Verilator: top + C++ SD card model +
#                  FAT16 image (test_sd_fat.cpp), ~2 min [registry]
#                  RUN THIS BEFORE GOING TO HARDWARE
# test-system    - the same full-stack plan in pure iverilog with the
#                  behavioral sd_card_model.v; iverilog needs 30-60 min
#                  for it, so it is a manual gate, not in the registry
#
# The FAT16 image is built by make_test_image.sh (dosfstools + mtools,
# no root needed); payload = Verilog/runSim/RTC.BPUN (small, real BPUN).

IVERILOG  = iverilog
VVP       = vvp
VERILATOR = verilator

SUPPRESS_FLAGS = -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-UNUSED -Wno-UNDRIVEN -Wno-WIDTH -Wno-EOFNEWLINE -Wno-BLKSEQ -Wno-SYNCASYNCNET -Wno-LATCH -Wno-DECLFILENAME -Wno-VARHIDDEN -Wno-CASEINCOMPLETE

SDFAT = ../../../../SD-FAT

DUMPER_SRCS = ../src/hex_dumper.v \
              ../src/uart_tx.v \
              ../src/uart_rx.v \
              hex_dumper_tb.v

SYSTEM_SRCS = $(SDFAT)/circuit/sdcmd_ctrl.v \
              $(SDFAT)/circuit/sd_reader.v \
              $(SDFAT)/circuit/sd_file_reader.v \
              $(SDFAT)/circuit/sd_writer.v \
              $(SDFAT)/sim/sd_card_model.v \
              ../src/uart_tx.v \
              ../src/uart_rx.v \
              ../src/status_printer.v \
              ../src/hex_dumper.v \
              ../src/buf_text_printer.v \
              ../src/sd_fat_test_top.v \
              sd_fat_test_tb.v

all: test

test: test-dumper test-verilator

hex_dumper_tb.vvp: $(DUMPER_SRCS)
	$(IVERILOG) -g2005 -DSIM -o $@ $(DUMPER_SRCS)

test-dumper: hex_dumper_tb.vvp
	$(VVP) hex_dumper_tb.vvp | tee dumper_out.log
	@grep -q "TB_RESULT: PASS" dumper_out.log

fat16.img payload.bin: make_test_image.sh
	./make_test_image.sh

sd_fat_test_tb.vvp: $(SYSTEM_SRCS)
	$(IVERILOG) -g2005 -DSIM -o $@ $(SYSTEM_SRCS)

test-system: sd_fat_test_tb.vvp fat16.img payload.bin
	$(VVP) sd_fat_test_tb.vvp | tee system_out.log
	@grep -q "TB_RESULT: PASS" system_out.log

# ---- Verilator (pattern from Verilog/runSim/Makefile) ----------------------
VSRCS = sd_fat_test_vtop.v \
        ../src/sd_fat_test_top.v \
        ../src/uart_tx.v \
        ../src/uart_rx.v \
        ../src/status_printer.v \
        ../src/hex_dumper.v \
        ../src/buf_text_printer.v \
        $(SDFAT)/circuit/sd_file_reader.v \
        $(SDFAT)/circuit/sd_reader.v \
        $(SDFAT)/circuit/sdcmd_ctrl.v \
        $(SDFAT)/circuit/sd_writer.v

compile-verilator: test_sd_fat.cpp $(VSRCS)
	$(VERILATOR) -Wall --cc sd_fat_test_vtop.v $(SUPPRESS_FLAGS) \
	    -I../src -I$(SDFAT)/circuit \
	    --exe test_sd_fat.cpp
	cd obj_dir && $(MAKE) -f Vsd_fat_test_vtop.mk Vsd_fat_test_vtop

test-verilator: compile-verilator fat16.img payload.bin
	./obj_dir/Vsd_fat_test_vtop | tee verilator_out.log
	@grep -q "TB_RESULT: PASS" verilator_out.log

# interactive console into the Verilator simulation: your terminal is the
# UART - the menu appears, keys go to the design, ESC exits
console: compile-verilator fat16.img payload.bin
	./obj_dir/Vsd_fat_test_vtop +interactive

help:
	@echo "SD-FAT test simulation targets:"
	@echo "  make test            fast checks: test-dumper + test-verilator"
	@echo "  make test-dumper     hex_dumper unit tb (iverilog, seconds)"
	@echo "  make test-verilator  full-system scripted test (Verilator, ~2 min)"
	@echo "                       - the gate to pass BEFORE hardware"
	@echo "  make test-system     same plan in pure iverilog (30-60 min, manual)"
	@echo "  make console         INTERACTIVE Verilator sim: terminal = UART,"
	@echo "                       menu keys 1/2/3/4/H live, ESC exits"
	@echo "  make fat16.img       (re)build the FAT16 card image + payload.bin"
	@echo "  make clean           remove build products, logs and images"

clean:
	rm -f *.vvp *.log fat16.img payload.bin
	rm -rf obj_dir

.PHONY: all test test-dumper test-system compile-verilator test-verilator console help clean
