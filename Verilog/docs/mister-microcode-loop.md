# SOLVED 01-SEP-2026 - the WCS read was one clock too slow

**Root cause.** `Shared/support/IDT6168A_20.v` builds the WCS from an
`altsyncram` in its `ifdef QUARTUS_ALTSYNCRAM` section - a section ONLY the
MiSTer build compiles - and it specified `outdata_reg_a("CLOCK0")`.
`altsyncram` ALWAYS registers the address in synchronous mode (`ram_block_type
("M10K")`, and an M10K physically cannot read asynchronously - the same
constraint that forces the async cache RAMs onto MLAB). `outdata_reg_a` adds an
OPTIONAL SECOND register, so the read took TWO clocks where the plain-Verilog
model every other target runs takes ONE.

Ronny called it: "i meant SRAM!!!! not DRAM - data needs to come out from WCS
ASAP as address changes."

**Consequence.** Every microinstruction reached the microsequencer a clock
late, so the sequencer ran one step out of step with the cycle controller. A
nested microsubroutine `T,RETURN` then popped the wrong address - 001015
instead of the 002027 MACL pushed at 002026 - MACL never resumed, and the CPU
looped forever in the interrupt-register microcode
(`RIIE1`/`RPIE1`/`RPID1`/`CHKIT`/`PICFM`) instead of reaching MACL2 and OPCOM.

**Fix.** `outdata_reg_a("UNREGISTERED")` in both Quartus-only sections
(`IDT6168A_20.v` = WCS, `MEM_RAM_49_BLOCKRAM.v` = main memory). Main memory
also had `rden_a(1'b1)` with `read_during_write_mode("DONT_CARE")`, reading on
every write cycle and returning undefined data where the plain model holds -
fixed to `rden_a(win && MWRITE50_n)`.

**Measured on the board (v44):**

| | before | after |
|---|---|---|
| CPU green lamp (set only at MACL2, i.e. self-test PASSED) | dark | **LIT** |
| MIPS | 00.00 | **00.43** |
| Active level | 000000 | 000001 |
| 001020 `NOTI2` `T,RETURN` | -> 001015 (wrong) | **-> 002027 (correct)** |
| after the return | 31-state loop | **02030, 02031, 03707 - matches the golden trace** |

**Why it hid for so long.** Only MiSTer compiles that section, so no
simulation could ever execute it. The equivalence check that was supposed to
guard it compared against `altsyncram_stub.v`, which was itself wrong by one
clock in BOTH settings (modelled 0 and 1 clocks instead of 1 and 2) - so the
test passed with the bug present. The stub is now faithful and
`Shared/support/sim/run_altsyncram_equiv.sh` is a real gate, registered as
`test-altsyncram-equiv`; it was demonstrated to FAIL with `CLOCK0` (16 differing
samples) and PASS with `UNREGISTERED` (557 + 1936 samples identical).

**Open question worth doing.** The plain-Verilog arrays carry `ram_style`
(Vivado) and `syn_ramstyle` (Gowin) but NOT Quartus's `ramstyle` - which is
very likely why Quartus refused to infer M10K and the `altsyncram` workaround
was written at all. Adding `ramstyle = "M10K"` and dropping the Quartus-only
section would make MiSTer run byte-identical RTL to every other target and
remove this whole class of bug rather than testing around it.

---

# The microcode loop the MiSTer board WAS stuck in (history)

> Measured on hardware 01-SEP-2026 with the console trace buffer
> (`Verilog/fpga/mister/rtl/nd120_csa_trace.v`), which records CONSECUTIVE
> microcode addresses. Listing: `Code/Microcode/ND-120-DELILAH-L.LISTING.txt`.
> Symbols: `Verilog/tests/instruction-verify/nd120_symbols.tsv`.
> All addresses OCTAL.

## The loop, in order

31 microinstructions, and it repeats about four times inside the 128-entry
buffer - which is how we know the WHOLE loop is captured and not a fragment.

