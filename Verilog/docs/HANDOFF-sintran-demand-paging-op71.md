> # SUPERSEDED 24-AUG-2026 - SINTRAN III BOOTS
>
> This document's title and conclusion no longer hold. SINTRAN III boots on
> the Tang Nano 20K. Root cause of the failure described below: the memory
> bank was decoded from the wrong side of the bus transceiver
> (`ND3202D.v:533`), so every incoming DMA write decoded to BANK0 - the disc
> data landed at the right ROW in the wrong BANK and the CPU read a page
> nothing had written.
>
> The reasoning below about "a decision made inside SINTRAN" was wrong: it was
> an RTL fault after all, in the bus address path rather than the fault
> delivery path. Kept as a record of the investigation.
> See `HISTORY.md` and `Verilog/fpga/tang-nano-20k/PLAN-pf-campaign-prio.md`.

# HANDOFF: SINTRAN III never boots - the first demand page-in is never serviced

Date: 17-AUG-2026.
Status: **root MECHANISM proven. The remaining unknown is a decision made inside
SINTRAN, not an RTL fault-delivery defect.**

Scope: booting SINTRAN III from the Winchester (`20500&` at the OPCOM `#`
prompt) on the ND-120 recreation, both Verilator and Tang Nano 20K.

---

## 1. The symptom, stated exactly

**SINTRAN has never printed a single character on either of our platforms.**

| Platform | Console output |
|---|---|
| nd100x oracle, same disc image | Full banner, reaches `SINTRAN III RUNNING -` |
| Tang Nano 20K | `#20500&` then straight to ERRFATAL. **No banner.** |
| Verilator | `#20500&` and nothing else - the console file is 7 bytes |

The Tang halt, in full (this exact text is also recorded in
`/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/HANDOFF-mpm5-parity-eccprobe.md`
lines 13-16, so seeing it again is NOT a new finding):

```
System malfunction. Sintran halt in ERRFATAL. L-reg: 072627
Current page index tables (NPIT/APIT): 000012 / 000007
Level: 000016

Perror: 064544
Level : 000001
IIC   : 000003      Page Fault
PES   : 000000  Err Code: 000000  Bank: 000000
PEA   : 000000
```

`072627` is inside `ENT14`, the level-14 entry. So SINTRAN dies BEFORE
announcing itself - during early startup, the phase that ends with
`PAGES FOR SWAPPING`, i.e. paging and swapping setup.

**Success criterion**, adopted 17-AUG-2026: grep the console for

```
SINTRAN III RUNNING
```

---

## 2. What operation 71 actually is

The Verilator boot stops after 71 Winchester disc operations. "Operation N"
means the Nth `START blk2=... blk1=... unit=0 pos=...` record in the file named
by `ND120_WD_TRACE_FILE`. Nothing more.

From an oracle run on a copy of the same image (logs in
`/tmp/claude-1000/oracle_wd/`):

- oracle transfers 1-70 are BULK multi-page loads, `WC=4608`, `4096`, `2560`
- from transfer 71 on, essentially every transfer is `WC=1024` or `512` - one
  ND page or half a page
- **oracle transfer #71 IS the read that services the first demand page fault**

So operation 71 is the structural boundary where SINTRAN stops bulk-loading its
resident image and starts demand paging. Our machine performs the whole bulk
load correctly and then fails at its FIRST DEMAND PAGE-IN.

### Counting rule - do not mix these up

`ND100X_WD_DEBUG=1` prints seeks WITHOUT a `GO` prefix:

| rule | matches | total | before banner | before RUNNING |
|---|---|---|---|---|
| A | `WD: GO M<d>-` (data transfers) | 249 | 175 | 246 |
| B | `WD: M<d>-` (**seeks only**) | 89 | 67 | 87 |

An earlier note claiming "the oracle only needs 67 operations for the banner"
was rule B and is misleading. On the transfer rule a full boot needs 246.

---

## 3. Page faults are NORMAL. The defect is that ours are not serviced

