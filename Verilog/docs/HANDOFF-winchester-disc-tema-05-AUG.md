> # SUPERSEDED 24-AUG-2026 - THE MACHINE BOOTS FROM THE WINCHESTER
>
> Section 8's "the machine cannot boot from the Winchester" no longer holds.
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

# HANDOFF — Winchester (ND_WINCHESTER, IOX 500) vs DISC-TEMA J02

Date: 05-AUG-2026. Nothing committed. Nothing in this document is speculation
unless it says so.

---

## 1. Where it stands, in one line

The controller transfers data correctly and every register it exposes now
matches the nd100x C model access-for-access on silicon — and DISC-TEMA still
reports `Memory address Register not as expected`. One real bug was found and
fixed along the way; it was not this one.

---

## 2. The symptom

`TPE > disc > DU-DI-C`, disc `DIS-74-1`, unit 0, cylinder 0, surface 0,
sector 0, amount 1:

```
***ERROR***  DISC-74MB-1 Unit 0
             Hardware Status: 060010b
             Controller finished
             Additional Status: 002000b
             Memory address Register not as expected
             Operation was: Read
**WARNING** Data is unreliable due to the detected error
```

All 512 data words come back **byte-identical to the oracle**, and the
hardware status word `060010` is **identical** too. Only the additional-status
bit is set.

The same program, from a byte-identical floppy image (md5 verified), against
the same 75 MB `WD0-L.img`, run under nd100x, reports **no error at all** —
reference capture saved at `<scratchpad>/oracle_final.txt`.

---

## 3. The bug that WAS found and fixed

`ND_WINCHESTER.v` raised status b3 ("finished with a device operation") on any
control word that did not carry the activate bit. The comment justifying it —
"the controller stays idle and is by definition ready" — is a **premise**, not
a consequence. Both C models may rely on it because their `Wd_ExecuteGO` is
**synchronous**: the operation is always over before the next IOX arrives. The
RTL takes real time, so such a word can land mid-transfer and make the card
report **b2 ACTIVE and b3 FINISHED at the same instant**, which no real card
can do.

Captured on silicon:

```
W+5 034005   GO
R+4 060005   active
W+5 000000   non-activating control word, mid-operation
R+4 060014   ACTIVE *and* FINISHED
```

Fix: `if (!s_active) s_rft <= 1'b1;`

Regression test: `sim/nd_winchester_oracle_tb.v`, `make test-wd-oracle`,
registered in `tests/run_all_tests.sh`. It has teeth — fails on the pre-fix
RTL with the exact silicon word `060014`, passes on the fixed one with
`060004`. Confirmed on hardware.

**`ND_SMD.v:685-686` has the same defect class** (see
`HANDOFF-smd-controller-01-AUG.md`, section added 05-AUG). Not touched — that
file belongs to another session. Floppy-DMA, floppy-PIO and tape were checked
and are clean.

---

## 4. Hypotheses ELIMINATED BY EXPERIMENT — do not re-litigate

Each of these was tested, not argued away.

1. **Memory address register not written back** — it is, `E_MEM_WR` advances
   it per DMA word and `E_DELAY` publishes it.
2. **The register returns the wrong value** — it does not. On silicon it reads
   `R+0 001000` then `R+0 000001` = `0x10000 + 512`, low then high, byte
   identical to the oracle. **The register was never wrong.**
3. **Level-vs-edge IOX strobes** — `ND_BUS_SLAVE.v:109` makes them
   SINGLE-CYCLE. (I "fixed" this and was wrong; see section 6.)
4. **Address-mismatch path skipping `clr_ff`** — activation already calls it
   before that path is reached.
5. **DMA ack granularity** — `ND_DMA_MASTER.v:310` pulses once per single word.
6. **IOX address collision on the OR-bus** — tape decodes `[15:2]`@400, the
   others `[15:3]`@500/1540/1560. No overlap.
7. **A divergent code path** — the full 33-operation oracle replay matches.
8. **The bus adapter** — `test-wd-bus` puts the card behind the real
   `ND_BUS_SLAVE`; one strobe per read, correct halves, correct readback.
9. **Device clear zeroing the registers** — the oracle does exactly the same
   (`deviceWinchester.c:153-157`).
10. **Different DISC-TEMA build or config** — the floppy image is md5-identical
    to the oracle's.
11. **Completion latency** — rebuilt with a 5 us delay instead of 8 ms so the
    first status poll reads FINISHED exactly as the oracle does. Identical
    error. Reverted; negative result recorded at `ND120_CORE.v:365`.

---

## 5. What silicon actually shows

