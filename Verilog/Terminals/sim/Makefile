# Testbenches for the board-independent terminal core (Verilog/Terminals/)
#
#   make            build and run every testbench, fail loudly on the first
#                   one that does not print TB_RESULT: PASS
#   make test-vga-timing     just the VGA timing testbench
#   make test-terminal-ctrl  just the terminal control testbench
#   make test-ps2-keyboard   just the PS/2 keyboard testbench
#   make test-console-uart   just the console UART loopback testbench
#   make test-console-loop   the whole console end to end
#   make test-text-screen    every pixel of four frames vs an independent model
#   make test-banner         the power-on message sender
#   make test-panel          the ND-120 operator panel
#   make lint       Verilator lint over the whole terminal core
#   make clean
#
# Run from WSL/Linux with iverilog on PATH (oss-cad-suite or the distro
# package). The repo convention is that every testbench prints a
# machine-checkable verdict - a test that can pass silently can fail silently.

SHELL := /bin/bash
.DELETE_ON_ERROR:

IVERILOG ?= iverilog
VVP      ?= vvp
RTL       = ../rtl

# -g2012 for the SystemVerilog-flavoured bits iverilog accepts by default
# elsewhere in this repo; -Wall to catch width mistakes early.
IVFLAGS = -g2012 -Wall -I$(RTL)

.PHONY: all test-vga-timing test-terminal-ctrl test-ps2-keyboard test-console-uart test-console-loop test-text-screen test-banner test-panel lint clean

all: test-vga-timing test-terminal-ctrl test-ps2-keyboard test-console-uart test-console-loop test-text-screen test-banner test-panel
	@echo "terminal core: all testbenches passed"

test-vga-timing: vga_timing_tb.vvp
	@$(VVP) $< | tee vga_timing_tb.log
	@grep -q "TB_RESULT: PASS" vga_timing_tb.log || { echo "vga_timing_tb FAILED"; exit 1; }

test-terminal-ctrl: terminal_ctrl_tb.vvp
	@$(VVP) $< | tee terminal_ctrl_tb.log
	@grep -q "TB_RESULT: PASS" terminal_ctrl_tb.log || { echo "terminal_ctrl_tb FAILED"; exit 1; }

test-ps2-keyboard: ps2_keyboard_tb.vvp
	@$(VVP) $< | tee ps2_keyboard_tb.log
	@grep -q "TB_RESULT: PASS" ps2_keyboard_tb.log || { echo "ps2_keyboard_tb FAILED"; exit 1; }

ps2_keyboard_tb.vvp: ps2_keyboard_tb.v $(RTL)/ps2_keyboard.v $(RTL)/ps2_decoder.v $(RTL)/ps2_ascii_table.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

test-console-uart: console_uart_tb.vvp
	@$(VVP) $< | tee console_uart_tb.log
	@grep -q "TB_RESULT: PASS" console_uart_tb.log || { echo "console_uart_tb FAILED"; exit 1; }

console_uart_tb.vvp: console_uart_tb.v $(RTL)/console_uart_tx.v $(RTL)/console_uart_rx.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

test-console-loop: terminal_console_tb.vvp
	@$(VVP) $< | tee terminal_console_tb.log
	@grep -q "TB_RESULT: PASS" terminal_console_tb.log || { echo "terminal_console_tb FAILED"; exit 1; }

terminal_console_tb.vvp: terminal_console_tb.v $(RTL)/console_uart_tx.v $(RTL)/console_uart_rx.v $(RTL)/terminal_top.v $(RTL)/terminal_ctrl.v $(RTL)/char_ram.v $(RTL)/text_screen.v $(RTL)/vga_timing.v $(RTL)/font_rom.v $(RTL)/cdc_byte.v $(RTL)/ps2_keyboard.v $(RTL)/ps2_decoder.v $(RTL)/ps2_ascii_table.v $(RTL)/term_console_feed.v $(RTL)/term_banner.v $(RTL)/term_banner_rom.v $(RTL)/term_panel.v $(RTL)/term_panel_rom.v $(RTL)/rate_meter.v $(RTL)/ratio_meter.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

