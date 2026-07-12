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

#   make test-floppy-boot  heavy system gate for the floppy mass boot:
#                    '1560&' at the OPCOM prompt makes the DMA floppy
#                    controller AUTOLOAD the boot sector to ND memory 0
#                    (verified word-for-word against a generated image
#                    with a WAIT instruction at word 0). ~12 min.
#
#   make test-smd-boot  heavy system gate for the SMD mass boot:
#                    '1540&' triggers the controller's boot handshake
#                    (control to +3, ready polled on +2), block 0
#                    (1024 words) DMA-lands at ND memory 0. ~12 min.
#
#   make test-dma-rtl  heavy system gate for DMA bus mastering: the
#                    Verilog ND_DMA_MASTER inside ND120_TOP requests the
#                    bus from the REAL arbiter (PAL_44801A) while the CPU
#                    runs, DMA-writes a pattern into the REAL RAM,
#                    verifies the RAM arrays, DMA-reads it back.
#                    ~12 min (one runSim compile + run).
#
#   make test-dma-xcheck  heavy system gate: OPCOM<->DMA cross-check. The
#                    CPU deposits known words via OPCOM (A/V<CR>) through
#                    the normal store path; the Verilog ND_DMA_MASTER then
#                    DMA-reads those same word addresses and asserts it
#                    sees exactly what OPCOM wrote - DMA and CPU address
#                    one and the same memory. ~12 min (one compile + run).

.PHONY: test test-full test-tape test-dma-rtl test-dma-xcheck test-floppy-boot test-floppy-stdin test-smd-boot test-instr

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
	$(MAKE) test-floppy-stdin
	$(MAKE) test-instr-argument
	@echo ""
	@echo "===================================================================="
	@echo "  FULL SUITE PASSED (units + goldens + vtest)"
	@echo "===================================================================="

# Filter that strips the C device models' debug prints, keeping console text
TAPE_FILTER = grep -vaE '^(PaperTape|FloppyPIO object|IDENT LVL|No device found|WTF|\[0\] FloppyPIO|Callback LVL|Clearing|Generating|Setting|\[binload\] (settling|streaming|injector|byte)|VerilogTape|Floppy PIO)'

test-tape:
	@echo "==== system gate: 400\$$ tape boot, C model vs Verilog device ===="
	$(MAKE) -C runSim clean >/dev/null
	$(MAKE) -C runSim compile USE_LATCHES=0 EXTRA_CFLAGS="-DSCRIPT_INPUT -DSCRIPT_CMD_TAPE400" >/dev/null
	cd runSim && ND120_BINLOAD_CHECK=001000:8 ./obj_dir/VND120_TOP </dev/null > /tmp/nd120_tape_c.log 2>&1
	$(MAKE) -C runSim clean >/dev/null
	$(MAKE) -C runSim compile USE_LATCHES=0 VERILOG_TAPE=1 EXTRA_CFLAGS="-DSCRIPT_INPUT -DSCRIPT_CMD_TAPE400" >/dev/null
	cd runSim && ND120_BINLOAD_CHECK=001000:8 ./obj_dir/VND120_TOP </dev/null > /tmp/nd120_tape_v.log 2>&1
	# Landmark gate: both runs must load AND EXECUTE the program (the
	# banner only prints if the loaded code runs). A byte-diff of the
	# consoles is impossible: the C model's debug prints glue onto the
	# console text mid-line.
	for L in "Words read   054731" \
	         "INSTRUCTION  VERIFY" \
	         "PROGRAM NAME  : INSTRUCTION-B" \
	         "The command HELP gives you a list of the commands."; do \
	  grep -qa "$$L" /tmp/nd120_tape_c.log || { echo "C-model run missing: $$L"; exit 1; }; \
	  grep -qa "$$L" /tmp/nd120_tape_v.log || { echo "Verilog run missing: $$L"; exit 1; }; \
	done
	# The Verilog run must NOT contain the C papertape (proves the swap)
	! grep -qa "PaperTape" /tmp/nd120_tape_v.log
	grep -a "RAM check" /tmp/nd120_tape_c.log > /tmp/nd120_tape_c_ram.txt
	grep -a "RAM check" /tmp/nd120_tape_v.log > /tmp/nd120_tape_v_ram.txt
	cmp /tmp/nd120_tape_c_ram.txt /tmp/nd120_tape_v_ram.txt
	@echo ""
	@echo "===================================================================="
	@echo "  TAPE GATE PASSED (Verilog tape-400 = C model, INSTRUCTION-B boots)"
	@echo "===================================================================="

