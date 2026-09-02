# Handoff - cache (CUP) and the ACTIVE LEVEL panel row

**Full path:** `Verilog/docs/HANDOFF-cache-and-panel-29AUG.md`
Written 29-AUG-2026, ~02:15, at Ronny's request. Companion to the living plan
[`PLAN-cache-and-panel.md`](PLAN-cache-and-panel.md) and the findings doc
[`CACHE-STATUS.md`](CACHE-STATUS.md).

---

## Read this first: what is NOT fixed

**Neither bug Ronny asked for is fixed.**

1. **The cache is still broken.** CACHE-1X0-A00 test 2 still reports the cache
   inert. What was done is measurement, not repair - the fault is now located
   to one signal, but nothing has been changed to fix it.
2. **The ACTIVE LEVEL row is still wrong.** It still lights the whole row. It
   is DIAGNOSED and the cause is measured, but **no code change was made.** I
   had the diagnosis and put the fix to Ronny as a multiple-choice question
   instead of just making it. That was the wrong call and it is why the row is
   still broken. The edit was being started when the session ended - nothing
   was written, so `term_panel.v` is untouched and still has the 63-frame
   afterglow.

---

## Board and machine state, as left

- Nexys 4 DDR is programmed over JTAG with the bitstream built from **f1ccf52**
  (`ilacache` probe set, cache enabled, VGA console). JTAG programming is
  volatile - a power cycle wipes it and the board comes back on whatever is in
  QSPI.
- The bitstream and its `.ltx` are at
  `E:\Dev\Repos\Ronny\nd-120-build\Verilog\fpga\nexys4ddr\nd120_nexys4ddr.{bit,ltx}`
  (02:01). The `.ltx` is required to name the ILA probes - program with
  `ila_cache.tcl -tclargs program`, not `program_only.tcl`, or the probes come
  back unnamed.
- The machine was left sitting at the CACHE-1X0-A00 `Test number(s) (1 to 8
  dec):` prompt. Ronny took the console over from there.
- Build worktree `E:\Dev\Repos\Ronny\nd-120-build` is detached at **f1ccf52**.
  The main tree is on `mister`.

---

## 1. Cache - the fault is one signal away

### What is measured, on the running board, not inferred

Full test-2 output and the reasoning are in `CACHE-STATUS.md`. The short form:

- The cache is inert in both directions, both halves, paged and unpaged.
- **WCA_n DOES fire** - 24 samples of it low. "Nothing is ever written" was an
  early theory and it is wrong.
- **FMISS is 0** in all 1024 samples, in two separate captures. It had been the
  standing suspect on the strength of its self-hold through `A177` and the
  PAL's own "WCA SHOULD NOT APPEAR WHEN FMISS" note. The mechanism is real; the
  suspicion was wrong.
- **LSHADOW is 0** throughout. **BRK_n** is high in all but 7 of 1024.
- **WCINH_n is LOW - the page marked cache-inhibited - in ~90% of samples.**
  Every sample in which WCA fires has WCINH_n high. So the cache works when the
  page is not inhibited, and nearly every access is marked inhibited.
- **The inhibit RAM IS written** - 69 WCLIM_n strobes in one 1024-sample
  window. "It is just uninitialised block RAM with the CPU never involved" is
  dead.

### The trap in reading that last point

All 69 write samples show `WCINH_n = 0`, which looks like "every write stores
inhibited". **It is not.** `IMS1403_25.v:34` is

```verilog
assign Q = (!CE_n && W_n) ? data_out : 1'b0;
```

so the RAM output is forced low for the whole of a write. That 0 is the model's
own artefact. Excluding the write samples, the stored bit still reads inhibited
in 936 of 955.

### THE NEXT STEP - one capture, not yet run

`DBG_CACHE[7]` now carries **PPN25, the data bit going into CHIP_20G**
(commit f1ccf52, in the flashed bitstream). Arm on WCLIM_n low, run test 2,
read bit 7.

