> # SUPERSEDED 24-AUG-2026 - THE MACHINE BOOTS FROM THE WINCHESTER
>
> Section 9's "the machine cannot boot from the Winchester" no longer holds.
> `20500&` boots SINTRAN III on the Tang Nano 20K and reaches the banner in
> 29.4 s. The suspicion recorded below that the fault was "in the mass-load
> microcode path" was WRONG: the actual defect was the memory bank being decoded
> from the wrong side of the bus transceiver (`ND3202D.v:533`), so every incoming
> DMA write landed in BANK0 and the CPU read a page nothing had written.
> Guarded since by `make test-bdbank`.
>
> The DISC-TEMA `Memory address Register not as expected` complaint is a separate
> matter and is NOT closed by this. Everything else below is kept as the record
> of the investigation.
> See `HISTORY.md` and `Verilog/fpga/tang-nano-20k/README.md`.

# HANDOFF — Winchester (ND_WINCHESTER, IOX 500) in Verilator

Date: 06-AUG-2026. **Nothing is committed.** Paths are relative to the repo
root. Nothing below is speculation unless it says so.

---

## 1. State in one paragraph

The Winchester had **never been run in Verilator against the real CPU** — it
went from iverilog unit benches straight to the Tang. It now runs: TPE Monitor
B01 boots with the card instantiated, DISC-TEMA J02 loads, `DU-DI-C` transfers
512 words off the disc image, and the dump shows real data. The transfer
sequence matches the silicon trace operation-for-operation. DISC-TEMA still
reports `Memory address Register not as expected` — **the same complaint it
makes on the Tang, and still unexplained.** That defect is untouched; the only
thing that changed is that it can now be reproduced somewhere with waveforms.

The one bug fixed on this hunt (05-AUG, confirmed on silicon) was a different
one: `ND_WINCHESTER.v` asserted status b3 FINISHED on any non-activating
control word, so such a word arriving mid-transfer made the card report b2
ACTIVE and b3 FINISHED simultaneously. Regression: `make test-wd-oracle`.

---

## 2. Why it had never run in Verilator

Two independent gaps, both now closed:

- `WINCHESTER/circuit` was missing from `BUSDEV_COMPONENTS` in **both**
  `Verilog/sim/Makefile` and `Verilog/runSim/Makefile`, so Verilator could not
  find `ND_WINCHESTER` at all. `ND120_TOP.v` had carried the
  `-DND120_INCLUDE_WD` switch unused since the card was written.
- `Verilog/simDevices/NDBus.cpp` had a disc backend for the SMD seam
  (`process_verilog_smd`) and **none for the Winchester**, so `WDISK_DONE` sat
  tied low and no transfer could complete even with the card instantiated.

**Generalisation worth keeping:** a device with a green unit bench and no entry
in `BUSDEV_COMPONENTS` has never met the CPU. Check that list before believing
any "it works".

---

## 3. How to reproduce (~50 minutes)

```
cd Verilog/sim
make probe-wd USE_LATCHES=0 EXTRA_WD_DEFINES=-DND120_DEV_DELAY_TICKS=216000

cd ../ND-BUS-DEVICES/WINCHESTER/sim
ND120_WD_IMG=<your 75 MB Winchester image> \
ND120_WD_TRACE_FILE=wd_trace.log \
python3 wd_disctema.py disctema_console.log
```

The driver is `Verilog/ND-BUS-DEVICES/WINCHESTER/sim/wd_disctema.py`. It boots
`1560&`, then types `disc`, `DU-DI-C`, `DIS-74-1`, unit/cyl/surface/sector 0,
amount 1 — the exact sequence from the oracle capture.

### Both build flags are MANDATORY

- **`USE_LATCHES=0`.** `Verilog/sim/Makefile` has `USE_LATCHES ?= 1` and only
  adds `FPGA_FF_MODE` when it is not 1, so the **default build is latch mode**,
  which never floppy-boots. The comment above the probe targets claiming "FF
  mode default (USE_LATCHES=0)" is **wrong** and should be fixed. Symptom:
  prompt appears, `1560&` echoes, then silence forever.
- **`ND120_DEV_DELAY_TICKS=216000`.** Without it DISC-TEMA dies with `Software
  Timeout` before it ever programs the transfer — no START/REQ reaches the
  backend and the dump reads back all zeros. Cause in section 5.

---

## 4. What the sim run produces

Winchester access history from `ND120_WD_TRACE_FILE`, transfer phase:

