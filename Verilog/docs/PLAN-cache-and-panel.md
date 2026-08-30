# Plan - cache (CUP) and the operator panel

**Full path:** `Verilog/docs/PLAN-cache-and-panel.md`
Living plan. Outstanding work only - finished items are deleted, not ticked.
Findings live in [`CACHE-STATUS.md`](CACHE-STATUS.md), not here.

> **Next:** TEST 3 ("Inhibit limits") - the one remaining CACHE-1X0-A00
> failure, now known to be BOARD-SPECIFIC: it PASSES in Verilator (run 26,
> 30-AUG 04:3x, "- End of test -") and hangs identically on the Nexys at
> 45.45 MHz (builds 4 and 7: "hanging on level: 0D - P=124563B"). So the
> route is the board, not more sim tracing: an ILA on the inhibit-limit
> path (TRR LCIL/UCIL, inhibit RAM - DBG_CACHE bit 7), or a slower-clock
> build to see if the hang follows frequency. Test 1 is FIXED and proven on
> BOTH board (0 error lines, was 20062) and sim (End of test, 0 errors);
> tests 2,4-8 clean on board. Unit registry: ALL 342 TESTS PASSED end to
> end (30-AUG, three stale-test blockers cleared - see CACHE-STATUS).
>
> DONE 30-AUG 06:2x: Nexys build 8 (cache fix + MIPS panel + VT100
> terminal, commits 1c02698/e26f44b + the uncommitted cache/DGA set) is
> FLASHED and VALIDATED - WNS +0.211 ns clean, RUN 1-8 executed by the
> build agent over the console: 1,2,4-8 "- End of test -", 0 error lines
> in the whole run; test 3 the identical board-specific hang. The board
> shows the VT100 terminal and the MIPS field. Remaining MIPS item:
> validate the FETCH count against a known instruction loop (section 7
> step 1) before trusting the displayed number.
>
> MIPS counter: IMPLEMENTED 30-AUG-2026 (Ronny asked twice on the night) -
> `Terminals/rtl/mips_counter.v` counts board FETCH (ND3202D DEBUG_FETCH)
> rising edges, publishes XX.XX BCD once a second, panel field at row 2 col
> 63 ("MIPS" label col 58), plumbed nexys top -> terminal_top -> term_panel,
> MiSTer tied 0. Testbenches green: mips_counter_tb (window arithmetic, idle
> clear, saturation - registered in run_all_tests.sh), term_panel_tb MIPS
> layer, MiSTer console tb. OUTSTANDING: (a) a Nexys build+flash to put it
> on the board - needs Ronny's go, board is in use, and build 7 showed this
> clock needs the physopt flag; (b) validate the FETCH count against a known
> instruction loop before trusting the number (plan section 7 step 1).
>
> Then, in order: rate meters (section 3), SINTRAN boot on the Nexys with
> the cache live.
>
> Build 7 timing note: the DGA RWCS-gate change costs real margin at clk=16 -
> plain args FAILED timing (WNS -0.134), the physopt retry closed at +0.137.
> Every future Nexys build should pass the physopt flag.

Findings and evidence: `CACHE-STATUS.md`. Faults 1 (CUP), 2 (44511A CWR
> pin), the Am9150 dropped write and the EPANS data-window leak are all
> fixed and board-confirmed; finished detail lives in the status doc, not
> here.

---

## 1. Cache - fault 2

Fault 1 is fixed (29-AUG-2026, see `CACHE-STATUS.md`): `PAL_44511A_EN.v` /
`PAL_44511A.v` now hold CWR as the level latch the listing describes, so CUP
sets on a cache write. Verified: PAL suite green, CACHE-1X0-A00 test 2 in
Verilator no longer reports "CUP does not work".

**Where it stands.** With CUP alive, test 2 still reports that hits return
memory data, reads do not fill the cache, and the instruction and data halves
are mixed up; the run then crashes with an illegal instruction at 177006B.

**Do next, in order:**

