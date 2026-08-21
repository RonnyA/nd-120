# Comparing the oracle against the Tang - what is actually affordable

**Full path:** `Verilog/fpga/tang-nano-20k/PLAN-oracle-vs-tang-tracing.md`
**Date:** 21-AUG-2026

Written after measuring the real numbers rather than estimating them.

---

## 0. What already exists - do not rebuild it

`F:\tmp\verilog` (= `/mnt/f/tmp/verilog`) already holds a working
oracle-vs-ND-120 comparison rig from earlier sessions:

| file | what it is |
|---|---|
| `oracle_make.sh` | builds an ND120CX oracle trace from nd100x; FULL ~104 B/line, COMPACT ~63 B/line |
| `lockstep.py` | timing-tolerant lockstep comparison, ND-120 trace vs oracle |
| `boot_compare.py` | compares an ND-120 RTL trace against the ND120CX oracle |
| `ctxdiff.py`, `ctxdiff_tight.py` | context-matched divergence hunt (first differing opcode/next-PC for the same context) |
| `oracle_full.trc` (2.35 GB), `oracle_1m.trc`, `nd120_*.trc` | previously captured traces, same column format |

Both sides emit the same columns:
`PIL PC OPCODE A D T X B L STS PIE PID IIE IID PGS MMU INT SEX`

**The ND-120 side of that rig has always been VERILATOR, never the Tang.**
That is the crux of the whole question below.

---

## 1. The hard numbers

### Oracle (nd100x)

- `--cputype=ND120CX` exists and works.
- Untraced speed: **2.9 M instructions/second**.
- Boot to `SINTRAN III RUNNING`: **between 10M and 20M instructions**.
- Trace cost: `-t` gives **190 B/instruction** raw; `oracle_make.sh` FULL is
  ~104 B/line, COMPACT ~63 B/line.
- **Full boot trace: roughly 1.3-3.8 GB.** Fine on F: (52 GB free).
- Also has `--watch=[phys:]ADDR[:r|w|rw]` (32 max) and `-B ADDR`. Octal needs a
  LEADING ZERO: `--watch=0175740:w`, not `175740`.

### Tang - the bandwidth ceiling

- **Console UART is fixed at 9600** and cannot be raised: the CPU board's baud
  thumbwheel is a hardware constant (BAUDV, microcode page 158) and
  `UART_BAUD_RATE` in `src/tang20k_defines.v:516` must match it. 960 B/s.
- **The debug dumper is a SEPARATE transmitter** and its baud is ours:
  `uart_tx #(.DELAY_FRAMES(1406))` on `clk2x` (13.5 MHz) in
  `src/ND120_TANG20K_TOP.v:1075`. `DELAY_FRAMES = 13.5e6 / baud`:

  | baud | DELAY_FRAMES | throughput |
  |---|---|---|
  | 9600 (today) | 1406 | 0.96 kB/s |
  | 115200 | 117 | 11.5 kB/s |
  | 460800 | 29 | 46 kB/s |
  | **921600** | **15** | **92 kB/s** |

  FT2232 handles 921600 comfortably. **That is a 96x improvement for one
  parameter**, and it costs nothing.
- Ring buffer today: **512 entries x 20 bits** of distributed RAM
  (`CAP_AW = 9`). Deeper costs logic cells the design does not have - 512 deep
  already overflowed the part once (see the comment at `:230`).
- SDRAM: 8 MB on the board, ND-120 populates 2 banks (~2 MB). Spare exists but
  it shares the controller with the CPU's own traffic.

### The arithmetic that kills full tracing on the Tang

A 20M-instruction boot, even at a minimal **5 bytes per record** (PC + opcode):

```
20M x 5 B = 100 MB
  at   9600 baud -> 29 hours
  at 921600 baud -> 18 minutes   (but needs 100 MB of buffering it does not have)
```

