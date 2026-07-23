# HANDOFF — nd100x floppy DMA controller: align to the ND-11.021 manual

**For:** whoever owns the nd100x emulator C source.
**Target files:** `nd100x/src/devices/floppy/deviceFloppyDMA.c` and `.h`
(the **DMA** controller, device octal 1560 — NOT `deviceFloppyPIO.*`).
**Authority:** the ND-11.021.01 controller manual (3106/3112). Full verified
layout quoted in `nd-120/Verilog/docs/floppy-3112-register-spec-ND-11.021.md`.
**Rule:** every change below is grounded in a quoted manual section — no guessing.
Verify each against the manual before applying.

The equivalent fixes have already been applied and tb-verified in the Verilog
core (`nd-120/Verilog/ND-BUS-DEVICES/FLOPPY-DMA/circuit/ND_FLOPPY_DMA.v`); this
handoff brings the C model into line with the same manual.

---

## Root cause: the C model conflates TWO distinct status words

The manual defines two *different* status words. nd100x (and the old Verilog)
merged them into one `StatusRegister1` value used for both the IOX read and the
memory writeback. That merge is the source of the M2/M3 defects below.

- **HARDWARE STATUS WORD** — returned by `IOX +2` AND `IOX +4` (manual §3.7;
  §3.1 Note 1: *"Reading either status gives the same result. They are
  duplicated to make it possible for microprograms in the ND-100 CPU to perform
  both Binary Format Load and Mass Storage Load (1560x and 21560)."*).
  Layout: b1 RFT/int-enabled, b2 device active, b3 ready-for-transfer,
  b4 OR-of-errors, b6 streamer active, b7 hard error, b14 streamer interface,
  **b15 = Dual density controller (always 1 — how SINTRAN detects the 3112)**.
  **It carries NO numeric error code.**
- **STATUS WORD 1** — written back to the command block at **CB+6 in memory**
  (manual §3.4). Layout: b4 OR-of-errors, b5 deleted record, b6 retry,
  b7 hard error, **b8 not used, b9-14 error code, b15 not used**. §3.9:
  *"These error codes are given in bits 9-15 of status word 1."*
  **The numeric error code lives ONLY here, never in the IOX register.**

---

## FIX 1 (M2) — error code is at bits 9-14, not bits 8-14

`deviceFloppyDMA.h`, the `StatusRegister1` bitfield (≈ lines 313-322) currently:
```c
uint16_t hardError    : 1;  // Bit 7
uint16_t errorCode    : 7;  // Bits 8-14   <-- WRONG (starts at bit 8)
uint16_t dualDensity  : 1;  // Bit 15
```
The manual (§3.4 table: bit 8 "Not used", error code bits 9-14, bit 15 "Not
used") requires the code to start at **bit 9**. RetroCore C# already does this
(`errorCode << 9`). Corrected memory Status Word 1 layout:
```c
uint16_t hardError    : 1;  // Bit 7
uint16_t notUsed8     : 1;  // Bit 8  (Not used)
uint16_t errorCode    : 6;  // Bits 9-14  (all documented codes <= oct 77 = 63 fit in 6 bits)
uint16_t notUsed15    : 1;  // Bit 15 (Not used — NOT dual density in the memory word)
```
Every `status1.bits.errorCode = X;` assignment then lands at bit 9 automatically.

---

## FIX 2 (M3) — IOX +4 must return the hardware status word, NOT status-word-2

`deviceFloppyDMA.c`, `FloppyDMA_Read` (≈ lines 120-128) currently:
```c
case FLOPPY_DMA_READ_DATA:    value = 0x1; break;         // +0
case FLOPPY_DMA_READ_STATUS1: value = CalculateStatusRegister1(self); break; // +2
case FLOPPY_DMA_READ_STATUS2: value = data->status2.raw; break;  // +4  <-- WRONG
```
Per §3.1 Note 1 / §3.7, `+4` returns the **same hardware status word as +2**, not
the format word. The format word (status word 2) is delivered only in memory at
CB+7 (the driver reads it there: `FDRI2` does `LDA 3COMF+7`). Fix:
```c
case FLOPPY_DMA_READ_STATUS2: value = CalculateHardwareStatusWord(self); break; // +4 == +2
```
(`data->status2` as an IOX-readable register is dead anyway — it is never
populated in the C model. Keep populating the command-block CB+7 writeback with
the format word; only stop exposing it at IOX +4.)

---

## FIX 3 (the split) — separate the hardware status word from Status Word 1

Introduce two builders instead of the single `CalculateStatusRegister1`:

- `CalculateHardwareStatusWord()` → used by IOX +2 and +4. Sets **bit 15
  dual-density** and the OR-of-errors/active/ready/hard-error flags, **omits the
  numeric error code** (§3.7).
- `CalculateStatusWord1()` → used only for the **CB+6 memory writeback**
  (`ExecuteFloppyGo` end ≈ line 603, and `ReadEnd` ≈ lines 630-631). Sets the
  **error code at bits 9-14**, leaves **bit 15 clear** (§3.4).

Today both the +2 read (line 124) and the CB+6 writebacks (603, 630) call the
same `CalculateStatusRegister1`, which is why dual-density leaks into the memory
word and the error code leaks into the IOX word. After the split:
- IOX +2/+4 → `CalculateHardwareStatusWord()`
- CB+6 writebacks → `CalculateStatusWord1()`

---

## Do NOT change (nd100x already matches the manual here)

These are correct in the C model — leave them (they are the points where
RetroCore C# is *wrong*, per the cross-check):
- **Write-protect enforcement** on WRITE → error oct 16 (§ error table). Keep.
- **bit 4 "OR of errors"** computed on status reads (§3.4/§3.7). Keep.
- **Command completion** for IDENTIFY and unknown/default commands (queues
  `ReadEnd`, fires the interrupt). Keep.
- **Real error-code enum values** (DRIVE_NOT_READY=oct 20, etc.). Keep — these
  match §3.9. (RetroCore is missing FORMAT_NOT_FOUND=8, WRITE_PROTECTED=14,
  RAM_ERROR=57; nd100x has them.)

---

## Known open items (note, do not silently "fix")

- **+0 idle read value.** Manual gives NO idle constant for `+0`. The only
  documented behavior: after a bus/DMA hard error, `+0` holds status word 1. The
  current `0x1` (and RetroCore's `0x1` with a `0x0F` TODO comment) are
  un-sourced guesses. Leave `0x1` unless the 3112 test/boot microcode proves a
  value. Do NOT invent.
- **Status word 2 bit layout (§3.5.2.2).** The manual puts bytes/sector at
  bit 1, double-sided bit 2, double-density bit 3, 5.25" bit 4, 96tpi bit 6,
  selected unit **bit 9**, sector/track bit 12. The C model uses bytes/sector at
  bits 0-1 and unit at bits 8-9. If you want full §3.5.2.2 conformance, remap;
  otherwise flag it as a known deviation. (The Verilog left this as a documented
  follow-up too, because it is tied to the media-format input contract.)

---

## How to validate

There is no standalone unit test for the nd100x floppy DMA. Validate by:
1. Booting SINTRAN / running the floppy driver `BFDIS` and confirming it reads
   the error code from the CB+6 memory word (bits 9-14) and detects the DMA
   controller via IOX +2 bit 15.
2. Cross-checking bit-for-bit against the corrected Verilog core and its
   passing testbench (`nd-120/Verilog/ND-BUS-DEVICES/FLOPPY-DMA/sim/
   nd_floppy_dma_tb.v`, verdict `TB_RESULT: PASS`), which now asserts: error
   code at bits 9-14 in CB+6, `+4 == +2` hardware status word, dual-density on
   the IOX word only (clear in CB+6).
3. Confirming RetroCore C# `NDBusFloppyDMA.cs` agrees on FIX 1 and FIX 2 (it
   already does: `errorCode << 9`, and `+4` falls through to the status-1 copy).

---

## Reference: the full octal error-code table (§3.9), for completeness
```
00 OK   05 CRC   06 sector-not-found  07 track-not-found  10 format-not-found
11 diskette-defect  12 format-mismatch  13 illegal-format  14 single-sided-inserted
15 double-sided-inserted  16 write-protected  17 deleted-record  20 drive-not-ready
21 controller-busy-on-start  22 lost-data  23 track-zero-not-detected  24 VCO-freq
25 microprogram-out-of-range  26 timeout  27 undefined  30 track-out-of-range
32 compare-error  33 internal-DMA  40 bus-error-cmd-fetch  41 bus-error-status
42 bus-error-data  43 illegal-command  44 word-count-not-zero  45 illegal-completion
46 addr-reg-error  50 no-bootstrap  51 wrong-bootstrap  53 error-during-autoload
60-67 streamer  70 PROM-checksum  71 RAM  72 CTC  73 DMA-CTRL  74 VCO  75 floppy-ctrl
76 streamer-data-reg  77 ND-100-register   (01-04, 31, 34-37, 47, 52, 54-57 unused)
```
