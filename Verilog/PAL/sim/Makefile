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

# _EN clock-enable equivalence testbenches: original PAL (posedge CLK on a
# registered level) vs PAL_xxx_EN USE_ENABLE=1 (posedge sysclk + enable),
# all outputs compared every cycle. FF_EN_equiv_tb pattern.
PAL_44402D_EN_equiv_tb: PAL_44402D_EN_equiv_tb.v $(VERILOG_ROOT)/PAL/PAL_44402D_EN.v $(VERILOG_ROOT)/PAL/PAL_44402D.v
	$(IVERILOG) -g2012 -I$(VERILOG_ROOT)/Shared/logisim -I$(VERILOG_ROOT)/Shared/ndlib -I$(VERILOG_ROOT)/Shared/support -I$(VERILOG_ROOT)/PAL -o $@ $^

PAL_44403C_EN_equiv_tb: PAL_44403C_EN_equiv_tb.v $(VERILOG_ROOT)/PAL/PAL_44403C_EN.v $(VERILOG_ROOT)/PAL/PAL_44403C.v
	$(IVERILOG) -g2012 -I$(VERILOG_ROOT)/Shared/logisim -I$(VERILOG_ROOT)/Shared/ndlib -I$(VERILOG_ROOT)/Shared/support -I$(VERILOG_ROOT)/PAL -o $@ $^

PAL_44404C_EN_equiv_tb: PAL_44404C_EN_equiv_tb.v $(VERILOG_ROOT)/PAL/PAL_44404C_EN.v $(VERILOG_ROOT)/PAL/PAL_44404C.v
	$(IVERILOG) -g2012 -I$(VERILOG_ROOT)/Shared/logisim -I$(VERILOG_ROOT)/Shared/ndlib -I$(VERILOG_ROOT)/Shared/support -I$(VERILOG_ROOT)/PAL -o $@ $^

PAL_44407A_EN_equiv_tb: PAL_44407A_EN_equiv_tb.v $(VERILOG_ROOT)/PAL/PAL_44407A_EN.v $(VERILOG_ROOT)/PAL/PAL_44407A.v
	$(IVERILOG) -g2012 -I$(VERILOG_ROOT)/Shared/logisim -I$(VERILOG_ROOT)/Shared/ndlib -I$(VERILOG_ROOT)/Shared/support -I$(VERILOG_ROOT)/PAL -o $@ $^

PAL_44408B_EN_equiv_tb: PAL_44408B_EN_equiv_tb.v $(VERILOG_ROOT)/PAL/PAL_44408B_EN.v $(VERILOG_ROOT)/PAL/PAL_44408B.v
	$(IVERILOG) -g2012 -I$(VERILOG_ROOT)/Shared/logisim -I$(VERILOG_ROOT)/Shared/ndlib -I$(VERILOG_ROOT)/Shared/support -I$(VERILOG_ROOT)/PAL -o $@ $^

PAL_44511A_EN_equiv_tb: PAL_44511A_EN_equiv_tb.v $(VERILOG_ROOT)/PAL/PAL_44511A_EN.v $(VERILOG_ROOT)/PAL/PAL_44511A.v
	$(IVERILOG) -g2012 -I$(VERILOG_ROOT)/Shared/logisim -I$(VERILOG_ROOT)/Shared/ndlib -I$(VERILOG_ROOT)/Shared/support -I$(VERILOG_ROOT)/PAL -o $@ $^

# Registered address-decode PALs (sheet 45) vs an independent PALASM-derived
# golden model: base PAL and its sysclk _D mirror side by side.
PAL_44445B_D_tb: PAL_44445B_D_tb.v $(VERILOG_ROOT)/PAL/PAL_44445B.v $(VERILOG_ROOT)/CPU-BOARD-3202/circuit/PAL_44445B_D.v
	$(IVERILOG) -g2012 -o $@ $^

PAL_44446B_D_tb: PAL_44446B_D_tb.v $(VERILOG_ROOT)/PAL/PAL_44446B.v $(VERILOG_ROOT)/CPU-BOARD-3202/circuit/PAL_44446B_D.v
	$(IVERILOG) -g2012 -o $@ $^

test-44445b-d: PAL_44445B_D_tb
	./PAL_44445B_D_tb

test-44446b-d: PAL_44446B_D_tb
	./PAL_44446B_D_tb

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

test-44402d-en: PAL_44402D_EN_equiv_tb
	./PAL_44402D_EN_equiv_tb

test-44403c-en: PAL_44403C_EN_equiv_tb
	./PAL_44403C_EN_equiv_tb

test-44404c-en: PAL_44404C_EN_equiv_tb
	./PAL_44404C_EN_equiv_tb

test-44407a-en: PAL_44407A_EN_equiv_tb
	./PAL_44407A_EN_equiv_tb

test-44408b-en: PAL_44408B_EN_equiv_tb
	./PAL_44408B_EN_equiv_tb

test-44511a-en: PAL_44511A_EN_equiv_tb
	./PAL_44511A_EN_equiv_tb

# Holds every PAL_*.v to its PALASM listing at PAL/<id>/<id>.pds: no output
# may be driven that the listing does not define, and none may be dropped.
# Also reports which PALs have no listing at all. See PAL/PROVENANCE.md.
test-pal-provenance:
	python3 check_provenance.py

test-all: test-pal44304e test-pal45008b test-44601 test-pal44801a test-pal44401b test-44402d-en test-44403c-en test-44404c-en test-44407a-en test-44408b-en test-44511a-en test-pal-provenance

clean:
	rm -f PAL_44304E_tb PAL_45008B_tb PAL_44601B_tb PAL_44801A_tb PAL_44401B_tb PAL_44402D_EN_equiv_tb PAL_44403C_EN_equiv_tb PAL_44404C_EN_equiv_tb PAL_44407A_EN_equiv_tb PAL_44408B_EN_equiv_tb PAL_44511A_EN_equiv_tb *.vcd

.PHONY: test-pal44304e test-pal45008b test-44601 test-pal44801a test-pal44401b test-44402d-en test-44403c-en test-44404c-en test-44407a-en test-44408b-en test-44511a-en test-all clean
