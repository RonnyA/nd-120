# Unit testbench for the ND-100 bus slave adapter
# (repo convention: sim/ next to the modules it tests)
#
# test / test-bus-slave - scripted CPU-side bus master driving IOX
#   read/write and IDENT against ND_BUS_SLAVE + two ND_TAPE_400 cores
#   (daisy-chain + clear-on-IDENT proven here too)

IVERILOG = iverilog
VVP      = vvp

SRCS = ../circuit/ND_BUS_SLAVE.v \
       ../../TAPE-400/circuit/ND_TAPE_400.v \
       nd_bus_slave_tb.v

all: test

test: test-bus-slave

nd_bus_slave_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -o $@ $(SRCS)

test-bus-slave: nd_bus_slave_tb.vvp
	$(VVP) nd_bus_slave_tb.vvp | tee bus_slave_out.log
	@grep -q "TB_RESULT: PASS" bus_slave_out.log

clean:
	rm -f *.vvp *.log *.vcd

.PHONY: all test test-bus-slave clean
