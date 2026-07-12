# Instruction-verify campaign - ND-120 RTL vs ND-110 golden traces

Goal: validate and bug-fix ALL macro instructions by comparing our ND-120
RTL (Verilator, runSim) against reference traces from a known-good ND-110
emulator running Norsk Data's INSTRUCTION-B verify program (204384B).
One unit test per instruction group, registered in tests/run_all_tests.sh,
plus the final full RUN.

## Reference material (delivered by the ND-110 side)

- Golden traces: `/mnt/e/Dev/Repos/Ronny/ND110Compile/traces/TRACE-INSTRUCTION-VERIFY-<AREA>.md`
  (AREA = ARGUMENT, MEMORY-REFERENCE, SEQUENCE, REGISTER-OPERATIONS,
  BIT-OPERATIONS, SHIFT-INSTRUCTIONS, 32-BITS-FLOATING, 48-BITS-FLOATING,
  PRIVILEGED, BYTE-STRING, ND100-24BIT, BCD, ND100-CX, STACK).
  Regenerated on the ND-110 side with `dotnet test --filter "Name~GenerateTrace"`.
- ND-110 microcode listing: `/mnt/e/Dev/Repos/Ronny/ND110Compile/ND110Compile/uCode/ND-110-RASK.LISTING.TXT`
- ND-110 symbols: `/mnt/e/Dev/Repos/Ronny/ND110Compile/ND110Compile/uCode/ND-110-RASK.SYMBOLS.TXT`
- ND-120 microcode listing: `/mnt/e/Dev/Repos/Ronny/ND110Compile/ND110Compile/uCode/ND-120-DELILAH-K.LISTING.TXT`

## Trace format (per golden file)

- Program started with `0!`, then the AREA command typed at the `>` prompt.
- One `###` section per macro instruction: `addr : opcode` + full register
  state at fetch (octal): A D T X B L P STS, current-level scratch R1-R7,
  Am2901 Q register, ALU output latch F, GPR shift register, loop counter LC,
  and PIL (the running interrupt level).
- Micro rows: `csar | symbol | changed-registers | RASK source`. Control-store
  addresses are ND-110 RASK addresses; the SYMBOL (exact label or LABEL+n
  octal offset) is the portable key into our DELILAH microcode.
- Detail arms at the first macro instruction on a test level (PIL 1-9),
  records 400 instructions; console preamble is skipped.

## Comparison rules

1. Macro rows (address, opcode, full register state at fetch) must match
   the ND-120 EXACTLY, including PIL and R1-R7.
2. Micro rows compare PER-SYMBOL (what each routine step changes), never by
   control-store address - the two microcodes place routines differently.
   Use the symbol map below.
3. Level-13 clock interrupts interleaved in the trace are real and
   timing-dependent - flag separately, do not report as register divergence.

## Symbol map (this directory)

- `gen_mic_map.py` - regenerates the map from the two listings.
- `ND110-ND120-MIC-MAP.md` - human document (GENERATED - do not hand-edit).
- `nd110_nd120_mic_map.tsv` - machine-readable: symbol, nd110 addr,
  nd120 addr, status (same | moved | ocr:... | only-110 | only-120).

Map results: 1067 symbols in both microcodes (612 same address, 455 moved),
25 OCR spelling twins reconciled (the ND-110 listing is OCR-sourced: 0/O and
1/I/L confusions - trace tooling must treat twin spellings as one symbol),
10 genuinely ND-110-only, 14 genuinely ND-120-only (extra console/BAUDS/TRM
words). Every symbol seen so far in the golden traces exists on our side.

## Running a compare (the recipe)

```bash
# 1. build runSim with the trace emitter (FF mode, public signals)
cd Verilog/runSim
make compile USE_LATCHES=0 EXTRA_VDEFINES="--public-flat-rw" EXTRA_CFLAGS="-DND120_TRACE_VERIFY"

# 2. boot INSTRUCTION-B from tape 400 and type the area command
printf '400$ARGUMENT\r' | ND120_MAX_CNT=400000000 ND120_STDIN_GAP=300000 \
  ND120_TVERIFY_OUT=trace_nd120_argument.md \
  ND120_TVERIFY_SYMS=../tests/instruction-verify/nd120_symbols.tsv \
  ./obj_dir/VND120_TOP > run.log 2>&1

# 3. compare against the golden trace
python3 ../tests/instruction-verify/compare_trace.py \
  /mnt/e/Dev/Repos/Ronny/ND110Compile/traces/TRACE-INSTRUCTION-VERIFY-ARGUMENT.md \
  trace_nd120_argument.md
```

The emitter arms at the first PIL 1-9 macro instruction and records 400
(ND120_TVERIFY_MAX overrides). Boundary detection uses the CPU FETCH strobe -
the ND-120 CONTINUE dispatch does NOT visit csa 0 (only level switches do),
so csa-0 boundaries miss most instructions.

## Calibration findings (ARGUMENT, 12-JUL-2026)

- Macro register state matches golden essentially exactly from instruction #1
  (A D T X B L P STS R1-R6 Q F GPR all equal on the armed snapshot).
- KNOWN BENIGN: `R7` differs (golden constant 020003, never written in-window;
  ours 000003/000001) - preamble/init difference (their emulator loads BPUN +
  `0!`; we boot via real 400$ MOPC path which uses R7 scratch). Whitelist with
  `--ignore-regs R7` until the ND-110 side confirms.
- LC: golden logs a 16-bit software count, our hardware loop counter is 6 bits
  ({ICD5,ICD4,LC3:0}) - comparator masks LC to 6 bits.
- Our F (ALU output latch) lands one micro-row later than golden's
  combinational F - micro rows are advisory (per-symbol warnings), macro rows
  are the gate.

## Execution plan

1. **Prerequisite: fix the Verilator IDB read race** - the AREA command is
   typed at the booted program's console, and booted programs poll the UART
   via IOX reads that return 0 in zero-delay sim (see
   Verilog/docs/sim-io-capture-and-clocking-lessons.md sections 1-2).
   Without this fix INSTRUCTION-B can never receive the command in sim.
2. Trace instrumentation in runSim: emit the same-format trace from our RTL
   (macro fetch state + per-microinstruction changed-register rows keyed by
   DELILAH symbol from the map).
3. Mechanical comparator: macro rows exact-match, micro rows per-symbol;
   reports FIRST divergence (macro address, register, expected vs actual,
   producing microcode routine by symbol). No LLM in the loop.
4. Calibrate with ARGUMENT (passes on the ND-120 per the ND-110 side's
   expectation) - a clean report proves the method.
5. Then the failing areas; STACK and BYTE-STRING first (they exercise the
   LC-indexed register-file rings). One registered `make test` target per
   area; final RUN gate last.