```
cd E:\Dev\Repos\Ronny\nd-120-build\Verilog\fpga\nexys4ddr
# 1. program (only if the board was power-cycled)
vivado -mode batch -source ila_cache.tcl -nojournal -nolog -tclargs program
# 2. console: 1560&  ->  LOAD-PROGRAM  ->  CACHE-1X0-A00
pwsh -File console.ps1 -Baud 115200 -Send "1560&" -Seconds 55
# 3. arm on WCLIM_n low (bit 6), run RUN 2 in parallel, read
#    ila_cache_run.tcl <seconds> <8-bit trigger pattern, MSB first>
vivado -mode batch -source ila_cache_run.tcl -nojournal -nolog -tclargs 90 x0xxxxxx
```

Bit layout of `s_ila_cache`:

```
[0] LSHADOW  [1] FMISS  [2] CYD  [3] BRK_n  [4] WCINH_n  [5] WCA_n
[6] WCLIM_n  [7] PPN25 (the data written into the inhibit bit)
```

**Interpreting the result - the two branches diverge completely:**

- **PPN25 = 0 on every write** -> the CPU is deliberately writing "inhibit".
  The question becomes who sets that bit and from what. Follow PPN25 back:
  `CPU_MMU_PPNX_28` drives PPN25-PPN18 from the IDB (chips 10B/9B/8B).
- **PPN25 = 1 on writes but the bit reads back inhibited** -> the write or its
  addressing is broken. Prime suspect is `CPU_MMU_PT_29.v:71`:
  `assign s_ims_ppn_25_10_in = s_ppn_25_10_in | s_ppn_25_10_out;` carrying the
  original author's own comment *"maybe do a conditional expression here to
  select which PPN"*. ORing the two directions of a bidirectional bus models
  neither. There is a bench for this at
  `CPU-BOARD-3202/circuit/sim/CPU_MMU_PT_29_wcinh_tb.v` (`make test-mmu-wcinh`)
  which asserts only that the address must be one of the two sources and never
  a bitwise mixture. It PASSES today, and its own header says the mixture it
  forces is probably unreachable in the real design - so it is a starting
  point, not evidence.

### Do NOT re-check these

Each was measured, not inspected. Re-doing them has already cost time once.

| Excluded | Evidence |
|---|---|
| FMISS, LSHADOW, BRK_n | see above, two captures |
| CON | tied high, `ND120_CORE.v:1184` |
| PAL_44402D transcription | both WCA product terms and the registered/combinational split checked line by line against `DesignDocuments/PAL-Code/SRC/44402D.txt` |
| PAL_44511A / CUP structure | independently confirmed by the 44155A listing a friend found - its CUP function is identical to ours once CWR's inverted polarity is accounted for |
| WCA routing to the CUP PAL | `s_wca_n` is driven by CPU_MMU_24 and consumed by CPU_PROC_32 - the same net that was measured firing |
| "the cache RAMs are not instantiated" | that block is inside `ifdef ND120_NO_CACHE`; a `cache` build takes the `else` branch with the five real memories. It reads like the bug when skimmed - it is not |

### On the 44155A listing

Same signal set as our 44511A, LEV0 byte-identical. Its CWR means "no cache
write happened"; ours means "a cache write happened" - complements. The CUP
equations use opposite CWR polarity, which cancels, so both listings describe
the same CUP function. Useful independent confirmation.

**Do not lift its equations into `PAL_44511A.v`.** Ours drives pin 19 declared
`/CWR`, which `CPU_MMU_CACHE_25.v:197` consumes as `!s_cwr` for HIT. Adopting
its equations without flipping the pin declaration inverts HIT silently.

Two things are still needed to say more, and neither is in hand: **44155A's pin
list** (fixes the polarity convention) and its **DESCRIPTION block** (date and
board reference - would say whether it is another board's part, an earlier
revision, or a fix we are missing).

