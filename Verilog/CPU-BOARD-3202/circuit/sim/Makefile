# Testbenches for CPU-BOARD-3202 circuit modules.
IVERILOG = iverilog
CIRCUIT  = ..
PAL      = ../../../PAL

# Exhaustive validation of CYC_TERM_D (TERM next-state mirror) vs PAL_44601B.
CYC_TERM_D_tb: CYC_TERM_D_tb.v $(CIRCUIT)/CYC_TERM_D.v $(PAL)/PAL_44601B.v
	$(IVERILOG) -g2012 -o $@ $^

test-cyctermd: CYC_TERM_D_tb
	./CYC_TERM_D_tb

# Exhaustive validation of CYC_CC_D (CC next-state mirror) vs PAL_44601B.
CYC_CC_D_tb: CYC_CC_D_tb.v $(CIRCUIT)/CYC_CC_D.v $(PAL)/PAL_44601B.v
	$(IVERILOG) -g2012 -o $@ $^

test-ccd: CYC_CC_D_tb
	./CYC_CC_D_tb

test-all: test-cyctermd test-ccd

clean:
	rm -f CYC_TERM_D_tb CYC_CC_D_tb *.vcd

.PHONY: test-cyctermd test-ccd test-all clean
