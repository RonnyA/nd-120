# iverilog testbench for the Tang Nano 20K sdram18 test
# (repo convention: sim/ next to the module it tests)
# Reuses the behavioral SDRAM model from ../../sdram-test/sim.

IVERILOG = iverilog
VVP      = vvp

SRCS = ../src/sdram18_test_top.v \
       ../src/msg_printer18.v \
       ../../sdram-bridge/sdram18.v \
       ../../sdram-test/src/uart_tx.v \
       ../../sdram-test/src/uart_rx.v \
       ../../sdram-test/sim/sdram_model.v \
       sdram18_test_tb.v

all: test

sdram18_test_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -DSIM -o $@ $(SRCS)

test: sdram18_test_tb.vvp
	$(VVP) sdram18_test_tb.vvp | tee sim_out.log
	@grep -q "TB_RESULT: PASS" sim_out.log

clean:
	rm -f sdram18_test_tb.vvp sim_out.log

.PHONY: all test clean
