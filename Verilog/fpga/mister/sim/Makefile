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

.PHONY: all test-console test-diag-print test-csa-trace test-csa-trig test-sterr test-storage-hps test-storage-devices lint clean

all: test-console test-diag-print test-csa-trace test-csa-trig test-sterr test-storage-hps test-storage-devices
	@echo "MiSTer core: all testbenches passed"

# The storage backend: the ND-120 client bus (Verilog/docs/
# nd-storage-interface-spec.md section 4) served by the HPS block interface.
# Run against hps_io_model.v, a signal-level model of the ARM + hps_io that
# also CHECKS the handshake rules the ARM depends on (request held until ack,
# dropped on ack, lba stable) - the real ARM would silently misbehave rather
# than complain. Checks the byte order, the no-image error path, read-only and
# range refusals, and two clients at once on the broadcast buffer bus.
SDFAT = ../../../SD-FAT/circuit

test-storage-hps: nd_storage_hps_tb.vvp
	@$(VVP) $< | tee nd_storage_hps_tb.log
	@grep -q "TB_RESULT: PASS" nd_storage_hps_tb.log 		|| { echo "nd_storage_hps_tb FAILED"; exit 1; }

nd_storage_hps_tb.vvp: nd_storage_hps_tb.v hps_io_model.v ../rtl/nd_storage_hps.v
	$(IVERILOG) $(IVFLAGS) -I$(SDFAT) -o $@ $^

# The whole storage subsystem at the controller seams: two floppy adapters,
# two Winchester adapters and the tape adapter on the backend. The first
# configuration anywhere with a second floppy drive and a second Winchester
# unit - the bench exists to prove drive/unit 1 reads ITS slot and that the
# OR of two adapters' outputs is clean.
test-storage-devices: nd_storage_mister_devices_tb.vvp
	@$(VVP) $< | tee nd_storage_mister_devices_tb.log
	@grep -q "TB_RESULT: PASS" nd_storage_mister_devices_tb.log 		|| { echo "nd_storage_mister_devices_tb FAILED"; exit 1; }

nd_storage_mister_devices_tb.vvp: nd_storage_mister_devices_tb.v hps_io_model.v 		../rtl/nd_storage_mister_devices.v ../rtl/nd_storage_hps.v 		$(SDFAT)/nd_storage_floppy_adapter.v $(SDFAT)/nd_storage_disc_adapter.v 		$(SDFAT)/nd_storage_tape_adapter.v
	$(IVERILOG) $(IVFLAGS) -I$(SDFAT) -o $@ $^

# Microcode trace buffer. Ordering matters: its whole job is to be diffed
# against the simulator's csa_trace.csv, so an off-by-one would point at the
# wrong microinstruction.
test-csa-trace: nd120_csa_trace_tb.vvp
	@$(VVP) $< | tee nd120_csa_trace_tb.log
	@grep -q "TB_RESULT: PASS" nd120_csa_trace_tb.log \
		|| { echo "nd120_csa_trace_tb FAILED"; exit 1; }

nd120_csa_trace_tb.vvp: nd120_csa_trace_tb.v ../rtl/nd120_csa_trace.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

# The TRIGGERED capture mode: arm on a microcode address, record, then FREEZE.
# The freeze is the part that must not break - the event under investigation
# happens once and the machine then settles into a loop that would otherwise
# overwrite it.
test-csa-trig: nd120_csa_trace_trig_tb.vvp
	@$(VVP) $< | tee nd120_csa_trace_trig_tb.log
	@grep -q "TB_RESULT: PASS" nd120_csa_trace_trig_tb.log \
		|| { echo "nd120_csa_trace_trig_tb FAILED"; exit 1; }

nd120_csa_trace_trig_tb.vvp: nd120_csa_trace_trig_tb.v ../rtl/nd120_csa_trace.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

# Self-test failure catcher: must count ENTRIES into STERR, not clocks spent
# there, or a single visit reports a meaningless large number and the "the WCS
# loader walked past it once" case becomes invisible.
test-sterr: nd120_sterr_catch_tb.vvp
	@$(VVP) $< | tee nd120_sterr_catch_tb.log
	@grep -q "TB_RESULT: PASS" nd120_sterr_catch_tb.log \
		|| { echo "nd120_sterr_catch_tb FAILED"; exit 1; }

nd120_sterr_catch_tb.vvp: nd120_sterr_catch_tb.v ../rtl/nd120_sterr_catch.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

# The CPU liveness probe. It exists to be BELIEVED when it reports a dead
# clock or a stuck microcode address, so its formatting is checked rather
# than eyeballed - the MIPS tap on this project was flashed wrong twice.
test-diag-print: nd120_diag_print_tb.vvp
	@$(VVP) $< | tee nd120_diag_print_tb.log
	@grep -q "TB_RESULT: PASS" nd120_diag_print_tb.log \
		|| { echo "nd120_diag_print_tb FAILED"; exit 1; }

nd120_diag_print_tb.vvp: nd120_diag_print_tb.v ../rtl/nd120_diag_print.v
	$(IVERILOG) $(IVFLAGS) -o $@ $^

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