test-floppy-boot:
	@echo "==== system gate: 1560& floppy mass boot (autoload -> RAM) ===="
	python3 tests/gen_fboot_img.py /tmp/nd120_fboot.img /tmp/nd120_fboot_exp.txt
	$(MAKE) -C runSim clean >/dev/null
	$(MAKE) -C runSim compile USE_LATCHES=0 VERILOG_TAPE=1 EXTRA_CFLAGS="-DSCRIPT_INPUT -DSCRIPT_CMD_FBOOT" >/dev/null
	cd runSim && ND120_FLOPPY_IMG=/tmp/nd120_fboot.img ND120_BINLOAD_CHECK=002000:16 ./obj_dir/VND120_TOP </dev/null > /tmp/nd120_fboot.log 2>&1
	grep -a "RAM check" /tmp/nd120_fboot.log > /tmp/nd120_fboot_got.txt
	cat /tmp/nd120_fboot_got.txt
	# words 0-2 = the loaded program; word at index 10 = 000077, the
	# value the program STORES when it RUNS (the preload background
	# fills the other cells, so a full-line compare is meaningless)
	awk '{ exit !($$5=="170477" && $$6=="004011" && $$7=="151000" && $$15=="000077") }' /tmp/nd120_fboot_got.txt
	@echo ""
	@echo "===================================================================="
	@echo "  FLOPPY BOOT GATE PASSED (1560& BPUN-booted and EXECUTED the program)"
	@echo "===================================================================="

# The interactive (typed-input) path: the SAME binary make run-floppy runs
# (no SCRIPT_INPUT), fed "1560&" through a pipe so all six chars sit in the
# stdin buffer at once - worst-case typing/paste. The harness must hold
# them until the '#' prompt and pace them one per gap, or MOPC (no RX
# FIFO) drops chars and the boot goes to a garbage address (the
# interactive-hang bug). Same RAM proof as test-floppy-boot.
test-floppy-stdin:
	@echo "==== system gate: interactive stdin 1560& floppy boot ===="
	python3 tests/gen_fboot_img.py /tmp/nd120_fstdin.img /tmp/nd120_fstdin_exp.txt
	$(MAKE) -C runSim clean >/dev/null
	$(MAKE) -C runSim compile USE_LATCHES=0 VERILOG_TAPE=1 >/dev/null
	cd runSim && printf '1560&' | ND120_FLOPPY_IMG=/tmp/nd120_fstdin.img ND120_BINLOAD_CHECK=002000:16 ND120_MAX_CNT=120000000 ./obj_dir/VND120_TOP > /tmp/nd120_fstdin.log 2>&1
	grep -a "RAM check" /tmp/nd120_fstdin.log > /tmp/nd120_fstdin_got.txt
	cat /tmp/nd120_fstdin_got.txt
	awk '{ exit !($$5=="170477" && $$6=="004011" && $$7=="151000" && $$15=="000077") }' /tmp/nd120_fstdin_got.txt
	@echo ""
	@echo "===================================================================="
	@echo "  STDIN FLOPPY BOOT GATE PASSED (piped 1560& booted and EXECUTED)"
	@echo "===================================================================="

