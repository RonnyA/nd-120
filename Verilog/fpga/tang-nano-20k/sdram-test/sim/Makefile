# iverilog testbench for the Tang Nano 20K SDRAM test
# (repo convention: sim/ next to the module it tests)

IVERILOG = iverilog
VVP      = vvp

SRCS = ../src/sdram_test_top.v \
       ../src/sdram.v \
       ../src/uart_tx.v \
       ../src/uart_rx.v \
       ../src/msg_printer.v \
       sdram_model.v \
       sdram_test_tb.v

all: test

sdram_test_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -DSIM -o $@ $(SRCS)

test: sdram_test_tb.vvp
	$(VVP) sdram_test_tb.vvp | tee sim_out.log
	@grep -q "TB_RESULT: PASS" sim_out.log

clean:
	rm -f sdram_test_tb.vvp sim_out.log

.PHONY: all test clean
