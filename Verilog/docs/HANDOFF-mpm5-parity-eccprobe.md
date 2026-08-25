# Handoff: why all memory reports "Mpm 5", and what was done about it

Written 11-AUG-2026. Branch `nd-bus-seam-gate`.

Repo-relative paths throughout. Repo root is the directory containing
`README.md` and `Verilog/`.

## The observed failure

SINTRAN III M halts on the Tang Nano 20K when booted from the Winchester disc:

```
System malfunction. Sintran halt in ERRFATAL.
L-reg: 072627 / Current page index tabl/APIT): 000012 / 000007
Level: 000016 / Perror: 064544 / Level : 000001 / IIC : 000003
Page Fault: 000000 Err Code: 000000 Bank: 000000 / PEA : 000000
```

`072627` is inside `ENT14`, the level-14 entry, at the arm labelled
"Page fault in ND-500/5000 window". The machine has no ND-500 attached, so
that arm is fatal.

## Why that arm is reached

The TPE `CONFIGURATION` diagnostic classifies each 16 Kword block of memory as
Local or Multiport. It does so with the ECC-simulate probe:

1. `TRR ECCR := 011` (octal) - arms the probe.
2. Write a word to the block under test.
3. `TRR ECCR := 004` - disarms.
4. Read the word back.

A level-14 parity interrupt with PES/PEA loaded means the block answered, and
the block is recorded as **Local**. Silence is recorded as **Mpm 5**.

Measured on the Tang, 11-AUG-2026, every cell of the map reads `Mpm 5`:

```
Total memory size....: 4.000 Mbytes
! 000B / 000D ! Mpm 5 ! Mpm 5 ! Mpm 5 ! Mpm 5 ! Mpm 5 ! Mpm 5 ! Mpm 5 ! Mpm 5 !
...
Mpm 5 memory size....:  4.000 Mbytes
```

SINTRAN III M then treats a page fault in that memory as a fault in the
ND-500/5000 shared-memory window, and takes the fatal arm of `ENT14`.

## Where the probe actually breaks

The path was traced link by link in the source. Links 1-3 are present and
correct - the earlier claim that "there is no ECCR path" was wrong:

1. `TRR ECCR` = IOX 100115 is decoded in
   `Verilog/DELILAH-CPU/CGA_MAC/circuit/CGA_MAC_APOS_CALCA.v:99` and reaches
   the memory sheets through CGA -> CPU_PROC_CGA_33 -> CPU_PROC_32 -> CPU_15 ->
   ND3202D -> MEM_43 / MEM_DATA_46 / MEM_LBDIF_48.
2. `Verilog/PAL/PAL_45008B.v` latches `TST` from LBD0/LBD1/LBD4 and `DISB` from
   LBD3, and drives `OER_n = ~(BCGNT50R | (TST & MWRITE))` - so with TST armed,
   a memory write enables both AM29833A output enables at once.
