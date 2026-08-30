# Testbenches for the MiSTer-specific parts of the ND-120 core.
#
#   make               build and run every testbench here
#   make test-console  the console glue (keyboard decode, banner, echo)
#   make lint          Verilator lint over the MiSTer glue + the terminal core
#   make clean
#
# The board-independent terminal core has its own, much larger, test suite in
# Verilog/Terminals/sim/. What is tested HERE is only the glue that is specific
# to this board - see the header of nd120_console_mister_tb.v for why glue is
# worth testing separately.
#
# Run from WSL/Linux with iverilog on PATH.

SHELL := /bin/bash
.DELETE_ON_ERROR:

IVERILOG ?= iverilog
VVP      ?= vvp
GLUE      = ../rtl
TERM      = ../../../Terminals/rtl

IVFLAGS = -g2012 -Wall

TERM_SRC = $(TERM)/terminal_top.v $(TERM)/terminal_ctrl.v $(TERM)/text_screen.v \
           $(TERM)/char_ram.v $(TERM)/vga_timing.v $(TERM)/font_rom.v \
           $(TERM)/cdc_byte.v $(TERM)/byte_fifo.v $(TERM)/ps2_decoder.v $(TERM)/ps2_ascii_table.v \
           $(TERM)/term_banner.v $(TERM)/term_banner_rom.v \
           $(TERM)/term_console_feed.v $(TERM)/term_panel.v $(TERM)/term_panel_rom.v $(TERM)/rate_meter.v $(TERM)/ratio_meter.v

.PHONY: all test-console lint clean

all: test-console
	@echo "MiSTer core: all testbenches passed"

test-console: nd120_console_mister_tb.vvp
	@$(VVP) $< | tee nd120_console_mister_tb.log
	@grep -q "TB_RESULT: PASS" nd120_console_mister_tb.log \
		|| { echo "nd120_console_mister_tb FAILED"; exit 1; }

nd120_console_mister_tb.vvp: nd120_console_mister_tb.v $(GLUE)/nd120_console_mister.v $(TERM_SRC)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

# Same suppression list as Verilog/sim and Verilog/Terminals/sim - "lint clean"
# has to mean the same thing everywhere or it means nothing.
VERILATOR ?= verilator
VVFLAGS = --lint-only -Wall \
  -Wno-BLKSEQ -Wno-DECLFILENAME -Wno-EOFNEWLINE -Wno-LATCH -Wno-PINCONNECTEMPTY \
  -Wno-PINMISSING -Wno-SYNCASYNCNET -Wno-TIMESCALEMOD -Wno-UNDRIVEN \
  -Wno-UNOPTFLAT -Wno-UNUSED -Wno-WIDTH

lint:
	$(VERILATOR) $(VVFLAGS) --top-module nd120_console_mister \
	  $(GLUE)/nd120_console_mister.v $(TERM_SRC)
	@echo "MiSTer console glue: verilator lint clean"

clean:
	rm -f *.vvp *.vcd *.log