---

## 2. ACTIVE LEVEL row - diagnosed, NOT fixed

### The measurement that settles it

Two ILA captures of `s_ila_pil` on the running board, TPE INSTRUCTION test:

- A level change is **one clean transition** (`0` -> `d`), no intermediate
  codes. The PIL bus is fine.
- PIL pulses to **12, 13, 14, 15 for exactly 15 CPU clocks each** (~1 us),
  ascending, with ~150 clocks at level 0 between them:

```
c x15   0 x149   d x15   0 x152   e x15   0 x149   f x15   0 x497
```

The machine does not RUN at those levels - it touches each for about a
microsecond. (Ronny is right that level 15 is never used as a running level;
PIL nonetheless reads 15 in these pulses.)

### The defect

`term_panel.v:323` loads `s_glow[pil] <= 6'h3F` **every clock**, and decays one
step per frame over 63 frames (~1 s at 60 Hz). So a 1 us blip becomes a lamp
lit for a full second. **The row converts momentary values into sustained
lamps** and saturates.

The 63-frame value is mine (commit `e33a785`). The previous value was 15 frames
(~250 ms), which had the same defect four times less visibly.

### The fix that was being made when the session ended

Replace the afterglow with **per-frame occupancy**: accumulate a one-hot of
every level seen during the frame being drawn, latch it at `frame_tick`, and
start the next frame fresh. Sketch:

```verilog
reg [15:0] s_seen;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n)          s_seen <= 16'd0;
  else if (frame_tick) s_seen <= (16'd1 << pil);   // new frame, seed with current
  else                 s_seen <= s_seen | (16'd1 << pil);
end
// r_lamp <= s_seen;  at frame_tick, replacing r_lamp <= s_lamp_now
```

That drops the smear from ~1 s to one frame (~16 ms) and removes `s_glow`
entirely. It is honest - a lamp means "this level was used in the frame you are
looking at". It will still show several lamps when the CPU really does touch
several levels inside one frame, because that is true.

**`Terminals/sim/term_panel_tb.v` check 7 tests the reload/decay ratio and will
fail** - it has to be rewritten for the new behaviour, not deleted.

### Three dead theories - do not revive them

1. **PIL clock-domain transient.** A 3-flop + 8-sample stability gate was
   written, flashed, and changed nothing; the bus is now measured clean.
   (The gate is still in `terminal_top.v`. It is harmless but it fixes nothing.)
2. **frame_tick / decay ratio.** The testbench was rebuilt with a real
   per-frame tick and passes.
3. **"the CPU visits every level within a second."** Wrong - Ronny rejected it
   and the capture confirms he was right. The levels are touched for
   microseconds, not run.

### The deeper issue, separate from the above

A real MC68705 panel's ACTIVE LEVEL row shows **ACTLV** - which levels are
*active* - sent by the microcode as `LDPANC 0x0A` plus two bytes. It is state,
not a sampled instantaneous bus. Our row shows PIL, which has no counterpart on
the real machine. The per-frame fix above makes the row much less wrong; only
ACTLV makes it right.

That became feasible during this session: the other agent's commits `1a8c0e1`
and `d80ef7f` fixed the panel path so panel commands actually reach the FIFO -
before them **no panel command of any kind ever left the CPU in the
recreation**, including the microcode's own ACTLV traffic. Wiring a
latched-ACTLV lamp row is now possible and is the correct end state.

---

## 3. Panel meters - not started

`rate_meter` uses 8 steps, a 2^24 window, linear fall. The real 68705 samples
LHIT at 6400 Hz over a 128-tick (20 ms) window in 5 steps with a halving
carry-over decay. Ours is wrong on every axis.

**Do not act on those numbers as given** - they came from another session's
reading, not from the firmware. Decode the duty-cycle loop in
`Code/68705/MC68705U3_35C.BIN` and confirm them first. This plan was burned
once already by acting on an unverified relayed claim.