Complete Winchester access history for one `DU-DI-C`, captured with
`TANG_WD_TRACE_DUMP` (the ring did NOT wrap — 55 unwritten entries — so this
is everything since reset):

```
 1 W+5 100000   11 W+7 000000   21 W+5 000000   31 INTERRUPT dropped
 2 R+4 020010   12 W+5 034005   22 W+7 000000   32 R+4 060010
 3 W+5 000000   13 R+4 060005   23 W+3 000000   33 R+0 001000
 4 R+4 020010   14 W+5 000000   24 W+1 000001   34 R+0 000001
 5 W+5 000011   15 R+4 060004   25 W+1 000000   35 W+5 000001
 6 INTERRUPT raised 16 R+4 060010 26 W+7 001000  36 INTERRUPT raised
 7 R+4 020011   17 W+5 000020   27 W+5 000005
 8 W+5 000010   18 W+5 000000   28 R+4 060005
 9 INTERRUPT dropped 19 R+4 060010 29 INTERRUPT raised
10 W+5 000020   20 W+5 000020   30 IDENT answered, code 1
```

Differences from the oracle's 33 operations, and only these:

- the oracle opens with `R+0 000000`; this run does not;
- ops 13/15 read `060005`/`060004` (active) where the oracle reads
  `060011`/`060010` (finished) — a latency difference, and **tested to be
  harmless** (section 4 item 11);
- ops 18 and 21 write `000000` where the oracle writes `000020`.

The transfer itself (23-34) is identical, including the readback.

---

## 6. Traps that cost time — read before starting

- **A testbench that samples `iox_rdata` with a blocking read AFTER the clock
  edge is one delta late.** The real slave latches it AT the edge
  (`ND_BUS_SLAVE.v:151`). Mirror it:
  `always @(posedge clk) if (iox_rd) capture <= iox_rdata;`
  Getting this wrong produced a convincing false failure and a false "fixed".
- **A check placed after a status read proves nothing** — a status read is
  itself a flip-flop reset condition and hides exactly the fault being tested.
- **`uniq` destroys evidence in a trace dump.** Each access appears TWICE (the
  tap pulses for one device clock, which spans two `clk2x` capture cycles), and
  the diagnostic legitimately writes the same control word twice in a row.
  Collapse exact pairs, never `uniq`.
- **Trace trigger:** anchor on an OPERATION COMPLETING plus ~1 s of quiet
  (`wd_trace_done`), NOT on a register access and NOT on quiet alone. The
  card's first access is a read of `+0`, and it sits idle for many seconds
  while DISC-TEMA collects its prompts — both naive triggers fire at the start
  and dump an empty ring.
- **The console needs per-character pacing** (~0.1 s). Writing a whole string
  drops characters and looks exactly like a wedged CPU. Driver:
  `<scratchpad>/ndcon.sh`.
- **The usbipd busid changes after every power cycle** (5-2, 3-2, 3-4 seen in
  one day). Always `usbipd list` first.
- **`TANG_WD_TRACE_DUMP` does not fit with everything else on.** With it the
  build is 95% logic / 98% CLS and routing can grind for 25+ minutes; without
  it, 91%/94% and about ten minutes.

---

## 7. Suggested next step

The register interface is exhausted as a line of enquiry. Before spending more
on satisfying this diagnostic's check, it is worth establishing whether the
Winchester is **usable** — a mass-storage load from it, or SINTRAN reading it.
The data path demonstrably works; this may be a diagnostic nitpick rather than
a functional defect. That is a judgement call for Ronny, not an assumption to
make.

Full suite: 179/179 green (`make test` from `Verilog/`, 502 s).

---

## 8. SECOND DEFECT, found 05-AUG: the machine cannot boot from the Winchester

Separate from the DISC-TEMA complaint, and more consequential.

```
#500&      -> echoes, then nothing. Console dead. CPU hung.
#20500&    -> echoes, then nothing. Console dead. CPU hung.
```

`20500&` is the mass-storage load: the `2` is bit 13 of the device word, not a
digit (`1560 + 020000 = 21560` for the floppy, so `500 + 020000 = 20500`).
Confirmed against `docs/floppy-3112-register-spec-ND-11.021.md`. Both forms
hang, reproduced across several reflashes.

### What the trace says

Captured with `TANG_WD_TRACE_DUMP` (trigger: >=4 accesses then 30 s of quiet,
no arm delay), with a PASSING CONTROL RUN of DISC-TEMA taken on the same
bitstream immediately before, which dumped its full 36-access history:

**The mass-load attempt dumps NOTHING** - fewer than four IOX accesses to the
card. A real mass load needs at least six (block address, memory address twice,
word count, control/GO, status poll).

