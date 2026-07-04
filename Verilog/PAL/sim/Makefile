# PAL testbenches — Icarus Verilog
IVERILOG = iverilog
VERILOG_ROOT = ../..

PAL_44304E_tb: PAL_44304E_tb.v $(VERILOG_ROOT)/PAL/PAL_44304E.v
	$(IVERILOG) -g2012 -I$(VERILOG_ROOT)/Shared/logisim -I$(VERILOG_ROOT)/Shared/ndlib -I$(VERILOG_ROOT)/Shared/support -I$(VERILOG_ROOT)/PAL -o $@ $^

PAL_45008B_tb: PAL_45008B_tb.v $(VERILOG_ROOT)/PAL/PAL_45008B.v
	$(IVERILOG) -g2012 -I$(VERILOG_ROOT)/Shared/logisim -I$(VERILOG_ROOT)/Shared/ndlib -I$(VERILOG_ROOT)/Shared/support -I$(VERILOG_ROOT)/PAL -o $@ $^

test-pal44304e: PAL_44304E_tb
	./PAL_44304E_tb

test-pal45008b: PAL_45008B_tb
	./PAL_45008B_tb

test-all: test-pal44304e test-pal45008b

clean:
	rm -f PAL_44304E_tb PAL_45008B_tb *.vcd

.PHONY: test-pal44304e test-pal45008b test-all clean