test-text-screen: text_screen_tb.vvp
	@$(VVP) $< | tee text_screen_tb.log
	@grep -q "TB_RESULT: PASS" text_screen_tb.log || { echo "text_screen_tb FAILED"; exit 1; }

text_screen_tb.vvp: text_screen_tb.v $(RTL)/text_screen.v $(RTL)/vga_timing.v $(RTL)/font_rom.v $(RTL)/char_ram.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

test-panel: term_panel_tb.vvp
	@$(VVP) $< | tee term_panel_tb.log
	@grep -q "TB_RESULT: PASS" term_panel_tb.log || { echo "term_panel_tb FAILED"; exit 1; }

term_panel_tb.vvp: term_panel_tb.v $(RTL)/term_panel.v $(RTL)/term_panel_rom.v $(RTL)/font_rom.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

test-banner: term_banner_tb.vvp
	@$(VVP) $< | tee term_banner_tb.log
	@grep -q "TB_RESULT: PASS" term_banner_tb.log || { echo "term_banner_tb FAILED"; exit 1; }

term_banner_tb.vvp: term_banner_tb.v $(RTL)/term_banner.v $(RTL)/term_banner_rom.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

vga_timing_tb.vvp: vga_timing_tb.v $(RTL)/vga_timing.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

terminal_ctrl_tb.vvp: terminal_ctrl_tb.v $(RTL)/terminal_ctrl.v $(RTL)/char_ram.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

# Verilator lint. The suppression list is the SAME one the project uses in
# Verilog/sim and Verilog/runSim - deviating here would make "clean" mean
# something different in this folder than everywhere else. Verilator catches
# the classes iverilog does not and that matter on an FPGA: inferred latches,
# combinational loops, undriven nets.
VERILATOR ?= verilator
VVFLAGS = --lint-only -Wall   -Wno-BLKSEQ -Wno-DECLFILENAME -Wno-EOFNEWLINE -Wno-LATCH -Wno-PINCONNECTEMPTY   -Wno-PINMISSING -Wno-SYNCASYNCNET -Wno-TIMESCALEMOD -Wno-UNDRIVEN   -Wno-UNOPTFLAT -Wno-UNUSED -Wno-WIDTH

lint:
	$(VERILATOR) $(VVFLAGS) --top-module terminal_top $(RTL)/terminal_top.v $(RTL)/terminal_ctrl.v $(RTL)/char_ram.v $(RTL)/text_screen.v $(RTL)/vga_timing.v $(RTL)/font_rom.v $(RTL)/cdc_byte.v $(RTL)/term_panel.v $(RTL)/term_panel_rom.v $(RTL)/rate_meter.v $(RTL)/ratio_meter.v
	$(VERILATOR) $(VVFLAGS) --top-module ps2_keyboard 	  $(RTL)/ps2_keyboard.v $(RTL)/ps2_decoder.v $(RTL)/ps2_ascii_table.v
	$(VERILATOR) $(VVFLAGS) --top-module ps2_decoder 	  $(RTL)/ps2_decoder.v $(RTL)/ps2_ascii_table.v
	$(VERILATOR) $(VVFLAGS) --top-module term_panel 	  $(RTL)/term_panel.v $(RTL)/term_panel_rom.v $(RTL)/rate_meter.v $(RTL)/ratio_meter.v $(RTL)/font_rom.v
	$(VERILATOR) $(VVFLAGS) --top-module term_banner 	  $(RTL)/term_banner.v $(RTL)/term_banner_rom.v
	$(VERILATOR) $(VVFLAGS) --top-module console_uart_rx $(RTL)/console_uart_rx.v
	$(VERILATOR) $(VVFLAGS) --top-module console_uart_tx $(RTL)/console_uart_tx.v
	@echo "terminal core: verilator lint clean"

clean:
	rm -f *.vvp *.vcd *.log