```
  RIIE1+1  001007   B,R1      ORDQ  SLB    ARG 10000
           001010   PIC,RMSK B,R2  INVD B  COMM,EPIC      <- reads PIC mask
           001011   AB,PIE    PASSD Q      REG
           001012   A,16      ANDDQ NONE   BMG   COND,F=0
           001013   A,R1 B,R1 A+B   Q      JMP NOTI2 CONDENABL
           001014   B,R6      PASSD B      ARG 100017
           001015   A,R6 B,R2 ANDAB B
           001016   A,R2 B,R2 ORAQ  B
           001017   PIC,LMSK B,R2  INVB    COMM,EPIC      <- writes PIC mask
  NOTI2    001020   AB,IIE    PASSQ NONE   COMM,EWRF  T,RETURN
  RPIE1    001021   PASSD Q   IDBS,SWAP    T,JMP T,PUSH PICFM  --+
                                                                |
  PICFM    001163   B,Z       ANDDQ SRB    ARG 74           <---+
           001164   A,7       ANDDQ NONE   BMG   COND,F=0
           001165   A,6       ANDDQ NONE   BMG   JMP PICF2
           001166   A,0 B,Z   ORDA  B      BMG   COND,COND
  PICF2    001167   B,Z       PASSB SRB MIS,ROT  T,RETURN T,POP
           001170             PASSD Q      ARG 77760
           001171   A,Z B,Z   ORAQ  B      T,RETURN T,POP    --+
                                                              |
           001022   A,Z B,STS PASSA B                     <---+  (correct
           001023   B,R1      ANDDA B      ARG 100017          return: RPIE1
           001024   A,STS     PASSA Q                          pushed 001022)
           001025   AB,IIE    ANDDQ Q      REG
           001026   A,R1 B,R1 ORAQ  B
           001027   PIC,LMSK B,R1  INVB    COMM,EPIC  T,JMP CHKIT
  RPID1    001030   PASSD Q   IDBS,SWAP    T,JMP T,PUSH PICFM
  CHKIT    001112             ALUD,NONE    IDBS,ALU
           001113   PIC,LOSTS B,10  EPIC   COND,IRQ
           001114   AB,PID    PASSD Q      COMM,CLIRQ          <- clears IRQ
           001115   IDBS,STS  PASSD NONE   COND,F15  T,RETURN
           001116   AB,PIE    ANDDQ SLB    COND,F11
                    % "NO HARDWARE INTERRUPT REQUEST IS PENDING"
           ... and back to 001007
```

### Reading the raw dump

Two things make the on-screen octal misleading, both accounted for above:

1. **Glitches.** `CSA` is combinational and settles, so the buffer catches
   intermediate values. `01007 00300 01010` is not a jump to `00300` - in
   octal `01007 + 1 = 01010`, so those are consecutive and `00300` is a
   transient. Same for the stray `01020` between `01014` and `01015`.
2. **The once-a-second status line ALIASES.** An earlier reading of "eleven
   addresses" came from sampling this tight loop once per second and was
   wrong. Only the trace buffer shows real order.

## What the routines are

| Symbol | Addr | Listing comment |
|---|---|---|
| `RIIE1` | 001006 | `% TRR IIE` - read Internal Interrupt Enable |
| `NOTI2` | 001020 | end of the IIE path, `COMM,EWRF`, returns |
| `RPIE1` | 001021 | `% TRR PIE` - read Priority Interrupt Enable |
| `RPID1` | 001030 | `% TRR PID` - read Priority Interrupt Detect |
| `CHKIT` | 001112 | `% ROUTINE TO CHECK WHICH INTERRUPT LEVEL SHOULD BE ENTERED` |
| `PICFM` | 001163 | `% SUBROUTINE USED BY TRR PID AND TRR PIE TO TRANSLATE TO PIC-FORMAT` |
| `STERR` | 002156 | `% DISPLAY ERROR NO. R2` - **never reached** |

`COMM,EPIC`, `PIC,RMSK`, `PIC,LMSK`, `PIC,LOSTS` are the operations that talk
to the priority interrupt controller (Am2914). Every pass reads and rewrites
its mask registers.

## Where it diverges from a machine that boots

Successors of the same addresses, board vs the Verilator boot trace
(`runSim/csa_trace.csv`, 1,273,865 transitions):

