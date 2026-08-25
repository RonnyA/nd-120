# Unit testbench for the ND-100 paper tape reader, device 400 (octal)
# (repo convention: sim/ next to the modules it tests)
#
# test / test-tape400 - full stack through ND_BUS_SLAVE with a tape-array
#   byte source: reset state, register offsets, iox_sel/iox_hit gating,
#   RFT preset/activate stream, end-of-tape, device clear + rewind,
#   level-12 interrupt, IDENT 02, seeded random soak

IVERILOG = iverilog
VVP      = vvp

SRCS = ../../BUS-IF/circuit/ND_BUS_SLAVE.v \
       ../circuit/ND_TAPE_400.v \
       nd_tape_400_tb.v

all: test

test: test-tape400

nd_tape_400_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -o $@ $(SRCS)

test-tape400: nd_tape_400_tb.vvp
	$(VVP) nd_tape_400_tb.vvp | tee tape400_out.log
	@grep -q "TB_RESULT: PASS" tape400_out.log

clean:
	rm -f *.vvp *.log *.vcd

.PHONY: all test test-tape400 clean
