###############################################################################
# QMTECH A35T memory-test bench
#
# Full path: Verilog/fpga/qmtech-a35t/mem-test/sim/Makefile
#
# This bench existed with NO Makefile at all until 09-AUG-2026, when
# `make test-audit` found it: a testbench nothing could build is not coverage,
# it is a file that looks like coverage. It builds and passes; it just had no
# way to be run.
#
#   make test-qmtech-memtest
###############################################################################
VERILOG_ROOT = ../../../..
include $(VERILOG_ROOT)/mk/iverilog.mk

MT = ..

SRCS = $(MT)/qmtech_mem_test_top.v \
       $(VERILOG_ROOT)/fpga/basys3/mem-test/msg_printer.v \
       $(VERILOG_ROOT)/fpga/basys3/mem-test/uart_tx.v \
       $(VERILOG_ROOT)/CPU-BOARD-3202/circuit/MEM_RAM_49.v \
       $(VERILOG_ROOT)/Shared/support/SIP1M9.v

qmtech_mem_test_tb.vvp: qmtech_mem_test_tb.v $(SRCS)
	$(IVERILOG) -g2012 $(ND_INC) -o $@ qmtech_mem_test_tb.v $(SRCS)

test-qmtech-memtest: qmtech_mem_test_tb.vvp
	$(VVP) qmtech_mem_test_tb.vvp | tee qmtech_memtest_out.log
	@grep -q "TB_RESULT: PASS" qmtech_memtest_out.log

clean:
	rm -f *.vvp *.log *.vcd

.PHONY: test-qmtech-memtest clean
