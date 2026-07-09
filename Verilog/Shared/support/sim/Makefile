# Shared/support unit tests (iverilog)
# Run:  make test-uart      (SC2661 TX-flag timing)
#       make test-ram       (SIP1M9 ramSize=3 synchronous BRAM: write/read + no-alias)
#       make test-am29833a  (AM29833A USE_SYSCLK=0 vs =2 equivalence)
#       make clean

IVERILOG = iverilog
VVP      = vvp
INCDIRS  = -I.. -I../../ndlib -I../../logisim

.PHONY: test-uart test-ram test-am29833a clean

test-am29833a: AM29833A_equiv_tb
	$(VVP) AM29833A_equiv_tb | tee am29833a_result.tmp
	@grep -q "TB_RESULT: PASS" am29833a_result.tmp && rm -f am29833a_result.tmp

AM29833A_equiv_tb: AM29833A_equiv_tb.v ../AM29833A.v
	$(IVERILOG) -g2012 -o $@ $(INCDIRS) AM29833A_equiv_tb.v ../AM29833A.v

test-uart: SC2661_UART_tb
	$(VVP) SC2661_UART_tb

SC2661_UART_tb: SC2661_UART_tb.v ../SC2661_UART.v
	$(IVERILOG) -g2012 -o $@ $(INCDIRS) SC2661_UART_tb.v ../SC2661_UART.v

test-ram: SIP1M9_bram_tb
	$(VVP) SIP1M9_bram_tb

SIP1M9_bram_tb: SIP1M9_bram_tb.v ../SIP1M9.v
	$(IVERILOG) -g2012 -o $@ $(INCDIRS) SIP1M9_bram_tb.v ../SIP1M9.v

clean:
	rm -f SC2661_UART_tb SIP1M9_bram_tb *.vcd