**There is no configuration in which the Tang streams a full instruction trace.**
The board has no storage for it and the link cannot carry it live.

---

## 2. The options, ranked by value per hour

### A. Keep the ND-120 side in VERILATOR - already built, still the best tool
Full traces, any depth, existing comparison scripts, no bandwidth limit.
**Cost:** hours of sim, no board.
**Risk, and it is real:** sim and silicon are already known to fail
differently, so a Verilator run may simply not reproduce the Tang's ERRFATAL.
Verify that it reproduces BEFORE investing in a long trace.

### B. Raise the dump baud - do this regardless
One parameter, `DELAY_FRAMES` 1406 -> 15. Every existing capture dumps 96x
faster: the 512-entry ring goes from 3.2 s to 33 ms. No downside; the console
is dead during a dump anyway.

### C. Landmark tracing on the Tang, not instruction tracing  ** RECOMMENDED **
Do not record instructions. Record only events that can be compared against a
filtered oracle log:
  - every level-14 entry (PIL 0->14) with P and IIC
  - every page-fault vector with LA and PT
  - every access whose page is one of the window pages 0o757/0o760/0o761
  - every page-table WRITE with index and data
A whole boot yields hundreds to a few thousand such records - **kilobytes**,
seconds to dump even at 9600. The oracle side is a grep over the existing
`.trc` files, or `--watch` for the memory events.

### D. Landmark COUNTING before landmark tracing
Cheapest possible comparison: both sides report only COUNTS - level-14 entries,
page faults, disc operations, page-table writes. Find the first count that
diverges, then aim C at that window. The ND120_PF_CAPTURE census already does
this on the Tang (`n_faults`, `last_la`).

### E. SDRAM-backed windowed trace
~1-2M records in spare SDRAM, dumped afterwards at 921600 (2M x 5 B = 10 MB =
~2 minutes). Gives a deep window, not a whole boot. **Only worth building if C
and D fail**, because it contends with the CPU's own SDRAM traffic and is the
most invasive option here.

### F. GAO
Documented (`GAO-HOWTO.md`) but wrong for this: needs a trigger armed for a
rare event, eats BSRAM the design has none of, and gives a microsecond window.

---

## 3. The concrete next step for the CURRENT question

The question is now narrow: **why does our machine access the ND-500 window
page (software `DPIT` page 60) when the oracle never does?**

Measured facts:
- The entry is deliberately unmapped on BOTH machines - SINTRAN writes zero to
  it (`IP-P2-SEGADM.NPL:503`, `0=:IWDN5  % CLEAR ND500 WINDOW`), confirmed on
  the oracle by a watchpoint hit at `PC=034747`.
- So this is NOT a missing mapping. It is a **spurious access**.
- SINTRAN reports the faulting instruction as `Perror` ~ `0644xx`
  (064406 / 064470 / 064544 across runs).

Cheapest decisive experiment, needs no board:

```
nd100x --cputype=ND120CX --boot=wd0 --wd0=<a COPY> -B 064406 -t
```

Stop the oracle at the same PC the Tang faults on and read what address that
code computes. If the oracle computes a different address there, the divergence
is in address generation and the trace comparison can be aimed at that exact
instruction instead of at 20M of them.

---

## 4. Two cautions

**Booting an image MODIFIES it.** `WD0-M.IMG` changed from `0af10921840e` to
`8b4785767949` after emulator boots - SINTRAN writes to the disc. Always boot a
COPY, or the image stops matching the SD card.

**There are now FOUR WD images**, all 78,643,200 bytes:
`WD0.IMG` (92b1b0be26b7), `WD0-M.IMG` (was 0af1…, the SD-card one),
`WD0-sim.IMG` (8072df07b29d), and `F:\tmp\verilog\TANG_WD0.IMG` (67a6a6119e2c).
Check which one is under test before drawing any conclusion - a full day was
spent on the assumption that the analysed image and the booting image were the
same file.
