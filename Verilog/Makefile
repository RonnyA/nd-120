# ND120 - top-level test entry points
#
#   make test        run EVERY self-checking unit testbench in the repo,
#                    fail-fast: the first failure aborts loudly (exit 1).
#                    Registry: tests/run_all_tests.sh - add new tbs there.
#
#   make test-full   `make test` plus the heavy system-level gates:
#                      - sim/ latch-vs-FF trace compare against the goldens
#                      - runSim FF-mode console against the golden log
#                      - fpga/tang-nano-20k vtest (full Tang boot + deposit
#                        + verified readback, ~100 s)
#
# Board builds stay in fpga/<board>/ (see fpga/README.md); the CPU sims
# stay in sim/ and runSim/. This Makefile only aggregates TESTS.

.PHONY: test test-full

test:
	@bash tests/run_all_tests.sh

test-full: test
	@echo "==== system gate: sim/ latch-vs-FF golden compare ===="
	$(MAKE) -C sim compare
	cmp sim/trace_ff.csv    sim/golden/trace_ff_golden.csv
	cmp sim/trace_latch.csv sim/golden/trace_latch_golden.csv
	@echo "==== system gate: runSim FF console vs golden ===="
	$(MAKE) -C runSim compile USE_LATCHES=0 EXTRA_CFLAGS="-DSCRIPT_INPUT -DSCRIPT_CMD_GOLDEN" >/dev/null
	cd runSim && ./obj_dir/VND120_TOP </dev/null > /tmp/nd120_console_check.log 2>&1; \
	  cmp /tmp/nd120_console_check.log golden/console_ff_golden.log
	@echo "==== system gate: Tang vtest (boot + deposit + readback) ===="
	$(MAKE) -C fpga/tang-nano-20k/sim vtest
	@echo ""
	@echo "===================================================================="
	@echo "  FULL SUITE PASSED (units + goldens + vtest)"
	@echo "===================================================================="