| Addr | Working sim | MiSTer board |
|---|---|---|
| `001021` `T,PUSH PICFM` | 1163 | 1163 - same |
| `001027` `T,JMP CHKIT` | 1030 | 1030 - same |
| `001171` `T,RETURN T,POP` | - | **1022 - CORRECT** (RPIE1 pushed 1022) |
| `001020` `NOTI2` `T,RETURN` | **2027** | **1021** |
| `001116` `CHKIT+4` | **2031 / 2144 / 2152** | **1007** |

**The microsubroutine stack works.** `PICFM` is called from `RPIE1` (001021,
`T,PUSH`) and returns to 001022, which is exactly right. So pushes and pops
are fine - an early guess that RETURN was broken is WRONG and withdrawn.

What differs is the **return addresses**, i.e. the CALLING CONTEXT. On the
board `NOTI2` returns to 001021 and `CHKIT` returns to 001007; in the sim they
return into the 2xxx region. These routines are being entered from somewhere
else than the sim ever enters them from, and that caller chain closes on
itself.

## What is ruled out, by measurement

- **Not a self-test failure.** `STERR` (002156) never entered, `R2` untouched
  (`ST 0/000`). Probe: `fpga/mister/rtl/nd120_sterr_catch.v`.
- **Not an interrupt storm.** With the panel request disabled (`TANG_NO_PAN`)
  the interrupt debug word went 000005 -> 000000 and this loop did not change
  by a single address.
- **Not macro instructions.** MIPS reads 00.00, and that counter is fed by
  `XGPRLOAD_DBG` (the GPR<-CD instruction-register load) with
  `ND120_MIPS_TAP` defined in this build. Zero instruction loads means the
  CPU is NOT fetching macro instructions - so despite `RIIE1`/`RPIE1`/`RPID1`
  being the TRR instruction routines, they are being entered FROM MICROCODE
  here, not from instruction decode. (Ronny made this point before the
  evidence was checked; it holds.)
- **Not the RTL configuration.** Verilator built with MiSTer's exact settings
  - cache off, panel clock on, WCS preloaded, no ND-bus devices - reaches the
  `#` prompt, and a 192 KB block-RAM main memory does too.

## The WCS store is NOT corrupt - but sim and hardware differ

Checked 01-SEP-2026, because an unconditional `T,RETURN` behaving as `T,NEXT`
would be explained by wrong bits in the control store, and MiSTer is the only
build that feeds the WCS from generated `.mif` files.

**All 32 per-chip MIFs match the canonical microcode exactly**
(`Code/Microcode/wcs`, which is also what `make wcs` converts from). So MiSTer
runs precisely the microcode Nexys runs. That theory is dead.

The check did expose something else, though:

| Copy of the 32 `wcs_*.hex` | vs `Code/Microcode/wcs` |
|---|---|
| `Verilog/fpga/nexys4ddr` | identical |
| `Verilog/fpga/tang-nano-20k` | identical |
| `Verilog/Shared/support` | **`wcs_28C.hex` differs, 1 line** |
| `Verilog/runSim` | **`wcs_28C.hex` differs, 1 line** |
| `Verilog/sim` | **`wcs_28C.hex` differs, 1 line** |

Every BOARD runs the same microcode; the VERILATOR SIMS run a patched one - a
`6` where hardware has `0`, at microcode address **0o2002**, in the MACL
region. Nothing catches this: `tests/test-microcode-sync` covers only the two
AM27256 PROM images (26 copies), not the 32 WCS chip images.

Consequence for this investigation: statements of the form "the sim boots with
MiSTer's configuration" carry the caveat that the sim was executing DIFFERENT
microcode at 0o2002 than any board does. It does not explain the MiSTer
failure - Nexys and Tang boot on the canonical images - but the divergence is
real, undocumented and untested, and should either be canonicalised or
recorded as a dated exception the way the PROM ones are.

## The golden window: what a booting machine does here

From `runSim/csa_trace.csv`, starting at 002026 (MACL's
`T,JMP T,PUSH RIIE1`, which pushes 002027):

```
2026 2027 1006 1007 1010 1011 1012 1013     MACL pushes 2027, calls RIIE1
1014 1020 2027 2030 2031 3707 1021 1163     NOTI2 RETURNS to 2027; MACL runs on
1164 1165 1166 1167 1022 1023 1024 1025     PICFM, then RPIE1's body
1026 1027 1030 1112 1113 1114 1115 1116     RPID1, CHKIT
2031  300 2032 2033 2034 2035 2036 2037     CHKIT RETURNS to 2031; MACL continues
```

