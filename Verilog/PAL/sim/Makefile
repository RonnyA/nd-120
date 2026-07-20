# PAL testbenches — Icarus Verilog
IVERILOG = iverilog
VERILOG_ROOT = ../..

PAL_44304E_tb: PAL_44304E_tb.v $(VERILOG_ROOT)/PAL/PAL_44304E.v
	$(IVERILOG) -g2012 -I$(VERILOG_ROOT)/Shared/logisim -I$(VERILOG_ROOT)/Shared/ndlib -I$(VERILOG_ROOT)/Shared/support -I$(VERILOG_ROOT)/PAL -o $@ $^

PAL_45008B_tb: PAL_45008B_tb.v $(VERILOG_ROOT)/PAL/PAL_45008B.v
	$(IVERILOG) -g2012 -I$(VERILOG_ROOT)/Shared/logisim -I$(VERILOG_ROOT)/Shared/ndlib -I$(VERILOG_ROOT)/Shared/support -I$(VERILOG_ROOT)/PAL -o $@ $^

PAL_44601B_tb: PAL_44601B_tb.v $(VERILOG_ROOT)/PAL/PAL_44601B.v
	$(IVERILOG) -g2012 -I$(VERILOG_ROOT)/Shared/logisim -I$(VERILOG_ROOT)/Shared/ndlib -I$(VERILOG_ROOT)/Shared/support -I$(VERILOG_ROOT)/PAL -o $@ $^

# PAL_44801A - the ND-100 bus arbiter (BARB). The CPU/DMA mutual-exclusion
# interlock that makes the bus "not interruptible" once allocated.
PAL_44801A_tb: PAL_44801A_tb.v $(VERILOG_ROOT)/PAL/PAL_44801A.v
	$(IVERILOG) -g2012 -I$(VERILOG_ROOT)/Shared/logisim -I$(VERILOG_ROOT)/Shared/ndlib -I$(VERILOG_ROOT)/Shared/support -I$(VERILOG_ROOT)/PAL -o $@ $^

# PAL_44401B - bus cycle timing (BTIM). Generates EIOD (-> BIOXE), gated by
# CACT: the IOX strobe cannot fire unless the CPU is active on the bus.
PAL_44401B_tb: PAL_44401B_tb.v $(VERILOG_ROOT)/PAL/PAL_44401B.v
	$(IVERILOG) -g2012 -I$(VERILOG_ROOT)/Shared/logisim -I$(VERILOG_ROOT)/Shared/ndlib -I$(VERILOG_ROOT)/Shared/support -I$(VERILOG_ROOT)/PAL -o $@ $^

test-pal44304e: PAL_44304E_tb
	./PAL_44304E_tb

test-pal45008b: PAL_45008B_tb
	./PAL_45008B_tb

test-44601: PAL_44601B_tb
	./PAL_44601B_tb

test-pal44801a: PAL_44801A_tb
	./PAL_44801A_tb

test-pal44401b: PAL_44401B_tb
	./PAL_44401B_tb

test-all: test-pal44304e test-pal45008b test-44601 test-pal44801a test-pal44401b

clean:
	rm -f PAL_44304E_tb PAL_45008B_tb PAL_44601B_tb PAL_44801A_tb PAL_44401B_tb *.vcd

.PHONY: test-pal44304e test-pal45008b test-44601 test-pal44801a test-pal44401b test-all clean
