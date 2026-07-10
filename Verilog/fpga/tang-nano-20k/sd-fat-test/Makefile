# Tang Nano 20K SD-FAT test - OSS toolchain flow (yosys / nextpnr / apicula)
#
# Requires oss-cad-suite on the PATH:  source ~/oss-cad-suite/environment
#
# Targets:
#   make          build build/sd_fat_test_top.fs
#   make load     volatile load into SRAM (fast iteration)
#   make flash    persistent (replaces whatever is in config flash)
#   make sim      run the self-checking iverilog testbenches (sim/)
#
# Card recipe and expected output: see README.md

TOP     = sd_fat_test_top
DEVICE  = GW2AR-LV18QN88C8/I7
FAMILY  = GW2A-18C
BOARD   = tangnano20k

# reusable SD/FAT library (board-independent, pins bound in the CST)
SDFAT   = ../../../SD-FAT/circuit

SRCS    = $(SDFAT)/sdcmd_ctrl.v \
          $(SDFAT)/sd_reader.v \
          $(SDFAT)/sd_file_reader.v \
          $(SDFAT)/sd_writer.v \
          src/uart_tx.v \
          src/uart_rx.v \
          src/status_printer.v \
          src/hex_dumper.v \
          src/buf_text_printer.v \
          src/sd_fat_test_top.v

BUILD   = build

all: $(BUILD)/$(TOP).fs

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/$(TOP).json: $(SRCS) | $(BUILD)
	yosys -l $(BUILD)/synth.log -p "read_verilog $(SRCS); synth_gowin -top $(TOP); write_json $@"

$(BUILD)/$(TOP)_pnr.json: $(BUILD)/$(TOP).json src/nano20k_sd.cst
	nextpnr-himbaechel --json $(BUILD)/$(TOP).json \
	    --write $(BUILD)/$(TOP)_pnr.json \
	    --device $(DEVICE) \
	    --vopt family=$(FAMILY) \
	    --vopt cst=src/nano20k_sd.cst

$(BUILD)/$(TOP).fs: $(BUILD)/$(TOP)_pnr.json
	gowin_pack -d $(FAMILY) -o $@ $<

# volatile load into SRAM (fast iteration; config flash untouched)
load: $(BUILD)/$(TOP).fs
	openFPGALoader -b $(BOARD) $<

# persistent: writes the config flash
flash: $(BUILD)/$(TOP).fs
	openFPGALoader -b $(BOARD) -f $<

sim:
	$(MAKE) -C sim

# interactive console into the Verilator simulation (terminal = UART, ESC exits)
console:
	$(MAKE) -C sim console

help:
	@echo "Tang Nano 20K SD-FAT test - targets:"
	@echo ""
	@echo "  Build / hardware (needs: source ~/oss-cad-suite/environment)"
	@echo "    make          build the bitstream (build/$(TOP).fs)"
	@echo "    make load     volatile load into FPGA SRAM (fast iteration)"
	@echo "    make flash    persistent: write the config flash"
	@echo ""
	@echo "  Simulation (run BEFORE hardware)"
	@echo "    make sim      run the registered checks (iverilog unit tb +"
	@echo "                  Verilator full-system test)"
	@echo "    make console  INTERACTIVE Verilator sim: your terminal is the"
	@echo "                  UART console - menu keys 1/2/3/H live, ESC exits"
	@echo "    make -C sim help   all simulation targets in detail"
	@echo ""
	@echo "  make clean    remove build products and sim artifacts"
	@echo ""
	@echo "  Card recipe + expected output: README.md"

clean:
	rm -rf $(BUILD)
	$(MAKE) -C sim clean

.PHONY: all load flash sim console help clean
