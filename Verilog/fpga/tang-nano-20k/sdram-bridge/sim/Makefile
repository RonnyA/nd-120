# iverilog testbench for the ND-120 sheet-49 SDRAM backend
# (reuses the behavioral SDRAM model from ../../sdram-test/sim/)

IVERILOG = iverilog
VVP      = vvp

SRCS = ../MEM_RAM_49_SDRAM.v \
       ../sdram18.v \
       ../../sdram-test/sim/sdram_model.v \
       mem_ram_49_sdram_tb.v

all: test

mem_ram_49_sdram_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -o $@ $(SRCS)

test: mem_ram_49_sdram_tb.vvp
	$(VVP) mem_ram_49_sdram_tb.vvp | tee sim_out.log
	@grep -q "TB_RESULT: PASS" sim_out.log

clean:
	rm -f mem_ram_49_sdram_tb.vvp sim_out.log

.PHONY: all test clean
