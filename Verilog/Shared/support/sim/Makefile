# Shared/support unit tests (iverilog)
# Run:  make test-uart      (SC2661 TX-flag timing)
#       make test-ram       (SIP1M9 ramSize=3 synchronous BRAM: write/read + no-alias)
#       make test-am29833a  (AM29833A USE_SYSCLK=0 vs =2 equivalence)
#       make test-inrprom   (BACKWIRING_PROM: PIL-addressed installation number)
#       make clean

IVERILOG = iverilog
VVP      = vvp
INCDIRS  = -I.. -I../../ndlib -I../../logisim

.PHONY: test-uart test-ram test-am29833a test-am29c821 test-inrprom clean

# Back-wiring PROM (installation number), addressed by PIL 3:0.
# -I.. also gives iverilog the include path for nd120_backwiring_defaults.vh.
test-inrprom: BACKWIRING_PROM_tb
	$(VVP) BACKWIRING_PROM_tb | tee inrprom_result.tmp
	@grep -q "TB_RESULT: PASS" inrprom_result.tmp && rm -f inrprom_result.tmp BACKWIRING_PROM_tb.vcd

BACKWIRING_PROM_tb: BACKWIRING_PROM_tb.v ../BACKWIRING_PROM.v ../nd120_backwiring_defaults.vh
	$(IVERILOG) -g2012 -o $@ $(INCDIRS) BACKWIRING_PROM_tb.v ../BACKWIRING_PROM.v

test-am29833a: AM29833A_equiv_tb
	$(VVP) AM29833A_equiv_tb | tee am29833a_result.tmp
	@grep -q "TB_RESULT: PASS" am29833a_result.tmp && rm -f am29833a_result.tmp

test-am29c821: AM29C821_equiv_tb
	$(VVP) AM29C821_equiv_tb | tee am29c821_result.tmp
	@grep -q "TB_RESULT: PASS" am29c821_result.tmp && rm -f am29c821_result.tmp AM29C821_equiv_tb.vcd

AM29C821_equiv_tb: AM29C821_equiv_tb.v ../AM29C821.v
	$(IVERILOG) -g2012 -o $@ $(INCDIRS) AM29C821_equiv_tb.v ../AM29C821.v

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

# P1c-2/P1d/P3: TTL_74646/74648 strobe-clock edge-capture equivalence
test-7464x: TTL_7464x_equiv_tb
	$(VVP) TTL_7464x_equiv_tb | tee t7464x_result.tmp
	@grep -q "TB_RESULT: PASS" t7464x_result.tmp && rm -f t7464x_result.tmp TTL_7464x_equiv_tb.vcd

TTL_7464x_equiv_tb: TTL_7464x_equiv_tb.v ../TTL_74646.v ../TTL_74648.v
	$(IVERILOG) -g2012 -o $@ $(INCDIRS) TTL_7464x_equiv_tb.v ../TTL_74646.v ../TTL_74648.v

# P2 wrappers: SCAN_FF_EN / D_FLIPFLOP_EN / R81_EN mode equivalence
NDLIB = ../../ndlib
LOGISIM2 = ../../logisim
test-ffen: FF_EN_equiv_tb
	$(VVP) FF_EN_equiv_tb | tee ffen_result.tmp
	@grep -q "TB_RESULT: PASS" ffen_result.tmp && rm -f ffen_result.tmp FF_EN_equiv_tb.vcd

FF_EN_equiv_tb: FF_EN_equiv_tb.v $(NDLIB)/SCAN_FF_EN.v $(NDLIB)/D_FLIPFLOP_EN.v $(NDLIB)/R81_EN.v $(NDLIB)/R41P_EN.v $(NDLIB)/SCAN_FF.v $(NDLIB)/R81.v $(NDLIB)/R41P.v $(LOGISIM2)/D_FLIPFLOP.v
	$(IVERILOG) -g2012 -o $@ $^