Oracle, during a healthy boot to `SINTRAN III RUNNING -`:

- **126 page faults**; 71 of them before the banner even prints
- **126 of 126 are followed by a Winchester transfer. Zero exceptions.**
- 0 memory-protection violations; 125 of 126 at PIL 1

The service sequence is invariant:

```
PF (IIC 3) -> CLPT (opcode 140505, unmap victim pages)
           -> 140750 (bank op)
           -> M4-Seek / M0-Read of 1024 or 512 words
           -> IO complete -> IDENT LEVEL 11
           -> ENPT (opcode 140506, map the new page in)
           -> resume
```

On heavier faults the handler unmaps up to thirteen victim pages with `CLPT`
before issuing the read.

**So our signature is not "a page fault happened". It is "a page fault happened
and no disc read followed" - which never occurs on a working machine.**

---

## 4. THE PROVEN MECHANISM

Microcode addresses, from
`/mnt/e/Dev/Ronny/nd120uc/source/nd-120-delilah.uc`:

```
CLPT  = CSA 0o5705 (3013 decimal)   unmap a victim page
ENPT  = CSA 0o5706 (3014 decimal)   map the new page in
CLPT1 = 0o4071,  CLPT3 = 0o4115
```

Measured on the Tang with STICKY flags latched from reset - so the result
covers the WHOLE boot, not a ring window:

```
ever reached CLPT (0o5705, unmap victim) : False
ever reached ENPT (0o5706, map page in)  : False
```

255 records captured; CSA live and sane in the same records (`0o06000`,
`0o01127`, `0o00031`, `0o00054` are all real microcode addresses), so `False`
means never reached, not a dead probe.

**Our machine never executes the page-in microcode. No page is ever mapped in,
so no disc read is ever issued, so the same unmapped entries are retried
forever.**

The Verilator run confirms this independently: it sits at operation 71 for
75+ million ticks (versus a 35 M quiet stretch measured as benign earlier) while
the zero-entry translation counter climbs past 2.2 million. The machine is
re-translating unmapped page-table entries endlessly and never resolving one.

### What this does NOT prove

SINTRAN's level-14 handler DOES run - it prints the ERRFATAL diagnostic. So the
machine takes the fault, enters level 14, and **bails out as unrecoverable
before unmapping anything**. The defect is in what SINTRAN checks BEFORE
deciding a fault is serviceable, not in fault delivery.

`PES` and `PEA` both print `000000` in the halt dump. If SINTRAN reads those to
decide what faulted and gets zeros, "unserviceable" is a plausible conclusion
for it to reach. That is a hypothesis, not a finding.

---

## 5. Ruled out by measurement - do not re-tread these

| Suspect | How it was cleared |
|---|---|
| `CGA_TRAP_TVGEN` combinational logic | **Exhaustive**: all 524288 input states, both build modes, TVEC/PVIOL/RESTR vs a spec-derived golden |
| Trap-vector staleness (TVEC=3 for a page fault) | Real but **harmless transient**. Cycle-resolution capture shows it settles to 1 within ~2 clocks and the correct `PVPF` handler at `00030` runs |
| Page-table storage | **All 2048 entries** written, read back and translated; 8198 checks; both RAM read models |
| Page-table RAM sync-vs-async read | `TMM_ASYNC_READ` changes NOTHING - sync and async give identical results. **Verilator needs no divergence from silicon here** |
| Late page-table address | `LA_20_10` is captured on MCLK by `R81_EN` (posedge CP, `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/Shared/ndlib/R81_EN.v:7`) and holds the whole microcycle |
| Late `VACC` | Measured high at the dispatch |
| PT vs APT table selection | **RE-OPENED 17-AUG, see 14.5.** `PTM=1` at the fault is still true, but the 17-AUG capture reads `PT=0 APT=017` with the table actually driven being 3 (data) / 014 (fetch) - matching neither. Two caveats must be closed before this means anything (missing `LA[20]`, ring-buffer sampling alignment) |
| Missing per-level PCR | Single PCR latch is faithful; microcode keeps the per-level copies and reloads with `COMM,LDPCR` on a level switch |
| `PAL_44306A` | All 8 equations match the original PALASM exactly |
| PT status bit indexing | Consistent end to end; index 0 = PT bit 9 through index 6 = PT bit 15 |
| SPT/SAPT co-assertion (PTSEL JK toggling) | Exhaustive bench, 1051 checks, both modes |
| `CGA_MAC_PTSEL` | Its own bench, 51 checks, both modes |
| FIDBO bits 1<->2 swap | The fix is intact and straight-through |
| Page-table write-back discard (CYD) | 72 of 72 shadow writes asserted `WMAP_n`; and in the REAL capture `CYD` is never low while `WMAP_n` is asserted, 0 violations in 4794 cycles |
| Page-fault detect equation | Matches the oracle: permit bits only (`PGF = VACC & ~WPM & ~RPM & ~FPM`), NOT `PTE == 0` |

