# HANDOFF: TPE Monitor (floppy) memory-test — banner corruption + probe char-capture

**Full path:** `Verilog/docs/HANDOFF-tpe-memory-test-corruption.md`
**Date:** 2026-07-23
**Status:** ACTIVE investigation. First-ever driving of the real TPE Monitor's
own diagnostics from a Verilator floppy boot. A concrete, reproducible
instruction bug is now on the table (banner-string corruption).

---

## 1. What we are doing (and why it changed)

Goal: get the ND-120 CPU to pass the **real TPE Monitor** diagnostics booted
from floppy in Verilator — not the older `instruction-verify` campaign
(`INSTRUCTION-B` via `400$`), which already passes but is a *lighter* harness.
The TPE-Monitor-booted-from-floppy tests are harder and were **never actually
driven into their own suite before this session** — earlier runs only reached
the `TPE>` prompt.

The moment we drove the memory test, we hit output corruption that **by itself
proves instruction-level bugs** (user's call: "the wrong characters already
give away that we have bugs in the instructions that need to be found").

---

## 2. Boot path (measured, working)

- Boot command at the `#` monitor prompt: **`1560&`** (octal device 1560,
  floppy autoload) — served by the **portable C floppy core**
  (`obj_dir_probe_floppycore` / `run-tpe` backend).
- Image: `Verilog/runSim/FLOPPY1.IMG`
- The **send-gap fix is confirmed working**: `1560&` now boots the *real*
  **TPE Monitor B01** (banner `TPE Monitor, ND-100 series - Version: B01 -
  1988-10-07`), NOT the old `INSTRUCTION-B` fall-through. This was the
  previously-unverified link (see `HANDOFF-session-2026-07-22.md`); it holds
  over a full-length run.
- The boot-time line `==TPE42=> The clock is not updated (display panel wrong
  or unexisting)` is EXPECTED (no display panel), not a failure.
- Wall time to `TPE>`: ~17-20 min at ~46k ticks/s (~90-130M sysclk ticks).

---

## 3. TPE Monitor command structure (as learned this session)

At the `TPE>` prompt (commands are case-insensitive; abbreviations accepted):

| Command    | Effect |
|------------|--------|
| `HELP`     | lists all commands (per the monitor's own hint) |
| `mem` / `MEMORY` | loads the **MEMORY** diagnostic (Version **D04**, 1988-02-01) |
| `run` / `RUN`    | runs the memory test areas (READ, WRITE/READ 7-pattern, walk, parity, ...) |

`config`/`run` was a DEAD END (a stale guess copied from
`runSim/Run120.cpp` `SCRIPT_CMD_FBOOTCFG` = `"1560&config\rrun\r"`): in TPE B01
`config` is echoed but drives no test — paging never turns on (`PON=0`), zero
memory activity. **Do not use `config`.** Use the test name (`MEMORY`) and/or
`RUN`.

### Expected reference output (user-provided ground truth)

`mem` / `MEMORY` should print:
```
TPE>mem


    MEMORY - Version: D04 - 1988-02-01


Total memory size....: 4.000 Mbytes
```

`RUN` should print (each area ends with `=== END OF TEST ===`, then loops):
```
TPE>run

AREA TESTED: 0.12-31.15
READ TEST ON  PROGRAM  PART    === END OF TEST ===
ADDRESSES  IN  ADDRESSES       === END OF TEST ===
WRITE/READ TEST (7 PATTERNS)   === END OF TEST ===
RAPIDLY CHANGING ADDRESS BITS  === END OF TEST ===
PARITY  ERROR  DETECTION       === END OF TEST ===
WALK TEST (34 PATTERNS)        === END OF TEST ===

=== THE TESTS ARE NOW LOOPING ===
```

**The MEMORY test is very slow** (enormous loop counts). It is a poor *first*
target for CPU-correctness validation. Prefer catching bugs at the earliest
cheap artifact (the banner corruption below) and/or the `RUN` area headers,
rather than waiting out the deep memory loops.

---

## 4. THE BUG: banner-string corruption ("MEMORY" -> "MEMO\x7f\x7f")

Actual sim output of the D04 banner:
```
    MEMO\x7f\x7f - Version: D04 - 1988-02-01
```
- `MEMO` (chars 1-4) correct; **`RY` (chars 5-6) both emitted as `0x7f`** (DEL,
  octal 0177). Everything AFTER the string (` - Version: D04 ...`) is correct.
- After the corrupted banner the test **HANGS**: the expected
  `Total memory size....: 4.000 Mbytes` line never appears (>30M ticks with no
  further output).

### Byte analysis (inferred, to be confirmed by capture)

- `0x7f` = `0o177` = all 7 low bits set. If the output routine masks to 7-bit
  ASCII, a **source byte of `0xFF`** masks to `0x7f`.
- `MEMORY` packs as three 16-bit words: `ME` `MO` `RY`. Words 1-2 print
  correctly; **word 3 (`RY`) reads back as `0xFFFF`** (all-ones = the classic
  failed/floating read pattern), so both its bytes mask to `0x7f`.
- Because the text *after* the string reads fine, this is not a dead address
  *range* — it is a specific bad access on that one word (a load returning
  all-ones, a byte-address computation error, or a corrupted-in-RAM word).
- Cousin to the open `177777` bug (top-page paged store reads back 0): both are
  memory-access defects. Relationship unproven.

**This is a HYPOTHESIS from the bytes, not proof.** The capture in §6 is what
localizes it.

---

## 5. Simulator speed — findings (compile flags are a DEAD END)

Measured on the probe (full CPU model, Verilator 5.024, 20-core host):

| Build | ticks/s |
|-------|---------|
| `-Os` single-thread (Verilator default) | **~46,000** (best) |
| `-O2 -march=native` single-thread       | ~37,900 (slower) |
| `-O2 -march=native --threads 8`         | ~17,300 (2.7x slower) |

- **`--threads` is a heavy pessimization**: the ND-120 is a tight sequential
  feedback loop (microcode + bus) that Verilator cannot partition, so worker
  threads spend all their time on per-tick barriers. Do not use `--threads`.
- **`-O2`/`-O3` is slower than `-Os`** for this model: the generated `eval` is
  enormous and aggressive inlining blows the instruction cache. This is exactly
  why Verilator defaults `OPT_FAST = -Os`. Do not override it.
- Net: **keep the default `-Os` single-thread.** Speed is not won at the
  compiler; it is won by (a) stopping early at the failure and (b) NOT
  re-booting per experiment. The probe is a live REPL — boot once, probe many
  times in one process.

---

## 6. Probe extension + capture method (this session)

### Probe change (committed to working tree, NOT git-committed)

`Verilog/sim/nd120_probe.cpp` — added two
read-only **pseudo-signals** so rules can trigger per emitted output character:

- `TXBYTE`   — the CPU's most-recently completed UART output byte (0..255)
- `TXSTROBE` — 1 for the single tick that byte completes

Set in `serviceUartRx()` `case 11` (byte fully received); `TXSTROBE` cleared
after `evalRules()` each tick. Registered in `buildRegistry()`. A char completes
~`11*DELAY_FRAMES` (DELAY_FRAMES=16, so ~176) ticks AFTER the CPU wrote it — so
pair `TXSTROBE` with a **deep pre-ring** (`set pre N`) to look back at the
store/load that produced the byte.

Rule usage (localizes the corruption):
```
watch MIC + STORE + BUS groups, plus TXBYTE, TXSTROBE ; set pre 3000 post 120
rule good_char  when "TXSTROBE==1 && TXBYTE==0x4f"  do log,csv,mark      # 'O' (good)
rule bad_char   when "TXSTROBE==1 && TXBYTE==0x7f"  do log,csv,mark,stop # DEL (bad)
```
Comparing the good-char vs bad-char CSA (microcode-address) + BIF store/bus
windows shows where the bad char's path diverges. Also reads `CSA_12_0` at the
hang to locate the stall loop.

### Build (incremental, fast — avoids the 15-min full rebuild)

Because a running process holds `obj_dir_probe_floppycore/VND120_TOP`
(ETXTBSY), copy the obj dir and relink in the copy (only `nd120_probe.o`
recompiles; the huge model objects are reused):
```
cd Verilog/sim
cp -r obj_dir_probe_floppycore obj_dir_probe_dbg
cd obj_dir_probe_dbg && make -f VND120_TOP.mk VND120_TOP     # ~1-2 min
```

### Driver scripts (currently in scratch — MOVE to `sim/examples/` to persist)

- `/tmp/claude-1000/tpe_capture.py`  — generic: boot -> `TPE_CMD` -> capture the
  `177777` paged store. **Fix vs the old example**: `Probe(timeout=900)` and
  `TPE_STEP=5_000_000` (a `run(STEP)` at 46k/s is ~110s; the old hardcoded 180s
  timeout blew up mid-step). Sends the test name (default `MEMORY`), NOT
  config/run.
- `/tmp/claude-1000/tpe_charcap.py` — the banner-corruption localizer described
  above (uses `TXBYTE`/`TXSTROBE`).

Note: `/tmp/claude-1000/...` is session scratch and will be deleted. Move both
drivers into `Verilog/sim/examples/` if this work
is to survive the session, and add the `TXBYTE`/`TXSTROBE` note to
`Verilog/sim/PROBE-README.md`.

---

## 7. Open threads / next steps

1. **Localize the banner corruption** (capture in flight): compare good vs bad
   char microcode/bus windows in `sim/tpe_char_mem.csv`; identify whether it is
   a load returning all-ones, a byte-address computation bug, or a
   corrupted-in-RAM word. Get the hang CSA.
2. **Reconsider test choice**: the MEMORY test is too slow for iteration. The
   banner corruption is the cheap early artifact; use it. For broader coverage
   the `RUN` area headers appear before the deep loops.
3. Relationship to the `177777` top-page store bug — both memory-access
   defects; check for a common root once §1 is localized.
4. Do NOT chase compiler speed (see §5). Iterate inside one boot via the probe
   REPL; if per-experiment boot cost becomes the bottleneck, the honest fix is a
   state snapshot at `TPE>` — but note Verilator `--savable` does not serialize
   the C device/UART layer, so that needs care.

---

## 8. Reproduce

```
cd Verilog/sim
# (instrumented probe already built in obj_dir_probe_dbg; else see §6)
export TPE_STEP=3000000 TPE_TIMEOUT=900
python3 /tmp/claude-1000/tpe_charcap.py \
    Verilog/sim/obj_dir_probe_dbg/VND120_TOP mem
# outputs: sim/tpe_char_mem.log , sim/tpe_char_mem.csv
```
