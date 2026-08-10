# HANDOFF - SMD disc controller (1540), 01/02-AUG-2026

All paths in this file are relative to the repository root (the directory
holding `Verilog/` and `NorskData-Doc/`).

**OWNERSHIP (02-AUG-2026): the SMD controller has been handed to a separate
session**, working with the Pi Pico C-code side that is checking the nd100x
oracle against ground truth. That session owns
`Verilog/ND-BUS-DEVICES/SMD/circuit/ND_SMD.v` and
`Verilog/SD-FAT/circuit/nd_storage_disc_adapter.v` from here on. The fixes
described below are already in the working tree and should be left in place.

Everything described here is **in the working tree and uncommitted**. Nothing
is on silicon: the Tang bitstream flashed on 01-AUG 11:20 predates every fix
below.

## Where this started

Ronny ran TPE's DISC-TEMA J02 disc diagnostic against the SMD on the Tang and
every read failed:

```
***ERROR*** DISC-75MB-1 Unit 0
Hardware Status: 020001b   Disc unit not ready / Not on cylinder
Additional Status: 100000b Controller not active after activate
Operation was: Read        (data all zeros, sector 0, 1, 2, ...)
```

## What was found and fixed (all verified in simulation)

**1. The controller finished operations far too fast - THE root cause of
"Controller not active after activate".**
`DELAY_TICKS` (how long the controller holds ACTIVE after a GO) was 10 sysclk,
copied from the oracle's `IODELAY_HDD_SMD = 10`, which is a coarse
device-manager tick in nd100x, not ten clock cycles. That is ~1.5 us; DISC-TEMA
reads the status a few thousand clocks after activating and correctly concludes
the controller never took the command, because no real drive can be finished.

Fixed as a TIME, not a tick count. `Verilog/ND120_CORE.v` derives
`DEV_CLK_HZ` from `` `BOARD_CLK_FREQ `` (fallback 100 MHz, the same one
`DECODE_DGA_POW` uses) and computes

```verilog
localparam integer SMD_DELAY_MS    = 8;
localparam [31:0]  SMD_DELAY_TICKS = (DEV_CLK_HZ / 1000) * SMD_DELAY_MS;
```

8 ms is close to the real mechanical figure (a 75 MB SMD at 3600 rpm averages
8.3 ms of rotational latency; seeks are tens of ms). That is 54,000 cycles at
the Tang's 6.75 MHz bring-up clock, 216,000 at 27 MHz, 27,000 in crawl,
800,000 in the Verilator sim. `DELAY_TICKS` in `ND_SMD.v` was widened to 32
bits for it; the module default stays 10 so the unit testbenches stay fast.

**2. Boot mode discarded `+1` and `+7` writes**, so `21540&` could never work:
the mass-storage microroutine at CSA o2217 writes `+1`, `+1`, `+3`, `+7`, `+5`,
then polls `+4`. A `+1` or `+7` write now takes effect AND leaves boot mode
(the BPUN byte-server never writes those registers).

**3. The first boot fetch reported ready while the fetch was in flight.** Only
the wrap-around fetch dropped `s_rft`. Harmless in sim (the C backend fills the
buffer instantly) but real on the Tang, where the SD backend is slow.

**4. Status bit 11 now reports a DMA channel error** - the name the oracle's
own status union gives bit 11, reserved there because its transfer is a memcpy.
Set only on the `dma_err` paths, cleared by reset and device clear, kept OUT of
the inclusive-OR (bit 4) to match the oracle's `hardwareError`. Purpose: on the
next silicon run the residual failure reports `024001` if the ND bus/memory DMA
faulted, `020001` if the SD/image side did.

**5. `make test-smd-boot` could never terminate.** `Run120.cpp`'s main loop is
`while (true)` and the `[binload] RAM check` line the gate greps for prints only
after that loop exits, which requires `ND120_MAX_CNT`. The floppy stdin gate set
it; the SMD gate did not - that, and nothing else, is why it once ran for six
hours. Added `ND120_MAX_CNT=120000000`; the gate now passes and was added to
`test-full`.

## Evidence

Reproduced the silicon failure in Verilator and then removed it. Before:

```
GO   WR +5 val=010005      (activate, device operation 2 - its spare-track test)
     RD +4 -> 040011       active=0 already -> "Controller not active"
```

After (`disc-tema-du-di-c.trace`):

```
cyc=516256519  WR +5 val=010005
cyc=516256623  RD +4 -> 040005    active=1
   ... six polls, all active=1 ...