---

## 6. Test benches added (all NEW files, nothing existing modified)

| File | Covers | Result |
|---|---|---|
| `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_TRAP/sim/CGA_TRAP_TVGEN_exhaustive_tb.v` | All 524288 steady input states | **PASS** both modes. Registered in `run_all_tests.sh` |
| `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/CPU-BOARD-3202/circuit/sim/CPU_MMU_24_allentries_tb.v` | All 2048 PTEs: write, read-back, translate; REX + SEX; anti-aliased pages; fault-and-fix | **PASS** 8198 checks, both RAM models. Registered as `test-mmu24-allentries` |
| `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_TRAP/sim/CGA_TRAP_TVGEN_transition_tb.v` | Every ordered pair of trap-condition classes | **FAILS 30/30 by design** - it is the DETECTOR. Catches Issue-D's vector 7 (8 cases) and the page-fault transient. Baselined as an orphan |
| `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_TRAP/sim/CGA_TRAP_TVGEN_pgfrace_tb.v` | Minimal reproduction of the stale-vector capture | FAILS by design. Baselined |
| `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/CPU-BOARD-3202/circuit/sim/PT_stale_read_tvec_tb.v` | Real PT RAM wired to the trap generator, address-lead sweep | Retired the async-read theory. Baselined |

The transition detector is the important one: the exhaustive bench passes on all
524288 STEADY states, but every trap-vector bug found on that sheet has lived in
a TRANSITION. Register it the day the vector timing is addressed.

---

## 7. RTL changed, all UNCOMMITTED, awaiting validation against the drawings

- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_TRAP/circuit/CGA_TRAP_TVGEN_P2.v`
  - **three level-2 vector flip-flops RESTORED**. Page 104 (`/CGA/TRAP/TVGEN`
    sheet 2 of 2, in
    `/mnt/e/Dev/Repos/Ronny/nd-120/DesignDocuments/DELILAH-CPU/DELILAH.pdf`)
    draws ALL SEVEN vector bits as FD1 flip-flops clocked from TCLK. The 27-JUL
    change had replaced `L2V0N`/`L2V1N`/`L2V2N` with combinational assigns,
    which has no basis on that sheet. With them restored the whole CGA_TRAP
    suite still passes, so that bypass was not load-bearing for any unit test.
  - `MUX31LP` note: `muxIn_3 = muxIn_2` is CORRECT - A=B=1 behaves as select 10
    and picks D2 (confirmed by Ronny 17-AUG-2026).
- Diagnostic capture plumbing, inert without its defines:
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA/circuit/CGA.v`,
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_MIC/circuit/CGA_MIC.v`,
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/src/ND120_TANG20K_TOP.v`,
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/src/tang20k_defines.v`
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/CPU-BOARD-3202/circuit/MEM_RAM_49_SIM.v`
  - earlier parity-flag work, still unmeasured. Independent of this fault.
- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/Shared/support/TMM2018D_25.v` is back to
  original - the async-read experiment was reverted.

---

## 8. Capture-rig defects found and fixed (they invalidated earlier evidence)

- `ND_WD_TRACE_TVEC` is a **dead capture mode**: it names a branch in BOTH
  capture chains of `ND120_TANG20K_TOP.v` that contains comments and nothing
  else - no `s_cap_src`, no `s_cap_stb`. Any record attributed to it is
  meaningless. Use `ND_WD_TRACE_TVEC_CSA`.
- `ND_WD_TRACE_TVEC_CSA` was missing from the `CGA_MIC.v` export chain, so
  `XMIC_DBG` carried the sim-probe bits and no trap vector.
- `ND_WD_TRACE_TVEC_CSA` also **requires `TANG_WD_TRACE_DUMP`**: `wd_trace_we`/
  `done`/`foreign` are declared and connected only inside that define, so
  without it `wd_count` never leaves 0 and the capture trigger can never fire.
- The ring dumper emits **FIVE** hex digits per line, not four as its own
  comment says.
- The trap-vector numbering comment in `tang20k_defines.v` was wrong. `TVEC` is
  the DELILAH **microcode** trap vector, anchored by the golden bench
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_TRAP/sim/CGA_TRAP_TVGEN_tb.v:16-17`:
  `1 = page fault, 2 = protect violation, 3 = ring down, 4 = PGU, 5 = WIP`.
  That is a DIFFERENT numbering from the ND-100 internal-interrupt code, where
  `IIC 3` genuinely IS page fault - SINTRAN prints the name itself. Confusing
  the two produced a mislabelled record on 11-AUG.

---

## 9. Traps that cost real time - read before repeating the work

- **Probe CSV captures store OCTAL strings.** Read them with `int(s, 8)`.
  Reading them as decimal produces values that look like plausible ND octal and
  are completely wrong. Check: if no value in a column contains the digit 8 or 9
  across hundreds of distinct values, it is octal.
- **A Verilator SINTRAN boot must run ~1 BILLION ticks** to reach where the Tang
  fails. Tang `clk_cpu` is 6.75 MHz and ERRFATAL arrives at 146.5 s = 989 M
  cycles. Every run before 17-AUG-2026 stopped at 17-30% of that and produced
  false negatives. Budget ~220 chunks of 5M, roughly 8 hours.
- **Validate a log filter against a line you know exists before quoting a
  count.** Two counters were wrong in one day: one matched `pt15_9=000`, which
  also appears in the zero-status WRITE lines of the normal init sweep; another
  searched for the literal word `zero`, which never appears. The zero-entry
  TRANSLATION probe marker is `[pt] Z` (`CPU_MMU_24.v:504`).
- **`0o5705` needs TWELVE bits.** A capture carrying only `CSA[10:0]` silently
  truncates bit 11 and shows `0o1705` - "never reached" for a routine that is
  running.
- **A hand-driven testbench tests the author's model, not the CPU.** Drive the
  protocol the real microcode emits. The real capture
  `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/sim/tpe_paging.csv` shows it: the
  two-write SEX pattern, status `0o162000` then the physical page, 64 entries
  per table, `CYD` never violated in 4794 cycles.

---

## 10. Reproduction

Verilator, full length (about 8 hours):

```
cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/sim
make probe-wd USE_LATCHES=0 EXTRA_WD_DEFINES=-DPTDBG     # engine with the PT probe
# then drive it: OPCOM '#', send 20500&, run 220 chunks of 5,000,000 ticks,
# NO stall detector, grep the console for SINTRAN III RUNNING
```

A hand-rolled build script MUST pass `-DFPGA_FF_MODE`. A latch-mode engine boots
the microcode self-test but never reaches the floppy `TPE>` prompt and stops
silently right after the `1560&` echo - two full runs were lost to that.

Tang, trap/CSA capture:

