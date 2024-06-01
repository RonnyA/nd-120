# Makefile for Verilog simulation using Icarus Verilog and GTKWave

# Files
VERILOG_SOURCES = ../F714.v F714_tb.v
OUTPUT_EXECUTABLE = F714_tb
VCD_FILE = F714_tb.vcd
WAVEFORM_FILE = F714.gtwk

# Commands
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Default target
all: simulate view_waveform

# Compile the Verilog files
$(OUTPUT_EXECUTABLE): $(VERILOG_SOURCES)
	$(IVERILOG) -o $(OUTPUT_EXECUTABLE) $(VERILOG_SOURCES)

# Run the simulation
simulate: $(OUTPUT_EXECUTABLE)
	$(VVP) $(OUTPUT_EXECUTABLE)

# View the waveform
view_waveform: $(VCD_FILE)
	$(GTKWAVE) $(VCD_FILE) $(WAVEFORM_FILE)

# Clean up generated files
clean:
	rm -f $(OUTPUT_EXECUTABLE) $(VCD_FILE)

.PHONY: all simulate view_waveform clean
