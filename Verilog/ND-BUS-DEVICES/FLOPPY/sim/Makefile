# Unit testbench for the ND-100 floppy PIO controller
# (repo convention: sim/ next to the modules it tests)
#
# test / test-floppy-pio - full stack through ND_BUS_SLAVE with an
#   image-backed disk model: select/format, sector read/write, seek,
#   auto-increment, errors, level-11 interrupt, IDENT 021

IVERILOG = iverilog
VVP      = vvp

SRCS = ../../BUS-IF/circuit/ND_BUS_SLAVE.v \
       ../circuit/ND_FLOPPY_PIO.v \
       nd_floppy_pio_tb.v

all: test

test: test-floppy-pio test-floppy-ioxmap

nd_floppy_pio_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -o $@ $(SRCS)

test-floppy-pio: nd_floppy_pio_tb.vvp
	$(VVP) nd_floppy_pio_tb.vvp | tee floppy_pio_out.log
	@grep -q "TB_RESULT: PASS" floppy_pio_out.log

# test-floppy-ioxmap - direct device-bus bench that attacks the WIRING
#   rather than the scenarios: exhaustive 65536-address decode sweep,
#   read/write register map, status bit positions in RSR1/RSR2,
#   exhaustive 256-value control-word command decode, drive/format/
#   sector/track field walks, completion delay, level-11 interrupt and
#   the IDENT answer + grant daisy-chain. ND_FLOPPY_PIO.v has no `ifdef,
#   so the second build only proves FPGA_FF_MODE changes nothing.
IOXMAP_SRCS = ../circuit/ND_FLOPPY_PIO.v ND_FLOPPY_PIO_IOXMAP_tb.v

test-floppy-ioxmap:
	$(IVERILOG) -g2012 -o nd_floppy_pio_ioxmap_tb.vvp $(IOXMAP_SRCS)
	$(VVP) nd_floppy_pio_ioxmap_tb.vvp | tee floppy_ioxmap_out.log
	@grep -q "TB_RESULT: PASS" floppy_ioxmap_out.log
	$(IVERILOG) -g2012 -DFPGA_FF_MODE -o nd_floppy_pio_ioxmap_ff_tb.vvp $(IOXMAP_SRCS)
	$(VVP) nd_floppy_pio_ioxmap_ff_tb.vvp | tee floppy_ioxmap_ff_out.log
	@grep -q "TB_RESULT: PASS" floppy_ioxmap_ff_out.log

clean:
	rm -f *.vvp *.log *.vcd

.PHONY: all test test-floppy-pio test-floppy-ioxmap clean
