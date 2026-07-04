# Makefile for IDT6168A_20 testbench — Icarus Verilog

VERILOG_SOURCES = ../IDT6168A_20.v IDT6168A_20_tb.v
OUTPUT_EXECUTABLE = IDT6168A_20_tb
VCD_FILE = IDT6168A_20_tb.vcd

IVERILOG = iverilog -DVERILATOR_SIM
VVP = vvp
GTKWAVE = gtkwave

all: simulate

$(OUTPUT_EXECUTABLE): $(VERILOG_SOURCES)
	$(IVERILOG) -o $(OUTPUT_EXECUTABLE) $(VERILOG_SOURCES)

simulate: $(OUTPUT_EXECUTABLE)
	$(VVP) $(OUTPUT_EXECUTABLE)

view_waveform: $(VCD_FILE)
	$(GTKWAVE) $(VCD_FILE)

clean:
	rm -f $(OUTPUT_EXECUTABLE) $(VCD_FILE)

.PHONY: all simulate view_waveform clean
