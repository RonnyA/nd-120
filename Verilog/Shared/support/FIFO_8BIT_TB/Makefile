# Makefile for Verilog simulation using Icarus Verilog and GTKWave

# Files
VERILOG_SOURCES = ../FIFO_8BIT.v FIFO_tb.v
OUTPUT_EXECUTABLE = fifo_tb
VCD_FILE = fifo_tb.vcd
WAVEFORM_FILE = fifo_tb.gtwk

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
