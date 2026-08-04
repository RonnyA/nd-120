# Shared/support unit tests (iverilog)
# Run:  make test-uart      (SC2661 TX-flag timing)
#       make test-ram       (SIP1M9 ramSize=3 synchronous BRAM: write/read + no-alias)
#       make test-am29833a  (AM29833A USE_SYSCLK=0 vs =2 equivalence)
#       make test-inrprom   (BACKWIRING_PROM: PIL-addressed installation number)
#       make clean

IVERILOG = iverilog
VVP      = vvp
INCDIRS  = -I.. -I../../ndlib -I../../logisim

.PHONY: test-uart test-ram test-am29833a test-am29833a-parity test-am29c821 test-inrprom clean

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

# Parity CONVENTION gate: the value every memory backend regenerates (~^data)
# must be the one this chip calls correct, and the inverted bit must always
# fault. Protects the "parity is computed, never stored" policy.
test-am29833a-parity: AM29833A_parity_regen_tb
	$(VVP) AM29833A_parity_regen_tb | tee am29833a_par_result.tmp
	@grep -q "TB_RESULT: PASS" am29833a_par_result.tmp && rm -f am29833a_par_result.tmp

AM29833A_parity_regen_tb: AM29833A_parity_regen_tb.v ../AM29833A.v
	$(IVERILOG) -g2012 -o $@ $(INCDIRS) AM29833A_parity_regen_tb.v ../AM29833A.v

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

# P2 wrappers: remaining ndlib _EN mode-equivalence tbs
# (base modules and gate primitives resolved via -y from ndlib/logisim;
#  F924's base module lives in the DGA tree, listed explicitly)
DGACIRC = ../../../DECODE-GateArray/DGA/circuit

test-scanrst-en: SCAN_WITH_RESET_N_EN_equiv_tb
	$(VVP) SCAN_WITH_RESET_N_EN_equiv_tb | tee scanrst_result.tmp
	@grep -q "TB_RESULT: PASS" scanrst_result.tmp && rm -f scanrst_result.tmp SCAN_WITH_RESET_N_EN_equiv_tb.vcd

SCAN_WITH_RESET_N_EN_equiv_tb: SCAN_WITH_RESET_N_EN_equiv_tb.v $(NDLIB)/SCAN_WITH_RESET_N_EN.v $(NDLIB)/SCAN_WITH_RESET_N.v $(LOGISIM2)/D_FLIPFLOP.v
	$(IVERILOG) -g2012 -o $@ SCAN_WITH_RESET_N_EN_equiv_tb.v -y $(NDLIB) -y $(LOGISIM2)

test-scanset-en: SCAN_WITH_SET_N_EN_equiv_tb
	$(VVP) SCAN_WITH_SET_N_EN_equiv_tb | tee scanset_result.tmp
	@grep -q "TB_RESULT: PASS" scanset_result.tmp && rm -f scanset_result.tmp SCAN_WITH_SET_N_EN_equiv_tb.vcd

SCAN_WITH_SET_N_EN_equiv_tb: SCAN_WITH_SET_N_EN_equiv_tb.v $(NDLIB)/SCAN_WITH_SET_N_EN.v $(NDLIB)/SCAN_WITH_SET_N.v $(LOGISIM2)/D_FLIPFLOP.v
	$(IVERILOG) -g2012 -o $@ SCAN_WITH_SET_N_EN_equiv_tb.v -y $(NDLIB) -y $(LOGISIM2)

test-sr44-en: SR44_EN_equiv_tb
	$(VVP) SR44_EN_equiv_tb | tee sr44_result.tmp
	@grep -q "TB_RESULT: PASS" sr44_result.tmp && rm -f sr44_result.tmp SR44_EN_equiv_tb.vcd

SR44_EN_equiv_tb: SR44_EN_equiv_tb.v $(NDLIB)/SR44_EN.v $(NDLIB)/SR44.v $(LOGISIM2)/D_FLIPFLOP.v $(LOGISIM2)/Multiplexer_2.v
	$(IVERILOG) -g2012 -o $@ SR44_EN_equiv_tb.v -y $(NDLIB) -y $(LOGISIM2)

test-m169c-en: M169C_EN_equiv_tb
	$(VVP) M169C_EN_equiv_tb | tee m169c_result.tmp
	@grep -q "TB_RESULT: PASS" m169c_result.tmp && rm -f m169c_result.tmp M169C_EN_equiv_tb.vcd

M169C_EN_equiv_tb: M169C_EN_equiv_tb.v $(NDLIB)/M169C_EN.v $(NDLIB)/M169C.v $(NDLIB)/D_FLIPFLOP_EN.v $(LOGISIM2)/D_FLIPFLOP.v
	$(IVERILOG) -g2012 -o $@ M169C_EN_equiv_tb.v -y $(NDLIB) -y $(LOGISIM2)

test-f924-en: F924_EN_equiv_tb
	$(VVP) F924_EN_equiv_tb | tee f924_result.tmp
	@grep -q "TB_RESULT: PASS" f924_result.tmp && rm -f f924_result.tmp F924_EN_equiv_tb.vcd

F924_EN_equiv_tb: F924_EN_equiv_tb.v $(NDLIB)/F924_EN.v $(DGACIRC)/F924.v $(NDLIB)/D_FLIPFLOP_EN.v $(LOGISIM2)/D_FLIPFLOP.v
	$(IVERILOG) -g2012 -o $@ F924_EN_equiv_tb.v $(DGACIRC)/F924.v -y $(NDLIB) -y $(LOGISIM2)

# FIFO_8BIT: write/read order, mid-stream reset, full/empty flags,
# write-when-full drop, read-when-empty zero (moved from FIFO_8BIT_TB/).
test-fifo: FIFO_tb
	$(VVP) FIFO_tb | tee fifo_result.tmp
	@grep -q "TB_RESULT: PASS" fifo_result.tmp && rm -f fifo_result.tmp

FIFO_tb: FIFO_tb.v ../FIFO_8BIT.v
	$(IVERILOG) -g2012 -o $@ FIFO_tb.v ../FIFO_8BIT.v

# IDT6168A_20 4Kx4 sync-BRAM SRAM model: write/readback, 1-clock read
# latency, CE_n/WE_n output masking, write-first forwarding (moved from
# IDT6168A_20_TB/).
test-idt6168a: IDT6168A_20_tb
	$(VVP) IDT6168A_20_tb | tee idt6168a_result.tmp
	@grep -q "TB_RESULT: PASS" idt6168a_result.tmp && rm -f idt6168a_result.tmp IDT6168A_20_tb.vcd

IDT6168A_20_tb: IDT6168A_20_tb.v ../IDT6168A_20.v
	$(IVERILOG) -g2012 -o $@ IDT6168A_20_tb.v ../IDT6168A_20.v

.PHONY: test-fifo test-idt6168a