cyc=517116076  RD +4 -> 040011    completed
```

No error; DISC-TEMA proceeds to its next prompt.

Gates: `test-smd`, `test-smd-iox`, `test-smd-p2` all `TB_RESULT: PASS`;
`make test-smd-boot` PASSES (`1540&` BPUN-booted and EXECUTED the program).

## Files touched

| File | Change |
|---|---|
| `Verilog/ND-BUS-DEVICES/SMD/circuit/ND_SMD.v` | boot-mode `+1`/`+7`, first-fetch ready, status bit 11, 32-bit `DELAY_TICKS`, `ifdef ND120_SMD_TRACE` |
| `Verilog/ND120_CORE.v` | `DEV_CLK_HZ` + `SMD_DELAY_MS`/`SMD_DELAY_TICKS`, passed to the SMD instance |
| `Verilog/Makefile` | `ND120_MAX_CNT` in `test-smd-boot`; gate added to `test-full` |
| `Verilog/ND-BUS-DEVICES/SMD/sim/nd_smd_tb.v` | (earlier session) |
| `Verilog/ND-BUS-DEVICES/SMD/sim/drive_console.py` | NEW - drives the OPCOM console through a command list |
| `Verilog/ND-BUS-DEVICES/SMD/sim/traces/*.trace` | NEW - captured ground-truth IOX transcripts |
| `Verilog/docs/ANALYSIS-smd-disc-tema-not-ready.md` | NEW - full analysis |
| `NorskData-Doc/OPCOM-Boot-Reference.md` | ALD switch-9 row corrected and made device-neutral |

## How to reproduce any of it

```
make -C runSim compile USE_LATCHES=0 VERILOG_TAPE=1 SD_STORAGE=0 \
     EXTRA_VDEFINES="-DND120_SMD_TRACE"

# DISC-TEMA against the SMD (run from Verilog/):
ND120_FLOPPY_IMG=FLOPPY.IMG ND120_SMD_IMG=<image> \
python3 ND-BUS-DEVICES/SMD/sim/drive_console.py /tmp/out.log 1500 \
    '1560&' 420 'dis' 90 'DISC-75MB-1' 120 'du-di-c' 60 '0' 700

# the mass loader:
... drive_console.py /tmp/out.log 300 '21540&' 240
```

The trace prints every register access with the state that decides its meaning
(`boot`, `cwr`, the HI/LO flip-flops) plus a sysclk counter. `$time` is useless
here - the model has no timescale and prints 0. A second line, `[SMD-OTHER]`,
logs IOX to any other device in 0400-1777, which is how the question "is
DISC-TEMA even talking to 1540" was answered (it is; the only other traffic is
the floppy at 1560-1567, TPE's own program-load path).

## OPEN - do not act without Ronny

**The controller type / single-write registers. BLOCKED ON PURPOSE.**
The mass-storage loader writes the word count with ONE `+7` write of `002000`
(1024 words). With the 15 MHz card's two-write HI/LO protocol the first write is
the HI byte, so `002000 & 0xFF` = 0 and the count stays zero - the GO then
transfers nothing. Both references model HI-first, but both switch the
flip-flops OFF for `BIG_DISC_CONTR` / `ECC_DISC_CONTR`, where a single write
loads the full 16 bits - and the RetroCore source says the ECC controller serves
the 38/75/288/150 MB drives, while DISC-TEMA tests a 75 MB unit. So this looks
like a controller-type parameter, NOT an inverted HI/LO order. Supporting that:
DISC-TEMA writes the address HI first and reads LO first, and our controller
matched it through its entire register walk.

**Ronny is having the Pico C-code side run ground-truth tests to confirm the
oracle is 100% correct before ANY further change to this RTL.** Until that
lands: no register-semantics changes, no `21540&` work. The captured traces in
`Verilog/ND-BUS-DEVICES/SMD/sim/traces/` are ground truth for what the real
ND-120 microcode and the real DISC-TEMA emit, independent of any model, and can
be used to check the C oracle.

**Silicon.** A rebuild and flash is needed for any of this to reach the Tang. It
answers the one remaining silicon question: whether the residual "Disc unit not
ready" half of the original failure is the SD/image side (`020001`) or the DMA
side (`024001`). Note also that the SMD slot on the card holds at most
2,818,048 bytes = 2752 sectors = cylinders 0..30 of the 75 MB geometry, so a
full-surface DISC-TEMA sweep will hit out-of-range errors regardless.

Also unverified: the image position mapping in
`Verilog/SD-FAT/circuit/nd_storage_disc_adapter.v` is
`blkaddr2 * 2048 + blkaddr1 * 64`, which is NOT the oracle's CHS->LBA. Block 0
is identical under both, which is why `1540&` boots and nothing caught it.
Changing it means changing three places together: the adapter, the unit-tb model
in `Verilog/ND-BUS-DEVICES/SMD/sim/nd_smd_tb.v`, and `process_verilog_smd()` in
`Verilog/simDevices/NDBus.cpp`.

## Other state from this session

- Console double-echo: NOT ours. Booting TPE in Verilator and typing `dis`
  echoes `dis`, one copy. It is local echo in the terminal program.
- Tang CPU clock: `fpga/tang-nano-20k/src/gowin_rpll_27_54.v` gives
  CLKOUT 13.5 MHz and clk_cpu = CLKOUT/2 = **6.75 MHz** for the default
  `TANG_SLOW_BRINGUP` build (27 MHz full, 3.375 MHz crawl). `s_dev_clk` is
  `clk_cpu`, so that is the SMD's clock.
- Backlog, Ronny's to start: the combined floppy+SCSI PCB (candidates 3201,
  3204, 3205, 3206, 3207) with an onboard Z80, decoding BOTH the 1560
  floppy/streamer window and the SCSI controller at 144300 - does the Z80
  service the mass-boot handshake arriving on 1560 by reading the SCSI disc?
- Testbench campaign remains PAUSED (`DECODE_DGA_COMM` partial, `BIF_BCTL_6`
  unstarted, then Tier 6).

---

## ADDED 05-AUG-2026 — a defect found in ND_WINCHESTER that ND_SMD shares

Reported here rather than fixed, because `ND_SMD.v` belongs to this session,
not to the one that found it. Nothing in `ND_SMD.v` has been touched.

### The defect

`ND_SMD.v:685-686`, in the control-word write path:

```verilog
s_active    <= iox_wdata[2];   // oracle: active = bit 2 (clear/GO override below)
s_rft       <= 1'b1;           // oracle: ready = true (top)
```

Status bit 3 — "finished with a device operation" — is asserted on **every**
control-word write, unconditionally. The GO branch further down overrides it
(`s_rft <= 1'b0; s_active <= 1'b1;`), so an activating word is safe. A
**non-activating** control word arriving while a transfer is still running is
not: it sets `active <= 0, rft <= 1`, and the card reports the operation
**finished when it has not finished**.

### Why both C models are right and the RTL is wrong

The line copies `deviceSMD.c` faithfully, and the C model is correct *there*:
its `ExecuteGO` is **synchronous**, so by the time any later control word
arrives the operation genuinely has completed and the card genuinely is idle.
"The controller stays idle and is by definition ready" is a **premise** that
holds in a synchronous model and does not hold in RTL, where an operation
occupies real time. Every place a C model asserts readiness as a side effect
of something other than completion deserves the same look.

### The same bug in the Winchester, and how it showed up

`ND_WINCHESTER.v` had the identical construct and it produced a status word no
real card can emit. Captured on silicon with `TANG_WD_TRACE_DUMP`:

```
W+5 034005   GO
R+4 060005   active            <- correct
W+5 000000   non-activating control word, mid-operation
R+4 060014   ACTIVE *and* FINISHED, both set
```

The nd100x C model's entire status vocabulary for that run is
`020010 / 020011 / 060011 / 060010 / 060005` — bits 2 and 3 are mutually
exclusive in every one of them.

Fix applied in `ND_WINCHESTER.v` (assert b3 only when the card is really idle):

```verilog
if (!s_active) s_rft <= 1'b1;
```

### Regression test to port

`ND-BUS-DEVICES/WINCHESTER/sim/nd_winchester_oracle_tb.v` carries the check,
and it has teeth — it fails on the pre-fix RTL with the exact silicon word
`060014` and passes on the fixed one with `060004`:

```verilog
iox_write(BASE + R_CONTROL, CTRL_GO);
iox_read (BASE + R_STATUS, st);
if (!st[2]) /* not active after GO - the rest proves nothing */;
iox_write(BASE + R_CONTROL, 16'o000000);   // non-activating, mid-transfer
iox_read (BASE + R_STATUS, st);
if (st[2] && st[3]) /* FAIL: no real card can report both */;
```

For the SMD the assertion differs slightly, because its GO branch overrides
`rft`: the failure there is not "both set" but "**finished asserted while a
transfer is still in flight**". Issue a GO, then a non-activating control
word, then require that the card still reports the operation as running.

### Checked and clean

`ND_FLOPPY_DMA.v` (`:408`), `ND_FLOPPY_PIO.v` (`:255`, `:264`) and
`ND_TAPE_400.v` (`:135`) only raise `s_rft` inside device-clear, completion or
reset paths, where the operation really has ended. No action needed there.