---

## 4. Known broken, found on the way, not blocking

- **`-tclargs ila` is dead at HEAD.** Its probe list still names
  `s_ila_ram_addr`, which does not exist in this configuration, so it exits
  before building a debug core. This killed one build before `ilacache` was
  added as a separate flag. `ilacache` and `ilaslim` are unaffected.
- **`Verilog/sim` `make test_nd120` fails** - 80 missing-pin warnings promoted
  to errors. **Pre-existing**: it fails identically at `54f30ca`, before any of
  this work. `DBG_PANEL` is unconnected in `ND120_TOP.v` and `DBG_CACHE` now is
  too, matching it.
- **`term_panel.v:554`**: `s_ruler_reversed = (s_row == 3'd3) && s_in_levels`,
  and `s_in_levels` already requires `s_row == 3'd2`. Always false - the ruler
  row never highlights. Cosmetic, found while reading, not investigated.

---

## 5. Tooling rules that cost build cycles to learn

- **Build from the detached worktree** `E:\Dev\Repos\Ronny\nd-120-build`
  pinned to a commit. Building the shared tree with another session's in-flight
  work produced a bitstream with a dead OPCOM console.
- **Launch Vivado via WMI**, not from a foreground tool call:
  `Invoke-CimMethod -ClassName Win32_Process -MethodName Create`. A foreground
  call that hits its timeout returns exit 143 and takes Vivado down with it.
  That silently killed three builds mid-synthesis with no error in the log.
- **Clear `.Xil` after any killed run.** Leftovers make Chipscope fail with
  `Config Param 'mark_debug' is already registered` / `Failed to load feature
  'core'`.
- **Arm and read an ILA in ONE Vivado session.** `hw_ila` properties are
  software-side and re-initialise per batch run, so a second run cannot tell an
  armed core from a never-armed one.
- **Compare ILA status case-insensitively.** Vivado returns `FULL`; comparing
  against `"Full"` reported "never triggered" on a run that HAD triggered - a
  false negative that would have become a false finding.
- **`CONTROL.TRIGGER_MODE` is read-only** in this Vivado (advanced trigger not
  supported); setting it aborts the script.

---

## 6. Commits from this session

```
f1ccf52  probe(cache): add the inhibit-RAM data bit to DBG_CACHE bit 7
8db99c0  probe(cache): add WCLIM_n to DBG_CACHE bit 6
7c35d16  probe(cache): measured on the board - FMISS is innocent, WCINH_n is not
df633f8  probe(cache): ILA session script for the cache-write question
425c5cf  build(nexys): write the .ltx for ilacache too
891a534  build(nexys): -tclargs ilacache, a probe set for the cache-write question
cef7b5f  docs(cache): the whole of test 2, measured on the board
1a3463b  probe(cache): bring the six WCA gating signals out to the ILA
9c98fd0  test(cmddec34): IDB2 is not dead, the random sweep just cannot reach it
d8ec959  console(banner): two lines after reset, not ten
9014a41  docs: living plan for the cache and panel work
```

`d8ec959` and `9c98fd0` are the only two things in this list that actually
FIXED something Ronny asked for (the reset banner, and a red test). Everything
else is probes, scripts and documentation.

---

## 7. Decisions outstanding

1. **ACTIVE LEVEL row.** Land the per-frame fix above now (small, testable
   immediately, makes the row much less wrong), or go straight to a
   latched-ACTLV row (correct, larger, now possible thanks to `1a8c0e1` /
   `d80ef7f`). These are not exclusive - the per-frame fix is a reasonable
   staging post.
2. **Flash the peer's DGA fixes on the Nexys.** Committed, so the "wait until
   they commit" condition Ronny set is met. They are unconditional in every
   build and change the EPANSN window and FIFO clocking, so **verify the OPCOM
   console first** after flashing.
