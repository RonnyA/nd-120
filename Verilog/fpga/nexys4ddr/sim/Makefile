# Nexys 4 DDR board-support unit tests (iverilog, self-checking).
IVERILOG = iverilog
VVP = vvp

# ERRFA evidence probe, W line: the Winchester-IOX ring
# (nd120_errfa_wdiox_ring.v). Verifies capture (48 entries, oldest-first,
# decoy addresses ignored), the console-text arming, the printed line
# format, and single-shot behavior.
test-wdiox-ring: wdiox_tb
	$(VVP) wdiox_tb | tee wdiox_result.tmp
	@grep -q "TB_RESULT: PASS" wdiox_result.tmp && rm -f wdiox_result.tmp

wdiox_tb: nd120_errfa_wdiox_ring_tb.v ../nd120_errfa_wdiox_ring.v
	$(IVERILOG) -g2012 -o $@ ../nd120_errfa_wdiox_ring.v nd120_errfa_wdiox_ring_tb.v

clean:
	rm -f wdiox_tb *.tmp

.PHONY: test-wdiox-ring clean
