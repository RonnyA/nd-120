# Plan - cache (CUP) and the operator panel

**Full path:** `Verilog/docs/PLAN-cache-and-panel.md`
Living plan. Outstanding work only - finished items are deleted, not ticked.
Findings live in [`CACHE-STATUS.md`](CACHE-STATUS.md), not here.

> **Next:** capture PPN25 at the WCLIM_n strobe on the board - what value is
> actually written into the cache-inhibit bit. Bitstream is built; the capture
> has not been run.

---

## 1. Cache - why is nearly every page marked inhibited?

This is the whole cache problem now. Everything else about the cache is
measured and accounted for.

**Where it stands.** `WCINH_n` reads LOW (page inhibited) in ~90% of samples
on the running board. That blocks EWC, which blocks WCA, which is why CUP
never sets and why CACHE-1X0-A00 test 2 reports the cache inert. The inhibit
RAM IS written (69 WCLIM_n strobes in one 1024-sample window), so this is not
uninitialised block RAM.

**Do next, in order:**

1. **Capture PPN25 at WCLIM_n.** `DBG_CACHE[7]` carries the data bit going into
   CHIP_20G. Arm on WCLIM_n low, run CACHE-1X0-A00 test 2, read bit 7.
   - if PPN25 is 0 on every write, the CPU is writing "inhibit" deliberately
     and the question moves to WHY - who sets that bit and from what;
   - if PPN25 is 1 on writes but the bit still reads back inhibited, the RAM
     write or its addressing is broken, and `CPU_MMU_PT_29.v:71`
     (`s_ims_ppn_25_10_in = s_ppn_25_10_in | s_ppn_25_10_out`, the author's own
     "maybe do a conditional expression here") becomes the prime suspect again.
2. **Whichever branch that opens.** Do not pre-plan it - the two paths diverge
   completely and guessing which one costs a build cycle.

**Do NOT re-check these.** Each was measured, not inspected, and re-doing them
has already wasted time once:

| Excluded | Evidence |
|---|---|
| FMISS | 0 in all 1024 samples, twice |
| LSHADOW | 0 throughout |
| BRK_n | high in all but 7 of 1024 |
| CON | tied high, `ND120_CORE.v:1184` |
| PAL_44402D transcription | both WCA product terms + the registered/combinational split checked against `44402D.txt` |
| PAL_44511A / CUP structure | independently confirmed by the 44155A listing (same CUP function under inverted CWR polarity) |
| WCA routing to the CUP PAL | `s_wca_n` driven by CPU_MMU_24, consumed by CPU_PROC_32 - same net |
| "cache RAMs not instantiated" | that block is inside `ifdef ND120_NO_CACHE`; `cache` builds take the `else` branch |
| "WCA never fires" | it does - 24 samples of WCA_n low |

---

## 2. Panel - the ACTIVE LEVEL row

**Measured 29-AUG-2026.** PIL pulses to 12, 13, 14, 15 for **exactly 15 CPU
clocks each** (~1 us), ascending, with ~150 clocks at level 0 between them.
The machine does not RUN at those levels; it touches each briefly. A separate
capture showed a level change is a single clean transition (`0` -> `d`) with no
intermediate codes, so the PIL bus itself is fine.

`term_panel.v:323` loads `s_glow[pil] <= 6'h3F` on every clock and decays one
step per frame over 63 frames (~1 s). So a 1 us blip becomes a lamp lit for a
full second, and the row saturates. **The row converts momentary values into
sustained lamps** - that is the defect.

Three explanations died before this and must not be revived: a PIL
clock-domain transient (the gate was flashed, no change, and the bus is now
measured clean), the frame_tick/decay ratio (tb passes), and "the CPU visits
every level" (wrong - Ronny corrected it; level 15 is never run).

**Blocked on a decision from Ronny** - see section 4.

## 3. Panel - the meters

`rate_meter` uses 8 steps, a 2^24 window and a linear fall. The real MC68705
samples LHIT at 6400 Hz over a 128-tick (20 ms) window in 5 steps with a
halving carry-over decay. Ours is wrong on every axis.

**Not started, and not to be started on the relayed numbers alone.** Decode the
duty-cycle loop in `Code/68705/MC68705U3_35C.BIN` first and confirm them
directly - the current values came from another session's reading, and this
plan has already been burned once by acting on an unverified claim.

## 4. Decisions waiting on Ronny

1. **ACTIVE LEVEL row source.** Rebuild on ACTLV (what a real panel shows,
   correct and permanent, but untestable until the DGA FIFO fix is flashed) vs
   drop the afterglow so PIL shows one lamp at a time (testable tonight, still
   the wrong quantity) vs leave it alone until the DGA fix is in.
2. **Flash the peer's DGA fixes on the Nexys?** They are committed now
   (`1a8c0e1`, `d80ef7f`), so the "wait until they commit" condition is met.
   Unconditional in every build - they change the EPANSN window and the FIFO
   clocking, so the console is the first thing to re-check after flashing.

## 5. Known broken, not blocking

- **`-tclargs ila` is dead at HEAD.** Its probe list still names
  `s_ila_ram_addr`, which does not exist in this configuration, so it exits
  before building a core. `ilacache` and `ilaslim` are unaffected. Fix by
  pruning that list when someone next needs the floppy/IOX probe set.
- **`Verilog/sim` `make test_nd120` fails** with 80 missing-pin warnings
  promoted to errors. Pre-existing - it fails identically at `54f30ca`, before
  any of this work. `DBG_PANEL` and `DBG_CACHE` are both unconnected there.
- **`term_panel.v:554`**: `s_ruler_reversed` is
  `(s_row == 3'd3) && s_in_levels`, and `s_in_levels` already requires
  `s_row == 3'd2`. Always false, so the ruler row never highlights. Cosmetic,
  found while reading; not investigated further.

## 6. Open question on the 44155A listing

Ronny's friend found a PAL 44155A with the same signal set as our 44511A. Its
CUP function matches ours once CWR's inverted polarity is accounted for, which
is useful independent confirmation. To say anything more, two things are
needed and neither is in hand:

- its **pin list** (the line above the equations) - without it the polarity
  convention is unknown, so whether its CWR pin matches ours or is the
  complement cannot be determined;
- its **DESCRIPTION block** - date and board reference, which would say whether
  it is an earlier revision, a different board, or a fix we are missing.

Do not adopt its equations into `PAL_44511A.v`. Its CWR means "no cache write";
ours means "a cache write happened", and ours drives pin 19 declared `/CWR`
which `CPU_MMU_CACHE_25.v:197` consumes as `!s_cwr` for HIT. Mixing halves
inverts HIT silently.

---

## Working rules learned the hard way this session

- **Build from the detached worktree** `E:\Dev\Repos\Ronny\nd-120-build`
  pinned to a commit, never the shared tree. Building the shared tree with
  another session's in-flight work produced a dead-console bitstream once.
- **Launch Vivado via WMI** (`Invoke-CimMethod Win32_Process Create`), not from
  a foreground tool call. A foreground call that hits its timeout returns
  exit 143 and takes Vivado down with it - that killed three builds.
- **Clear `.Xil` after any killed run.** Leftover directories make Chipscope
  fail with "Config Param 'mark_debug' is already registered".
- **Arm and read an ILA in ONE Vivado session.** `hw_ila` properties are
  software-side and re-initialise per batch run, so a second run cannot tell an
  armed core from a never-armed one.
- **Compare ILA status case-insensitively.** Vivado returns `FULL`; comparing
  against `"Full"` reported "never triggered" on a run that had triggered.