Both returns land back in MACL, and MACL then proceeds past 2032. Side by side
with the board:

| Return site | Working sim | MiSTer board |
|---|---|---|
| `001020` `NOTI2`, unconditional `T,RETURN` | **2027** | **1021** |
| `001116` `CHKIT+4` | **2031** | **1007** |

Both of the board's destinations keep control inside the 1xxx routines, which
is exactly what closes the 31-state loop. MACL is never resumed, so the boot
never continues - and that is why there is no `#` and no STERR.

Note `1021 = 1020 + 1`, which looks like `T,RETURN` behaving as `T,NEXT`. But
`1116 -> 1007` is NOT `1116 + 1`, so a simple "RETURN acts as NEXT" does not
explain both. Do not settle on that story without the triggered capture.

## FIRST DIVERGENCE FOUND - 001013, a condition, not a return

Captured 01-SEP-2026 with the trace armed on 002026 (`TRIGGERED=1`):

```
board:   02026 02027 01006 01007 01010 01011 01012 01013
golden:   2026  2027  1006  1007  1010  1011  1012  1013    identical

board:   01014 01015 01016 01017 01020 01021 01007 ...
golden:   1014  1020  2027  2030  2031  3707  1021 ...
                 ^ first divergence
```

Identical from MACL's call at 002026 all the way to **001013**. There:

- **Working machine:** 001013 TAKES its conditional jump to `NOTI2`, so
  001014 is only a transient; 001020 then RETURNS to 002027 and MACL runs on.
- **Board:** 001013 does NOT take the jump. It falls through 001014, 001015,
  001016, 001017, reaches 001020 the long way, and never gets back to MACL.

So the RETURN is NOT broken - an earlier reading here said it was, and that
was wrong. The fault is a CONDITION evaluating the other way:

```
001012   A,16   ALUF,ANDDQ  ALUD,NONE  IDBS,BMG   COND,F=0
001013   A,R1 B,R1  ALUF,A+B  ALUD,Q   T,JMP T,HOLD NOTI2 CONDENABL
```

001012 forms the condition by ANDing with the value read one microinstruction
earlier at 001011 - `AB,PIE ... IDBS,REG`, the read of the **Priority
Interrupt Enable** register. The board reads a different PIE than the
simulator, `F=0` comes out the other way, and the branch goes wrong.

That is consistent with the interrupt debug word showing PICV empty, and it
narrows the hunt from "somewhere in the machine" to one register read in the
interrupt controller (Am2914 / `CGA_INTR`).

### The golden PIE value