**So the mass-storage load microcode never meaningfully drives IOX 500.** The
controller is never given the chance to misbehave; the CPU hangs without
talking to it. That is consistent with both command forms hanging identically.

The fault is therefore NOT in ND_WINCHESTER.v. Look at the boot path: whether
the mass-load microroutine reaches the device at all, and whether the device
address decode selects the card for `20500&`.

### Instrument notes, learned the hard way

The capture went through four iterations before it could be trusted. Each of
these produced a confident WRONG answer first:

- **The ~40 s `cap_armed` delay silently discards triggers.** A hang three
  seconds after reset trips the idle window at ~6 s and is thrown away,
  dumping nothing - indistinguishable from "the card was never touched". The
  WD mode now bypasses arming (`s_cap_arm`); the CPU-debug modes keep it.
- **Never compare a saturating counter with `==`.** It matches for one cycle
  and is lost if anything gates that cycle. Use `>=`.
- **The idle threshold must exceed the diagnostic's PROMPT gaps.** DISC-TEMA
  leaves the card quiet for ~15 s while collecting its six answers; a 4 s
  window fired at the "Amount" prompt and dumped only the opening probe. 30 s
  clears it. A hang is permanent, so any threshold works there.
- **ALWAYS run the control first.** Two conclusions in this file were nearly
  drawn from "no dump" while the instrument itself was broken. A DISC-TEMA run
  that dumps its full history is the only proof the capture works.
- **After a reflash the CPU needs ~8 s before it accepts console input.**
  Sending sooner drops characters and looks exactly like a hang.

### REFINED 05-AUG (later): the CPU issues NO IOX AT ALL

The trace was extended to record `Cxxxx` = an IOX to any address that is not
this card's (the card sees the whole bus). Control run first, same bitstream:
a DISC-TEMA session produced **53** such records, all `C0372` (octal 1562, the
floppy DMA) — so the foreign-address path demonstrably works.

The mass-load attempt produces **nothing**: no accesses to 500-507, and no
foreign IOX either.

**So after `20500&` the ND-120 issues no IOX whatsoever and then hangs.** The
mass-storage load never gets as far as touching a device. That puts the fault
in the CPU / MOPC / microcode path, NOT in ND_WINCHESTER.v, and it is a
different workstream.

Supporting reading of the microcode
(`/mnt/e/Dev/Ronny/nd120uc/source/nd-120-delilah-L-from-K.uc:5862`, MASS):
the routine derives every IOX from the typed load code in Q — `DEV.NO + 2 -> D`,
then `D-1` = N+1 core address (twice), `D+1` = N+3 block address, `D+5` = N+7
word count, `D+3` = N+5 activate, `D+2` = N+4 status poll. That is the
Winchester register protocol exactly, which is why this card carries no
boot-mode special case. The bit-13 test that selects the path is
`ALUF,ANDDQ ALUD,NONE` — the result is DISCARDED, so Q retains bit 13 unless
`MASKDQ` at `LOAD1` strips it. **UNVERIFIED**: confirming that needs the ALU
function definitions, which were not consulted. It would explain a hang, but
not the total absence of IOX, so something earlier is stopping first.

Also established:
- **`500&` was never going to work.** That is a BINARY FORMAT load, which needs
  a boot byte-server on the card. `ND_SMD.v` has one (`s_boot_mode`) precisely
  because the microcode's protocol does not match its registers; the Winchester
  deliberately has none. Not a defect — a wrong command for this card.
- **The mass-storage load path is unexercised everywhere.** The SMD's own boot
  gate uses `1540&`, not `21540&`. This matches the standing note that
  `21560&` mass load is "unimplemented both sides".

---

## 9. CLOSED 06-AUG-2026: the fault was the CPU, not this card

The "Memory address Register not as expected" defect this document chases is
FIXED. Root cause: the ND-120 RTL zeroed the A register at the end of every
IOX WRITE (CDLBD 74646 bidirectional-pin transcription flaw in
`Verilog/CPU-BOARD-3202/circuit/BIF_DPATH_9.v`; the IOX microcode's
unconditional `A := DBR` then loaded 0). DISC-TEMA's expected-address
variables are saved FROM A right after each IOX write, so its expectation was
garbage while every wire value stayed correct - consistent with every
elimination in section 4. The unexplained `000000` at ops 18/21 of section
5's trace was the same bug (second write of a back-to-back IOX pair reads
the already-zeroed A). Full analysis and verification:
`Verilog/docs/HANDOFF-winchester-verilator-06-AUG.md` section 10.