```
W+5 000020 / W+5 000000     (twice)
W+7 000000
W+3 000000                  block address
W+1 000001                  memory address hi
W+1 000000                  memory address lo
W+7 001000                  word count = 512
W+5 000005                  GO
START blk2=000000 blk1=000000 unit=0 pos=0
REQ wr=0 words=512 pos=0
READ DONE 512 words, next pos=1024
IDENT level=11
R+0 / R+0 001000            two-part memory-address readback
W+5 000001
```

This is silicon ops 22–35 from `Verilog/docs/HANDOFF-winchester-disc-tema-05-AUG.md`
section 5, operation-for-operation, including the readback.

Console verdict, identical to the Tang:

```
***ERROR***  DISC-74MB-1 Unit 0
             Hardware Status: 060010b
             Controller finished
             Additional Status: 002000b
             Memory address Register not as expected
```

---

## 5. The delay trap (harness artifact, NOT an RTL bug)

`ND120_CORE.v` computes

```
SMD_DELAY_TICKS = (DEV_CLK_HZ / 1000) * SMD_DELAY_MS      // 8 ms
```

`DEV_CLK_HZ` is `BOARD_CLK_FREQ` where defined and **100 MHz otherwise**. The
Tang defines 27 MHz. So the same 8 ms becomes **216,000 cycles on silicon and
800,000 in Verilator**. The CPU executes per cycle, so the sim hands
DISC-TEMA's status-wait loop 3.7x more iterations before the card completes,
and its software timeout fires.

`ND120_DEV_DELAY_TICKS` was added to override the cycle count directly. It is a
**diagnostic lever, left undefined by default** — it changes what the drive
models.

**Open design question for Ronny, deliberately not decided here:** whether a
wall-clock 8 ms is the right thing to model when the sim clock is a nominal
fallback. Every clock variant gets a different cycle count from it.

Note: the `TESTED AND EXONERATED 05-AUG` comment on this delay in
`ND120_CORE.v` refers to the **MAR symptom on silicon**, a different failure.
It does not cover the sim timeout, and it nearly caused the suspect to be
skipped.

---

## 6. Instrument notes

`Verilog/simDevices/NDBus.cpp` now logs, all to `ND120_WD_TRACE_FILE`:

- whether the disc image opened,
- every IOX aimed at 500–507, with register and data,
- every IDENT, with the level and what the C `DeviceManager` answered,
- every disc-side START / REQ / READ DONE.

**The trace must go to a file.** `printf` goes to stdout, which carries the
probe engine's machine-readable line protocol; trace lines there are parsed as
junk and silently dropped.

**Two limits of that log, so it is not misread:**

- the logged `data` on a **read** is the CPU's outgoing word, **not** the
  card's answer — read values are not the card's status;
- `c_model_code=0` on IDENT means only that the C model did not answer. The
  Verilog card answers on the internal bus and never appears in this log.

**The console echoes input.** A pattern equal to a typed command matches the
echo and reports a false success — this produced one wrong conclusion. Match
on text only the machine can produce, or check that the console actually grew.

**The probe engine wants the literal two characters `\r`, not a CR byte**
(`nd120_probe.cpp`, the `send` command). A real CR makes every command echo and
never execute. `1560&` masks this completely, because MOPC acts on the `&`
itself and needs no CR — so the one input that appeared to prove the console
worked was the one case that could not detect the fault.

---

## 7. The open defect

`Memory address Register not as expected`, additional status `002000b`, on both
silicon and sim. Everything the card exposes matches the nd100x C model
access-for-access, and the register the diagnostic names reads back correctly
(`R+0 001000` then `R+0 000001` = 0x10000 + 512).

Eleven hypotheses were eliminated by experiment on silicon — listed in
`Verilog/docs/HANDOFF-winchester-disc-tema-05-AUG.md` section 4. **Do not
re-litigate them from scratch;** read that list first.

What is newly possible and has **not** been done: watching the card's internal
memory-address register and the DMA address in a waveform across the transfer,
and comparing against what DISC-TEMA expects. The engine is built with
`--public-flat-rw` and `--vpi`, so internal signals are reachable by name at
runtime through the probe.

**Image caveat:** the sim was run against `WD0-M`; the oracle capture in the
05-AUG handoff used `WD0-L`. The dumps differ by a two-word offset with several
values off by one, which is consistent with different images and is **not**
evidence of a transfer fault. Get both sides on the same image before reading
anything into a data comparison.

