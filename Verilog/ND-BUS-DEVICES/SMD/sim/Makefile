# Unit testbench for the ND-100 SMD disk controller
# (repo convention: sim/ next to the modules it tests)
#
# test / test-smd - the full DMA device stack: CWR-multiplexed register
#   file, M0/M1 transfers through ND_DMA_MASTER against the BCU+memory
#   model, seek/on-cylinder, interrupt + IDENT 017

IVERILOG = iverilog
VVP      = vvp

SRCS = ../../BUS-IF/circuit/ND_BUS_SLAVE.v \
       ../../DMA/circuit/ND_DMA_MASTER.v \
       ../circuit/ND_SMD.v \
       nd_smd_tb.v

# test-smd-iox: the IOX register / status / control-word conformance matrix
#   asserted directly at the device IOX slave port (no BUS_SLAVE, no GO/DMA):
#   boot-mode exit, CWR multiplexing, 24-bit HI/LO flip-flop load+readback,
#   15 MHz seek-id bit, level-sensitive interrupt + IDENT 017, device clear.
IOX_SRCS = ../circuit/ND_SMD.v \
           nd_smd_iox_tb.v

all: test

test: test-smd test-smd-iox

nd_smd_tb.vvp: $(SRCS)
	$(IVERILOG) -g2005 -o $@ $(SRCS)

test-smd: nd_smd_tb.vvp
	$(VVP) nd_smd_tb.vvp | tee smd_out.log
	@grep -q "TB_RESULT: PASS" smd_out.log

nd_smd_iox_tb.vvp: $(IOX_SRCS)
	$(IVERILOG) -g2005 -o $@ $(IOX_SRCS)

test-smd-iox: nd_smd_iox_tb.vvp
	$(VVP) nd_smd_iox_tb.vvp | tee smd_iox_out.log
	@grep -q "TB_RESULT: PASS" smd_iox_out.log

clean:
	rm -f *.vvp *.log *.vcd

.PHONY: all test test-smd test-smd-iox clean