```
# in /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/src/tang20k_defines.v
`define TANG_WD_TRACE_DUMP          # REQUIRED - provides the trigger counters
`define ND_WD_TRACE_TVEC_CSA        # the working trap capture

cd /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k
make gowin && make load-gowin       # volatile SRAM; a power cycle restores the flashed image
# console 9600 8N1 on /dev/ttyUSB1, ~0.30 s between characters (OPCOM has no receive FIFO)
# MACL, then 20500&
```

Oracle:

```
cd /home/ronny/repos/nd100x
ND100X_TRACE_ND110=1 ND100X_WD_DEBUG=1 stdbuf -o0 -e0 timeout 150 ./build/bin/nd100x \
  --boot=wd --wd0=/tmp/claude-1000/oracle_wd/WD0-copy.IMG --cputype=ND120CX \
  </dev/null > pf_mix.log 2>&1
```

Always work on a COPY of the disc image.

---

## 11. WHY SINTRAN REFUSES THE FAULT - traced in the oracle

The level-14 path was disassembled from the resident kernel in the disc image
(SINTRAN III **VSX/500 M**; symbols
`/home/ronny/repos/nd100x/template-glass/data/symbols/M06/SYMBOL-2-LIST.SYMB.TXT`;
listing at `/tmp/claude-1000/oracle_wd/level14_pagefault.lst`).
Under M06: `ENT14=073003`, `IICPF=073265`, `COMEB=072561`.

Level 14 wakes, reads `TRA IIC` (=3), reads `TRA PVL` to get the previous level,
dispatches `P := 073111 + IIC` to `IICPF`, which falls into `COMEB`. Only THREE
things are inspected, and **PES/PEA are never read on this path at all**:

- **previous level** - must be 1, 2, 4 or 5, else give up
- **`TRA PGS` bit 15** - "fault was an instruction fetch"; only controls whether
  the faulting P is backed up so the instruction re-executes. Not fatal.
- **the faulting PAGE NUMBER** - `COMEB` masks `PGS & 001777` (= PT<<6 | VPN)
  and compares it against the three fixed pages `0757 / 0760 / 0761`, whose
  frames live at `M[STSIN+22 / +23 / +24]` (`STSIN = M[004007] = 012174`).

### `L-reg: 072627` identifies ONE instruction

Scanning every `JPL` in `070000-076000`, exactly one leaves `L = 072627`:

```
072626  135122  JPL I 122   ->  M[072750] = 004356      (the give-up routine)
```

reached **only** when `PGS & 001777 == 000760` **and** `M[STSIN+24] == 0`.

So the machine is reporting the faulting page as **`000760`** - a page that in
the oracle NEVER faults. `004356` is the common target of every give-up branch;
a breakpoint on it never fired in 400 M instructions of a successful boot.

### Known-good values, first serviced fault (oracle, live)

| Item | Read at | Value |
|---|---|---|
| IIC | `073012 TRA IIC` | `000003` |
| PVL | `073073 TRA PVL` | `0153612` -> previous level **1** |
| **PGS** | `073271 TRA PGS` | **`040762`** (PM=1, fetch=0, PT=7, VPN 0o62) |
| `M[004004]` | `072644` | `000000` |
| `M[004270] .. M[004271]` | `072655/072660` | `000172 .. 000177` (RT-COMMON window) |

Whole-boot census: 126 faults, 125 at PIL 1. Pages `0757` and `0760` **never**
fault; `0761` faults 12x, `0762` 2x, `0763` 1x.

### What this kills

- **PES/PEA are a red herring** - never read on this path, so their `000000` in
  the halt dump means nothing.
- **No evidence for the ND-500 window hypothesis.** The only configuration data
  consulted are the three fixed pages via `STSIN+22/23/24` and the RT-COMMON
  window `M[004270..004271]`. Nothing reads a memory-type or ND-500 table.
  The Mpm5 line is dead FOR THIS PATH.

### PGS - and a correction

