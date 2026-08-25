###############################################################################
# Basys3 memory-test bench
#
# Full path: Verilog/fpga/basys3/mem-test/sim/Makefile
#
# This bench existed with NO Makefile at all until 09-AUG-2026, when
# `make test-audit` found it: a testbench nothing could build is not coverage,
# it is a file that looks like coverage. It builds and passes; it just had no
# way to be run.
#
#   make test-basys3-memtest
###############################################################################
VERILOG_ROOT = ../../../..
include $(VERILOG_ROOT)/mk/iverilog.mk

MT = ..

SRCS = $(MT)/basys3_mem_test_top.v \
       $(MT)/msg_printer.v \
       $(MT)/uart_tx.v \
       $(VERILOG_ROOT)/CPU-BOARD-3202/circuit/MEM_RAM_49.v \
       $(VERILOG_ROOT)/Shared/support/SIP1M9.v

basys3_mem_test_tb.vvp: basys3_mem_test_tb.v $(SRCS)
	$(IVERILOG) -g2012 $(ND_INC) -o $@ basys3_mem_test_tb.v $(SRCS)

test-basys3-memtest: basys3_mem_test_tb.vvp
	$(VVP) basys3_mem_test_tb.vvp | tee basys3_memtest_out.log
	@grep -q "TB_RESULT: PASS" basys3_memtest_out.log

clean:
	rm -f *.vvp *.log *.vcd

.PHONY: test-basys3-memtest clean