Measured in the working boot (`runSim`, MiSTer's RTL settings), by exposing
FIDBO as a port on `ND120_TOP` - the internal wire is driven and never read,
so Verilator optimises it away and the C harness cannot reach it:

```
[pie] cnt=290 CSA=001011 FIDBO=010000
```

So a machine that boots reads **010000 octal** (bit 12) from PIE at 001011,
and 001011 is executed EXACTLY ONCE in the entire boot. On the board it runs
continuously, because it sits inside the loop.

The board's value is printed as the `PE` field on the status line
(`PE hit/count value`), captured by a second `nd120_sterr_catch` instance
armed at 001011 - that module is already an address-triggered capture of a
bus, so only the address and the source differ.

### That comparison was INVALID - a sampling artifact

The board printed `PE 1/377 007774` against the sim's `010000`, which looked
like the answer. It is not. Dumping FIDBO across the WHOLE window in the
working sim, instead of one sample:

```
[bus] cnt=288 CSA=001010 FIDBO=007774   <- the board's value appears HERE
[bus] cnt=289 CSA=001010 FIDBO=010000
[bus] cnt=290 CSA=001011 FIDBO=010000
[bus] cnt=291 CSA=001011 FIDBO=000000
```

**007774 is a value the working machine produces too**, one microinstruction
earlier. The two probes sample different instants: the board's catcher latches
on the clock edge where it first sees `csa == 001011`, and CSA is the address
being FETCHED while the datapath still executes the previous microinstruction,
so it captures 001010's bus content. Nothing here shows the board reading a
wrong PIE.

LESSON, and it has now cost two near-misses in one day: a single-sample
comparison between two different simulators/machines proves nothing unless
both sample the SAME instant. Dump the window, not the point.

To make this measurement mean something, the board probe must capture FIDBO at
the trigger AND one and two cycles after, so the window can be compared
against the sim's window rather than a point against a point.

**What still stands:** the branch at 001013 goes different ways on the two
machines. That comes from the CSA trace, where both sides read the same signal
and the sequence is unambiguous. What DRIVES that branch is still unmeasured.

### Comparable windows, both sides, same format

Both the board and the simulator now emit `csa:fidbo` pairs, armed on 002026,
recorded on each address CHANGE. The board does it in
`rtl/nd120_csa_trace.v` (`TRIGGERED=1`, `aux` = `DEBUG_FIDBO_15_0`); the
harness does it in `runSim/Run120.cpp` under `TRACE_CSA_BOOT`. Same trigger,
same sampling rule, same printing - so the two dumps can be diffed line for
line instead of value against value.

GOLDEN (working boot, MiSTer RTL settings):

```
02026:000010 02027:000045 01006:000045 01007:007774
01010:007774 01011:010000 01012:000000 01013:000000
01014:040000 01020:040000 02027:040000 02030:040000
02031:040000 03707:000010 01021:000010 01163:000000
01164:000074 01165:000074 01166:000200 01167:000200
01022:000100 01023:000000 01024:000000 01025:100017
01026:000000 01027:040000 01030:000000 01112:177777
01113:177777 01114:000000 01115:000010 01116:000000
02031:000160 00300:000000 02032:000000 02033:177777
```

BOARD (v34, same trigger, same format):

```
02026:077775 02027:000045 01006:000045 01007:000000
01010:007774 01011:007774 01012:010000 01013:177777
01014:040000 01020:040000 01015:100017 01016:100017
01017:100017 01020:000000 01021:000000 01007:177777
01163:177777 01164:177777 01165:000074 01166:000074
```

### What the diff says, and what it does not

**Not conclusive: the FIDBO values.** Entries 5-7 look like the board lagging
one sample (007774, 007774, 010000 against 007774, 010000, 000000) but entry 8
does not fit that pattern. FIDBO is a shared bus sampled at an address-change
instant, so it is phase-sensitive on both sides. Treating these numbers as
data differences is exactly the mistake made earlier today; do not repeat it.

**Conclusive: the address sequence.** Both machines run
`01013 -> 01014 -> 01020`. So NOTI2 IS reached on the board - an earlier
reading here said the 001013 jump was simply "not taken", and that was too
strong. What the board then does is continue into 01015, 01016, 01017, reach
01020 a SECOND time, and go on to 01021. The working machine leaves 01020
straight to 02027 and resumes MACL.

So the board reaches NOTI2 and fails to LEAVE it, while the data feeding the
decision largely agrees. That points at the microsequencer's condition/return
control rather than at the datapath.

**Prime suspect: `CGA_MIC_CSEL`.** It holds the only `LATCH` instantiation in
the entire repo (the one Quartus needed renamed to `ND120_LATCH`, because its
own built-in primitive of that name silently wins otherwise), and it gates
exactly this class of decision:

```
ND120_LATCH CSEL_LATCH (.D(s_pcond_n), .ENABLE(s_aluclk_n), .Q(s_cond_n_out));
```

`Shared/ndlib/LATCH.v` is NOT a real transparent latch - it is a
level-sensitive sysclk approximation ("while ENABLE is high, regD tracks D on
every sysclk edge"). Its behaviour therefore depends on the ENABLE window
measured in sysclk periods, which is a CLOCK-RATE dependent property, and
MiSTer runs a different clock rate from every other board. That is a mechanism
by which the same RTL can behave differently here. NOT YET MEASURED - the next
probe should capture the condition itself (`s_cond_n_out` / the CC/TERM lines,
some of which ND120_CORE already exposes as `DEBUG_CC_TERM`).

## THE CONDITION LINES DIFFER - measured 01-SEP-2026

Same trigger (002026), same sampling rule, same format, both sides - this time
recording `{TERM_n, CC3_n, CC2_n, CC1_n, CC0_n}` (`ND120_CORE.DEBUG_CC_TERM`,
all ACTIVE LOW) instead of the phase-sensitive data bus.

| addr | golden | board | meaning |
|---|---|---|---|
| 02026 | 000037 | 000037 | nothing active - agree |
| 02027 | 000037 | 000037 | agree |
| 01006 | 000036 | **000034** | golden CC0; board CC0 **and CC1** |
| 01007 | 000016 | **000037** | golden CC0 **and TERM**; board **nothing** |
| 01010-01014 | 000037 | 000037 | agree |
| 01020 | 000036 | **000037** | golden **CC0**; board **nothing** |

(000037 = all `_n` high = nothing asserted. 000036 = CC0 asserted.
000016 = CC0 + TERM asserted. 000034 = CC0 + CC1 asserted.)

**Two faults, at exactly the addresses that matter:**

1. At 001007 the working machine asserts **TERM** and the board does not.
2. At 001020 (NOTI2, the RETURN) the working machine asserts **CC0** and the
   board does not.

That matches the behaviour exactly: the board reaches NOTI2 and cannot leave,
because the condition it would leave on never asserts.

This comparison is trustworthy in a way the earlier FIDBO one was not: the
lines AGREE across 01010-01014 and differ only at specific addresses, so it is
not a blanket sampling phase shift. (Still worth remembering they are sampled
at address-change instants on both sides.)

**Configuration caveat raised and RESOLVED.** The first golden run did not use
`MAIN_RAM_BLOCKRAM`, so the simulator had the 6 MB sim RAM while the board has
block RAM. That mattered in principle, because CC0..CC3 are the CYCLE
CONTROLLER's state and the cycle controller is driven by the memory handshake
- a different backend could move CC and TERM by itself. Rebuilding the golden
in the board's exact configuration:

```bash
make compile CACHE=0 PANEL_CLOCK=1 SKIP_WCS=1 VERILOG_TAPE=0 \
  EXTRA_VDEFINES='-DMAIN_RAM_BLOCKRAM -DND120_BLOCKRAM_ADDR_BITS=15' \
  EXTRA_CFLAGS='-DTRACE_CSA_BOOT -DND120_SIM_BLOCKRAM_RAM'
```

produced a window IDENTICAL to the first. (`ND120_SIM_BLOCKRAM_RAM` gives the
harness scratch arrays in place of the sim-RAM b0_lo/b0_hi it pokes for debug
shortcuts, which do not exist in the BLOCKRAM build.) So the memory backend
does not move these lines and the divergence is genuine.

**Where to look next.** What generates CC0 and TERM:
- TERM comes from the cycle controller (`CYC_36`, `CYC_TERM_D`) - the
  memory/cycle handshake that ends a microinstruction.
- The condition codes run through `CGA_MIC_CONDREG` and `CGA_MIC_CSEL`, and
  `CGA_MIC_CSEL` holds the ONLY `LATCH` instantiation in the repo
  (`ND120_LATCH` under Quartus) - a level-sensitive sysclk approximation whose
  behaviour depends on the ENABLE window measured in sysclk periods, which is
  a CLOCK-RATE dependent property. MiSTer runs a different clock rate from
  every other board. That is a plausible mechanism; it is NOT yet measured.

## RETRACTED: the 1.89x figure and the "extra clock at 002027"

Both claims below were made too confidently and do NOT hold. Kept, with the
correction, because the way they failed is the lesson.

**1. The 1.89x terminate rate is CONFOUNDED.** It was measured over the first
65536 CPU clocks after reset, on the argument that both machines run the same
microcode there. They do not: they diverge within about THIRTY clocks, so the
remaining 65500 compare a board stuck in a short interrupt-check loop against a
simulator that is still booting. Different code, different cycle mix. The same
confound was identified and supposedly removed one step earlier; shrinking the
window from "free-running" to "first window" did not fix it, because the window
was still three orders of magnitude longer than the agreement.

**2. The extra clock at 002027 is largely a PROBE ARTIFACT.** The board's RTL
records `csa` and `aux` together at `posedge clk_cpu` (pre-edge values); the
harness reads them after `eval()` with sysclk high (post-edge). For a registered
signal that is a one-clock offset. Printing the PREVIOUS csa beside the current
aux in the simulator (`-DND120_TRACE_CSA_LAG`) reproduces the board's early
window essentially exactly:

```
lagged sim: 01006:003417 01006:163437 01006:003416 01007:163437
board:      01006:003417 01006:163437 01006:003416 01007:163437
```

**What survives.** The aux/CC sequence itself is IDENTICAL on both machines
through this window, and the enable count within the same 32 clocks is 5 on
both. A real difference does appear a few clocks later:

```
lagged sim: 01010:003416 01010:163437 01011:002456 01011:002477
board:      01007:003416 01010:163437 01010:003416 01011:163437
```

The simulator's aux goes to 002456/002477 - decoding to **DLY0 asserted, no
clock enables**, i.e. entering a long cycle. The board stays at 163437 - **DLY0
deasserted, enables firing** - i.e. short cycles. `DLY0_n` comes from
PAL_44403C (`DLY0 = MDLY + CSDELAY0 + ACOND*CSECOND + ACOND*CSLOOP`), where
MDLY is a registered CSDLY and CSDELAY0/CSDLY are MICROCODE WORD bits.

That is the next thing to chase, and it must be chased with the probes aligned
(use `ND120_TRACE_CSA_LAG` for any csa-vs-aux comparison).

## SUPERSEDED - the 1.89x reasoning, kept for the record

Measured 01-SEP-2026 by COUNTING, not sampling - the earlier windowed dumps
suggested the clock enables fired at different microinstructions, but those
are one-sysclk pulses read at an address-change instant, which is the shape
that produced a false result with FIDBO. A count cannot be fooled that way.

`ALUCLK_EN` is `aluclk_en & ~aluclk_pa`, a rising-edge detect on `s_term_d`,
so **one pulse == one bus-cycle terminate**.

| | ALUCLK_EN per 65536 CPU clocks | ratio |
|---|---|---|
| Working simulator | 11939 | 0.1822 |
| **MiSTer board** | **22603** | **0.3449** |

**1.89x.** Both figures are the FIRST window after reset, where the two
machines provably run the same microcode (their traces agree to 001006), with
the same memory backend (`MAIN_RAM_BLOCKRAM`), same cache setting, same
devices. An earlier free-running measurement gave a similar ratio but was
CONFOUNDED - the board was looping in short interrupt-check microcode while
the simulator was booting, and different code has a different cycle mix. The
first-window version removes that.

Board measurement: `nd120.sv` counts `ALUCLK_EN` over 65536 `clk_cpu` and then
FREEZES (a free-running 16-bit counter wraps every ~360k clocks at this rate,
so two wrapped values cannot be turned back into a ratio). Simulator: the
matching counter in `runSim/Run120.cpp` under `TRACE_CSA_BOOT`.

**So bus cycles are being cut short on this board.** That is consistent with
everything else seen: the CC state diverges at 001006, TERM is missing at
001007, and the machine never completes MACL. It also explains why MiSTer
alone fails - Verilator, Tang and Nexys all run the same RTL and boot.

### Where to look

`CYC_TERM_D.v` mirrors PAL 44601B's terminate plane. The fast terminate terms
are gated by `SHORT` and `HIT`:

```
50NS   cc3_n & cc2_n & cc1_n & cc0_n & SHORT & DLY0_n & CSDELAY0_n
75NS   cc3_n & cc2_n & cc1_n & CC0   & (SHORT | HIT) & BRK_n & DLY1_n
100NS  cc3_n & cc2_n & CC1 & CC0     & (SHORT | HIT) & BRK_n
```

`HIT` is 0 on this build (no cache), so `SHORT` is the one to examine.
`SHORT_n` is produced by an `F924_EN` register in `DECODE_DGA_COMM.v:1100`,
clocked by `CLK` with the `CLK_EN` enable - i.e. by the SAME clock-enable
scheme the cycle controller generates. Enables -> DGA decode -> cycle-
controller inputs -> enables is a closed loop, so an error anywhere in it
propagates everywhere.

### The per-clock waveform: ONE STEP OF MISALIGNMENT at 002027

Recorded 01-SEP-2026 with `PER_CLOCK=1` (one entry per clk_cpu, not one per
microcode address), same trigger and format on both machines.

`002026` is BYTE-IDENTICAL on both - 8 clocks, same aux sequence, terminate at
clock 7. The first difference is the very next microinstruction:

| | golden | board |
|---|---|---|
| 002027 | **1 clock** (003577) | **2 clocks** (003577, 003576) |
| 001006 | 17 clocks, starts 003576 | 17 clocks, starts 003574 |

The board spends ONE EXTRA CLOCK at 002027. After that the cycle state runs
exactly one step behind the microcode address - the board's 001006 begins at
003574 where the golden begins at 003576, the identical sequence shifted by
one.

That shift is what makes the 1.89x:

```
golden:  01007:003416  01010:163437 01010:003416  01011:163437 01011:002456  01012:002477 ...
board:   01007:163437 01007:003416  01010:163437 01010:003416  01011:163437 01011:003416  01012:163437 01012:003416  01013:002477 ...
```

The golden enters a LONG cycle at 001012 (002477 begins an 8-clock sequence).
The board does not - it keeps running 2-CLOCK cycles through 001007, 001010,
001011 and 001012, terminating on every second clock, and only starts its long
cycle one microinstruction later at 001013.

**So this is not "cycles are shorter" in general. The microsequencer and the
cycle controller are ONE STEP OUT OF ALIGNMENT**, so the cycle controller keeps
ending short cycles where it should be running a long one. The 1.89x terminate
rate is the consequence, not the cause.

### The reference was audited, and it holds

Before trusting "the board takes an extra clock", the SIMULATOR was checked for
sim-vs-FPGA differences that every board would share. TWO were found, both real:

1. **OSC.** `IO_DCD_38.v` builds OSC as a combinational decode under
   `VERILATOR_SIM` and as a clean clock net (`s_XTAL1`) on FPGA. OSC clocks the
   AM29C821 delay chain and PAL_44403C (DLY0/DLY1), so a phase difference there
   would move cycle timing.
2. **STAT3.** `IO_37.v` adds a console-traffic "conkick" pulse to STAT3 under
   `VERILATOR_SIM` that NO FPGA board has. Its own comment says that pulse
   "only turns fatal with real FPGA timing" and that the FPGA branch "is what
   removes the phantom-level-10 wedge on silicon" - i.e. exactly the
   panel/interrupt area this investigation kept landing in.

Both are now forceable in a sim build:

```bash
EXTRA_VDEFINES='... -DND120_FORCE_FPGA_OSC -DND120_FORCE_FPGA_STAT3'
```

**With both forced the golden window is UNCHANGED** - 002026 eight clocks,
002027 one clock, 001006 starting 003576. So neither explains the board's extra
clock, and the divergence is genuinely MiSTer's.

Also ruled out by the reports, not by argument:
- Timing is met and `Unconstrained Clocks = 0` (the unconstrained entries are
  I/O pins, not internal register paths), so this is not a hidden violation.
- Physical synthesis touched `CYC_36` only to DUPLICATE `CC0_reg` for
  routability - functionally neutral, no retiming or deletion.
- `CPU_CS_ACAL_17.v` once had a sim-only latch branch in exactly this path; it
  was DELETED 18-AUG-2026 and there is now one implementation.

**Next:** find what makes 002027 take an extra clock. Both machines are in the
same microcode with the same inputs up to that point, so the candidates are
the clock-enable generation in `CYC_36` (FPGA_FF_MODE: `CLK_EN`, `MCLK_EN`,
`ALUCLK_EN` and their FALL counterparts) and the microsequencer's own advance
(`CGA_MIC`, whose `MCLK_EN`-gated registers step the address). One of the two
domains is taking an extra clock to advance on this board.

## The open question

What calls this chain, and why it never exits. The next probe should capture
the microcode addresses IMMEDIATELY AFTER RESET (the boot path) rather than
the steady-state loop, so the point where the board first leaves the path the
sim takes can be found by diffing against `runSim/csa_trace.csv` from cycle 0.
`nd120_csa_trace.v` currently keeps the LAST 128 transitions; a capture-once-
from-reset mode is the change needed.