`PGS` is built in
`/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_IDBCTL/circuit/CGA_IDBCTL_PGSREG.v`
from self-holding scan flip-flops: `D` tied to `Q` (hold), `TI` = the new value
(`LA_21_10`, `PVIOL`, `FETCHN`), `TE = VACC` = capture select. So
`VACC=1 -> load`, `VACC=0 -> hold`.

**Drawing page 98 (`/CGA/IDBCTL/PGSREG`, sheet 1 of 1) shows EXACTLY five
inputs - MCLK, VACCN, LA(21:10), FETCHN, PVIOL - and NO EPGSN.** Our RTL matches
the drawing. An earlier note in this project that "PGS has no lock and EPGSN
never reaches it" is misleading on both counts: there is no lock on that sheet
to be missing, and `EPGSN` is the IDB READ ENABLE for `TRA PGS`
(`CGA_DCD.v:1322`), correctly wired at `CGA_IDBCTL.v:110`.

So PGS simply holds whatever `VACC` last loaded. On real hardware something must
stop `VACC` asserting after the fault, so the faulting page survives until
SINTRAN reads it many instructions later. ~~Whether ours does is the open
question.~~ **ANSWERED 17-AUG-2026 - see section 14. Nothing needs to stop VACC:
the microcode reads PGS two microinstructions after the trap and neither of them
makes a memory request, and VACC requires MREQ.**

### CAVEAT

The disassembly used **VSX/500 M** symbols. Under the L07 map `072627` falls in
a different routine, so this identification holds only if the RTL disc runs the
same M revision. Confirm the boot banner before acting on it.

---

## 12. Next step - one measurement

**Capture `PGS` at the instant of the page fault on the Tang and compare with
the oracle's `040762`.**

- a value of the form `xx0760` confirms the diagnosis outright
- `PGS = 0` would NOT produce this failure (it would still be serviced), so the
  specific value matters
- capture `VACC` alongside it: if `VACC` keeps asserting after the fault, PGS is
  being overwritten before SINTRAN reads it, and that is the defect

The capture rig for this already exists - see section 10 - and `PGS_11_0` is
available in `CGA_IDBCTL`. The previous ring already carries `VACC`.

---

## 13. Original next-step note (superseded by 11 and 12)

Find what SINTRAN's level-14 entry tests before agreeing to service a page
fault. `ENT14` is at `072627` (the L-register in the halt). The oracle runs that
same code successfully 126 times per boot, so:

1. Trace/disassemble the level-14 path in the ORACLE from `072627` to the branch
   that chooses "service" versus "ERRFATAL".
2. Identify the registers, status words or memory locations it reads to make
   that decision, and capture the known-good values at the decision point for
   two or three successful faults.
3. Compare those same inputs on our machine. The one that differs is the answer.

There is a standing hypothesis worth testing in that step: SINTRAN may consult
memory-configuration information, and treat a fault in memory it believes is the
ND-500/5000 shared window as unrecoverable. That is what the "all 4 MB reports
Mpm 5" work was about - see
`/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/HANDOFF-mpm5-parity-eccprobe.md`.
It was set aside because it does not explain why a page FAULTS; it may still
explain why a fault is REFUSED.

---

## 14. Measurements of 17-AUG-2026 (evening) - three theories killed, one hard new fact

Everything in this section is MEASURED, on the Tang unless it says Verilator.
Where it contradicts an earlier section, this section wins and the earlier claim
is marked above.

### 14.1 RETRACTED: "PGS is overwritten before SINTRAN reads it"

The PONI capture recorded 255 cycles around the fault. All eight post-fault
`VACC` loads carried **the same value, page 0377**. PGS is stable across the
whole trap window. The earlier "PGS IS OVERWRITTEN" verdict was a defect in the
capture script - it counted `VACC` loads without checking whether the value
changed.

The microcode says why no lock is needed. From
`/mnt/e/Dev/Repos/Ronny/nd-120/Code/Microcode/nd-120-delilah-L-from-K.uc`,
the hardware trap vector (which `CGA_MIC_IPOS` selects by forcing
`MA = TVEC`, selector 3, bits 12:4 grounded):

