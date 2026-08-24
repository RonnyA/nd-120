> # SOLVED 24-AUG-2026 - this document is a HISTORICAL RECORD
>
> The ERRFATAL page-fault investigation this file belongs to is **closed**.
> Root cause: the memory bank was decoded from the wrong side of the bus
> transceiver (`ND3202D.v:533`). On an incoming DMA write the board drives
> nothing and that net idles all-ones, so every transfer decoded to BANK0 -
> disc data landed at the right ROW in the wrong BANK, the CPU fetched zeros
> from a page nothing had written, executed them as STZ and halted in
> ERRFATAL after exactly 143 s on every boot.
>
> **SINTRAN III now boots on the Tang Nano 20K.**
>
> Anything below describing the fault as open, or naming a suspect, is
> superseded. The measured trail and the theories that were REFUTED are in
> `PLAN-pf-campaign-prio.md`; the regression guard is `make test-bdbank`.

# Handoff: the IIC-7 / IDENT PL10 line of work is RETRACTED (Verilator-only)

**Repo path:** `Verilog/fpga/tang-nano-20k/HANDOFF-iic7-verilator-only-retraction.md`
**Date:** 23-AUG-2026
**Status:** closed as a dead end. One real but unrelated bug fixed and committed.
**Active line of work is unchanged:** `PLAN-zero-read-nonresident-page.md`

External files live outside the repository and are referenced through
`$ND120_ORACLE_DIR` (the directory holding `nd120_win.trc`, `oracle_full.trc`,
`win_console.log`, `disdrv`, `oracle_pc_histogram.txt`).

---

## 1. The one-line rule this cost us

**Before building anything on a Verilator trace, read that run's console log.**

`$ND120_ORACLE_DIR/nd120_win.trc` is a 17,179,489-row trace from reset. It looks
authoritative. Its console log `$ND120_ORACLE_DIR/win_console.log` is **7 bytes** -
just the `#20500&` echo. That run never printed the SINTRAN banner and never
printed ERRFATAL. It was failing earlier, and differently, than the board.

A whole root-cause chain was built on it before anyone checked. `wc -c` on the
console log would have killed it in five seconds.

## 2. What was claimed, and why it was wrong

Claimed: SINTRAN's level-14 handler dispatches through a jump table at 073110
(`RADD SA DP`, `P = 073111 + A`); the oracle takes index 3 (Page Fault) on
125/125 traps, we arrive with A=7 (IOX Error) and land on 073120, which the
oracle never executes, leading to `013xxx` -> TBREA `0062xx` -> ERRFATAL.

Measured in `nd120_win.trc` and genuinely true **of that run**:

| | oracle | that Verilator run |
|---|---|---|
| `IDENT PL10` (143604) | 473, all return A=1 | 68, all return A=0 |
| IIC at 073013 = 1 / 3 / 7 | 742 / 125 / 0 | 46 / 52 / 68 |

Wrong because: **the Tang has always reported IIC 3, Page Fault - never IIC 7.**
The board's halt signature is identical across every capture taken, before and
after the fix below:

    System malfunction. Sintran halt in ERRFATAL. L-reg: 072627
    Current page index tables (NPIT/APIT): 000012 / 000007
    Level: 000016
    Perror: 064406
    Level : 000001
    IIC   : 000003      Page Fault
    PES   : 000000  Err Code: 000000  Bank: 000000

## 3. The bug that WAS found (real, committed, does not fix the boot)

Commit `eb411d0` on branch `nd-bus-seam-gate`, one line in
`Verilog/CPU-BOARD-3202/circuit/ND3202D.v`:

    -  assign s_ibint10_n =(s_binput_n_out & s_binput_n_in);
    +  assign s_ibint10_n = s_bint10_n;

Line 823 was a copy of the `s_ibinput_n` line above it, so the CPU's level-10
interrupt request was driven by `BINPUT~`, the ND-bus data-transfer handshake -
every bus read raised a level 10. The correct source, `s_bint10_n` (line 464,
C-plug `BINT10~` AND the IOC's level-10 output), was assigned and never read: a
dead net. Levels 11/12/13/15 already take their own `s_bint*_n` at line 953.

Verified by reading, end to end: `ND_BUS_SLAVE` drives `BINPUT_n=0` on every
read -> `ND120_CORE.v:969` wired-AND -> `:1029` -> `ND3202D.v:489` -> `:823` ->
`:745 .IBINT10_n` -> `CPU_15` -> `CPU_PROC_32` -> `CPU_PROC_CGA_33` CHIP_34G
D[7] -> CGA_INTR -> level-10 request.

Built (gowin_build.ps1 -Variant slow), flashed, booted `20500&`.
**Result: byte-identical ERRFATAL.** Keep the fix - it is correct - but it is
not this bug.

## 4. Things measured along the way that are worth keeping

* `IOXT` is opcode **150415**, not 143700. Searching 143700 finds nothing and
  makes it look as if neither machine touches the console.
* The oracle's console driver at 057155-057161 runs 473 times at PIL 10 and
  enables the output interrupt with `IOXT 307`, A=1. The failing Verilator run
  never executes that code at PIL 10 at all.
* PIL histogram over the same first 17,179,489 rows - ours vs oracle: PIL 0
  12.24M/13.14M, PIL 1 2.00M/2.13M, PIL 2 1.36M/1.42M, PIL 3 118k/252k, PIL 10
  73.9k/35.4k, PIL 11 50.4k/93.7k, PIL 13 1.26M/57.1k (RTC ~22x too fast),
  PIL 14 78.7k/19.2k.
* `s_bint10_n` was the only dead interrupt net in `ND3202D.v`; a sweep found
  only four other unread wires, all `s_cyc_*_en` spares from the FF-mode work.
* `IO_37.v:297-300` - the IDB source MUX `default:` branch ORs all four IO_37
  sources for every CSIDBS code not explicitly listed, including `IDBS,ALU`.
  The mux's own comment says the OR-bus "caused contamination". **Latent, not
  yet shown to bite.** Candidate fix `default: s_idb_mux = 16'b0;` - the
  explicit cases (16/37/20/21/26/35/27) already cover all four sources; ECSR
  (24), EPEA (12) and EPES (13) come from the MEM and BIF contributions.
* `Shared/support/TTL_74273.v:43` - `always @(posedge CLK) //or negedge CLR_n`.
  The asynchronous master reset is commented out, so the IOC register can only
  be cleared by a `CLEAR_n` that coincides with a `SIOC` strobe. On a real
  74273 that pin is asynchronous. **Latent, untested.**
* `CGA_INTR_IRSRC.v` - `BINT10..13` land on `IREQ[0..3]` while `BINT15N` lands
  on `IREQ[15]`, and IOXERR/PARERR/MOR/POWFAIL sit on 10..13. The existing tb
  header flags this as "CHARACTERISED, not judged". The PIL histogram above
  **refutes** the reading that `BINT10..13` produce PIL 0..3 (those levels are
  not inflated), so there is a remap somewhere that nobody has located. Leave
  it alone until someone reads the drawing.

## 5. Where to pick up

`PLAN-zero-read-nonresident-page.md` is still the live plan: the board takes a
genuine page fault at Perror 064406 on a page the oracle pages in normally.
Nothing in this handoff changes that.