3. `Verilog/Shared/support/AM29833A.v` implements that as forced-error mode:
   transmit R->T with the parity bit INVERTED (per the datasheet, "the user can
   force a parity error by enabling both OER and OET simultaneously"). This was
   fixed 30-JUL-2026. The bad parity bit lands on DD[8]/DD[17].

Link 4 is the break, and it broke identically in Verilator and on silicon:

- `Verilog/CPU-BOARD-3202/circuit/MEM_RAM_49_SIM.v` regenerated parity from the
  data on EVERY read ("PARITY IS ALWAYS REGENERATED, NEVER READ FROM STORAGE",
  policy set 3-AUG-2026). The injected bad bit was healed on the way out.
- The Tang SDRAM path does the same - commit `451b05b`, "never store parity on
  any FPGA target".

With no error surviving the read, the AM29833A check passes, LOERR never
asserts, no level-14 parity interrupt is raised, and CONFIGURATION writes
"Mpm 5".

## Two further blockers, both fixed and committed

Both sat downstream of link 4, so neither changed behaviour on its own. Both
were transcription slips against the 600 DPI drawings.

- `6d95b09` - `Verilog/CPU-BOARD-3202/circuit/MEM_DATA_46.v` published the two
  AM29833A error pins through a gate on `OET_n`. On sheet 46, region E2-F3, the
  ERR pins (1H pin 10, 2H pin 10) are open collector, pulled up by R21/R26, and
  drive the 74F04 (1F) directly; nothing on the drawing gates them. The gate
  was not merely extra - `OET_n` comes from PAL 45008 and equals `MWRITE_n`, so
  `OET_n` high is exactly a read cycle, the one case where a stored parity
  error would be reported. The testbench
  `Verilog/CPU-BOARD-3202/circuit/sim/MEM_DATA_46_tb.v` carried the same fault
  in its golden expectation and was corrected with it.
- `148594d` - `Verilog/CPU-BOARD-3202/circuit/MEM_43.v` computed the local
  parity error and then discarded it: `assign LPERR_n = s_lperr_n | 1;`. That
  pinned the board output high, so the 74LS112 parity flip-flop (8J, sheet 46
  region F6) could never be seen outside the sheet.

Full registry after both: **ALL 199 TESTS PASSED (2305 s)**.

## The change under test for link 4

`Verilog/CPU-BOARD-3202/circuit/MEM_RAM_49_SIM.v` (Verilator model only; the
FPGA path is untouched).

Parity is still **computed from the data on read** - the 3-AUG-2026 policy
stands. What is stored is a single "this location was deliberately corrupted"
flag per byte lane (`b0_lo_bad` .. `b2_hi_bad`), set on a write when the parity
bit presented disagrees with the data:

```verilog
b0_lo_bad[idx0] <= DD_17_0_IN[8]  ^ odd_par(DD_17_0_IN[7:0]);
b0_hi_bad[idx0] <= DD_17_0_IN[17] ^ odd_par(DD_17_0_IN[16:9]);
```

and used on read only to invert the computed parity:

```verilog
wire [17:0] q0e = {odd_par(q0[16:9]) ^ qbad0_hi, q0[16:9],
                   odd_par(q0[7:0])  ^ qbad0_lo, q0[7:0]};
```

Only an AM29833A forced-error write can set a flag. Every ordinary write clears
it, so the change is behaviour-neutral outside the probe.

**Storing the parity bit itself and reading it back would have been wrong
here.** An untouched location holds data 0 with a 0 parity array, but odd
parity of a zero byte is 1 - so every word the machine had not yet written
would report a parity error. A flag defaults to "not corrupted" and has no such
failure mode. It also leaves the `b*_p` arrays and the C++ preload hooks in
`Verilog/sim/nd120_probe.cpp` and `Verilog/runSim/Run120.cpp` untouched.

Status: built clean into an isolated `obj_dir_par` (so the running TPE
regression in `obj_dir_probe_wd` was not disturbed); the CONFIGURATION run
against it is what decides whether the map turns Local. **No verdict yet** -
see "Measurement status" below.

### The same idea already exists in the C emulator

`~/repos/nd100x/src/cpu/cpu_mms.c:818-915` (outside this repo) does exactly
this and confirms the shape is right: `gEccLatch`, one byte per physical
address, set on write when an ECCR simulate bit is armed, tested on read.
Parity/ECC itself is never stored. Its own comments record why per-address and
not one global flag: an instruction fetch between the probe's write and its
read-back would otherwise consume the error.

Two differences from the RTL change above, both deliberate:

- nd100x latches WHICH bit was corrupted (SimBit0/SimBit15/SimBit6) because its
  PES error code depends on it. That is ND-100 ECC. The 3202D has plain odd
  parity per byte with separate LOERR/HIERR pins, so one flag per byte lane is
  the right granularity here.
- **nd100x CONSUMES the latch on read** ("the read corrects/clears that word's
  bad ECC") and gates single-bit errors behind ECCR bit 2. Its comment records
  a concrete failure from not doing so: a residual latch left behind by TPE
  MEM's parity-detection subtest fired an unhandled parity interrupt on the
  next read during the WALK test, and the guest deadlocked at PIL 14.

  The RTL flag added here does **not** self-clear - it persists until the word
  is rewritten, which is what the physical RAM does (a bad parity bit stays in
  the chip until overwritten). That is the hardware-faithful choice, but it is
  exactly the condition that deadlocked nd100x. **TPE MEMORY is the test that
  decides whether it bites.** If MEMORY hangs at PIL 14 after the
  parity-detection subtest, this is why, and consuming the flag on read is the
  fix to try first.

## What is NOT done

- The FPGA path still regenerates parity unconditionally, so silicon will still
  report Mpm 5 even if the Verilator run turns Local. Extending the same
  one-bit-flag idea to the Tang costs SDRAM the storage cache currently uses,
  and reverses `451b05b` - that is Ronny's call, not one to take here.
- `Verilog/CPU-BOARD-3202/circuit/ND3202D.v:819` still has
  `s_ibperr_n = 1'b1; // DISABLE BUS PARITY ERROR`. That is ND-bus parity, not
  local memory parity, so it was left alone deliberately.
- Our PGS register has no lock. The reference behaviour is "errors lock the PGS
  register, reading it with TRA PGS unlocks it again"
  (`CpuND100.MMS.cs`, in the RetroCore repo). `CGA_IDBCTL_PGSREG` has no lock
  and `EPGSN` never reaches it, so what freezes PGS across a trap is unknown.
- `VEX` is commented "Violation exception" in
  `Verilog/DELILAH-CPU/CGA_DCD/circuit/CGA_DCD.v:34` but "Vector EXecute signal"
  in its generator `Verilog/DELILAH-CPU/CGA_MAC/circuit/CGA_MAC.v:45`. One of
  the two comments is wrong; which has not been established.
- `Verilog/DELILAH-CPU/CGA/circuit/CGA.v:620` ORs the IDBCTL output into FIDBO
  where the drawings do not. Flagged, not touched.

## Measurement status as of the end of 11-AUG-2026

**No CONFIGURATION verdict has been obtained yet on either build.** Three runs
were started and the first two produced nothing, both times because of defects
in the driver script, not in the hardware model. Recorded here so the next
person does not repeat them:

- Run 5: the script sent `HELP` after the banner. `HELP` does not print a list
  and return to `TPE>`; it opens a sub-prompt `Command:` that waits for a
  command name. The `CONFIGURATIO` meant for the loader was eaten by that
  sub-prompt, and the following `RUN` answered `NO SUCH FILE NAME`.
- Runs 6 and par: the load-wait was written to require the string `TPE>` to
  appear TWICE after the load command. `mark` is taken before the command is
  sent, so the prompt already on screen is not in the window being searched and
  a successful load prints `TPE>` exactly ONCE. The condition could never be
  satisfied, so every load timed out silently after twelve chunks.

The third pair of runs was started with both fixed, plus per-chunk progress
printing during the load so a stall is visible rather than silent, and the
console dump raised from the last 4000 to the last 20000 characters (the memory
map is most of 4000 on its own).

Regression scope: the run against the committed build exercises CONFIGURATION,
INSTRUCTION, PAGING, CACHE-1X0 and MEMORY, to confirm the six RTL fixes of
11-AUG plus the two parity commits introduced nothing. The run against the flag
build is CONFIGURATION only, and answers the single question of whether a map
cell turns Local.

## How to reproduce the measurement

TPE monitor boots from floppy with `1560&` at the OPCOM `#` prompt. Reaching
the `TPE>` prompt takes roughly 90-130 million ticks (about 25-35 minutes of
wall clock). Four rules, each learned the expensive way:

1. **Never send `HELP`** - it opens a `Command:` sub-prompt that swallows
   whatever is sent next.
2. **Only the FIRST program is loaded by its bare name.** Every later one needs
   `LOAD <name>`; a bare name then answers `*** No such command ***`.
3. **Wait for `TPE>` to come back after a load before sending `RUN`.** Loading
   off the floppy takes far more than one 5M-tick chunk. Poll for `TPE>` in the
   text written since the command was sent - exactly one occurrence means the
   load finished - and watch for `NO SUCH FILE NAME` too.
4. Program names on the floppy are `CONFIGURATIO-D05:TEST`,
   `INSTRUCTION-C03:TEST`, `PAGING-C02:TEST`, `MEMORY-D04:TEST`,
   `CACHE-1X0-A00:TEST`. `CONFIGURE` is rejected - it diverges from
   `CONFIGURATIO` at the ninth character. CONFIGURATION ends with
   `=== END OF INVESTIGATION ===`, not "END OF TEST".

The two Verilator harnesses used here are `Verilog/sim/obj_dir_probe_wd`
(committed build) and `Verilog/sim/obj_dir_par` (the flag build). Separate
obj_dirs can run concurrently; building into one while a run uses it cannot.
`Verilog/runSim/` belongs to Ronny and is not to be touched.