test-smd-boot:
	@echo "==== system gate: 1540& SMD mass boot (boot handshake -> RAM) ===="
	python3 tests/gen_fboot_img.py /tmp/nd120_sboot.img /tmp/nd120_sboot_exp.txt
	$(MAKE) -C runSim clean >/dev/null
	$(MAKE) -C runSim compile USE_LATCHES=0 VERILOG_TAPE=1 EXTRA_CFLAGS="-DSCRIPT_INPUT -DSCRIPT_CMD_SBOOT" >/dev/null
	cd runSim && ND120_SMD_IMG=/tmp/nd120_sboot.img ND120_BINLOAD_CHECK=002000:16 ./obj_dir/VND120_TOP </dev/null > /tmp/nd120_sboot.log 2>&1
	grep -a "RAM check" /tmp/nd120_sboot.log > /tmp/nd120_sboot_got.txt
	cat /tmp/nd120_sboot_got.txt
	# loaded program + the 000077 it stores when it RUNS (see the
	# floppy gate note about the preload background)
	awk '{ exit !($$5=="170477" && $$6=="004011" && $$7=="151000" && $$15=="000077") }' /tmp/nd120_sboot_got.txt
	@echo ""
	@echo "===================================================================="
	@echo "  SMD BOOT GATE PASSED (1540& BPUN-booted and EXECUTED the program)"
	@echo "===================================================================="

test-dma-rtl:
	@echo "==== system gate: DMA master vs the real arbiter + RAM ===="
	$(MAKE) -C runSim clean >/dev/null
	$(MAKE) -C runSim compile USE_LATCHES=0 VERILOG_TAPE=1 EXTRA_CFLAGS="-DSCRIPT_INPUT" >/dev/null
	cd runSim && ND120_DMA_TEST=010000:32 ./obj_dir/VND120_TOP </dev/null > /tmp/nd120_dma_rtl.log 2>&1
	grep -a "dmatest" /tmp/nd120_dma_rtl.log
	grep -qa "\[dmatest\] RESULT: PASS" /tmp/nd120_dma_rtl.log
	@echo ""
	@echo "===================================================================="
	@echo "  DMA RTL GATE PASSED (real arbiter granted, real RAM read+written)"
	@echo "===================================================================="

test-dma-xcheck:
	@echo "==== system gate: OPCOM deposit <-> DMA read cross-check ===="
	$(MAKE) -C runSim clean >/dev/null
	$(MAKE) -C runSim compile USE_LATCHES=0 VERILOG_TAPE=1 EXTRA_CFLAGS="-DSCRIPT_INPUT -DSCRIPT_CMD_DMAXCHECK" >/dev/null
	cd runSim && ND120_DMA_XCHECK=1 ./obj_dir/VND120_TOP </dev/null > /tmp/nd120_dma_xcheck.log 2>&1
	grep -a "dmaxcheck" /tmp/nd120_dma_xcheck.log
	grep -qa "\[dmaxcheck\] RESULT: PASS" /tmp/nd120_dma_xcheck.log
	@echo ""
	@echo "===================================================================="
	@echo "  DMA XCHECK GATE PASSED (OPCOM-written word read back over DMA)"
	@echo "===================================================================="

# Instruction-verify area gate: boots INSTRUCTION-B, types the area command,
# records the golden-format trace and compares against the ND-110 reference
# (tests/instruction-verify/README.md). Heavy (~15-25 min sim per area).
#
# Validated areas (golden trace delivered by the ND-110 side AND passing the
# architectural gate). The ND-110 side has NOT yet delivered content for
# 32-BITS-FLOATING, PRIVILEGED, ND100-24BIT, BCD, ND100-CX (0-macro golden
# files) or RUN - add them here once their traces arrive and pass.
INSTR_AREAS = ARGUMENT STACK BYTE-STRING MEMORY-REFERENCE SEQUENCE \
              REGISTER-OPERATIONS BIT-OPERATIONS SHIFT-INSTRUCTIONS \
              48-BITS-FLOATING

# `make test-instr-<AREA>` runs one area; `make test-instr` runs the full
# validated sweep (~1.5h). test-full runs only ARGUMENT as a smoke gate.
test-instr-%:
	@echo "==== system gate: instruction-verify $* vs ND-110 golden ===="
	bash tests/instruction-verify/run_area_test.sh $* | tee /tmp/nd120_iverify_$*_gate.log
	grep -q "TB_RESULT: PASS" /tmp/nd120_iverify_$*_gate.log

test-instr: $(addprefix test-instr-,$(INSTR_AREAS))
	@echo "==== all $(words $(INSTR_AREAS)) instruction-verify areas PASSED ===="
