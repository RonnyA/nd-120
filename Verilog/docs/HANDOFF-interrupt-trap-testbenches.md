# HANDOFF — ND-120 interrupt/trap testbenches + RUN blocker fix

Written 15-JUL-2026. Branch `clock-enable-fix`. Repo root: `/mnt/e/Dev/Repos/Ronny/nd-120`.
Verilog root: `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog`.

This is a cold-start handoff for the next LLM. All paths are absolute.
NOTHING has been committed — see "Commit" below (needs Ronny's explicit git permission).

---

## 1. What is DONE and PROVEN this session

### 1a. RUN blocker root-caused + fixed (THIRD CPU transcription bug)
- **File:** `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR.v`
  lines ~129-131.
- **Bug:** `s_fidbo_2_0[1]` and `[2]` were swapped on the status-write path
  (`s_fidbo_2_0 -> VECGEN.FIDBO_2_0 -> HISIN/LOSIN` = the microcode LDSTAT
  status-fence value). The swap corrupted the AIIC (`TRA IIC`, CS 000725)
  status-fence scan so an IOX interrupt (hivec 2) got bracketed at fence 4 and
  decoded as MOR — reported `IIC 11 (octal)` instead of `IIC 7`. Only RUN's
  internal-interrupt path used LDSTAT, so self-test / RTC / 13 instruction
  areas all passed with the bug; only RUN failed.
- **Fix:** straight-through assignment `s_fidbo_2_0[0..2] = s_fidbo_15_0[0..2]`,
  applied CLEANLY (no `#ifdef`, no version fork — Ronny explicitly required a
  single version with a one-line comment, NOT a big comment block or an
  `ND120_INTR_FIDBO_SWAP_FIX` gate).
- **Validated:** self-test 0 STERR; unit suite green; 13/13 instruction-verify
  areas PASS vs golden; sim/ latch-vs-FF golden traces byte-identical; console
  swap-neutral; RUN now handles IOX-ERROR -> LEVEL 13 -> END-OF-TEST.
- Full analysis: `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/RUN-level14-livelock-analysis.md`.

Also in the coordinated (uncommitted) change set, validated green earlier this session:
- **Am2914 status fence** default-ON (escape hatch `ND120_INTR_STATUS_FENCE_OFF`):
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_STAT.v`
  and `.../CGA_INTR_CNTLR_VECGEN_STAT_SBIT.v`.
- **MOR level-12 wiring** (from the MON-signal LLM), KEPT:
  `.../CGA_INTR/circuit/CGA_INTR.v` (`assign s_mor_n = MORN;`) + `NORN->MORN`
  rename in `CGA_INTR.v` / `CGA_INTR_IRSRC.v`.

### 1b. 29 gate-level unit testbenches — ALL PASS, teeth-checked, IN THE SUITE
- 24 for CGA_INTR, 5 for CGA_TRAP. Each: iverilog `-g2012`, self-checking with
  an INDEPENDENT shadow model (golden NOT copied from DUT wires), prints exactly
  `TB_RESULT: PASS`, and has a `-DTEETH_TEST` perturbation proven to force FAIL.
- **NO DUT bug was found in any of the 29** (~600k+ total checks). The gate
  netlists match the independently-derived behavior everywhere.
- Files: `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_INTR/sim/*_tb.v`
  (24) and `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_TRAP/sim/*_tb.v` (5).
- **Runner:** a generic `iv-%` rule was added to BOTH Makefiles
  (`.../CGA_INTR/sim/Makefile`, `.../CGA_TRAP/sim/Makefile`):
  `make iv-<MODULE>` compiles `<MODULE>_tb.v` against the gate netlists via `-y`
  (Shared libs + circuit dir) and runs it.
- **Registered:** all 29 added to
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/tests/run_all_tests.sh`
  (entries `... :: iv-<MODULE> :: TB_RESULT: PASS`).
- **Verified in-harness:** running every registered target exactly as the suite
  does gave PASS=29 FAIL=0. (I did NOT run the full `make test` end-to-end —
  that rebuilds the whole 48-test suite incl. Verilator builds; Ronny gates
  heavy runs. New LLM: run `cd Verilog && make test` when you want the full
  green confirmation. Only the new iv- targets were run individually here.)

Modules covered by the 29:
- VECGEN: PTY_PTYENC, PTY, CMP_MAGCMP, CMP, STAT_SBIT, STAT, ISMUX, OSMUX, VHR
- IRQ: IRQ_REG_RQBIT, IRQ_REG, IRQ_MASK_MASKBIT, IRQ_MASK, IRQ_MREQ, IRQ
- IRGEL: IRGEL_VMUX, IRGEL_HIGEL, IRGEL_LOGEL, IRGEL_HIRL, IRGEL_LORL, IRGEL
- Command/clear/top: MDCD, CLR, CGA_INTR_CNTLR (the CNTLR-top tb carries 43
  dedicated FIDBO no-swap assertions guarding the 1a fix)
- TRAP: TBUF, BRKDET, TVGEN_P2, TVGEN, CGA_TRAP

### 1c. RTC question answered (Ronny asked: free-running or manual-start for "bit 3"?)
- The **RTC timebase is FREE-RUNNING from master clear** — `s_rtc_cnt` in
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DECODE-GateArray/DGA/circuit/DECODE_DGA_POW.v:363-382`
  has NO enable/start input; it counts every `sysclk`, zeroed only by power-on
  reset (`s_rescl`) or the microcode re-arm (`COMM,CLRTC` -> `s_clrti`).
- **"bit 3" = IOC-register bit 3** (`s_ioc_3`,
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/CPU-BOARD-3202/circuit/IO_REG_41.v:180`,
  "clock interrupt generated from RTC trap handler"). It is a `TTL_74273` Q
  output written ONLY by software (IOX/`COMM,SIOC`); after master clear it is 0.
  It becomes 1 when the 20 ms RTC trap-handler microcode (`MS20`, `o2333` in the
  listing) writes IOC via `WSIOC`. Board level-13 needs BOTH bit 3 and bit 0
  (OS-set enable): `s_bint13_n = ~(s_ioc_3 & s_ioc_0)` (`IO_REG_41.v:148`).
- Net: the timebase needs no manual start; bit 3 appears only after the RTC
  trap handler has run at least once, and a level-13 interrupt additionally
  needs the OS to have set IOC bit 0 first.
- Open/unknown: IOC bit 7 ("Reset real time clock", `IO_REG_41.v:175`) is
  captured but NOT wired to the DGA RTC in this RTL — whether original hardware
  used it needs the DELILAH schematic sheet to confirm.

---

## 2. PENDING — the next big task Ronny asked for (NOT STARTED)

**Ronny's request (verbatim intent):** build COMPLICATED functional SEQUENCE
testbenches (not just leaf-unit tests) that drive the interrupt controller
through realistic command sequences and validate the reported level. His words:

> "the test benches must execute all known interrupt config commands, and
> follow up commands to clear, set allowed interrupts, set multiple interrupt
> pins, check correct level reported, set interrupt bits via interrupt design
> internals command (not pin), check level again, clear interrupt pin, check
> interrupt level, clear interrupt detection/chip ... analyse the manual for the
> Am2914 Priority Interrupt Controllers and build tests that validate [the two
> chips] cascaded together to provide a total of 16 interrupt levels."

### What this means concretely
- **DUT:** `CGA_INTR_CNTLR` (the controller that wires VECGEN + IRQ + IRGEL +
  MDCD + CLR), or the `CGA_INTR` top. This is a FUNCTIONAL/behavioral sequence
  test, distinct from the 29 leaf-unit tbs already done.
- **The "two Am2914 chips cascaded = 16 levels"** maps in our RTL to the **HI
  group + LO group** inside `CGA_INTR_CNTLR_VECGEN` / `IRGEL` (each group = 8
  vectors; HI wins over LO). Confirm this mapping from the RTL before building.
- **Commands** are decoded by `CGA_INTR_CNTLR_MDCD` from `LAA_3_0` (4 bits = up
  to 16 PIC commands). The real command semantics are in the microcode listing
  (PICF/PICI/PICS/RMSK/LOSTS/etc.). The Am2914 datasheet instruction set is the
  spec to validate against.
- **Driving a command** = set `LAA_3_0` + `FIDBO_15_0` (data for mask-load /
  internal set) + pulse `MCLK`. Outputs to check: `PICV_2_0` (vector),
  `PICS_2_0` (status/group), `IRQN`, `PICMASK_15_0`, `HIGSN`/`LOGSN`.
- **"set interrupt bits via internals command (not pin)"** = the software
  set-request path through `FIDBO` + a PIC command, as opposed to asserting an
  `IREQ_15_0_N` pin. Identify the exact command + RTL path.
- **"clear interrupt detection/chip"** = the clear-all / master-clear command
  path (`CGA_INTR_CNTLR_CLR` + the MDCD clear strobes).

### Recommended approach (spin off as agents, per Ronny)
1. **Research agent FIRST (single, blocking):** produce a spec file that nails
   (a) the Am2914 datasheet instruction set — FETCH IT (WebSearch/WebFetch for
   "Am2914 Vectored Priority Interrupt Controller datasheet"); (b) the mapping
   Am2914-instruction <-> our `LAA_3_0` code <-> microcode PIC mnemonic <-> MDCD
   strobes; (c) the DUT port list + how many `MCLK` pulses each command needs;
   (d) the HI/LO -> 16-level cascade mapping (which `IREQ` bit index = which
   (group, level) = which reported `PICV`+`PICS`); (e) a concrete worked
   sequence with expected outputs at each step. Write it to
   `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/am2914-command-model.md`.
   Do NOT let the builder agents each re-derive the command model — they will
   disagree. One shared spec, then fan out.
2. **Builder agents** (2-3) consume that spec + the RTL and build the sequence
   tbs (iverilog, self-checking, `TB_RESULT: PASS`, `-DTEETH_TEST`, independent
   golden). Register with the same `iv-%` rule + `run_all_tests.sh` pattern used
   for the 29 unit tbs.
3. Ronny's explicit sequence to cover at minimum: master-clear -> set allowed
   (mask) -> assert multiple IREQ pins -> read level (verify highest-priority
   reported, incl. HI-over-LO across the cascade) -> set request bits via the
   internal command (not pin) -> re-read level -> clear one interrupt pin ->
   re-read level -> clear detection/chip -> verify cleared.

### Reference material for the Am2914 work
- Microcode listing (PIC command usage, AIIC at CS 000725):
  `/mnt/e/Dev/Ronny/nd120uc/source/ND-120-DELILAH-L.LISTING.txt`
- C# PIC ground-truth trace:
  `/mnt/e/Dev/Repos/Ronny/ND110Compile/traces/PIC-TRACE-RUN-ND120.md`
- nd100x IIC reference: `~/repos/nd100x/src/cpu/cpu.c` (`calcIIC`) and
  `cpu_instr.c:1888` (`TRA IIC`).
- Established interrupt architecture facts (verified this session, DO NOT
  re-derive): `IIC = highest set bit of (IID & IIE)`; our IREQ bits IOX=10,
  PAR=11, MOR=12, POW=13 -> hivec IOX=2,PAR=3,MOR=4,POW=5 -> `IIC_bit =
  IREQ_bit - 3 = hivec + 5`; MDCD decodes `LAA_3_0`; the FIDBO->status path is
  now straight-through (1a). See `docs/RUN-level14-livelock-analysis.md`.
- Am2914 datasheet is NOT on disk — fetch it from the web.

---

## 3. Other open tasks (unchanged, not this session's focus)
- **Commit (task #50):** NOTHING is committed. When Ronny gives git permission,
  commit as ONE coherent change: FIDBO fix + status fence default-on + MOR
  wiring + `docs/RUN-level14-livelock-analysis.md` + the 29 tbs + the two
  Makefile `iv-%` rules + the `run_all_tests.sh` registry additions + the
  probes in `runSim/Run120.cpp` (`ND120_PROBE_RUNIDENT`, `ND120_COUNT_STERR`) +
  `test_irsrc.cpp`. Branch `clock-enable-fix` is ~19+ commits ahead of origin,
  not pushed. **NEVER put the word "claude" in the commit message.**
- **Task #41 (PHASE D):** Tang Nano 20K `400$` FF-mode hang (level-12 tape
  storm suspect) — owned by the devices/FAT workstream, not this one.
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/HANDOFF-tang-sd-tape-boot.md`.

---

## 4. Modified / created files (git status, on branch clock-enable-fix)
Modified (tracked): `CGA_INTR/circuit/CGA_INTR.v`, `CGA_INTR/circuit/CGA_INTR_CNTLR.v`,
`CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_STAT.v`,
`CGA_INTR/circuit/CGA_INTR_CNTLR_VECGEN_STAT_SBIT.v`,
`CGA_INTR/circuit/CGA_INTR_IRSRC.v`, `CGA_INTR/sim/Makefile`,
`CGA_TRAP/sim/Makefile`, `docs/RUN-level14-livelock-analysis.md`,
`runSim/Run120.cpp`, `tests/run_all_tests.sh` (all under
`/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/`).
Untracked (new): 29 `*_tb.v` under the two `sim/` dirs, `CGA_INTR/sim/test_irsrc.cpp`,
`CGA_INTR/sim/obj_dir_irsrc/` (build artifact — do not commit).

## 5. How to run
```
cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog
# one unit tb:
make -C DELILAH-CPU/CGA_INTR/sim iv-CGA_INTR_CNTLR      # -> TB_RESULT: PASS
make -C DELILAH-CPU/CGA_TRAP/sim iv-CGA_TRAP            # -> TB_RESULT: PASS
# teeth check (must FAIL):
iverilog -g2012 -DTEETH_TEST -y Shared/logisim -y Shared/support -y Shared/ndlib \
  -y DELILAH-CPU/CGA_TRAP/circuit -o /tmp/x \
  DELILAH-CPU/CGA_TRAP/sim/CGA_TRAP_tb.v && vvp -N /tmp/x
# full suite (heavy — Ronny gates this):
make test
```
