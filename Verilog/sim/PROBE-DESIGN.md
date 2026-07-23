# ND-120 generic sim probe + Python driver — design

**Full path:** `E:\Dev\Repos\Ronny\nd-120\Verilog\sim\PROBE-DESIGN.md`

Goal: replace the hardcoded, recompile-per-signal tracing in `test_nd120.cpp` /
`latch_ff_compare.cpp` with ONE reusable, scriptable probe you can point at *any*
signal and *any* trigger at runtime, driven from Python the same way nd100x is
driven by `tools/nd100x_expect.py`.

## What exists today (baseline, see analysis in chat)

- `test_nd120.cpp` — full FST dump (`top->trace(m_trace,1)`), UART console driver,
  BPUN backdoor load. Window = `ND120_START_TRACE`/`ND120_MAX_TICKS` (runtime). One
  ad-hoc post-trigger window (`logwin=60` on CSA 06000..06003) → `mic_trace.csv`.
- `latch_ff_compare.cpp` — per-cycle CSV of a **hardcoded** signal list via
  `top->rootp->ND120_TOP__DOT__…` root paths. Change a signal ⇒ edit C++ + ~12 min
  Verilator rebuild. No pre-trigger history, no runtime trigger.

Gaps: (a) signal list is compile-time, (b) trigger is compile-time, (c) no
pre-trigger (ring-buffer) capture — exactly what a store-routing bug needs.

## Architecture

```
  Python example scripts  (examples/mmu_177777_probe.py, …)   <- the investigation
        │  import
  nd120_probe.py   (pexpect-style driver; mirrors nd100x_expect.py; stdlib only)
        │  spawn + line protocol over stdin/stdout (unbuffered)
  obj_dir/VND120_TOP   built from nd120_probe.cpp  (the ENGINE)
        │  Verilator --vpi --public-flat-rw
  VND120_TOP  (whole ND-120, report-only RTL — never edited)
```

### The engine — `nd120_probe.cpp`

Instantiates `VND120_TOP`, backdoor-loads RAM, toggles `sysclk`, calls
`proccess_bif_signal(top)` (reuse the existing bus/UART code paths). On top it adds:

1. **Runtime signal access by name (VPI).** Build with `--vpi --public-flat-rw`.
   Signals are resolved on demand with `vpi_handle_by_name("ND120_TOP.CORE.CPU_BOARD.MMU.s_wmap_n", NULL)`
   and read with `vpi_get_value`; handles are cached in a `map<string,vpiHandle>`.
   This is what makes it generic — Python names a signal, the engine reads it, no
   recompile. (FALLBACK if VPI is unavailable in this Verilator: a curated
   `{name→&root_path}` registry, proven to work by `latch_ff_compare.cpp`. The
   protocol below is identical either way.)

2. **Named signal GROUPS** (convenience aliases resolved to VPI name lists), so a
   script can `watch group MMU` instead of listing ten hierarchical names:
   - `MMU`   = `MMU.s_lshadow, MMU.s_wmap_n, MMU.s_epmap_n, MMU.s_ept_n,
                MMU.s_la_20_10, MMU.s_cyd` + `…CPU_BOARD.s_poni` (PON)
   - `STORE` = CD/LBD/DD write path + effective store address + write strobes
   - `BUS`   = BAPR/BDAP/BDRY/BINPUT/BREQ/INGRANT/BMEM (+ `BD_23_0`)
   - `MIC`   = `CSA_12_0, XMIC_DBG_15_0` (microcode addr/rep — top ports, always ok)
   Groups live in one table in the engine; add a signal = one line (but with VPI you
   usually just name it from Python, no edit).