---

## 8. Files changed, all uncommitted

- `Verilog/simDevices/NDBus.cpp` — new `process_verilog_wd()` disc backend for
  the Winchester seam (Micropolis 1325 geometry: 8 heads, 9 sectors, 1024-byte
  sectors, oracle CHS→LBA mapping), plus the IOX/IDENT/disc trace. Called from
  the same tick site as the SMD backend, so `runSim/Run120.cpp` and
  `sim/nd120_probe.cpp` are untouched.
- `Verilog/simDevices/NDBus.h` — declaration.
- `Verilog/sim/Makefile` — new `probe-wd` target with its own
  `obj_dir_probe_wd`, plus the `EXTRA_WD_DEFINES` pass-through.
- `Verilog/ND120_CORE.v` — `ND120_DEV_DELAY_TICKS` override, undefined by
  default.
- `Verilog/ND-BUS-DEVICES/WINCHESTER/sim/wd_disctema.py` — the driver.

Nothing in the FPGA build path changed; the Tang is unaffected.

---

## 9. Also open, from the 05-AUG work

- **The machine cannot boot from the Winchester.** `500&` and `20500&` both
  hang, and a trace with a passing control run proved the CPU issues **no IOX
  at all** after `20500&`. The fault is in the mass-load microcode path, not in
  `ND_WINCHESTER.v`. See `Verilog/docs/HANDOFF-winchester-disc-tema-05-AUG.md`
  section 8.
- **`ND_SMD.v` lines 685-686 carry the same defect class** as the
  ACTIVE+FINISHED bug fixed in the Winchester — status asserted as a premise
  rather than earned. That file is owned by another session and was reported,
  not modified.

---

## 10. CLOSED 06-AUG-2026 (evening): root cause found and fixed - it was the CPU

The open defect of section 7 is RESOLVED. The fault was never in
`ND_WINCHESTER.v`, the bus slave, or DISC-TEMA's expectations:

**The ND-120 RTL zeroed the A register at the end of every IOX WRITE.**

- The IOX microcode's final microword is `A := DBR` for BOTH directions
  (microcode listing, IOXG/IOXX1 routine: `B,A ALUF,PASSD ALUD,B IDBS,DBR`).
  On real silicon this is a harmless self-write on outputs, because the BIF
  echoes the outgoing data back over CD during the EMD window: the CDLBD
  74646 captures the write data at the DSTB_n rise (PALASM 44302B: "DSTB TO
  SAMPLE DATA AT LBD/CD BUFFERS", "DSTB MUST NOT CLOCK DATA BEFORE CACT GOES
  OFF IN IOXES") and drives it back onto CD for the DBR.
- In the RTL the CDLBD's bidirectional LBD pin had been transcribed as
  separate in/out nets, and the chip's own output was NOT part of its own
  input, so the DSTB capture read a dead bus, the echo delivered 0, and the
  DBR (hence A) got 0 after every IOX write - in latch mode AND FF mode,
  since the first transcription.
- DISC-TEMA saves A after each IOX write to build its expected memory
  address (`IOX 501; STA`, `IOX 507; STA`, `IOX 505; STA` - file offsets
  100642-100654 of DISC-TEMA-J02:TEST). All three saves stored 0, its
  expected value was garbage, and its additional-status bit 10 ("Memory
  address Register not as expected") fired even though every register value
  on the wire was correct - which is exactly why sections 4-5's access-level
  comparisons could never find a difference.

**Fix:** one OR-term in `Verilog/CPU-BOARD-3202/circuit/BIF_DPATH_9.v` -
`s_cdlbd_lbd_15_0_in` now includes `s_cdlbd_lbd_15_0_out`, restoring the
single bidirectional pin node of the drawing. No new signals.

**Verified 06-AUG-2026:**
- 4-instruction repro (`SAA 20; IOX 505; STA`): A survives (`000020`).
- Back-to-back `IOX 505; IOX 505`: both writes carry the value (was
  `value, 0` - the section-5 silicon trace's unexplained ops 18/21).
- IOX reads unchanged (status read returns device data).
- DISC-TEMA `DU-DI-C`: ZERO errors on the Tang (hand-verified) and in the
  Verilator run, same RTL.

The repro driver and captures live in the 06-AUG session's scratchpad; the
minimal repro is: deposit `170420 164505 004003 124000` at 1000, run `1000!`,
examine 1005 - `000020` = fixed, `000000` = broken.
