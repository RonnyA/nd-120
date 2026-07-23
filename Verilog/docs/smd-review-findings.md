# Adversarial review: ND_SMD vs nd100x deviceSMD (12-JUL-2026)

RTL: ND-BUS-DEVICES/SMD/circuit/ND_SMD.v (octal 1540, ident 017, lvl 11).
TB: ND-BUS-DEVICES/SMD/sim/nd_smd_tb.v.
Reference: /mnt/e/Dev/Emulators/ND/nd100x/src/devices/smd/deviceSMD.{h,c}
(CONTR_SMD_15MHZ, hasFlipFlops=true), geometry diskSMD.c;
docs/nd100x-device-semantics.md. Backends: tb disk model +
simDevices/NDBus.cpp process_verilog_smd. Read-only review; verified
both sides. Companion: docs/floppy-review-findings.md.

VERDICT: the register skeleton and happy-path M0/M1/M4 DMA engine are
real and tested, but the controller is a boot demo. About half the
reference register semantics are hardwired zeros, three status error
bits can never assert, two declared registers are dead, dma_err is
wired and never read, and the block-address-to-image mapping is an
INVENTED linear formula no SINTRAN driver will produce. The 1540& mass
boot is the only end-to-end faithful path.

## CRITICAL

C1. WORD COUNT = 0 transfers ~65536 words: destroys 64K of ND memory
    (M0 read) or 128KB of the disk image (M1 write).
    ND_SMD.v:326-336 loads chunk=0 with no guard; E_MEM_WR :390-412
    DMA-writes before any count check, decrements 0 -> 65535, refills
    1024-word chunks until wraparound; same wrap in E_MEM_RD/E_DISK_WR
    writes the wrapping stream TO THE IMAGE. Reference: while
    (wordCounter > 0) - WC=0 moves nothing (deviceSMD.c:912,942).
    The FUN diagnostic pokes odd word counts. NOTE: sibling
    ND_FLOPPY_DMA.v:404-408 HAS the != 0 guard - SMD skipped it.

C2. Block-address geometry is INVENTED. Reference: BA1 = {head[15:8],
    sector[7:0]}, BA2 = cylinder; LBA = (C*heads + H)*spt + S; 75MB =
    512 w/sector, 5 heads, 18 spt, 823 cyl (deviceSMD.c:838-844,
    1161-1171; diskSMD.c:36-48). ND_SMD exports raw blkaddr1/2
    ("backend owns geometry") - and BOTH backends implement
    word = BA2*2048 + BA1*64 (nd_smd_tb.v:196, NDBus.cpp:490-491),
    matching no SMD that ever existed and not the nd100x image layout.
    Anything beyond cylinder 0 lands in the wrong image position -
    silent wrong data / silent pack corruption on write. The tb's
    "real 75MB image" phase validates the invention against itself.
    Mass boot works only because it starts at BA1=BA2=0.

C3. dma_err accepted as SUCCESS. ND_SMD.v:94 declares the port; it is
    never read. ND_DMA_MASTER asserts dma_err WITH dma_ack on timeout,
    so failed words count as delivered; transfer completes clean with
    corrupt data. Reference raises error status and aborts. (Floppy DMA
    checks dma_err at :376; SMD does not.)
    RESOLVED 12-JUL-2026: both DMA states (E_MEM_WR, E_MEM_RD) now check
    dma_err with dma_ack and, on a fault, set s_hw_err (status bit 7,
    "hardware error / no memory contact", which ORs into bit 4) and abort
    to E_DELAY - mirroring disk_err_in handling and floppy's :376 check.
    A fresh command clears s_hw_err (recovery). Proven by nd_smd_tb test 7
    (mem_stall -> DMA master timeout -> bit 7 + bit 4 asserted, then a
    normal transfer succeeds with the bit cleared); TB_RESULT: PASS.

## MAJOR