1. **Read the write-then-read capture.** Build and run as below with
   `ND120_CACHE_WIN="8:1500"` (from the 8th WCA on, 1500 evals: the boot has
   4-5 writes, the test's first ones come next). Per eval it prints CA, PPN,
   the tag and data the cache RAMs read back, the used bits, both HIT
   comparators, WCA/CWR/CUP and the CD bus into MMU and CPU. Look for: does the
   tag written on WCA equal the PPN read back on the next access to the same
   CA; does HIT assert on that access; does `cd_cpu` carry the cache word or
   the memory word; does the used bit set.
2. **Two RTL facts to check against the capture** (not measured yet): the
   TMM2018D model reads synchronously (`data_out_reg` one sysclk after the
   address), and `CPU_MMU_CACHE_25.v` gates the cache's CD output with HIT
   (26-JUL banner fix). A HIT decided one sysclk late, or on a stale tag,
   returns memory data and reads as "taken FROM MEMORY".
3. **Then the board.** Once test 2 passes in the sim, build the Nexys `cache`
   bitstream from the fixed tree and re-run CACHE-1X0-A00 there. The board
   captures so far are consistent with everything measured in the sim (an
   all-inhibited map after power-up / a `0:37777` sweep) and add nothing on
   their own.

**How to run the diagnostic in the sim** (what finally worked, 29-AUG-2026):

```
cd Verilog/runSim
make compile VERILOG_TAPE=0 SD_STORAGE=0 DEVICECORE=1 DEVICECORE_FLOPPY=1      USE_LATCHES=0 EXTRA_VDEFINES="-DND120_SIM_RAM_64K"      SDFAT_SUPPRESS="-Wno-PINMISSING -Wno-IMPLICIT -Wno-DECLFILENAME -Wno-BLKSEQ -Wno-TIMESCALEMOD"
mkfifo /tmp/nd_in; sleep 100000 > /tmp/nd_in &
ND120_FLOPPYCORE_IMG=FLOPPY1.IMG ND120_CACHE_TRACE=1 ./obj_dir/VND120_TOP < /tmp/nd_in > out.log &
printf '1560&' > /tmp/nd_in                       # wait for TPE>
printf 'LOAD-PROGRAM CACHE-1X0-A00
' > /tmp/nd_in  # wait for the 2nd TPE>
printf 'RUN 2
' > /tmp/nd_in                      # NO answer needed at "Initialize memory : >"
```

`Initialize memory : >` is NOT a prompt - it is TPE initialising all memory
before the run, one `>` per bank, and it takes ~600M sim cycles (~35 min)
regardless of the sim RAM size. Anything typed there lands on TPE afterwards
as a command. The program never echoes. `-Wno-PINMISSING -Wno-IMPLICIT` are
needed because the `run-tpe` flag set trips on the newer `DBG_*` ports.
`--public-flat-rw` is NOT needed and makes the sim ~4x slower.

**Do NOT re-check these.** Each was measured, not inspected:

| Excluded | Evidence |
|---|---|
| inhibit-map addressing / data / write strobe | full sweeps measured in the sim, map counted after each: power-up = all inhibited; `TRR LCIL/UCIL 100:200` = exactly 65 inhibited |
| the WCHIM -> WCLIM gate | WCLIM_n strobes once per swept page at cycle state d (`ND120_CYC_WINDOW`) |
| CUP PAL set path | fixed; CUP now sets on every WCA (`ND120_CACHE_TRACE`) |
| FMISS | 0 in all 1024 board samples, twice |
| LSHADOW | 0 throughout |
| BRK_n | high in all but 7 of 1024 |
| CON | tied high, `ND120_CORE.v:1184` |
| PAL_44402D transcription | both WCA product terms + the registered/combinational split checked against `44402D.txt` |
| WCA routing to the CUP PAL | `s_wca_n` driven by CPU_MMU_24, consumed by CPU_PROC_32 - same net |
| "cache RAMs not instantiated" | that block is inside `ifdef ND120_NO_CACHE`; `cache` builds take the `else` branch |

**Probe trap, written down so nobody loses another hour to it:** the probe
block in `runSim/Run120.cpp` runs once per sysclk period with
`top->sysclk == 1`. A probe gated on `top->sysclk == 0` never fires and reads
as "this never happens".

---

## 3. Panel - the meters

`rate_meter` uses 8 steps, a 2^24 window and a linear fall. The real MC68705
samples LHIT at 6400 Hz over a 128-tick (20 ms) window in 5 steps with a
halving carry-over decay. Ours is wrong on every axis.

**Not started, and not to be started on the relayed numbers alone.** Decode the
duty-cycle loop in `Code/68705/MC68705U3_35C.BIN` first and confirm them
directly - the current values came from another session's reading, and this
plan has already been burned once by acting on an unverified claim.

## 4. Decisions waiting on Ronny

1. **Flash the peer's DGA fixes on the Nexys?** They are committed now
   (`1a8c0e1`, `d80ef7f`), so the "wait until they commit" condition is met.
   Unconditional in every build - they change the EPANSN window and the FIFO
   clocking, so the console is the first thing to re-check after flashing.
2. **ACTIVE LEVEL row - now driven by ACTLV, needs a Nexys build.** Ronny
   said it plainly (29-AUG-2026 evening): the row was still wrong on the board
   with the per-frame change. It had to be: the ILA shows the CGA's level bus
   stepping through 12..15 every few hundred clocks, so any view of PIL lights
   the row. The real panel never looks at PIL - the microcode sends the
   68705 the ACTIVE LEVEL word (LDPANC 0x0A + two bytes, low byte first,
   measured with ND120_PANEL_CLOCK_TRACE) and the 68705 shows that. Wired
   29-AUG-2026: `PANCAL_68705_CLOCK.v` captures the word (output `ACTLV`),
   it travels `IO_PANCAL_40 -> IO_37 -> ND3202D -> ND120_CORE -> Nexys top ->
   terminal_top -> term_panel` as `PANEL_ACTLV` / `panel_actlv` / `actlv`,
   and `term_panel.v` shows it (latched per frame) as soon as the first word
   has arrived; the PIL view is only the fallback for builds without the
   panel processor (MiSTer ties it to 0). Terminal lint clean, panel tb
   green. NOT YET ON THE BOARD - the next Nexys build carries it (the panel
   clock is a default there now, so ACTLV is live).

## 4b. ACTIVE LEVEL row - hold time (done in RTL, not yet on the board)

Ronny, 29-AUG-2026 late: the all-16-lit bug is fixed on the Nexys, but the
row "flickers like stupid when there is a lot of changes". The row sampled
ACTLV once per frame tick and showed it for one frame (16 ms). Now
(`term_panel.v`, `ACTLV_HOLD_FRAMES = 2`): ACTLV is OR-ed over the whole
frame and every lamp stays lit 2 frames (33 ms) from the frame it was last
seen in - his "double it". Panel tb has a check for it (check 9), terminal
lint clean. If it still flickers, raise `ACTLV_HOLD_FRAMES` (3 bits, up to 7
frames = 117 ms) - one line, no other change. Goes out with Nexys build 3.

Also reported by Ronny in the same message: the CACHE HIT RATE bar "is
showing signs of working" on the board.

## 7. Panel - MIPS counter (queued, not started)

Ronny wants a MIPS figure on the panel, right after the FLOPPY lamps:
million macro instructions per second, updating itself while the machine
runs. Not started. What it needs, in order:

1. **Count the FETCH signal** (Ronny, 29-AUG-2026: "you can probably count
   when there is a FETCH signal", and "don't change the original design, we
   have signals enough"). `CFETCH` already exists as an input of
   `DELILAH-CPU/CGA_MIC/circuit/CGA_MIC.v:27` - tap it where it is driven,
   outside the gate array; add NOTHING inside the CGA/DGA. Count its rising
   edges over a known TPE loop and check the number against the instruction
   count of that loop before trusting it.
2. **A counter with a 1-second window** in the CPU clock domain (the board
   clock is known per build - 45.45 MHz Nexys, 20.25 MHz Tang - so a 1 s
   window is a fixed count), latched into a per-second result and synced to
   the video clock like `panel_actlv` is (2-flop, it is a slow-changing word).
3. **Rendering**: a `XX.XX` field after FLOPPY in `term_panel.v`. Ronny's
   sizing note: the ND-120 does under 1 MIPS at 6.75 MHz, but the Nexys runs
   at 45 MHz, i.e. up to ~7 MIPS, so leave TWO integer digits (up to 99.99).
   Hundredths of a MIPS = per-second count / 10^4.
4. Per-frame latch like every other field, a tb check that a known pulse
   rate gives the expected digits, and the same plumbing as ACTLV
   (`IO_37 -> ND3202D -> ND120_CORE -> Nexys top -> terminal_top`, MiSTer
   tied to 0).

## 5. Known broken, not blocking

- **`-tclargs ila` is dead at HEAD.** Its probe list still names
  `s_ila_ram_addr`, which does not exist in this configuration, so it exits
  before building a core. `ilacache` and `ilaslim` are unaffected. Fix by
  pruning that list when someone next needs the floppy/IOX probe set.
- **`Verilog/sim` `make test_nd120` fails** with 80 missing-pin warnings
  promoted to errors. Pre-existing - it fails identically at `54f30ca`, before
  any of this work. `DBG_PANEL` and `DBG_CACHE` are both unconnected there.
- **`term_panel.v`**: `s_ruler_reversed` is
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