```
 1/   % PAGE FAULT
        A,6                      ALUD,NONE
        IDBS,BMG   COMM,SMPID    T,JMP  T,HOLD    PVPF;

PVPF:   AB,PGS                   ALUD,NONE
        IDBS,PGS   COMM,EWRF     T,NEXT T,HOLD
```

PGS is copied into the scratchpad register `PGS` on the SECOND microinstruction
after the trap. Neither microinstruction makes a memory request, and
`VACC` requires `MREQ`. Two cycles of retention is all the hardware owes.
`SINTRAN`'s later `TRA PGS` reads the scratchpad copy, not the live register.

Note also that trap vectors 3 (ring-down), 4 (PGU) and 5 (WIP) read `IDBS,PGS`
in their FIRST microinstruction; only the page-fault vector defers it by one.

### 14.2 RETRACTED: "PGF never fires / this is not a real page fault"

`errfatal-pagefault-is-not-a-real-pagefault.md` is contradicted by direct
measurement: `PGF=1` held for the entire 8-cycle window while `TRAPN=0`. The
page-fault condition is genuinely asserted in the MMU. `IIC 3` is therefore
HONEST reporting, not a crossed trap wire - consistent with the TPE programs and
the 29-testbench INTR/TRAP suite never having caught one.

`PONI` stays 1 throughout: paging is never turned off during the trap.

### 14.3 RETRACTED: the EX / `LA[19:16]`-undriven theory

`EX = PCR2 & DOUBLE` was validated against **drawing page 39
(`/CGA/MAC/LASEL`)** at 600 DPI - the lower NAND takes `PCR2` and `DOUBLE` and
emits `EXN`; the upper takes `~DOUBLE` and `~PCR2` and emits `REXN`. Our
`GATES_13`/`GATES_12` match exactly. **No transcription error on that sheet.**

`EX` and `REX` are genuinely not complementary (`PCR2=1, DOUBLE=0` asserts
neither), and both drivers of `LA[19:16]` (`GATES_3`, `GATES_4`) are AND-ed with
`ex_out`, so the "nothing drives the table number" state is real. It is just not
what is happening here:

```
records with EX=0             : 0 of 255      <- never exercised
records with EX=1 AND used==0 : 193
```

`EX` was high in every captured cycle. Table-0 lookups happen WITH `EX`
asserted, so the undriven-bus story does not explain them.

### 14.4 THE HARD NEW FACT (Verilator): half of all lookups go to page table 0

The `PTDBG` zero-entry probe in `CPU_MMU_24.v:510` fires on
`!EPT_n && WMAP_n && entry[15:9]==0` - a translation read returning an unmapped
entry - and is edge-filtered, so each line is a distinct lookup. Over a 5000-line
window of a full Winchester boot:

```
page-table number distribution (index = LA[20:10], table = >>6, VPN = &63)
   PT=0      2473   49.5%
   PT=6      2210   44.2%
   PT=3/5/12/13/2  317    6.3%

adjacent PT=0 / PT!=0 transitions: 4944, of which SAME VPN: 4135 (83.6%)

PT=6 VPN=15 x797  <-> PT=0 VPN=15 x795
PT=6 VPN=64 x270  <-> PT=0 VPN=64 x270   (exact)
PT=6 VPN=16 x216  <-> PT=0 VPN=16 x216   (exact)
```

**Every translated access is looked up twice: once in the real table and once in
table 0, which is empty.** The table-0 lookup is what raises `PGF`. This is the
cleanest signature found so far and it reproduces in Verilator, so it can be
chased without silicon.

### 14.5 Tang PT/APT capture - numbers that do not yet add up

Same boot, capturing `PT=PCR[14:11]`, `APT=PCR[10:7]` (confirmed the right
fields: `CGA_MAC_LA1025.v:160` marks `PCR[15]` and `PCR[6:0]` unused, so only
`PCR[14:7]` reach the LA table field), and the table actually driven onto
`LA[19:16]`:

