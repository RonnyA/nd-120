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

test: test-floppy-pio

nd_floppy_pio_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -o $@ $(SRCS)

test-floppy-pio: nd_floppy_pio_tb.vvp
	$(VVP) nd_floppy_pio_tb.vvp | tee floppy_pio_out.log
	@grep -q "TB_RESULT: PASS" floppy_pio_out.log

clean:
	rm -f *.vvp *.log *.vcd

.PHONY: all test test-floppy-pio clean
