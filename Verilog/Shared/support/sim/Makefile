# Shared/support unit tests (iverilog)
# Run:  make test-uart   (SC2661 TX-flag timing)
#       make test-ram    (SIP1M9 ramSize=3 synchronous BRAM: write/read + no-alias)
#       make clean

IVERILOG = iverilog
VVP      = vvp
INCDIRS  = -I.. -I../../ndlib -I../../logisim

.PHONY: test-uart test-ram clean

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