3. **Rule engine (runtime) — react on ANY signal combination.** The core generic
   feature (Ronny, 2026-07-22): rules are `WHEN <expression> DO <actions>`, defined
   from Python at runtime, evaluated every tick.
   - **Condition = a boolean expression over any signals** (the combination
     requirement). Grammar: dotted signal names, integer literals (`o177777` octal /
     `0x…` / decimal), bit-select `name[hi:lo]`, compares `== != < <= > >=`, boolean
     `&& || !`, parentheses. Example:
     `MMU.s_wmap_n==0 && MMU.s_lshadow==1 && CSA_12_0 >= o6000`.
     The engine parses once into an AST of VPI-resolved signal reads; evaluates cheaply
     each tick. Rising-edge semantics by default (fire when the expr goes false→true);
     `level` modifier fires every tick it holds.
   - **Actions (one or more per rule):**
     - `log[:"msg"]` — debug-log the tick + the rule's referenced signal values (and
       optional message) to stdout as an `EVENT`/`LOG` line the Python side captures.
     - `fst_on` / `fst_off` — **enable/disable** the `.fst`/GTKW dump (Ronny: gate the
       waveform output on a signal combination). Lets a script record ONLY the window
       where the interesting condition holds → tiny, focused `.gtkw`-viewable trace.
     - `csv` — snapshot the PRE ring + arm the POST window into the CSV (§4).
     - `event` — emit a machine-parseable `EVENT` (default if no action given).
     - `mark:"tag"` — write a labelled marker (into CSV + FST comment) for navigation.
     - `stop` — end the run (so `runto` = a one-shot rule with `stop`).
   - Convenience shorthands expand to rules: `store_la:<addr>` →
     `WHEN <store-strobe> && LA==<addr> DO event`; `csa:<lo>..<hi>` →
     `WHEN CSA_12_0>=lo && CSA_12_0<=hi DO event`.
   - Rules are named (`rule add <name> when "…" do …`, `rule clear <name|all>`), so a
     Python script builds a whole reactive debug policy (e.g. "log every shadow write,
     and turn the FST on only while paging is enabled and a top-page store is in
     flight") without any recompile.

4. **Pre/post window ring buffer.** Every tick, the active watch set is pushed into
   a ring of depth `PRE` (default 128). On a trigger: flush the `PRE` retained
   cycles, then keep capturing `POST` cycles (default 128) into the current event's
   CSV. Multiple events append (each tagged with an event id + which trigger fired).

4b. **Trigger-windowed FST (full-fidelity path).** The engine ALSO holds a
   `VerilatedFstC` (as `test_nd120.cpp` does) but gates `m_trace->dump()` to a
   window: dumping turns ON at an `arm` point and OFF `POST` cycles after the
   trigger, so the FST is FULL-hierarchy but small. This is the "much more detailed"
   path Ronny flagged: the windowed `waveform_win.fst` is then read by the EXISTING
   Python tools — `fst.py::open_wave` (pipes through `fst2vcd`) and
   `vcd_extract.py` (`-s NAME…`, `-p PATTERN`, `--gtkw top_3202d.gtkw`, `--tstart/
   --tend`, `--json`, `--list`) — so scripts get arbitrary-signal detail WITHOUT the
   engine pre-naming anything, and the same `.gtkw` opens it in GTKWave for eyeballing.
   Capture mode is per-run: `capture csv` (compact/ring, assertable) and/or
   `capture fst <path>` (full/windowed, for deep analysis) — both can be on.

5. **Backdoor RAM.** `deposit <addr> <val>` / `examine <addr>` (word-indexed
   `ram_high<<8|ram_low`, the proven backdoor) so a script can set up and then
   VERIFY where a store landed (main vs shadow) with a control, per the anti-assume
   discipline.

### Line protocol (stdin → engine; engine → stdout)

Commands (one per line; engine replies `OK …` / `ERR …` / `EVENT …`):

```
load <bpun-path>                 # backdoor-load a BPUN into RAM
deposit <octal-addr> <octal-val> # backdoor word write
examine <octal-addr>             # -> "VAL <addr> <val>"
watch add <signal-name>          # start sampling a signal into the CSV ring
watch group <MMU|STORE|BUS|MIC>  # add a whole group
watch clear
rule add <name> when "<expr>" do <act[,act…]>   # reactive rule (any signal combo)
rule clear <name|all>            # actions: log[:msg] fst_on fst_off csv event mark:tag stop
set pre <N> / set post <N>       # ring depth / post-window
capture csv <path> | fst <path> | off   # select compact and/or full-fidelity sinks
open <csv-path>                  # where CSV windows are written (alias of capture csv)
run <ticks>                      # step; emits EVENT/LOG lines as rules fire
runto "<expr>" [maxticks]        # run until an expression fires (one-shot rule+stop)
get <signal-name>                # -> "VAL <name> <value>"  (one-shot read)
reset                            # pulse sys_rst_n
quit
```

Engine → stdout event line, e.g.:
`EVENT id=3 trig=store_la:177777 tick=812345 wrote=<csv-path>#rows=256`

### The Python driver — `nd120_probe.py`

Mirrors `nd100x_expect.py`: spawn the engine as a subprocess, unbuffered pipes,
a small API. Stdlib only.

```python
from nd120_probe import Probe
with Probe(bpun="INSTRUCTION-B.BPUN", latches=False) as p:   # FF mode default
    p.load("mmu_setup.bpun")
    p.watch_group("MMU"); p.watch_group("STORE")
    p.set(pre=64, post=64); p.open("mmu_177777.csv")
    p.trigger("store_la:177777")
    ev = p.runto("store_la:177777", maxticks=50_000_000)   # -> Event or None
    print(p.examine(0o177777))          # backdoor verify (control)
```

Methods: `load/deposit/examine/watch/watch_group/trigger/set/open/run/runto/get/
reset`, plus `expect_event(trig, timeout)` and a `wait_console(pattern)` helper if
the UART console driver is enabled (so it can double as a TPE driver, like
`tpe_instruction_nd120.py`).

### Build (WSL only — never a Windows exe)

New Makefile targets in `sim/Makefile`:
```
make probe                 # verilator --vpi --public-flat-rw ... nd120_probe.cpp
make probe USE_LATCHES=0   # FF mode (shipped) — default for investigations
```
Run everything via `wsl.exe -e bash -lc '…'`, `/mnt/e/…` paths.

## First use — the 177777 store-routing question

`examples/mmu_177777_probe.py`: boot/setup a paged store to logical `177777`,
trigger `store_la:177777`, capture `MMU`+`STORE` PRE/POST, then backdoor-examine to
see whether the store routed to shadow (`s_epmap_n`/`s_wmap_n` active) or main. A
CONTROL normal paged store is captured in the same run so a harness failure can
never masquerade as a top-page bug (anti-assume discipline).

## Guardrails
- CPU-BOARD RTL is **report-only** — the probe never edits RTL; `--public-flat-rw`
  and VPI are non-invasive (no source change).
- Keep `test_nd120.cpp` / `latch_ff_compare.cpp` working — the probe is a NEW file.
- WSL-only builds/runs. No LINQ (n/a, C++), keep comments dense.
