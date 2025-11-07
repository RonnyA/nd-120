# Makefile for running testbenches for Vivado warning fixes
# Uses Icarus Verilog (iverilog) for simulation

# Verilog compiler
IVERILOG = iverilog
VVP = vvp

# Include paths for module dependencies
VERILOG_ROOT = ../..
INC_PATHS = -I$(VERILOG_ROOT)/PAL \
            -I$(VERILOG_ROOT)/DELILAH-CPU/CGA/circuit \
            -I$(VERILOG_ROOT)/DELILAH-CPU/CGA_MIC/circuit \
            -I$(VERILOG_ROOT)/CPU-BOARD-3202/circuit \
            -I$(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit \
            -I$(VERILOG_ROOT)/Shared/support \
            -I$(VERILOG_ROOT)/Shared/ndlib

# Testbench files
TBS = PAL_44304E_tb \
      PAL_45008B_tb \
      BusDriver16_tb \
      CGA_MIC_MASEL_tb \
      CPU_CS_TCV_20_tb \
      F595_tb

# Default target - run all tests
all: $(TBS)
	@echo "========================================"
	@echo "Running all testbenches..."
	@echo "========================================"
	@for tb in $(TBS); do \
		echo ""; \
		echo "Running $$tb..."; \
		echo "----------------------------------------"; \
		./$$tb || echo "FAILED: $$tb"; \
	done
	@echo ""
	@echo "========================================"
	@echo "All testbenches complete!"
	@echo "========================================"

# Pattern rule for compiling testbenches
%_tb: %_tb.v
	@echo "Compiling $<..."
	$(IVERILOG) -g2012 $(INC_PATHS) -o $@ $<

# Individual test targets
PAL_44304E_tb: PAL_44304E_tb.v $(VERILOG_ROOT)/PAL/PAL_44304E.v
	$(IVERILOG) -g2012 $(INC_PATHS) -o $@ $^

PAL_45008B_tb: PAL_45008B_tb.v $(VERILOG_ROOT)/PAL/PAL_45008B.v
	$(IVERILOG) -g2012 $(INC_PATHS) -o $@ $^

BusDriver16_tb: BusDriver16_tb.v $(VERILOG_ROOT)/DELILAH-CPU/CGA/circuit/BusDriver16.v
	$(IVERILOG) -g2012 $(INC_PATHS) -o $@ $^

CGA_MIC_MASEL_tb: CGA_MIC_MASEL_tb.v $(VERILOG_ROOT)/DELILAH-CPU/CGA_MIC/circuit/CGA_MIC_MASEL.v
	$(IVERILOG) -g2012 $(INC_PATHS) -o $@ $^

CPU_CS_TCV_20_tb: CPU_CS_TCV_20_tb.v $(VERILOG_ROOT)/CPU-BOARD-3202/circuit/CPU_CS_TCV_20.v
	$(IVERILOG) -g2012 $(INC_PATHS) -o $@ $^

F595_tb: F595_tb.v $(VERILOG_ROOT)/DECODE-GateArray/DGA/circuit/F595.v
	$(IVERILOG) -g2012 $(INC_PATHS) -o $@ $^

# Clean up generated files
clean:
	rm -f $(TBS) *.vcd *.lxt

# Run individual tests
test-pal44304e: PAL_44304E_tb
	./PAL_44304E_tb

test-pal45008b: PAL_45008B_tb
	./PAL_45008B_tb

test-busdriver16: BusDriver16_tb
	./BusDriver16_tb

test-masel: CGA_MIC_MASEL_tb
	./CGA_MIC_MASEL_tb

test-tcv20: CPU_CS_TCV_20_tb
	./CPU_CS_TCV_20_tb

test-f595: F595_tb
	./F595_tb

.PHONY: all clean test-pal44304e test-pal45008b test-busdriver16 test-masel test-tcv20 test-f595
