## RESOLUTION STATUS (13-JUL-2026)

Settled against the ND-11.021.01 manual (spec: `floppy-3112-register-spec-ND-11.021.md`):
- **C1 (sector-count), C3 (partial-write tail), M1 (real error codes)** — FIXED in
  `ND_FLOPPY_DMA.v`, tb-verified.
- **M2 (error-code bits)** — RESOLVED: bits **9-14** (not 8-14). Manual §3.4/§3.9;
  RetroCore C# agrees. FIXED in Verilog.
- **M3 (IOX +4)** — RESOLVED: +4 = hardware status word (§3.7), same as +2; the
  format word is Status Word 2 at CB+7, not an IOX register. FIXED in Verilog.
  Root cause was conflating two distinct status words (hardware §3.7 vs memory §3.4).
- **M11 (+0 constant)** — NO manual basis for 1 or 0x0F; left as 1 (do not invent).
- **C2 (no-drive wedge)** — watchdog added (param, default off; needs real backend latency).
- Emulator fixes captured as handoffs: `HANDOFF-nd100x-floppy-dma-manual-fixes.md`,
  `HANDOFF-floppy-pio-c-and-csharp-fixes.md`.
- OPEN (need a backend-input contract, not bugs): Status Word 2 extra bits
  (5.25"/96tpi/sector-track, §3.5.2.2), write-protect input, streamer port.

---

# Adversarial review: Verilog floppy stack vs reference code (12-JUL-2026)

Reviewed RTL: ND-BUS-DEVICES/FLOPPY-DMA/circuit/ND_FLOPPY_DMA.v (octal
1560), ND-BUS-DEVICES/FLOPPY/circuit/ND_FLOPPY_PIO.v,
SD-FAT/circuit/nd_storage_floppy_adapter.v.
References: /mnt/e/Dev/Emulators/ND/nd100x/src/devices/floppy/
deviceFloppyDMA.{c,h} + deviceFloppyPIO.{c,h} (the stated port source);
/mnt/e/Dev/Repos/Ronny/RetroCore/Emulated.HW/ND/CPU/NDBUS/
NDBusFloppyDMA.cs + NDBusFloppyPIO.cs (richer register-level reference);
Verilog/simDevices/NDBus.cpp + NDDevices.cpp;
docs/nd100x-device-semantics.md; FLOPPY-DMA/NEVER-READY-ANALYSIS.md.
Every finding verified against both sides. Companion: SMD review report.

## CRITICAL (would break SINTRAN/boot or corrupt data)

C1. DMA command-block word 4 (OPWCH) fetched and THROWN AWAY -
    sector-count mode does not exist.
    ND_FLOPPY_DMA.v:153-159 (s_cb[4] never read; count always words,
    16-bit) vs deviceFloppyDMA.c:297-303,346-348 (w4 b15 = WC/SC select,
    SC multiplies by words/sector; w4[7:0] = count HIGH byte = 24-bit
    counts); NDBusFloppyDMA.cs identical; driver contract spelled out in
    deviceFloppyDMA.h:224-236 (SINTRAN BFDIS).
    Failure: sector-count transfer of N sectors moves N WORDS, clean
    status - silent data starvation. >64K-word transfers impossible.
    tb only ever writes 16'h8000 to w4.

C2. Selecting a drive with no adapter instance WEDGES the controller
    forever - no error, no timeout, only device clear recovers.
    Adapter nd_storage_floppy_adapter.v:209 answers only its own DRIVE
    (silence otherwise, by design); controller E_DISK_RD/:420 and
    E_DISK_WR/:499 wait on disk_done with no timeout. Drive 2/3 = one
    bad command-word bit = hang. Reference: DRIVE_NOT_READY + status
    writeback + RFT + interrupt for unattached units (NDBusFloppyDMA.cs
    ~720; deviceFloppyDMA.c:411-418). The sim harness MASKS this:
    NDBus.cpp process_verilog_floppy() ignores FDISK_DRIVE and serves
    every unit from FLOPPY.IMG - passes runSim, hangs silicon.

C3. WRITE with wordcount not a whole number of sectors commits STALE
    BUFFER contents to the tail of the last sector.
    ND_FLOPPY_DMA.v:480-496: partial chunk loads chunk words; E_DISK_WR
    always runs disk_wordcount = full sector (:237); adapter overlays
    the full sector - tail words are leftovers from the previous sector
    (or reset garbage). C# writes exactly wordsToRead*2 bytes; nd100x C
    truncates (differently wrong, but never leaks stale data).
    Real data corruption; tb writes only whole-sector counts.

## MAJOR

M1. Error codes are INVENTED (1 = CB-fetch bus error, 2 = disk error;
    ND_FLOPPY_DMA.v:378,423,503). Documented repertoire: DRIVE_NOT_READY
    = 16 (oct 20), CRC = 5, bus-error CB fetch = oct 41, etc.
    (deviceFloppyDMA.h:121-185). Also s_hard_err (b7 "no memory
    contact") raised for a plain not-ready - C sets only the code.
M2. Error-code BIT POSITION unresolved reference conflict: nd100x =
    bits 8-14 (Verilog follows); RetroCore C# = errorCode << 9 =
    bits 9-15; the ND doc block contradicts itself. If C# is right,
    every code reads doubled. Settle vs the 3112 manual (ND-11.021)
    before trusting any error path.
M3. IOX +4 three-way conflict: C# returns RSR1 duplicated at +2 AND +4
    ("to make Binary Format Load and Mass Storage Load possible,
    1560& & 21560&"); nd100x + Verilog return the format word. If the
    21560& microcode polls +4 for ready, Verilog never shows ready.
M4. execute+testMode / execute+streamer run a REAL command (only
    iox_wdata[8] checked, ND_FLOPPY_DMA.v:349-358); reference routes to
    ExecuteTest / streamer (no CB fetch). FLOPPY-STREAM/TPE test
    programs trigger stray DMA command fetches from stale pointers.
    s_test_mode is latched (:302) and never read - dead register.
M5. READ FORMAT succeeds on an unmounted drive (no not-ready path;
    disk_media_fmt defaulted 0xF = healthy 1.2MB descriptor,
    NDBus.cpp:346) and media format is ONE GLOBAL input, not per-drive
    (ND_FLOPPY_DMA.v:124) - drive 1 reports drive 0's geometry.
M6. Failed-read memory side effects match NEITHER reference: C
    zero-fills the full count and advances to the end; C# aborts before
    data DMA; Verilog aborts mid-transfer with partial last-address in
    w8/w9. Retry-from-checkpoint drivers see three different worlds.
M7. w10/w11 writeback: C/C# write wordsTransfered (=N on success);
    Verilog writes 0/s_words_left (=0). Verilog matches the FIELD NAME
    (remaining), C matches the emulator that actually boots SINTRAN.
    Deliberate decision needed, currently a silent choice.
M8. PIO: sector 0 not clamped to 1 (deviceFloppyPIO.c:354-355 vs
    ND_FLOPPY_PIO.v:309) - 1-based backend math underflows to the
    previous track's last sector, clean status.
M9. PIO autoload (b2) entirely ignored - 1560& on the PIO flavor does
    nothing (stale buffer, ready status). Documented as not ported, but
    it is a functional hole; should at least error visibly.
M10. PIO same-write control-bit ordering bugs: b5 clear-buffer +
    command latches the STALE pre-clear pointer
    (ND_FLOPPY_PIO.v:262-265 vs :280); b4 device-clear + command uses
    the OLD drive select (C deselects first -> not-ready). Drivers
    combine WCWD bits in one IOX routinely.
M11. +0 read constant = 1 (nd100x TODO value). C# comment: "0x0F at
    least allow enter-directory from SINTRAN to work"
    (NDBusFloppyDMA.cs:405). SINTRAN @ENTER-DIRECTORY may fail against
    the Verilog constant.

## MINOR
m1. Reset RFT: Verilog 1, C reference 0 (assignment commented out).
m2. Device clear clears the error code; C preserves it for post-mortem.
m3. Format 2 sector size 128 in Verilog vs 123 in both references
    (their OCR typo, almost certainly) - fmt-2 images byte-incompatible.
m4. First CB+6 writeback carries BUSY=1 (C: busy never set).
m5. CB fetch 6 words vs C's 7 (no effect).
m6. DELAY_TICKS: PIO 3000 vs DMA 300, both claiming C's IODELAY_FLOPPY
    (=300); units differ from C's IO-delay queue anyway.
m7. PIO status bits that can never assert: timeout, deleted, crc_err,
    overrun, write_prot (no WP input anywhere; NDBus.cpp read-only
    fopen fallback silently drops writes = success reported).
m8. PIO pre-drive-select error class differs (driveNotReady vs C's
    sectorMissing).
m9. "BRAM" buffers are 2-3-port ASYNC-read arrays in both controllers -
    cannot map to block RAM; ~16 Kbit LUTRAM each on the Tang. The
    adapter's s_blkbuf does it right (registered read).
m10. Boot-mode +0 read not gated by RFT: double read skips a boot word;
    read at bootptr==512 serves stale content. No reference exists
    (both emulators stub autoload) - empirically validated only.
m11. Adapter tail-block rule makes the last partial block of an
    odd-sized image silently unwritable (fine for real floppy sizes,
    trap for hand-truncated images).
m12. Harness media-format default: sizes matching neither floppy size
    report the 1.2MB descriptor; C reports 0.
m13. DMA tb line 486 self-sabotage: control word octal 420 = clear +
    EXECUTE (stray command from stale CB while tb rewrites memory).
    Works by timing luck.

## STUB INVENTORY

| # | Where | Reference behavior | Verilog behavior | Consequence |
|---|---|---|---|---|
| S1 | DMA :153-159 | w4 WC/SC + count high byte | fetched, never decoded | C1 |
| S2 | DMA :404-414 | fns 0x02 FIND_EOF, 0x05 WRITE_EOF, 0x21 FORMAT, 0x23/24 R/W DELETED, 0x2C COPY, 0x2D FORMAT TRACK, 0x2E CHECK, 0x38 IDENTIFY | no-op, clean status (C same) | FORMAT/CHECK fake success |
| S3 | DMA :302 | testMode -> ExecuteTest | latched, never read | M4 |
| S4 | DMA ctl b5 | streamer path | ignored, floppy go runs | M4 |
| S5 | DMA :141-150 | deletedRecord/retry status bits | hardwired 0 | FIND_EOF impossible |
| S6 | DMA :377-423 | error codes oct 20/41/42/43... | invented 1/2 | M1 |
| S7 | DMA :200 | +0: C TODO=1, C# hints 0x0F | constant 1 | M11 |
| S8 | DMA :47-347 | autoload = TODO stub in BOTH refs | fully invented boot server | unverified-by-reference spec; only empirical (runSim TPE) |
| S9 | DMA :124 | per-unit media info | single global input | M5 |
| S10 | PIO ctl b2 | autoload | ignored | M9 |
| S11 | PIO b6/RSR1 b8 | timeout enable/status | never set (C same) | dead diagnostics |
| S12 | PIO :104-114 | writeProtect/crcError/overrun/deleted | only cleared, no WP input | RO media "writes" succeed |
| S13 | PIO absent | C deleted-sector shadow (WRITEDEL/READID) | not ported (documented) | diagnostics fail |
| S14 | PIO absent | RSR1 "magic" bits 9-11 | not ported (documented) | FLOPPY-FU-1986F fails |
| S15 | PIO backend | - | no storage adapter exists (DMA-only, owner decision) | PIO tb-only, unusable on hw |
| S16 | adapter :139 | - | s_direct unreachable (wordcount <= 512) | dead code |
| S17 | NDBus.cpp:369-447 | drive passed to callbacks | FDISK_DRIVE ignored | C2/M5 masked in sim |

## TESTGAP (feeds the comprehensive-testbench task)

nd_floppy_dma_tb.v never exercises: sector-count mode / w4 at all;
partial-sector WRITE; zero wordcount; disk_err_in (read/write/boot);
dma_err (fetch/data/writeback); any drive != 0; data ops in fmt 1/2;
READ FORMAT 8-inch / no-media; testMode/streamer; clear-during-transfer;
boot +0 double-read / mid-chunk error / boot-after-command; 24-bit DMA
addresses; CB+8 value; error codes in CB+6. Backend answers all drives,
never errors. Line 486 stray-execute race to fix.

nd_floppy_pio_tb.v: FORMAT TRACK / WRITE DELETED / READ ID / CONTROL
RESET untested (4 of 8 commands); test regs +6/+7; b4/b5/b2 control
bits; sector 0; end-of-track auto-increment stop; pointer wrap; formats
0/1/2; track clamps; deselect b11; same-write bit combos; backend error
pulses.

nd_storage_floppy_adapter_tb.v (strongest): missing wordcount=0;
s_span>1024 guard; TWO instances OR-wired with alternating drives;
composite request for a drive with NO instance (the C2 hang has no test
and no owner); open_start racing an op; woff+wc==1024 boundary;
fmt 1/2 sector sizes.

System: runSim golden backend must become drive-aware or C2/M5 class
stays invisible; no SINTRAN @ENTER-DIRECTORY check for the +0 constant;
no BFDIS driver-sequence replay (SINTRAN J p.411); no error-code decode
check against the oct-20/41 table.

## NEVER-READY-ANALYSIS.md verification (parallel workstream)
Their F1/F2/F3 fixes are implemented and tb-covered (E_FINAL CB+6
rewrite, real s_status2, +0=1, autoload priority). Open ends: (a)
control-latch-while-busy only partial - autoload/execute during a
transfer still silently dropped (E_IDLE gates :315,:349) where C always
acts; (b) the inert harness interrupt check NDBus.cpp:238-241
((bits & 1<<11) == 1, never true) is still in the tree. Pushback: the
doc treats nd100x C as known-good, but C# contradicts it on +4 (M3),
error bit position (M2) and the +0 constant (M11) - "matches the C
model" is not "matches the 3112"; resolve against ND-11.021/ND-11.015.

## Judgement
Happy path (whole-sector word-count transfers on drive 0, 1560& boot,
READ FORMAT on a mounted 1.2MB image, completion interrupt, IDENT 021)
is faithful and well-tested. Off it: C1/C2 each break SINTRAN outright,
C3 corrupts data, error reporting (M1-M3) is unvalidated invention, PIO
has ordering bugs (M10) and no boot story (M9). The nd_storage adapter
is the soundest component; its hole is architectural (silent non-answer
for unserved drives), not internal.