M1. Seek Condition register (+2, CWR=0) FABRICATED: returns
    {0, on_cyl, 14'0}. Reference (deviceSMD.h:183-194, .c:176-252):
    b0-7 seekComplete per unit, b8-10 unitSelected, b11 seekError,
    b12 ALWAYS 1 for 10/15MHz SMD (the bit SINTRAN M uses to decide
    whether to r/w/boot DISC-75-1!), b13-15 ECC flags. No on-cylinder
    bit exists there; Verilog's bit 14 is ECC parity in the reference.
    No seek-complete tracking exists in the module at all.
M2. Status b6 timeout / b8 address mismatch / b10 compare error /
    b13 UNIT NOT READY hardwired 0 (ND_SMD.v:140-142); s_illegal (b5)
    is a dead register (only ever assigned 0). Reference maps almost
    every error to b13; bounds-checks addresses; flags load-while-
    active. All Verilog errors collapse into b7+b4.
M3. 24-bit core address / word count double-write flip-flop protocol
    (hasFlipFlops=true) MISSING: single 16-bit registers; high address
    only via control b5-6 (the OLD non-flip-flop controller behavior,
    deviceSMD.c:463-468). Documented two-write sequence gets its high
    byte clobbered. Reads never return high parts. Max 64KW vs 16MW.
M4. Device Clear near-opposite: reference zeroes addr/count/blkaddr,
    sets seekComplete, readyForTransfer=FALSE; Verilog keeps registers,
    sets rft=1 (ND_SMD.v:307-314 vs deviceSMD.c:474-497).
M5. Control write while active processed instead of ignored (reference
    early-returns): CWR/unit change mid-transfer redirects the register
    map and disk_unit mid-flight (ND_SMD.v:300-306 vs .c:417-419).
M6. ECC subsystem zero-stub with WRONG constants: pattern must read
    >= 0xB800 (b11-13,b15 always 1; b14=0 identifies 10/15MHz); ECC
    Control b1 forces parity error (FILE-SYS-INV uses it). Verilog
    reads 0/0 and ignores the write (ND_SMD.v:178,180,358).

## MINOR
m1. Count Memory Address: increments unconditionally, no word-counter
    decrement, missing testMode && marginalRecovery gate.
m2. testMode (b3) / marginalRecoveryCycle (b10) never latched or used.
m3. Status b4 OR-composition wrong set (includes b7 analog, excludes
    illegal/timeout/compare/mismatch/seekError).
m4. M4 sets on-cylinder DURING the GO cycle (FUN transcript treats
    "immediately on-cyl" as an error; C model equally sloppy).
m5. Unit select: reference masks to 4 units + DRIVE_NOT_SELECTED; both
    backends ignore SDISK_UNIT - all 8 units are one image.
m6. RFT not set on plain control writes (reference sets it on every).
m7. Header LIES: claims M6 seek-complete-search and M9 select-release
    implemented; both are the default stub (:49 vs :350). Boot-mode
    "restored by device clear" claim also false.

## STUB INVENTORY
S1 b6 timeout: constant 0, dma_err unread (C3/M2).
S2 b8 addr mismatch + bounds check: constant 0.
S3 b10 compare + M3 compare op: constant 0; M3 delay-only.
S4 b13 unit-not-ready (the PRIMARY error bit): constant 0.
S5 b5 illegal load: dead register.
S6 s_op: write-only, never read.
S7 s_errint_en: echoed in status, raises nothing (C equally hollow).
S8 ECC count/pattern/control: 0 / wrong 0 / ignored.
S9 M2 read-parity, M5 format, M8 run-ECC: self-declared clean stubs.
S10 M6/M9: stubbed but header claims implemented.
S11 Seek-condition register: fabricated single bit.
S12 24-bit flip-flop protocol: absent.
S13 testMode/marginal recovery: control bits dropped.
S14 CHS geometry: punted to backends that also punt (C2).
Grep sweep: only self-admissions are ND_SMD.v:50/:350, floppy's
documented mirrors; SMD's stubs are SILENT hardwired constants.

## disk_* CONTRACT GAPS
(1) blkaddr semantics unowned (C2). (2) done/err pulse width unstated
(tb 1 cycle, NDBus 2 ticks). (3) linear chunk advance assumed; CHS
rollover nobody's job. (4) single err bit vs 9 reference error codes;
NDBus read-only fopen fallback makes write-protected writes report
SUCCESS. (5) disk_unit consumed by no backend. (6) zero-wordcount
chunks: the two backends already disagree. (7) dbuf_rdata combinational
1024-word read - distributed RAM on FPGA, synthesis check needed
(floppy same pattern).

## 1540& BOOT
Reference has no register-level boot (SMD_Boot is a host-side cheat);
the Verilog boot mode is ORIGINAL DESIGN validated only empirically vs
the microcode (test-smd-boot). Coherent on the happy path. Fragile:
+0 read increments bootptr/clears rft unconditionally (double read or
pre-activate read desyncs silently); +0 at bootptr==1024 serves stale
buffer[0]; +3 activate during in-flight fetch clobbers s_blkaddr1;
boot mode unrecoverable after any control write.

## INTERRUPT/IDENT: faithful (pending = int_en && rft, IDENT 017
clears int-enable). errint decorative (reference parity).

## TESTGAP - nd_smd_tb.v never exercises
1 any error path (disk_err_in forever 0, dma_err never provoked, no
  status-error assertions); 2 WC=0 (would catch C1), WC>64K, WC not
  sector-multiple; 3 load-while-active, control-while-active, device
  clear AT ALL; 4 unit != 0, unit with no image; 5 CWR=1 reads, ECC
  writes, Count Memory Address, test mode; 6 M2/M3/M5/M6/M8/M9 even as
  stubs; 7 seek-condition contents / seekComplete across M4/M6/RTZ;
  8 24-bit double-write/read protocols; 9 boot-mode abuse (double read,
  chunk-boundary read, +3 during fetch, read before activate);
  10 interrupt clear via b0=0, IDENT pass-through, two-device chain;
  11 read-only image write (reports success); 12 tb line 426 asserts a
  FABRICATED bit - a test that enshrines a stub.

## RECOMMENDATIONS (in order)
1. C1 + C3: mechanical guards (copy floppy's !=0 gate; dma_err ->
   timeout b6 + abort). Data-destroying otherwise.
2. C2: decide where CHS lives, implement the reference LBA formula on
   ONE side of the contract, re-point the real-image tb at
   reference-computed positions.
3. M1/M2 error/status bits before any SINTRAN-from-SMD attempt
   (driver decisions hang off b13/b8/seek-condition bit 12).
4. Fix the header (m7) or the code - the file's own doc overstates
   what exists: exactly the half-finished pattern under review.
5. Error-path/device-clear/CWR=1 tb phases (TESTGAP 1-5), registered
   in tests/run_all_tests.sh.