```
   PT=0 APT=17 used=0   x193
   PT=0 APT=17 used=14  x48
   PT=0 APT=17 used=3   x14
at the fault:  PT=0 APT=17 used=3, DATA access, EX=1, PGF=1
```

`used` matches NEITHER `PT` nor `APT` on either fetch or data. Before treating
that as a finding, note two honest caveats:

- `used` is `LA[19:16]`, only the LOW FOUR BITS of the five-bit table index
  (`LA[20:16]`) the MMU actually uses. `LA[20]` was not captured.
- `PCR`, `LA` and `FETCH_n` are sampled into the ring buffer per clock and are
  not proven to be aligned to the same access. A one-cycle skew would scramble
  exactly this comparison.

**Do not build a theory on 14.5 until those two are closed.** 14.4 is the solid
result; it is measured at the MMU on the index actually used for the lookup.

### 14.6 Next measurement - in Verilator, not on silicon

Extend the `PTDBG` probe in `CPU_MMU_24.v` to print, on the SAME cycle as each
`[pt] Z` line: `PCR_15_0`, `EX`, `FETCH_n`, `PTM` and the full `LA[20:10]`.
That removes both caveats in 14.5 - one cycle, one access, no ring-buffer
alignment doubt - and answers directly whether the table-0 lookup of each pair
is a second lookup of the same access or a separate access.

Build it in a SEPARATE `obj_dir` (see the memory note `verilator-harness-folders`
- separate obj_dirs may run concurrently; the same one may not).

### 14.7 The 44404D gap - checked, parked, NOT the cause

Ronny recalled a hand-drawn `LSHADOW` line depending on a PAL revision we do not
have. It is real: **sheet 36 of
`/mnt/e/Dev/Repos/Ronny/nd-120/DesignDocuments/CPU-BOARD-3202/3202-REV-D-OCT-87-600DPI.pdf`**
carries a red ECO - a tap on the `LSHADOW` node at pin 4 of the `74F32 32C`
wait-state gate, routed to **pin 18 (B1) of `PAL16R4D 15D UCYIN1 44404`**, plus
red text naming **pin 16 (Q1) `DLSHADOW`**.

**That ECO is already implemented**: `CYC_36.v:485-489` wires
`.LSHADOW(s_lshadow)` exactly as drawn, and the wait-state gates match the
drawing term for term. What is genuinely missing is only the 44404**D**
equations - `PAL_44404C.v:81-83` implements `DLSHADOW` as an admitted guess, and
`LSHADOW` appears in no other equation, so today it influences nothing. The only
output the board consumes from that PAL is `DLY1_n`, into the cycle state
machine `PAL_44601B` pin I0.

Parked on Ronny's decision (17-AUG): PAGING passes 11/11 on silicon and PAGING
hammers page-table access, which is real evidence that shadow-access timing is
fine. **Do not wire `.DLSHADOW()` or edit the PAL without the 44404D listing.**

### 14.8 Benches added

- `/mnt/e/Dev/Repos/Ronny/nd-120/Verilog/DELILAH-CPU/CGA_DCD/sim/CGA_DCD_VACC_tb.v`
  - exhaustive `VACC`/`DVACC` sheet-10 check, 24576 comparisons per build mode,
  PASS in both, registered as `test-dcd-vacc`. Golden derived geometrically from
  drawing page 75, independent of the Verilog. Teeth build fails 256 checks.
  Coverage 96/128: the 32 unreached are all `MREQ=0 & FETCHN=0`, structurally
  unreachable from the module pins.

### 14.9 Verilator boot status

The Winchester boot reached **disc operation 73**, past the operation-71
demand-paging boundary. Earlier "Verilator stalls at 71" reports were an artefact
of runs that stopped at 17-30% of the needed length. Silicon dies around
operation 133. Console has still never contained a byte of SINTRAN output.
