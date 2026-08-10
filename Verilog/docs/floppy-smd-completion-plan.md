# PLAN: make the floppy and SMD controllers REAL (12-JUL-2026)

Owner order: no boot demos - full, reference-faithful floppy and SMD
controllers with comprehensive testbenches and a validated boot from
SMD0. Inputs: docs/floppy-review-findings.md and
docs/smd-review-findings.md (every item below references those).
Boot via the CPU stays gated on the CPU-core bug work; everything below
the CPU gets proven at device level NOW.

## Phase 0 - ground truth + coordination (blocking items only)

0.1 OWNER RULINGS NEEDED (block phase 2's error layer, nothing else):
    (a) Error-code bit position in the floppy status writeback:
        nd100x says bits 8-14, RetroCore says bits 9-15. Settle via
        ND-11.021 (3112 manual) / SINTRAN J listing p.411 or owner call.
    (b) IOX 1564 (+4) read: format word (nd100x) or status-1 duplicate
        (RetroCore, "needed for 21560& mass load")?
    (c) Floppy +0 read-data constant: 1 (nd100x TODO) or 0x0F
        (RetroCore: "at least allows SINTRAN enter-directory")?
0.2 OWNER INPUT: SINTRAN IOX access logs - floppy (1560-1567) and SMD
    (1540-1547) - time-ordered read/write, address, value, from working
    emulator boots. Feeds the phase-3 replay testbenches.
0.3 COORDINATION: the device workstream is mid-edit in FLOPPY-DMA
    (working tree). Split: THIS workstream takes SMD (untouched by
    them), the storage adapters, the sim backend, and all new
    testbenches; floppy CONTROLLER fixes are handed to them as the
    review work order UNLESS the owner says otherwise. SMD geometry
    profile to support first: DISC-75MB (512 w/sector, 5 heads,
    18 spt, 823 cyl) - table parameterized for 30/60/288 later.

## Phase 1 - stop the data destroyers (mechanical, no rulings needed)

SMD (ND_SMD.v):
1.1 WC=0 guard (review C1): zero word count = clean completion, zero
    transfers. Copy the floppy's != 0 gate. TB case: WC=0 on M0 and M1,
    assert zero DMA words, zero disk writes, clean status.
1.2 dma_err handling (C3): any dma_err during CB/data/writeback ->
    abort, status b6 (timeout), error interrupt path. TB: provoked
    timeout mid-read and mid-write.
1.3 Device clear real semantics (M4): zero addr/count/blkaddrs, clear
    flip-flops/errors, seekComplete set, RFT=0 per reference. TB:
    clear-then-readback, clear-during-transfer.
FLOPPY (handed to device workstream unless owner reassigns):
1.4 Sector-count mode + 24-bit counts (C1). 1.5 absent-drive
    DRIVE_NOT_READY instead of wedge (C2) - controller-level answer
    (bounded wait -> not-ready) so the composite never hangs.
1.6 Partial-sector write stale-tail fix (C3).
Gate: every fix lands with a failing-then-passing registered tb case.

## Phase 2 - real geometry + real status (the de-demo phase)

SMD:
2.1 CHS geometry IN THE CONTROLLER (C2): decode BA1={head[15:8],
    sector[7:0]}, BA2=cylinder; bounds-check against the unit's
    geometry table (b8 address mismatch on violation); emit a LINEAR
    block/word index on the disk_* port (contract updated + documented;
    backend stays geometry-free). Update tb model + NDBus.cpp + the
    real-image tb phase to reference-computed positions.
2.2 Status truth (M1/M2): b13 unit-not-ready (no image/unit), b5
    illegal load (load-while-active), b10 compare + real M3 compare op,
    b6 timeout (from 1.2), b4 = reference OR-set. Seek Condition
    register real contents: per-unit seekComplete (b0-7), unitSelected
    (b8-10), seekError (b11), b12 = 1 ALWAYS (SINTRAN controller-type
    probe), ECC flags b13-15. seekComplete tracking across M4/M6/RTZ.
2.3 24-bit flip-flop protocol (M3): double-write/double-read for core
    address and word count, flip-flop reset on status read/device
    clear. 24-bit word counter and address registers.
2.4 Control-while-active rejected (M5); testMode/marginalRecovery
    latched and honored where the reference uses them (m1/m2).
2.5 ECC probe-correct stubs (M6): pattern reads >= 0xB800 with the
    generation-identifying constants; ECC control b1 -> parity-error
    status path (FILE-SYS-INV depends on it). Full ECC math stays out
    of scope - but stubs must be DECLARED in the header and
    probe-accurate, never silent zeros.
2.6 Header/doc truth pass (m7): the file header lists exactly what is
    implemented, what is a declared stub, and why.
FLOPPY (work order to device workstream): real error codes (M1/M2 +
ruling 0.1a), test-mode/streamer gating (M4), per-drive media format +
not-ready READ FORMAT (M5), writeback semantics decision (M6/M7 +
ruling), PIO sector-0 clamp / same-word ordering / autoload visible
error (M8-M10), +0 constant per ruling 0.1c.

## Phase 3 - comprehensive testbenches (both controllers)

3.1 Register-map conformance tb per controller, table-driven from the
    reference: every IOX register read/write, every command (including
    declared stubs - assert their exact stub behavior), every status
    bit assertable and asserted, every error path, device clear, units
    0-3, WC edge cases (0/1/odd/sector-multiple/24-bit max), boot-mode
    abuse cases (double read, chunk-boundary, activate-during-fetch),
    interrupt/IDENT edges (clear via b0=0, pass-through, two-device
    daisy chain).
3.2 Drive-aware, error-injecting sim backend: NDBus.cpp honors
    FDISK_DRIVE/SDISK_UNIT with per-unit images, honest write-protect
    (read-only image -> error status, never fake success), injection
    hooks (not-ready, read error, write error, timeout) reachable from
    tb plusargs. This unmasks review items C2/M5/M11-class bugs in
    runSim.
3.3 SINTRAN replay testbenches (needs 0.2 logs): drive the controllers
    with the exact recorded IOX sequences, assert the recorded
    responses. Registered as test-floppy-sintran / test-smd-sintran.
3.4 Everything registered in tests/run_all_tests.sh (TB_RESULT: PASS).

## Phase 4 - boot from SMD0, validated end to end (device level)

4.1 nd_storage_disc_adapter.v: SMD disk_* port onto one nd_storage
    client (same pattern as the floppy adapter). v1 = BOOT WINDOW:
    the client slot preloads the first 320KB of SMD0.IMG; blocks
    inside the window are served, outside -> b13-class error (declared
    limitation until Phase-4 tag caching). This makes 1540& boot from
    the CARD possible now, without pretending the 75MB image fits.
4.2 test-smd-boot-storage: replay the exact 1540& microcode boot
    sequence against ND_SMD + smd adapter + nd_storage + the C++ card
    model with a real SMD0.IMG; assert every loaded word byte-exact
    against the image. This is the owner's "validate boot from SMD0"
    unit test - CPU not involved, CPU bugs cannot block it.
4.3 Same for floppy: test-floppy-boot-storage (1560& replay through
    nd_storage_floppy_adapter + card model) - closes review TESTGAP T5
    (no test runs the DMA controller against the REAL adapter).

## Phase 5 - hardware
Tang top integration (device workstream, step 10 handoff) then 1540&
and 1560& from a real card on silicon. Full SINTRAN boot follows the
CPU-core bug work.

## Sequencing / parallelism
Phase 1 SMD starts NOW (no collisions - SMD files untouched by the
device workstream). Phase 2 SMD follows immediately; 2.2/2.3 do not
need the floppy rulings. Phase 3.1 SMD tb grows WITH phases 1-2 (every
fix lands with its cases). Floppy items ship as a work order the owner
relays (or reassigns here). Phase 4 starts once phase 2.1 geometry is
in (the adapter needs the linear-index contract).
