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
#   make test-tape   heavy system gate for the Verilog tape-400 device
#                    (ND-BUS-DEVICES): boots INSTRUCTION-B twice via
#                    '400$' - once with the C papertape model, once with
#                    the Verilog device (VERILOG_TAPE=1) - and requires
#                    identical console tails and identical loaded RAM.
#                    ~25 min (two full runSim compiles + runs).
#
# Board builds stay in fpga/<board>/ (see fpga/README.md); the CPU sims
# stay in sim/ and runSim/. This Makefile only aggregates TESTS.

.PHONY: test test-full test-tape

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

# Filter that strips the C device models' debug prints, keeping console text
TAPE_FILTER = grep -vaE '^(PaperTape|IDENT LVL|No device found|WTF|\[0\] FloppyPIO|Callback LVL|Clearing|Generating|Setting|\[binload\] (settling|streaming|injector|byte)|VerilogTape|Floppy PIO)'

test-tape:
	@echo "==== system gate: 400\$$ tape boot, C model vs Verilog device ===="
	$(MAKE) -C runSim clean >/dev/null
	$(MAKE) -C runSim compile USE_LATCHES=0 EXTRA_CFLAGS="-DSCRIPT_INPUT -DSCRIPT_CMD_TAPE400" >/dev/null
	cd runSim && ND120_BINLOAD_CHECK=001000:8 ./obj_dir/VND120_TOP </dev/null > /tmp/nd120_tape_c.log 2>&1
	$(MAKE) -C runSim clean >/dev/null
	$(MAKE) -C runSim compile USE_LATCHES=0 VERILOG_TAPE=1 EXTRA_CFLAGS="-DSCRIPT_INPUT -DSCRIPT_CMD_TAPE400" >/dev/null
	cd runSim && ND120_BINLOAD_CHECK=001000:8 ./obj_dir/VND120_TOP </dev/null > /tmp/nd120_tape_v.log 2>&1
	$(TAPE_FILTER) /tmp/nd120_tape_c.log | tail -30 > /tmp/nd120_tape_c_tail.txt
	$(TAPE_FILTER) /tmp/nd120_tape_v.log | tail -30 > /tmp/nd120_tape_v_tail.txt
	cmp /tmp/nd120_tape_c_tail.txt /tmp/nd120_tape_v_tail.txt
	grep -a "RAM check" /tmp/nd120_tape_c.log > /tmp/nd120_tape_c_ram.txt
	grep -a "RAM check" /tmp/nd120_tape_v.log > /tmp/nd120_tape_v_ram.txt
	cmp /tmp/nd120_tape_c_ram.txt /tmp/nd120_tape_v_ram.txt
	grep -qa "INSTRUCTION-B" /tmp/nd120_tape_v_tail.txt
	@echo ""
	@echo "===================================================================="
	@echo "  TAPE GATE PASSED (Verilog tape-400 = C model, INSTRUCTION-B boots)"
	@echo "===================================================================="
