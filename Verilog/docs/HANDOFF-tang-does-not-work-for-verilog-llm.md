# HANDOFF: the Tang Nano 20K build does NOT work - please analyse

**To:** the session doing Verilog / Verilator testing
**Date:** 17-JUL-2026
**This file:** `Verilog/docs/HANDOFF-tang-does-not-work-for-verilog-llm.md`

---

## Why you are getting this

There is a belief in circulation that "the Tang code works". **It does not.** The
Tang Nano 20K has **never run instruction validation, by any route** - not from
SD, not over serial. Please treat the FPGA build as unvalidated and help work out
why.

The 13/13 instruction-verify pass is a **runSim / Verilator FF-mode** result
(`Verilog/tests/instruction-verify/CAMPAIGN-STATUS.md`,
13-JUL). Grepping that whole directory for `tang` / `silicon` / `ndcomm` returns
nothing. There is no console capture anywhere in the repo showing
instruction-verify output that came from the Tang.

What Tang silicon HAS proven: the SDRAM controller (standalone), the SD/FAT stack
including 4-bit transfers, and the SD -> tape -> CPU byte path (see "the bytes
arrive" below). Those are subsystems. **They are not a validated CPU.**

`ndcomm` serial deposit: commit `1bf2b7f` says "board deposit works" - that is
**single-word OPCOM deposits**, and `TRACE-CAPTURE-GUIDE.md` confirms those are
logic-analyzer triggers (`deposit 054321`), not program loads. An RTC test is
recorded as having run from a deposit. One timer program. Not a validation
campaign.

**Caveat, stated honestly:** the campaign's deep logs (`verdict2_*` / `verdict3_*`)
were written to a session scratchpad and never committed, so the repo is provably
not a complete record of everything that was ever run. Absence of a capture in
git is not proof a run never happened. But nothing in the repo supports a Tang
instruction-validation run, and the `400$` hang below is hard to reconcile with
one.

---

## MEASURED on the board (Ronny, 17-JUL) - these are observations, not theories

Build: Gowin flow, `FPGA_FF_MODE`, `VARIANT=slow` (CPU/bus 6.75 MHz).
Card: `CONFIGURATIO-C08.BPUN` as `BOOT.BPUN`.

1. **`400$` hangs the CPU hard.** It echoes `400$`, then 60 s of total silence.
   No `?`, no prompt. **ESC does not recover it** - 6 ESCs then CR returned zero
   bytes. Only S1 (Master Clear) recovers.
2. **The bytes DO arrive.** After the hang, S1 (which resets the CPU but
   preserves SDRAM), all 23,244 words were dumped over the console and diffed
   against the card's file:
   ```
   words compared 23244 of 23244 (100.0% of the image)
   21 of 23 1K-blocks: OK
   RESULT: 14 of 23244 words differ  (23,230 correct)
   ```
   The SD -> tape -> CPU path delivered the whole file. **Storage is eliminated
   as the cause of the hang.** The 14 outliers are NOT explained - 12 of 14 are
   addresses where the file holds `000000` and memory holds leftover non-zero
   from an earlier run (S1 does not clear SDRAM). Do not assume they are the
   cause; do not assume they are innocent.
3. **`0!` does NOT start the code - it hangs again.**
4. **`20!` DOES give a prompt/menu** after `400$` + S1.
5. **`HELP` lists only a tiny menu - the test programs are missing.** Ronny:
   "help didnt print the full command list, or at least not the full as we know
   it should". The MONITOR-COMMANDS / PROGRAM-COMMANDS that the
   instruction-verify campaign drives are **not there**. This is the point where
   Tang instruction validation dies: even after a successful load and a `20!`
   start, the program does not present the commands we need.
6. **LEDs during that state: LED5 blinking (the heartbeat), NO other LED on.**
   Ronny reported this explicitly. For reference, the storage bring-up LED set in
   `Verilog/fpga/tang-nano-20k/src/ND120_TANG20K_TOP.v`
   (active low, lit = true):
   - led[5] heartbeat
   - led[4] = sd_status[1], led[3] = sd_status[0]  (both lit = mount OK)
   - led[2] tape byte served
   - led[1] SD clock toggled
   - led[0] CPU asked tape
   **Earlier in the same session, after `400$`, ALL LEDs were on except the
   blinking one.** So the all-dark storage LEDs in observation 6 are a state
   AFTER S1. Whether S1 legitimately clears these latched indicators is
   **UNVERIFIED** - I have not read that logic. It may be nothing. It may mean
   the storage state Ronny is looking at is not the state that did the load.
   Please do not build a story on it without reading the LED source.

### Not the same hang

`0!` hangs and cannot be escaped. The `20!`/HELP hang Ronny CAN escape with
repeated ESC. The `400$` hang needs S1. These may be three different faults or
one. Unknown.

---

## What we would like analysed

The central question: **the identical RTL completes `400$` in Verilator and hangs
on silicon.** Something is true on the board that is not true in sim.

Candidate directions - all **UNVERIFIED**, listed so nobody re-derives them:

1. **The tape-400 level-12 interrupt storm.**
   `Verilog/docs/BUG-tape400-sd-level12-storm.md`.
   `400$` is known to storm level-12 interrupts. In Verilator that only makes the
   sim slow - tests still complete. On silicon a storm could livelock the CPU,
   which would look exactly like this: all the data arrives, the CPU never
   returns. This is a guess. Confirm or kill it.
2. **The HELP-menu shortfall (observation 5) may be the more informative bug.**
   A load can be byte-correct and the program still come up wrong. That points at
   execution, not transfer - which is your territory, and it is reproducible
   without chasing the hang first.
3. **Async SR-latch interrupt logic on Gowin.** RQBIT/PICMASK were the 22
   combinational loops that blocked OSS PnR; they are now loop-free V2
   (`9d5a1cb`). Whether the V2 swap changed silicon behaviour here is untested.
4. **Timing.** Slow bring-up runs CPU/bus at 6.75 MHz against a measured 9.38 MHz
   Fmax, so nominally it has margin - but the known real WNS is a 52 ns / 76-level
   WCS->ACAL path to a CE pin (a multicycle-constraint problem, see
   `Verilog/fpga/tang-nano-20k/README.md`). Not
   ruled out.

**Ownership note:** INSTRUCTION-B's `RUN` belongs to the CPU/interrupt session -
untouched here. CONFIGURATION-C08's `RUN` (a device probe, `make run-config`) is a
different command and is fine.

---

## Reproducing (the console is fussy - follow exactly)

Board attach after every replug. The Tang was **busid 2-3**; the Basys3 is ALSO
`0403:6010` at busid 1-7, so do **not** select by VID:PID:
```
powershell.exe -NoProfile -Command "usbipd attach --wsl --busid 2-3"
sudo chmod 666 /dev/bus/usb/001/006       # bus path CHANGES per attach
sudo chmod 666 /dev/ttyUSB0 /dev/ttyUSB1
```

The **OSS flow (yosys/nextpnr) cannot PnR this design** - use Gowin:
```
cd Verilog/fpga/tang-nano-20k
make gowin VARIANT=slow
make load-gowin            # volatile SRAM - a power cycle wipes it
```

Console `/dev/ttyUSB1` @ 9600 8N1. **Input MUST be paced ~0.3 s/char** or MOPC
silently drops characters - an unpaced `0<77` returns literally nothing. Memory
dump syntax is `n<y` (start, end, octal).

Pristine dump recipe: `400$` (hangs) -> press S1 -> do **NOT** run `20!` (it
scribbles its own scratch into memory) -> dump:
```
cd Verilog/tools
./check_bpun_memory.py --bpun ../runSim/CONFIGURATIO-C08.BPUN --commands
./check_bpun_memory.py --bpun ../runSim/CONFIGURATIO-C08.BPUN --dump cap.log
```

## The sim reference

```
cd Verilog/runSim
make run          # 400$ boots INSTRUCTION-B off a simulated SD card
make run-config   # CONFIGURATIO-C08
make run-fs       # FILSYS-INV-Q04
```
`400$` completes there with **RAM starting empty**. That matters: the harness used
to pre-deposit the BPUN into RAM before every run (its default `DEBUG.BPUN` is
byte-identical to `INSTRUCTION-B.BPUN`), which made **every earlier "boots from
SD" claim worthless**. That pre-deposit is now gated off under `ND120_SD_STORAGE`
(`bff68b5`). `sim/` keeps its pre-deposit ON PURPOSE - there is no tape there, so
it IS the injection method and the latch/FF golden gate.

Ronny has also noted a string test that hangs in Verilator. **Unconfirmed here** -
not reproduced, area not identified. Worth pinning down, since a program-level
fault in sim could be the same fault as the missing HELP menu on silicon.

---

## Things that are NOT bugs - do not re-chase

- **`?` after `400$`** = BPUN checksum error, and the machine was RIGHT: the
  card's file was genuinely corrupt. Fixed. Microcode reference:
  `/mnt/e/Dev/Ronny/nd120uc/source/nd-120-delilah-L-from-K.uc:6212`
  ("ALL WORDS ARE PLACED IN MEMORY" -> read checksum -> `XORAB` -> `ILLEG`).
- **`400$` not auto-starting the program.** All three BPUNs have
  `execute = 000000` = "load only, do not start". `20!` is the intended start.
  This explains a *clean* load returning to the prompt; it does **NOT** explain
  the hard hang, and it does **NOT** explain `0!` hanging.
- **Words 1..15 reading `000001..000017`** - that ramp is the program's real
  content.
- **Contiguity.** `sd_file_reader.v:37` walks the FAT chain; the contiguity rule
  is `nd_storage` v1's own contract via `nd_storage_fatchk`, and Ronny's card
  already passes it.

---

## Full paths

- This handoff:
  `Verilog/docs/HANDOFF-tang-does-not-work-for-verilog-llm.md`
- Storage-side handoff (full detail):
  `Verilog/fpga/tang-nano-20k/HANDOFF-tang-sd-tape-boot.md`
- Status written for the CPU/interrupt session:
  `Verilog/fpga/tang-nano-20k/STATUS-FOR-CPU-LLM.md`
- Level-12 storm bug:
  `Verilog/docs/BUG-tape400-sd-level12-storm.md`
- Instruction-verify campaign (SIM ONLY):
  `Verilog/tests/instruction-verify/CAMPAIGN-STATUS.md`
- Memory-dump comparison tool:
  `Verilog/tools/check_bpun_memory.py`
- Tang board top (LED assignments, clocking):
  `Verilog/fpga/tang-nano-20k/src/ND120_TANG20K_TOP.v`
- Tang build defines:
  `Verilog/fpga/tang-nano-20k/src/tang20k_defines.v`
- Tape SD source:
  `Verilog/ND-BUS-DEVICES/TAPE-400/circuit/nd_tape_sdfat_source.v`
- Tape device:
  `Verilog/ND-BUS-DEVICES/TAPE-400/circuit/ND_TAPE_400.v`
- BPUN format + loader:
  `Verilog/runSim/Run120.cpp`
- Tang README (timing / WNS):
  `Verilog/fpga/tang-nano-20k/README.md`
