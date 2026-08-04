# Unit testbenches for the ND Winchester disc controller, 5 1/4 inch ST506
# (card 3041) and 8 inch (card 3038).
# (repo convention: sim/ next to the modules it tests)
#
# test-wd-iox - the IOX register / status / IDENT conformance matrix asserted
#   directly at the device IOX slave port (no BUS_SLAVE, no DMA backend):
#   the two-access memory address with its deliberately opposite read order,
#   ALL FOUR flip-flop reset conditions, the SINGLE-access word count that
#   distinguishes this card from the 15 MHz SMD, the block-address split,
#   the status constants, M4's relative step seek, M7, the address-mismatch
#   bound, and the section 4.1 interrupt / IDENT probe that TPE CONFIGURATION
#   uses to find the card.
#
# The same behaviour is cross-checked between the two C implementations
# (nd100x tests/wd_trace.c and the portable core's test/wd_trace.c walking a
# shared conformance sequence), so a divergence between RTL and C shows up
# here rather than on silicon.

IVERILOG = iverilog
VVP      = vvp

IOX_SRCS = ../circuit/ND_WINCHESTER.v \
           nd_winchester_iox_tb.v

# test-wd-adapter: the Winchester BINDING of nd_storage_smd_adapter. There is
#   no nd_storage_wd_adapter.v: that adapter has nothing SMD-specific in it -
#   its CHS->LBA is driven by GEO_HEADS/GEO_SPT and its one hard assumption
#   (1024-byte sectors) holds for this card too. This bench proves the reuse
#   with Winchester geometry, and closes a real hole: the adapter's own bench
#   instantiates it twice and both times at the DEFAULT geometry, so the
#   parameterisation was never exercised.
AD_SRCS  = ../../../SD-FAT/circuit/nd_storage_smd_adapter.v \
           nd_winchester_adapter_tb.v

all: test

test: test-wd-iox test-wd-adapter

nd_winchester_iox_tb.vvp: $(IOX_SRCS)
	$(IVERILOG) -g2005 -o $@ $(IOX_SRCS)

test-wd-iox: nd_winchester_iox_tb.vvp
	$(VVP) nd_winchester_iox_tb.vvp | tee wd_iox_out.log
	@grep -q "TB_RESULT: PASS" wd_iox_out.log

nd_winchester_adapter_tb.vvp: $(AD_SRCS)
	$(IVERILOG) -g2005 -o $@ $(AD_SRCS)

test-wd-adapter: nd_winchester_adapter_tb.vvp
	$(VVP) nd_winchester_adapter_tb.vvp | tee wd_adapter_out.log
	@grep -q "TB_RESULT: PASS" wd_adapter_out.log

clean:
	rm -f *.vvp *.log *.vcd *.fst

.PHONY: all test test-wd-iox test-wd-adapter clean
