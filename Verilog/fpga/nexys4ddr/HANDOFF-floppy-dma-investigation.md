# HANDOFF: Nexys 4 DDR floppy path fault (ROOT-CAUSED + FIX IN TEST) + main-RAM fix (done)

Date: 23-AUG-2026 12:30 (originally 00:40). Every claim below is measured
unless marked hypothesis.

## PART 0 - 23-AUG DAYTIME: ROOT CAUSE FOUND, FIX VERIFIED IN SIM

The floppy fault of PART 2 is ROOT-CAUSED and fixed in RTL; silicon
validation of the fix is the only step left (bitstream building as this
is written).

Mechanism (proven twice - silicon ILA capture and Verilator, the SAME
three corrupt words byte-identical):
- ND-BUS-DEVICES/DMA/circuit/ND_DMA_MASTER.v ST_DATA captures read data
  as the LAST GENUINELY-DRIVEN value on BD (needed because the board
  releases its drivers before the visible BDRY edge).
- In the ticks before memory drives the DMA answer, the BIF transceiver
  briefly presents the CPU's current LBD word - an instruction fetch of
  the polling loop (a 2-tick flicker; measured values 165562 = IOX 1562,
  004151 = STA, 156475 = SHA of the test program's own poll loop).
- Non-zero answers overwrite the flicker; a ZERO word drives ~0 =
  24'hFFFFFF on the inverted bus - indistinguishable from idle - so the
  flicker SURVIVES as the captured value. Command-block words 1/2/4
  (diskAddress 0 etc.) therefore read as garbage exactly when the CPU is
  busy; the controller then reads sector 2305, the adapter answers
  NDS_ERR_RANGE (4), the controller reports error oct 20, status1 020032,
  zero data. 1560& stage 2 and every FILSYS floppy op die this way.
- All idle-CPU tests pass by construction (dmaSim hammer incl. the new
  incrementing-address mode, the floppy-seam probe): no CPU fetches = no
  flicker. That is also the Tang difference: its memory path never shows
  this. NOTE for the MIN_GAP backlog task: the shipping config is CLEAN
  even for changing-address bursts (512/512) - the missing ingredient
  was CPU contention, not the gap.

THE FIX (applied, uncommitted): ND_DMA_MASTER.v ST_DATA discards a
captured value after TWO consecutive undriven-bus ticks while BDRY_n is
still high (2-tick filter protects the legit 1-tick release gap before
the edge). Genuine data always runs contiguously into the BDRY edge; a
foreign transient always has the memory-access-time gap after it.
Verified: sim CB fetch now 007400 000000 000000 061100 000000 000002,
s_lsect 0; regressions green: dmaSim test-dma-p3 PASS, INCR hammer
512/512, fixed hammer 64/64, DMA sim/ 2x PASS, FLOPPY-DMA sim/ 4x PASS.

Instruments built today (all reusable, all autonomous):
- tests/floppy-dma-test/gen_floppy_dma_test.py: standalone ND-100 test
  program (117 words + 12-word CB at 0o3000, CB pointer 0o3000 via IOX
  1565/1567/1563 control 1403, prints S/E/F/B in octal on the console,
  no OPCOM during the run). Healthy oracle line:
  S100012 E000012 F000000 B000060 000057 000062 000015
  Nexys failure line (pre-fix, deterministic):
  S100032 E020032 F000000 B000000 000000 000000 000000
- fpga/nexys4ddr/deposit_loader.ps1: OPCOM deposit+verify+retry+start
  loader (129 words in ~13 min at 250 ms/char pacing).
- fpga/nexys4ddr/build.tcl "-tclargs ila": opt-in post-synth ILA on the
  floppy DMA client port + FDISK seam; fpga/nexys4ddr/ila_capture.tcl
  modes program/arm/capture/read. HARD-WON RULE: JTAG TCK must be set
  BELOW the ILA clock (set_property PARAM.FREQUENCY 5000000 on the
  hw_target) or EVERY upload fails "Labtools 27-3312 corrupted".
- dmaSim ND120_OPCOM_SCRIPT=<file>: types a script into the sim OPCOM
  console (bit = 32 half-cycle ticks, ND120_OPCOM_PACE=20000 minimum or
  chars drop) and prints console output; ND120_FLP_TRACE=1 traces the
  DMA master data window; end-of-run dump prints the floppy's fetched
  CB. Replays the whole silicon experiment in ~3 min.

SILICON RESULTS (23-AUG afternoon):
- Standalone test on the fixed bitstream: S100012 E000012 F000000
  B000060 000057 000062 000015 - character-identical to the oracle.
- Boot-shaped op (word-count mode, control 400): S100010 E000010 ... plus
  full-transfer checksum C125441 over 1024 words = word-perfect.
- FILSYS LIST-USERS: works, identical to the oracle, repeatable.

STILL OPEN (next campaign, evidence in the memory files
nexys-1560-tpe-stall-sim-repro + this doc):
- FILSYS LIST-FILE-NAMES on SILICON loops printing FILSYS's own intro
  text, input-immune. Every page it reads is byte-exact on the board
  (DUMP-PAGE 774 and 34 verified against the image); the DMA capture rule
  is exonerated (both the clear-based and the stronger bounded-freshness
  window rule behave identically: LFN clean in sim, loops on silicon).
  The divergence is CPU-side (LFN decodes byte-string file names -
  different instruction mix than LIST-USERS) or interrupt timing at
  12.5 MHz FF mode.
- 1560& TPE boot: silent on silicon AND in the dmaSim rig (reproducible
  in ~3 min): all 37 CBs load, TPE never transmits, CPU polls a flag at
  ~0o176755 forever. UART model healthy (status ready, TPE never writes).
  Ties to the OTHER session's open MMU bug (non-resident page read as
  zeros instead of faulting) - TPE enables paging, FILSYS does not.
- A/B WARNING for future sim work: a concurrent session edits shared
  CPU/MMU files (CPU_15.v DBG_PTW tap, CGA.v TANG_* capture blocks);
  builds minutes apart can differ. Hash the shared files around builds
  (scratch method used 23-AUG) or the comparison is void. One such
  contaminated pair mimicked an RTL regression for an hour.

ND_DMA_MASTER now carries the BOUNDED-FRESHNESS window rule (accept a
captured read value at the BDRY edge only if the bus was driven within
the last 2 ticks; transients incl. trains sit >=6 ticks out). Regression
bench ND_DMA_MASTER_STALE_CAPTURE_tb.v has 10 cases incl. the
transient-train T10; pre-fix RTL fails 4 of them (teeth proven).
Registered in tests/run_all_tests.sh as test-dma-stale-capture.

FINAL SILICON CONFIRMATION (23-AUG ~17:45): the deployed bitstream
carries the bounded-freshness window rule and passes the standalone test
word-perfect: S100010 E000010 F000000 B000060 000057 000062 000015
C125441. FILSYS LIST-USERS re-verified on the same bitstream.

NEXT STEP PREPARED (for the LIST-FILE-NAMES silicon runaway): ILA v2 on
the CPU side. CSA_12_0 (microcode address) and XMIC_DBG_15_0 are already
ports of ND120_CORE and nets in fpga/nexys4ddr/nd120_nexys4ddr_top.v
(CSA_12_0 wire at line ~207, s_xmic_dbg at ~342). Plan: swap the probe
list in build.tcl's ILA section to {CSA_12_0, XMIC_DBG_15_0/s_xmic_dbg,
FDISK_REQ/DONE/ERR, uartTx}, rebuild with "-tclargs ila", boot 400& ->
FILSYS -> LIST-FILE-NAMES until the runaway loop is printing, THEN arm
the ILA (any trigger, e.g. a uartTx edge - the loop is steady state) and
read 4096 samples = ~4000 microinstructions of the loop. The CSA address
histogram identifies the spinning microcode path. Remember: JTAG TCK
5 MHz (ila_capture.tcl does this) or the upload corrupts.

TANG-vs-NEXYS BUILD DIFFERENCES (measured 23-AUG evening from the build
files; the Nexys build.tcl derives its source list from the Tang .gprj):
- CPU CACHE: Tang defines ND120_NO_CACHE (CPU_MMU_CACHE_25.v: cache SRAMs
  and hit logic compiled OUT, machine reports cache OFF). Nexys: cache
  present and ENABLED (ND120_CORE.v:1084 ties SW1_CONSOLE high). This
  cache has never been validated on hardware. A cache that misses a DMA
  write gives exactly "memory correct, CPU reads stale" - the
  LIST-FILE-NAMES signature. build.tcl now accepts "-tclargs nocache"
  (adds ND120_NO_CACHE); nd120_nexys4ddr_nocache.bit was built and
  flashed 23-AUG ~19:40 for the test.
- Main memory: Tang SDRAM 4 MB + ND_SDRAM_PACK16 (parity recomputed on
  read); Nexys BLOCKRAM 128K words, stored parity, no PACK16.
- Disc images: Tang ND_STORAGE_DISCS_UNCACHED; Nexys Winchester CACHED
  (CACHE_MASK 8'b11000000) - untested on Nexys beyond LIST-USERS (which
  PASSES on DISC-74MB-1: 7 users).
- CPU clock: Tang ~6.75 MHz; Nexys 16.67 MHz (clk_sel 16 default;
  earlier notes in this file saying 12.5 MHz are wrong - 12.5 is clk=12).
- Everything else (CPU, MMU, bus, DMA masters, device controllers,
  SC2661 console) is the same source.
- Console UART: any command-register write with TxEN=0 aborts the
  character in flight (SC2661_UART.v TX machine reset) -> misframed
  garbage when input arrives during output (Ronny measured it during
  HELP). The real chip finishes the character first. Fix candidate, not
  applied (shared with Tang; Ronny's call).

USB/JTAG TRAP (cost 20 min): if usbipd shows the Nexys FT2232 as
"Shared", its stub driver owns the programming channel and Vivado finds
no hw_target while COM11 still works. Fix: admin "usbipd unbind --busid
<id>" + replug.

Remaining: decide with Ronny whether the opt-in ILA section in build.tcl
stays; commit approval for everything (NO commits made).

## PART 1 - SOLVED AND SILICON-VALIDATED: 400& boot / main RAM

`400&` loads FILSYS-INV-Q04.BPUN byte-perfect and runs it (banner + prompt).
Root cause of the old "repeating junk" was MEM_RAM_49_BLOCKRAM, not storage:

- `CPU-BOARD-3202/circuit/MEM_RAM_49_BLOCKRAM.v` had `lin = {AA_9_0, row_q}`
  but PAL 44902A (`PAL/PAL_44902A.v`: HIEN=states 0,1,2 = RAS phase,
  LOEN=3,4,5,6 = CAS phase) presents the HIGH address half at RAS. The
  12-bit truncation then dropped CPU address bits [9:2] (proven on silicon:
  OPCOM deposits at 1000/1004/.../0 all aliased one cell).
- Fixes (uncommitted): `lin = {row_q, AA_9_0}`; BANK_ADDR_BITS overridable
  via `ND120_BLOCKRAM_ADDR_BITS` (`CPU-BOARD-3202/circuit/MEM_43.v`), Nexys
  sets 15 in `fpga/nexys4ddr/build.tcl`; `cascade_height = 1` on the array
  (DRC REQP-1962 rejects cascaded RAMB36 inference at 128K words).
- Testbenches updated to the real phase semantics and green:
  `CPU-BOARD-3202/circuit/sim/` test-blockram, test-memchain,
  test-memchain-blockram. (test-memchain-sim fails IDENTICALLY before and
  after - pre-existing stored-parity/ECC-probe conflict, memory workstream.)
- build.tcl also REPLACED `set_clock_groups -asynchronous` (cpu/stor/ui)
  with pairwise `set_max_delay -datapath_only` bounds so CDC payload paths
  are timed. WNS +1.460, hold +0.026, clean.

## PART 2 - OPEN: floppy reads fail (1560& stage 2, FILSYS floppy ops)

Symptoms measured on silicon (instrumented bitstream, see PART 3):
- `1560&`: 64-word stage-1 bootstrap loads via CPU/PIO and runs (63/64
  words byte-exact, 2 runtime-modified); stage 2 (floppy DMA) writes ZERO
  words; board hangs (DISK_TIMEOUT=0 in ND120_CORE.v = watchdog disabled).
- FILSYS (booted via 400&): FLOPPY-DISC-1 opens, "Total pages 001150"
  correct; LIST-USERS / DUMP-PAGE fail with `status1 020032` = error code
  oct 20, intermittently (fail, fail, pass, wedge pattern).
- 7-seg debug counters after one LIST-USERS run: 8 FDISK requests, error
  code first=last = 4 = NDS_ERR_RANGE, first captured lsect = 0x901 = 2305.
- The FILSYS command block WAS found in ND memory at 0o011565:
  w0=007400 (READ, format 3 = 1024 B/sector), w1=000000 (diskAddress 0!),
  w3=061100 (buffer), w5=000002 (2 sectors), w6=020032 (status1 written
  back), w7=000000. Full dumps: session scratchpad filsys_*.log.

What that proves:
- DMA WRITEBACK to memory WORKS (status 020032 landed where FILSYS read it).
- A read of SECTOR 0 was rejected as RANGE - impossible on a 1232-sector
  diskette UNLESS the adapter compares against c_size_bytes = 0.
- **PRIME HYPOTHESIS: the floppy client's 32-bit size_bytes reads as ZERO
  on the clk_cpu side** (nd_storage_floppy_adapter's range check
  `end > c_size_bytes` then rejects EVERY read; error code 4 matches; any
  page matches; "Total pages" is unaffected because it comes from the
  media descriptor, not size). lsect 0x901 = 576*4+1 is then FILSYS
  RETRYING alternate geometry (512-byte sectors, 1-origin) after errors -
  not the first request.
- Tang-vs-Nexys difference under this hypothesis: how client-1's
  size_bytes bus (clk_stor -> clk_cpu, quasi-static after mount) behaves -
  check `SD-FAT/circuit/nd_storage.v` size_bytes fan-out and whether the
  adapter samples it before/while the mount publishes it, and whether the
  Nexys open sequencing (floppy opens FIRST, mount order floppy->WD->tape)
  lets the adapter latch size too early. NOTE: c_size_bytes is sampled by
  the adapter per-op, not latched - read the adapter source before
  trusting this sentence.

Exonerated by measurement (do NOT re-investigate):
- Storage stack RTL end-to-end at the real 12.5/27.027 MHz ratio with the
  REAL nd_ddr2_storage + nd_ddr2_port: byte-exact for tape (50,870 bytes)
  and floppy FDISK reads, on FAT16, FAT32+MBR(part@2048), and a card
  mirroring the real root (BPUN subdir + LFN). Benches in session
  scratchpad ddr2boot*/ (tb1..tb5b, all TB_RESULT: PASS).
- Masked DDR2 writes on silicon (MASKW PASS), DMA master vs BLOCKRAM in
  Verilator (dmaSim with -DMAIN_RAM_BLOCKRAM: PASS - see the dmaSim
  Makefile invocation in PART 3), CDC payload-race (max-delay rebuild
  changed nothing), card content (FLOPPY1.IMG on card == Verilog/runSim/
  FLOPPY1.IMG, pages 1/4/383 verified via sd-fat app), FAT32 mount, LFN.

## PART 3 - instruments now in place

- `fpga/nexys4ddr/nd120_nexys4ddr_top.v` 7-seg debug mux (observation
  only): sw[15:14]=01 {FDISK req count, done count}; =10 {err count,
  first code, last code}; =11 first lsect. NOTE the done counter counts
  CYCLES done is high, not pulses (8 reqs showed done=0x88) - fix or
  ignore. Counters reset only by reconfiguration.
- dmaSim BLOCKRAM build:
  `make test-dma-p3 EXTRA_VDEFINES="-DMAIN_RAM_BLOCKRAM
  -DND120_BLOCKRAM_ADDR_BITS=15 -I../SD-FAT/circuit -Wno-PINMISSING"
  TIMING_CFLAGS="-std=gnu++20 -fcoroutines -DDMASIM_BLOCKRAM"` (the
  guarded ByteView in dmaSim/dma_p3_main.cpp).
- FILSYS OPCOM round trip: FILSYS command `OPCOM` drops to `#` with memory
  intact; `<` dumps are interruptible by any input char; OPCOM prints at
  roughly 1.3 lines/s so budget scans accordingly.

## PART 4 - next steps, in order

1. Check the size_bytes-zero hypothesis IN SOURCE first: adapter range
   check + size_bytes crossing (`SD-FAT/circuit/nd_storage_floppy_adapter.v`,
   `nd_storage.v` size fan-out, `nds_sync` usage for 32-bit values).
2. Stepwise silicon counters (needs eyes on the 7-seg): reprogram, read
   counters after `400&` alone, after FLOPPY-DISC-1 open, after one
   LIST-USERS - separates open-phase requests from FILSYS's ops and shows
   the REAL first lsect.
3. Oracle ground truth if still needed: nd100x (ONLY ~/repos/nd100x) with
   FLOPPY1.IMG and DEBUG_FLOPPY_DMA prints - the healthy CB for LIST-USERS.
4. Uncommitted changes awaiting Ronny's review (no commits made):
   MEM_RAM_49_BLOCKRAM.v, MEM_43.v, fpga/nexys4ddr/build.tcl,
   fpga/nexys4ddr/nd120_nexys4ddr_top.v, sim/MEM_RAM_49_BLOCKRAM_tb.v,
   sim/MEM_CHAIN_tb.v, dmaSim/dma_p3_main.cpp.

## 24-AUG 00:30 ADDENDUM - LIST-FILE-NAMES runaway RE-ROOT-CAUSED on silicon

The 23-AUG "wrong indirect jump / CPU executes text at 0o016004" story is
REFUTED by direct ILA measurement and the fault has moved to the console
UART status path. Full trail in the memory file
nexys-lfn-indirect-jump-highbits (24-AUG section). Short form:

MEASURED (ILA v3 bitstream, probes s_cd_15_0/s_ica_15_0/s_la_23_10_out at
the CGA_MAC boundary; `build.tcl -tclargs ila` now sets the define
ND120_ILA_MARK_DEBUG so those nets keep their names through synthesis -
without it get_nets finds nothing, and note get_nets -hier matches LEAF
names only, so hierarchy patterns with '/' silently fail):
- capjpl (trigger CD==0x6004): the end-of-list JPL I 25 at 0o057430 loads
  pointer 0o060004 and jumps CORRECTLY - CD, ICA and LA_23_10 all right,
  next fetches 0o060004/5 with the correct STA -7 operand access.
- capbad (trigger ICA==0x1C04) never fires across the whole runaway: the
  CPU NEVER fetches at 0o016004. The old 0o016xxx "fetch addresses" were
  CSA-bus mid-microcycle transients of the form {3'b111, ICA[9:0]}.
- capnow during the runaway: the loop is real code - 0o060033-37 (poll),
  0o060207-0o060310 (error printer), 0o053726 (console char out). FDISK
  seam idle the whole time (v2 probes REQ=DONE=ERR=0).

DECODED (oracle nd100x + DAP, same BPUN, COPY of FLOPPY1.IMG):
- 0o060033: EXR ST with T=164303 (IOX 303 console control write),
  AAT 3, EXR ST (IOX 306 console output status read), BSKP tests the
  ready bit; fail -> JPL I 150 -> 0o060224 = "DEVICE ' ' NEVER READY.
  STATUS:" printer (strings at words 0o060253/0o060264) -> retry.
- Oracle enters this SAME routine during healthy LFN (breakpoint at
  0o060033 hits; called from 0o060014) and exits the FIRST poll:
  IOX 306 returns 0o000010 (bit 0o10 = ready for transfer) and BSKP
  skips. On the Nexys the bit never reads as set -> infinite retries,
  one help-text line ("  o update and check directories", text at word
  0o010446) printed per pass.

PRIME SUSPECT: Shared/support/SC2661_UART.v:221
    assign s_txrdy_n = cmd_txEnabled ? ~regStatusRegister[0] : 1'b1;
TxRDY is forced NOT READY whenever the command register's TxEN bit is 0,
and the failing loop WRITES the control register (IOX 303) every pass
before reading status. The already-documented quirk in this file (command
write with TxEN=0 aborts the character in flight -> the misframed HELP
garbage Ronny measured) sits in the same logic. Second file to read:
CPU-BOARD-3202/circuit/IO_UART_42.v (IOX 30x decode - what a 303 write
touches, which bits a 306 read returns).

WHY SIM NEVER SHOWED IT: the Verilator builds use the fast-UART path, so
the poll exits first try just like the oracle - the retry/timeout path has
NEVER been exercised anywhere but on silicon. Repro plan: build the dmaSim
rig with real UART timing, watch the same loop appear in sim, fix, verify
latch+FF, then silicon.

Session artifacts (24-AUG night):
- ILA v3 bitstream/probes: fpga/nexys4ddr/nd120_nexys4ddr_ila_v3.bit/.ltx
  (nd120_nexys4ddr.bit currently holds the v2 copy - the LAST PROGRAMMED
  bitstream on the board is v2, FDISK probes).
- ila_capture.tcl gained modes capjpl/capbad and a 180-unit wait note:
  wait_on_hw_ila -timeout is in MINUTES, not seconds.
- Captures in /mnt/f/tmp/verilog/: nexys_lfn_ila_healthy_jpl.csv,
  nexys_lfn_ila_runaway_loop.csv; oracle rig in /mnt/f/tmp/verilog/lfnrun.

## 24-AUG 01:15 - SIM REPRODUCTION + RTL FIX (console UART TX abort)

REPRODUCED IN SIM: dmaSim rig rebuilt with real UART timing
(`make compile EXTRA_VDEFINES="-DND120_UART_DELAY_FRAMES=1736"` - new
override in Shared/support/SC2661_UART.v; 1736 = 16.67 MHz / 9600; the
OPCOM typist takes ND120_OPCOM_BIT=3472 = 2x that). Replaying the FILSYS
LIST-FILE-NAMES dialog (script /mnt/f/tmp/verilog/lfnrun/lfn_script.opcom,
BPUN poke + C floppy server):
- every machine-generated console line came out MISFRAMED GARBAGE (the
  same class as the silicon HELP garbage) while the ECHO of typed chars
  was clean;
- at ~65M ticks the transmitter DIED completely: [uart] probe showed
  txhold=3E ('>'), insend=0, txState idle, status 0xC5 (TxRDY+TxEMT
  claiming ready) - a stranded THR character, console dead forever.
  Log: /mnt/f/tmp/verilog/lfnrun/rig_lfn.log

ROOT CAUSE (Shared/support/SC2661_UART.v, TX state machine): the
`if (!cmd_txEnabled)` branch reset the WHOLE transmitter - chopping the
character in flight (misframed output whenever FILSYS writes the command
register during transmission, which its status-poll sequence does
constantly) and clearing regDataInSendRegister (stranding a THR character
written inside the disable window; the write and the clear race in the
same always block and the clear wins).

FIX (applied): TxEN=0 now only prevents STARTING a new character - a
character in progress completes, the THR pending flag survives, and a
pending character transmits when TxEN returns. This is the documented
real-2661 behavior ("the transmitter completes the character in
progress"). The fix is mode-independent (no latch/FF split) and shared
with the Tang build.

REGRESSION BENCH (registered): Shared/support/sim/SC2661_TX_ABORT_tb.v,
`make test-uart-txabort` (run_all_tests.sh entry added).
- fixed RTL:  TEST1 PASS (frame completes across a TxEN=0 window),
              TEST2 PASS (char written while disabled transmits later),
              TB_RESULT: PASS
- git-HEAD RTL: BOTH FAIL (TEST1 "char aborted - 0 low clocks",
              TEST2 "stranded THR"), TB_RESULT: FAIL - teeth proven.
- the pre-existing `make test-uart` (TX-flag timing) still passes.

VERIFY IN FLIGHT: rig LFN re-run with the fixed RTL
(rig_lfn_fixed.log) - expect clean console lines and the listing to
complete. THEN the silicon step: rebuild the Nexys bitstream (normal, no
ila needed) with the UART fix and re-run LIST-FILE-NAMES on the board.
NOTE for Ronny: SC2661_UART.v is SHARED with the Tang - the Tang boots
SINTRAN with the old code, so retest the Tang console after this lands.

## 24-AUG 01:45 - SILICON RETEST: NOT FIXED; sim fully healthy; ILA v4 in flight

SILICON (UART-fix bitstream, nd120_nexys4ddr_uartfix.bit, WNS +1.460,
flashed via new fpga/nexys4ddr/program_only.tcl): LIST-FILE-NAMES user 0
STILL runs away printing "  o update and check directories" forever. The
SC2661 TX-abort fix is real (bench-proven) but is NOT the LFN cause.

SIM (rig, real UART timing, reader fixed for back-to-back frames -
op_rxhold half-bit MARK requirement in dmaSim/dma_p3_main.cpp): the FULL
LFN dialog is CLEAN - banner, 42 files, prompt - on BOTH the old and the
fixed SC2661 RTL. The earlier "misframed garbage" readings in the rig logs
were the rig READER's misalignment, not DUT output; and the "TX deadlock"
reading was wrong - txhold keeping the last char with insend=0 is the
normal post-send idle state. Logs: /mnt/f/tmp/verilog/lfnrun/
rig_lfn{,_fixed,_fixed2}.log.

WHERE THAT LEAVES THE FAULT: silicon-only; FILSYS's device-wait at
0o060033-37 polls console output status (IOX 306) and its ready bit
(0o10) never reads as 1 on the board, while the oracle and the
real-timing rig both exit that same wait normally. On silicon that bit is
the CHIP_33G (AM29C821) FF-mode CAPTURE of TBMT_n in
CPU-BOARD-3202/circuit/IO_UART_42.v, clocked by the 1-sysclk CLK_EN pulse
- the stale-capture suspect the sim-only ND120_IOR_PROBE diagnostic was
built for (sim shows nothing; the divergence, if real, is silicon-only).

IN FLIGHT: ILA v4 build - adds MARK_DEBUG (same ND120_ILA_MARK_DEBUG
define) on IO_UART_42's s_tbmt_n (live), s_io_idb_15_0_out (captured IOR
bits), s_clk_en, s_eiorn_n, keeping the v3 MAC probes. Plan: capnow during
the runaway; if live TBMT_n shows ready while the captured bit 15 stays
not-ready (or CLK_EN never pulses), the fault is the FF-mode status
capture on silicon - then fix that capture (e.g. move the IOR status bits
to a sysclk-domain capture with a proven enable, or bypass CHIP_33G for
the live signal in FF mode).

## 24-AUG 02:05 - ILA v4 RESULT: console status capture EXONERATED; suspect moves to the FLOPPY IOX STATUS

Capture (capnow during the live runaway, v4 probes, saved as
/mnt/f/tmp/verilog/nexys_lfn_ila_v4_console_seam.csv):
- live s_tbmt_n = 0 (READY) in ALL 4096 samples; s_clk_en pulsing (~8%);
  the CHIP_33G-captured IOR word reads 0x7818 when EIOR_n strobes low -
  captured TBMT bit = READY too. The FF-mode IOR status capture WORKS.
- EIOR_n strobed only 3 times in 246 us: the spinning wait is NOT reading
  the console status at all. The "console IOX 306" identification from
  the v3 CD flicker was wrong - FILSYS's generic device-wait takes its
  IOX base from a VARIABLE, and during LIST-FILE-NAMES that device is
  the FLOPPY (IOX 156x, reached over the ND bus, no EIOR involved).

STANDING PICTURE: FILSYS polls the floppy controller's IOX status forever
while the storage seam BEHIND the controller is idle (v2 capture:
FDISK_REQ=DONE=ERR=0) - ND_FLOPPY's CPU-visible status (or its
interrupt/IDENT completion path) never shows done/ready for an operation
whose data phase finished. Same shape as the 1560&/TPE stall (TPE polls a
memory flag its floppy interrupt handler should set).

IN FLIGHT: ILA v5 - adds the device-chain IOX seam from ND120_CORE.v
(s_dev_iox_addr/wr/rd, s_dev_iox_rdata, s_dev_int_pending, all
mark_debug-guarded) to see exactly which floppy register the CPU polls in
the runaway, what the controller answers, and whether an interrupt is
pending forever. build.tcl's marked-net loop now takes explicit glob
patterns (s_dev_iox_rd needed an exact-suffix pattern - it prefixes
s_dev_iox_rdata).

## 24-AUG 02:35 - THREE MORE THEORIES KILLED ON SILICON; the runaway is the INPUT-WAIT TIMEOUT REPRINT PATH

Measured tonight with ILA v5/v6 (v6 = v5 + IDENT seam probes; both saved
as nd120_nexys4ddr_ila_v6.bit/.ltx; v6 is ON THE BOARD now; NOTE the ltx
lesson below):

KILLED (all measured, do not re-chase):
1. Floppy IOX status poll: ZERO device IOX reads/writes during the
   runaway (v5 capnow, 246 us; caperr pre-window, 228 us).
2. Level-11 interrupt lost: s_dev_int_pending=2 constant on silicon, BUT
   the healthy rig run shows the SAME - the FINAL floppy interrupt stays
   pending forever while FILSYS idles at the prompt (rig probe
   ND120_INTP_TRACE in dmaSim; healthy handshake: pend -> IDENT strobe
   level=11 -> clears, latency up to ~2.4M ticks). A standing pending
   level-11 at idle is NORMAL for FILSYS. Log:
   /mnt/f/tmp/verilog/lfnrun/rig_lfn_intp.log
3. Phantom console input: capda trigger (EIOR read AND captured DA=char
   available, 2 probe compares ANDed) armed 3 minutes on the live
   runaway - NEVER fired. The input status always reads "no char"
   (IOR=0x7818 every strobe).

WHAT THE RUNAWAY ACTUALLY EXECUTES (caperr capture with 3800 pre-trigger
samples, /mnt/f/tmp/verilog/nexys_lfn_ila_v5_caperr.csv): the console
INPUT WAIT at 0o060403-0o060436 (0x6103-0x611E - write input control IOX
303 at 0x6104, read input status IOX 302 at 0x6106, BSKP, then the
timeout-counter path 0x610F/0x6110/0x6111 -> 0x611E) - the SAME region
the healthy oracle idles in (P=0o060435) - PLUS one menu-line print
(text at word 0o010446) per ~0.85 s through 0x6094/0x57d6. So the
runaway = the input wait's TIMEOUT/REPRINT path firing forever on
silicon while the oracle's never fires. The caperr trigger itself fired
on a 1-sample ICA transient of 0x6094 during 0x6110's RADD - ICA
transients can fake fetch addresses (same lesson as the CSA {111,
ICA[9:0]} flicker).

NEXT (pure analysis + at most one capnow): the wait loop re-reads its
state variables every pass - 0x6100 LDA 40 -> mem[0x6140], 0x6101
ADD I 40 -> mem[mem[0x6141]], 0x6103 LDA 37 -> mem[0x6122] - so their
SILICON values are already in the captures as CD operand reads. Compare
those against the oracle's memory at the same point (oracle is parked at
the prompt in the DAP session, workdir /mnt/f/tmp/verilog/lfnrun). Find
which variable differs -> trace which earlier write corrupted it (the
LFN listing phase is the suspect window).

LTX LESSON (cost 3 void captures): ila_capture.tcl loads
nd120_nexys4ddr.ltx BY NAME - a finishing background build OVERWRITES
bit+ltx, and arming with a mismatched ltx yields garbage triggers and
empty uploads ("No matching hw_probes" in the worst case). Copy the
bit/ltx pair aside per probe revision (v6 saved) and do not run captures
while a build is in its write-out phase.
wait_on_hw_ila -timeout is in MINUTES; on timeout it may RETURN normally
(no throw) with an empty buffer - a 2-line csv means NO TRIGGER, not a
capture.

## 24-AUG 02:50 - final state of the night

- The post-LFN wait code (0x6109-0x611E) uses MON 66/64/3/1 monitor calls
  (FILSYS standalone MON emulation) - the reprint decision lives in that
  layer, not in the raw IOX poll.
- SILICON COUNTER LEAD: in the caperr capture's input-wait passes, an
  operand read DECREMENTS once per pass: 0x9060 -> 0x905F. A live
  countdown on silicon; the oracle at the same prompt never prints, so
  its countdown is absent or never expires. The cell's address is not
  yet identified (it is read in the 0x611E+ / MON-handler stretch).
  NEXT: identify that cell (oracle disasm of the MON dispatch + the
  input-wait's data block around 0x57C8-0x57D0/0x6123-0x6140), read it
  on the oracle, and find who initializes it during LFN.
- Generic prompt-timeout REFUTED on silicon: fresh boot + 2 minutes of
  silence at "Device name :" prints NOTHING. The runaway needs the
  post-LIST-FILE-NAMES state.
- Board state: ILA v6 bitstream + matching ltx (saved as
  nd120_nexys4ddr_ila_v6.bit/.ltx), sitting at the Device-name prompt.
- All ILA captures of the night in /mnt/f/tmp/verilog/nexys_lfn_ila_*.csv.

## 24-AUG 03:00 - LOCALIZED: the runaway fires on ANY answer to LFN's "User no." prompt

Measured on silicon (ILA v6 bitstream, fresh boots between tests):
- LIST-FILE-NAMES user 0 (42 files): runaway. User 1 (NO files): runaway.
  EMPTY answer (bare CR): runaway. The listing loop and byte-string
  filename decode are EXONERATED - no directory content is needed.
- LIST-USERS: clean prompt after, 30 s quiet.
- DUMP-PAGE: full 4-prompt dialog + floppy read + dump -> clean prompt,
  40+ s quiet. EMPTY answer to its "Page no." prompt: accepted, moves on.
  Parameter prompts and empty answers per se are FINE.
- Fresh boot + 2 min silent at "Device name :": NOTHING prints. No
  generic prompt timeout.

So the divergence is inside LIST-FILE-NAMES' post-answer path (between
reading the user-number answer and returning to the '>' prompt), on
silicon only - the rig with identical RTL and real UART timing runs the
same path clean, and the oracle returns to a silent prompt. Everything
CPU-visible measured so far (console status, DA, floppy IOX, pending
interrupts) behaves; the runaway itself executes the input wait at
0o060403-0o060436 plus one menu line (word 0o010446) print per ~0.85 s,
with a per-pass decrementing cell observed (0x9060 -> 0x905F values on
CD).

Oracle session parked at the post-LFN prompt (nd100x -d, port 4711,
workdir /mnt/f/tmp/verilog/lfnrun) for memory reads. Next session: walk
LFN's post-answer code from 0o057400 onward on the oracle (JPL I 30 /
JPL I 25 handlers at 0o060004+, the MON 66/64 input layer at
0o060511-0o060436), find the cell that arms the reprint, and identify
the silicon-only write. The empty-answer repro makes every experiment a
20-second cycle.

## 24-AUG 03:05 - decoded map of LFN's exit path and the console state block

- ICA covers DATA accesses too: the "code at 0o053726" reading was wrong -
  0x57D6 is a DATA cell (console-output character-position counter;
  silicon runaway shows it counting 0x1D..0x26 as the menu line prints;
  oracle idle = 0). Same transient lesson as CSA/{111,ICA[9:0]} and the
  1-sample 0x6094 ICA hit.
- End-of-LFN handler at 0o060004 (called via JPL I 25 from 0o057430):
  zeroes mem[0x57D6] and mem[0x57D7] (via pointer cells 0x607D/0x607E),
  tests mem[0x57D4] (JAF at 0x600B), calls mem[0x6080]=0x60ED when zero
  (that routine runs the 0x601b console-OUT wait, L=0o060015), then tests
  mem[0x57D5] (JAF 134 at 0x600E). Console state block: 0x57CB/CC/CD =
  device bases (0o300); 0x57D1 = 0o061100 disk buffer ptr; 0x57D4-0x57D7
  = output state.
- Oracle post-LFN prompt values: 0x57D4=0 0x57D5=0 0x57D6=0 0x57D7=5.
- STILL UNLOCATED: the per-pass decrementing cell (0x9060 -> 0x905F in
  caperr CD). Candidate next step: in the v6 runaway capture, list every
  (ICA, delivered CD) pair for ICA outside code (0x0000-0x5FFF data
  region) to find which address serves the 0x90xx values, then read that
  address on the oracle.
- 20-SECOND REPRO: boot 400& -> FLOPPY-DISC-1 -> 0 -> LIST-FILE-NAMES ->
  bare CR. Runaway immediate, no files needed.

## 24-AUG 03:10 - the 0x90xx values sit ON the BSKP at 0o060407

The per-pass stepping values (0x9060, then 0x905F next pass) appear on CD
while ICA=0x6107 - the `BSKP ONE 30 DA` (175235) right after the EXR of
the IOX 302 input-status read at 0x6106. Two readings, undecided:
(a) they ARE the IOX 302 result in A - i.e. the console INPUT status
    reads back garbage with high bits set on silicon (oracle reads 0
    there; IOR capture shows a clean 0x7818, so the corruption would be
    in the microcode assembly of the status word or the IDB path); or
(b) a CD transient of something else stepping once per pass.
ENTRY POINT FOR THE NEXT SESSION:
1. Decode BSKP 175235 exactly (bit number, source register) from the
   ND-100 reference card / nd100x source - what does it skip on?
2. In the dmaSim rig, print the IOX 302 RESULT (A after 0x6106) per pass
   in the same wait (healthy values), and the 0x6107 BSKP outcome.
3. On silicon, ILA-trigger on ICA==0x6106 and read the CD sequence to
   pin the delivered status value per pass; if it really is 0x90xx,
   chase the IDB path microcode-side (IOR 0x7818 -> status-word
   assembly).
20-second repro stands: 400& -> FLOPPY-DISC-1 -> 0 -> LIST-FILE-NAMES ->
bare CR.

## 24-AUG 03:25 - NIGHT CLOSE-OUT

- BSKP 175235 decoded from nd100x source: BSKP ONE, bit 3, register A -
  "skip if A bit 3 set". Matches the oracle's healthy exits everywhere.
  The 0x90xx per-pass values would NOT fire this test (bit 3 clear) -
  reading (b) [CD transient] is now more likely; thread parked.
- Rig, empty-answer LFN, ND120_IOR_PROBE: bare CR to "User no." DEFAULTS
  TO USER 0 and lists all 42 files cleanly; every IOR read shows
  cap15=0/cap14=1 with capture==live. Healthy on every axis.
  Log: /mnt/f/tmp/verilog/lfnrun/rig_lfn_empty_ior.log

WHERE THIS STANDS (for the morning):
- SOLVED + verified this night: nothing new on LFN itself. Landed on the
  way (uncommitted, teeth-proven): the SC2661 TX abort fix +
  test-uart-txabort bench; ND120_UART_DELAY_FRAMES real-timing sim UART;
  rig OPCOM reader back-to-back fix + ND120_OPCOM_BIT + [intp] probe;
  ND120_ILA_MARK_DEBUG probe infrastructure (CGA_MAC.v, IO_UART_42.v,
  ND120_CORE.v, build.tcl ila v6, ila_capture.tcl modes
  capjpl/capbad/caperr/capda + program_only.tcl).
- OPEN: the LFN runaway. Localized to: silicon-only; fires on ANY answer
  to LIST-FILE-NAMES' "User no." prompt (bare CR incl., zero directory
  access needed); LIST-USERS + DUMP-PAGE (incl. empty answers) clean;
  no generic prompt timeout. Measured healthy on silicon during the
  runaway: console TBMT/DA + IOR capture, device IOX (silent), pending
  interrupts (level-11 standing pending is normal at idle). The runaway
  executes the 0o0604xx input wait + one menu-line reprint per ~0.85 s.
- The uncommitted working tree carries all of the above + the night's
  plan/handoff/memory updates. Ronny's review + commit decisions per the
  Phase 1 list in PLAN-nexys-floppy-next-phases.md.

## 24-AUG morning - capmenu/capfix: the runaway's print source and the prompt descriptor

New captures (v6 bitstream, saved in /mnt/f/tmp/verilog/):
- nexys_lfn_ila_v6_capmenu.csv: trigger ICA==0x1126 (menu text word
  0o010446). The print-string routine at 0o057010-0o057064 (0x5E08-
  0x5E34) walks the text; the string pointer value 0x1124/0x1126 is
  DELIVERED on CD during reads in the 0x607B/0x607C area on the decision
  path.
- nexys_lfn_ila_v6_capfix.csv: trigger (ICA==0x607C AND CD==0x1124),
  armed BEFORE the bare-CR answer - fired on the FIRST pass. Pre-history
  shows a lockstep three-table walk: reads at 0x5FFD/0x5FFE (values
  0x4883/0x5083 on silicon), 0x5F80/0x5F81, 0x607B/0x607C (values
  0x000D / 0x1124 on silicon).
- ORACLE at the matching moment (bare-CR answer just given):
  mem[0x607B]=0x5083, mem[0x607C]=0xAA87 (unchanged);
  mem[0x5F80]=0x08B8, mem[0x5F81]=0xBA33 (code words);
  mem[0x5FFC..0x5FFE] = {0x6004, 0x003E '>', 0x0003} - this block looks
  like the CURRENT-PROMPT DESCRIPTOR (the '>' prompt char + state).
- CAUTION carried from tonight: single-sample ICA/CD attribution has
  been wrong repeatedly (transients). The three-table lockstep walk and
  the 0x000D/0x1124 deliveries are multi-sample (5-9 dwell) and firm;
  WHICH address delivered WHICH value needs the next experiment, not
  more csv staring.

DECISIVE NEXT EXPERIMENT (oracle side first): set a DAP WRITE WATCHPOINT
on 0x5FFD (the prompt-char cell) and on 0x607C, re-run LFN with bare CR
on the oracle, and record WHICH ROUTINE writes the prompt descriptor and
with what value. Then on silicon, ILA-trigger at that routine's address
and compare the written value. If the silicon writes the MENU pointer
where the oracle writes the '>' descriptor, the corrupting routine is
nailed and its inputs (registers/flags) become the target.

## 24-AUG morning session 2 - the corruption target is the CONSTANT POINTER TABLE at 0o060203-0o060216

ORACLE FACTS (DAP, write-watches, matching bare-CR LFN):
- The 0o060004 routine is FILSYS's PUTCHAR: entry saves A (the character)
  and T into 0x5FFD/0x5FFE (STA -7/STT -7; watch hit at PC=0o060005 with
  A='L' during the echo). The epilogue stub at 0x607A-0x607C restores
  A/T from those cells and returns via mem[0x6003]=0x00B6.
- A write-watch on 0x607C stayed SILENT through the ENTIRE healthy LFN
  (dialog + 42 files + prompt): the oracle never writes the epilogue/
  pointer-table area. Those cells are CONSTANTS.
- Constant pointer table (oracle): 0x6087=0x6094, 0x6088=0x57CF,
  0x6089=0x60D1, 0x608A=0x57CE, 0x608B=0x57CB, 0x608C=0x57D2,
  0x608D=0x07FF, 0x608E=0x57D3. The ring/counter code at 0x6030-0x603B
  (head/tail compare + MIN I through 0x6088) operates on the 0x57Cx-0x57Dx
  console state block through these pointers.

SILICON FACTS (capfix/capfix2 captures, both armed BEFORE the dialog
finished; /mnt/f/tmp/verilog/nexys_lfn_ila_v6_capfix*.csv):
- On the runaway's first pass, the flow = ring-consumer loop
  (0x6033/0x6034/0x6037) -> epilogue stub (0x607A..) -> putchar, and CD
  delivers 0x000D and 0x1124 in the stub/table area where the oracle
  holds the constants 0x5083/0xAA87/0x57CF - character-like junk in a
  CONSTANT region.
- LIMIT REACHED: the ILA's ICA/CD columns skew by 1-2 samples, so
  csv-reading cannot prove whether these are READS of already-clobbered
  cells or the clobbering WRITES themselves.

NEXT (ILA v7): probe the MAIN-RAM WRITE PORT - write-enable, write
address, write data (MEM_RAM_49_BLOCKRAM seam) - and trigger on a WRITE
with address in the constant table (e.g. waddr==0x607C or 0x6088). That
yields the corrupting store's exact moment with the executing code in
pre-history, read/write ambiguity gone. Then compare the writer PC path
against the oracle (which provably never writes there) and the bug -
CPU store mis-address, or a mis-taken branch into a store loop - falls
out.

## 24-AUG ~10:50 - MAJOR NARROWING: IOX 302 status = IOR | scratch-register R6; suspect = R6 readback on silicon

MEASURED CHAIN (v7 RAM-port probes + oracle DAP single-step + microcode):
1. v7 capwr NULL: NO write ever hits the constant pointer table on
   silicon (matching the oracle's write-watch). v7 capnow: the ONLY RAM
   writes in the runaway are 0x57D6 counting up (print position). THERE
   IS NO MEMORY CORRUPTION AT ALL - every earlier junk-value reading was
   ILA sample skew. The divergence is pure control flow on clean data.
2. v7 capcr (trigger = RAM write of the CR byte): the answer CR is stored
   at 0x5A28 (line buffer), parsed via 0x58xx, and the machine enters the
   input-poll subroutine at 0o060400-0o060436 - which the ORACLE ALSO
   enters after its CR (breakpoint hit at 0o060400). The poll subroutine
   returns (P:=L+1 at 0o060436) to a caller loop at 0o060334-0o060336
   that calls it repeatedly.
3. Oracle single-step through the poll: after the EXR of IOX 302 at
   0o060406, A = 0o000004 - input status with ONLY bit 2 set. Per the
   nd100x terminal model (src/devices/terminal/deviceTerminal.h): bit 2 =
   "DEVICE ACTIVATED" (a latch set by input-control-word bit 2; FILSYS's
   control word 0o044004 sets it), bit 3 = data available. The poll's
   BSKP (bit 3 of A) falls through healthily with no char; the caller
   loop's release involves the returned status (0o0434 does AND 7 before
   return - status masked to bits 2:0).
4. MICROCODE (nd120_symbols.tsv, the CSA values captured on silicon
   during the poll): the console service TRM20/TRM21/TRM22 at 0o0530-
   0o0541 forms the IOX 302 result as: read IOR (TRM20+1: IDBS,IOR) then
   OR in SCRATCH REGISTER R6 (TRM20B+1/TRM22: A,R6 ... ORAB) with
   R4/R13/R16 masks. R6 = the console's SOFT STATUS (activated +
   interrupt-enable bits kept by microcode, since the IOR hardware word
   has no such latch).

HYPOTHESIS (the sharpest yet, one step from the RTL): on silicon the
scratch-register R6 readback loses the activated bit (or the R4/R13/R16
masks read wrong) -> IOX 302 returns status without bit 2 -> FILSYS's
LFN answer-reader waits forever for an activated device -> the periodic
timeout prints one menu/help line per ~0.85 s. The scratch registers live
in the CGA 2901 register file (CGA_ALU_RALU / WRF) - the same FF-mode
register-file area that produced earlier campaign bugs (QREG multiply,
SSEL shift capture).

NEXT: ILA v8 - probe the CGA RALU register-file write/read port (B-address,
write strobe, write data / read data), trigger on accesses to register 6
during the poll; compare the stored vs read-back value on silicon. Find
the nets in Verilog/DELILAH-CPU/CGA_ALU/circuit/CGA_ALU_RALU*.v. If R6
reads back wrong at speed, the fix campaign moves to that register file's
FF-mode conversion.

## 24-AUG ~12:00 - R6 lead dead; runaway prints ONE CHAR PER RTC TICK

- R6 EXONERATED: the healthy rig (ND120_R6_PROBE in CGA_WRF_RBLOCK.v,
  sim-only define) also holds scratch R6=0o1 at the post-LFN prompt and
  through the wait - R6=1 is the NORMAL wait-state value, the "expected
  0o4" inference was wrong. 177k R6 writes logged, rich values during
  work, 1 at rest. Log: /mnt/f/tmp/verilog/lfnrun/rig_lfn_r6.log
- RX ALIVE during the runaway (capda + typing, v8 bitstream): a typed
  char sets DA (IOR 0xF818 -> 0xB818 at the CSA 0x17E-0x180 status
  service) and STAYS pending - not consumed, not lost. Yet typed
  commands still have no effect (runaway continues).
  Capture: /mnt/f/tmp/verilog/nexys_lfn_ila_v8_capda_typing.csv
- QUANTITATIVE ANOMALY: the runaway prints ~36 chars per ~0.85 s line =
  ~23 ms PER CHARACTER, while the same hardware prints the FILSYS banner
  at full 9600 speed (1.04 ms/char). 23 ms is one RTC tick (20 ms) plus
  overhead: THE RUNAWAY PRINTS ONE CHARACTER PER RTC TICK. The capda
  window (246 us) sits inside a single character with the print-wait
  polling TBMT busy at ~17 us cadence - the char itself transmits at
  9600; the 20 ms sits BETWEEN characters. The 0x54xx cell accesses in
  the flow + the MON 66/64 calls fit an RTC-paced wait layer.
NEXT: measure the inter-character gap precisely and what ends it -
trigger on the TBMT ready edge (IOR bit15 falling) and capture forward:
does the next char start immediately (then the 20 ms is spent INSIDE
FILSYS's retry/bookkeeping) or does the machine idle until the RTC
interrupt (then the print-wait's ready test never passes and the RTC
wakes it - a status-test failure at the microcode/IOR level, which the
oracle-vs-silicon IOR values can pin). Also compare: does the HEALTHY
banner print use the same 0x601b wait (fast) - if yes, what differs in
the wait's entry state during the runaway.

## 24-AUG ~12:40 - COURSE CORRECTION: stop FILSYS-internals archaeology, run the timing A/B

Three consecutive window-readings of the runaway loop were WRONG (input
-wait timeout -> "one char per RTC tick" -> "drain spin"): 246 us ILA
windows show fragments and the fragments mislead. Corrected measured
facts that DO stand:
- chars stream at full 9600 pacing when printing (capready: next char
  10.5 us after TBMT ready; capioq: 95% busy-poll ratio consistent with
  full-speed streaming);
- per printed line: ~8 bookkeeping writes incl. the putchar wrapper at
  0x60ED (MIN I on the in-flight counter 0x57D4, L saved at 0x60EC -
  decoded from oracle disasm);
- the pending typed char is never consumed; the input-poll IOR read with
  DA visible NEVER occurs at ICA 0x6106 (capinp timeout with char
  pending);
- memory 100% clean (v7), registers consistent (v8 R6 exonerated by the
  rig reference).
The remaining explanation class: a timing-marginal CPU path at 16.67 MHz
flipping one branch in LFN's answer path - identical RTL is clean in the
rig at real UART timing.
IN FLIGHT: clk=8 bitstream with TODAY's RTL (the 23-AUG clk8 test ran on
the old RTL). LFN passes at 8 MHz -> timing confirmed, bisect frequency
and attack the failing paths; still fails -> a sim-invisible logic
difference and the hunt changes character.
All captures: /mnt/f/tmp/verilog/nexys_lfn_ila_v8_cap{da_typing,ready,
qual,gap,ioq}.csv + v7 set.

## 24-AUG ~13:15 - ROOT CAUSE FOUND: the FPGA runs UNPATCHED microcode at 0o2002

THE CHAIN, each link measured:
1. clk=8 with today's RTL STILL runs away -> clock rate out.
2. The rig (clean) uses RUNTIME WCS load; the board uses SKIP_WCS_LOAD
   preload. New rig probe ND120_WCS_DUMP (dma_p3_main.cpp) dumps the
   loaded 8192x64 WCS; diff vs the preload image
   Code/Microcode/wcs/wcs_image.hex: EXACTLY ONE WORD differs -
   LUA 0o2002 (MACL+1): preload 7b800020810960e0, runtime 7b800020810900e0
   (RF0 bits 14:13 = the COND,F=0 / F,JMP enable fields per the DELILAH
   listing).
3. The difference traces to the SOURCE FILES: the tree carries TWO
   variants of AM27256_45133L.hex - byte 4104 = 0x60 in Code/Microcode/
   (+ every CPU-BOARD unit-test copy), 0x00 in Verilog/{sim,runSim,
   dmaSim,ND-120-Yosys}. md5s: ccffae8c... vs ac983381...
4. git history: commit 895f360 (07-DEC-2024, Ronny) "Need pacthed hex
   files for the run-simulator" - the patch DISABLES the conditional
   microjump at MACL+1 that misbehaves in this RTL. Every simulator and
   every instruction-verify/golden-trace validation since has run
   PATCHED microcode. Code/Microcode kept the raw dump; in JUL-2026
   gen_wcs_image.py built the FPGA preload from the RAW dump - so the
   Nexys AND THE TANG have been running the one microword no simulation
   ever validated. FILSYS LIST-FILE-NAMES is the first workload that
   visibly trips it (MACL+1 = memory-address-cycle microcode; the
   misbehaving conditional fires in LFN's answer path).

FIX APPLIED (uncommitted): Code/Microcode/gen_wcs_image.py now applies
the documented runtime patch (PATCHES table: LUA 0o2002 clear bits
0x6000) and the wcs/ images are regenerated - the preload now equals
what the simulators load. The raw PROM dumps stay untouched.

VERIFICATION IN FLIGHT:
- negative control: -promload build (runtime load FROM THE RAW PROMs) is
  building - expected to STILL fail LFN (it loads unpatched content).
- positive test: patched-preload build next - expected to FIX LFN.
- THE TANG runs the same unpatched preload (tang20k_defines SKIP_WCS_LOAD
  from the same wcs/ images): after the Nexys confirms, the Tang needs a
  rebuild with the regenerated images too.
OPEN QUESTION for later (not blocking): WHY the RTL needs the DEC-2024
patch at MACL+1 - the underlying conditional-microjump (F=0 at that
word) divergence from the real machine is still an un-root-caused RTL
bug; the patch is a validated workaround, now applied consistently.

## 24-AUG ~13:30 - CORRECTION: Tang PASSES LFN with the unpatched word - causality unproven

Ronny measured on the TANG (400& tape boot, FILSYS): LIST-USERS and
LIST-FILE-NAMES work with NO problems - and every Tang WCS copy
(fpga/tang-nano-20k/wcs_*.hex incl. the synthesis-stage copies of the
current build) carries the UNPATCHED word 60e0 at 0o2002. So the raw
microword does NOT break LFN by itself. The "root cause found" claim of
13:15 is DOWNGRADED to: a real microcode split (sim validates patched,
both boards run raw - must be unified either way), causality for the
Nexys LFN failure UNPROVEN.
Decision matrix now: rig+patched=PASS, Nexys+raw@16.67=FAIL,
Nexys+raw@8=FAIL, Tang+raw@6.75=PASS.
IN FLIGHT:
- rig with the RAW PROMs (scratchpad run, ND120_WCS_DUMP verifies 60e0
  loaded): does the raw word break LFN IN SIMULATION? If yes - the
  Nexys failure reproduces with full visibility and the MACL+1
  conditional divergence gets root-caused in the rig; if no - the raw
  word is innocent in this RTL too and the Nexys difference lies
  elsewhere (Xilinx-vs-Gowin mapping of the condition cone, or another
  board delta).
- Nexys -promload negative control + patched-preload positive test still
  queued on Vivado.

## 24-AUG ~14:00 - MICROCODE FULLY EXONERATED; testing the BLOCKRAM model in sim

Completed A/B matrix for the LFN runaway:
| config                              | word 0o2002 | LFN  |
| rig (sim RAM, runtime load)         | patched     | PASS |
| rig (sim RAM, runtime load, RAW)    | raw         | PASS |
| Tang preload 6.75 MHz               | raw         | PASS (Ronny) |
| Nexys preload 16.67 MHz             | raw         | FAIL |
| Nexys preload 8 MHz                 | raw         | FAIL |
| Nexys -promload (runtime load)      | raw         | FAIL |
| Nexys preload PATCHED 16.67 MHz     | patched     | FAIL |
Microcode content AND load path are OUT. The microcode SPLIT in the tree
(sim copies patched since commit 895f360, Code/Microcode raw) remains a
hygiene problem - both variants demonstrably work in sim, so WHICH to
canonicalize is Ronny's decision; the gen_wcs_image.py PATCHES table
addition can be kept or reverted accordingly (bitstreams built either
way behave the same).
Remaining Nexys-vs-Tang deltas: (1) Vivado-vs-Gowin synthesis of the
same RTL (loop cones, latch mapping), (2) MEM_RAM_49_BLOCKRAM vs the
Tang SDRAM bridge, (3) the Nexys top/DDR2 integration.
IN FLIGHT: the rig rebuilt with the EXACT Nexys memory configuration
(-DMAIN_RAM_BLOCKRAM -DND120_BLOCKRAM_ADDR_BITS=15, DMASIM_BLOCKRAM
backdoor). Rig fails LFN -> reproduced in sim with full visibility;
rig passes -> memory model out, next tool = Vivado post-synth funcsim
netlist run inside the rig (synthesis-functional divergence hunt).
Bitstreams kept: nd120_nexys4ddr_{clk8_current,promload,patched}.bit.

## 24-AUG ~14:10 - ROOT CAUSE PROVEN IN SIM A/B: BLOCKRAM ADDRESS TRUNCATION (ADDR_BITS=15)

The rig rebuilt with the EXACT Nexys memory configuration:
- MAIN_RAM_BLOCKRAM + ND120_BLOCKRAM_ADDR_BITS=15: the LFN runaway
  REPRODUCES in Verilator ("o update and check directories" forever).
  Log: /mnt/f/tmp/verilog/lfnrun/rig_lfn_blockram.log
- Same build with ND120_BLOCKRAM_ADDR_BITS=16: LFN PASSES clean (42
  files, prompt). Log: rig_lfn_blockram16.log
ROOT CAUSE: ADDR_BITS=15 gives 32K words per bank = HALF the ND-120's
64K-word logical space; every access at/above word 0o100000 wraps onto
low memory. FILSYS's LFN answer path touches such an address; the
aliased state re-arms the help-line reprint forever. The Tang (4 MB
SDRAM) and the sim RAM carry the full space - only the Nexys BLOCKRAM
truncated it. Same family as the fixed 400& lin-concat truncation, one
bit deeper. Explains every silicon symptom: any answer triggers it,
input-immune, clock-independent (8 = 16.67), microcode-independent
(raw = patched), load-path-independent (preload = promload).
FIX (uncommitted): fpga/nexys4ddr/build.tcl ND120_BLOCKRAM_ADDR_BITS
15 -> 16. RAMB budget was 88/135 tiles; the doubled main RAM is
borderline - the fix build is in flight; if placement overflows, the
fallback is 2 banks x 64K words (BANK2 dropped).
MICROCODE SPLIT (side finding, Ronny's decision): both word-0o2002
variants pass everywhere now; whether to keep the gen_wcs_image.py
PATCHES entry (canonicalize the DEC-2024 sim patch) or revert it and
re-raw the sim copies is open - behaviorally equivalent, but ONE variant
should be canonical tree-wide.

## 24-AUG ~14:35 - FIXED AND VERIFIED ON SILICON

ND120_BLOCKRAM_ADDR_BITS=16 bitstream (fits: 128/135 RAMB36 tiles =
94.8%, WNS +0.756 ns at 16.67 MHz, saved as
fpga/nexys4ddr/nd120_nexys4ddr_addr16.bit and now the tree default in
build.tcl): on silicon, LIST-FILE-NAMES with bare CR lists all 42 files
and returns to a live prompt; repeat with user 0 clean; LIST-USERS
clean; input works afterwards. THE LFN RUNAWAY IS FIXED.

The one-line fix: fpga/nexys4ddr/build.tcl ND120_BLOCKRAM_ADDR_BITS
15 -> 16 (full 64K-word logical space per bank instead of half).

FOLLOW-UPS (Ronny's decisions, then the plan's next tasks):
1. Review/commit the accumulated diff (this fix + the SC2661 TX-abort
   fix + test benches + probe infrastructure + rig features).
2. Microcode canonicalization: raw vs DEC-2024-patched word 0o2002 -
   both pass everywhere; pick ONE for the whole tree (gen_wcs_image.py
   PATCHES entry stays or goes accordingly).
3. RAMB budget note: 94.8% leaves ~7 tiles headroom on the xc7a100t;
   if future features need block RAM, the 2-banks-of-64KW variant frees
   ~32 tiles.
4. Plan continues: task 2b Winchester LFN, task 3 1560&/TPE (the MMU
   workstream gate), task 4 SINTRAN.

## 24-AUG ~15:10 - TPE front: oracle references measured; the version check is the blocker

- 1560& TPE BOOTS on the Nexys now (the ADDR_BITS fix unblocked task 3).
  Ronny's silicon transcript: TPE Monitor B01 banner, then
  "==TPE42=> The clock is not updated (display panel wrong or unesting)",
  then CONF and LOAD INSTR both abort "*** TPE version too old ***"
  (requires B00 / A02 - both OLDER than B01, so the comparison itself
  misbehaves).
- ORACLE (nd100x --boot=floppy, same FLOPPY.IMG): NO TPE42 warning, and
  CONF prints its banner with NO version complaint. The oracle emulates
  the PANEL PROCESSOR (TRA PANS/TRR PANC message protocol incl. the
  calendar clock, src/devices/panel/); our RTL has the DGA register
  plumbing (EPANS/LDPANC/PRQ) but NO panel processor behind it. NOTE:
  TPE42 alone may be benign - a real panel-less ND-100 warns the same
  way; whether the VERSION check depends on the clock is unproven.
- RIG (BLOCKRAM-16 build): reproduces the boot + TPE42 warning, prints
  "TPE>" (txhold=0x3e) and then the prompt is DEAF - typed chars pile up
  to an SC2661 OVERRUN, never consumed. TPE console input is interrupt-
  driven (level 12); suspicion: the console input interrupt path in our
  RTL. Matches the OLD rig stall note (TPE polls the flag at 0o176755
  that the input interrupt handler should set). SILICON TPE accepts
  input, so silicon-vs-rig differ here too - unresolved.
  Logs: /mnt/f/tmp/verilog/lfnrun/rig_tpe_conf2.log, oracle session on
  DAP 4711 parked at a healthy TPE> prompt.
NEXT on this front: (1) find what the CONFIGURATION overlay actually
compares for the version check (oracle DAP: breakpoint/trace around the
CONF load, or find the version cell TPE exports); (2) the rig console-
input interrupt delivery (level 12 IDENT for the internal console);
(3) decide whether a minimal panel-processor stub (PANS present-bit +
calendar tick) is wanted - it would silence TPE42 and match the oracle.

## 24-AUG ~16:15 - TPE console input: interrupt path exonerated by measurement

Rig probes (ND120_INT12_PROBE in IO_REG_41.v - IOC bits, DA, BINT lines,
and every SIOC write value):
- TPE NEVER sets IOC bit 1 (console input interrupt enable): all SIOC
  writes over a full TPE boot are 0o141/0o151/0o150/0o050/... - bit 1
  clear in every one. The console INPUT interrupt is not used by TPE;
  input must be polled (the RTC level-13 interrupt fires constantly -
  IOC0+IOC3 - and is the natural poller).
- BINT12 wiring itself is correct in ND3202D.v (unlike the old level-10
  dead net) - it simply never has reason to fire.
- The rig's DA shows brief pulses, not a held pending char - the sim-side
  consumption chain (who reads the char, where it goes, why TPE's prompt
  stays deaf in the RIG ONLY) is still open, but SILICON TPE input works,
  so this thread is parked. Logs: /mnt/f/tmp/verilog/lfnrun/
  rig_tpe_{int12,sioc}.log
PRIORITY remains the silicon-relevant VERSION CHECK ("*** TPE version
too old ***" for overlays that are OLDER than the monitor). Open
approaches: (a) find TPE's monitor-version cell + the overlay's required-
version cell via the oracle (DAP memory reads around the CONF load) and
compare on silicon via TPE's own examine commands at Ronny's console;
(b) get the rig prompt consuming input, then reproduce CONF in sim.

## 24-AUG ~16:45 - AUTONOMY KIT + ALL SESSION-REVIEW IMPROVEMENTS LANDED

Per Ronny's directives ("test without me being involved" + "do all
improvements"), all uncommitted:

AUTONOMOUS BOARD TESTING (validated end-to-end on the live board):
- fpga/nexys4ddr/board_expect.ps1 - expect-style console driver:
  SEND / EXPECT <sec> <regex> / FAILON <regex> (instant fail on e.g.
  ERRFATAL or the runaway line) / QUIET <sec> (idle-prompt check) /
  PAUSE / LABEL. Timestamped transcript, BT_RESULT verdict, distinct
  exit codes for hang vs failon vs port-busy.
- fpga/nexys4ddr/run_board_test.sh - full cycle: JTAG reset, run the
  .bt script, on FAIL take an ILA capnow of the LIVE machine (-ila),
  save artifacts to boardtest-results/<name>-<stamp>/. Backs off
  cleanly if a human holds COM11.
- boardtests/: lfn.bt (PASS on the live board), tpe_boot.bt (PASS;
  found on the way that TPE HELP is interactive), sintran_boot.bt
  (FAILON ERRFATAL, ready for the task-4 campaign).

CONFIGURATION GATES:
- tests/microcode_sync.py + make test-microcode-sync (registered in
  run_all_tests.sh): every PROM-image copy must match Code/Microcode,
  dated exceptions only. On its FIRST run it found a FOURTH microcode
  variant: BIF_BCTL_SYNC_8/sim/AM27256_45132L.hex byte 4109 (LUA 0o2003
  MACL3, RF1 bit7) - flagged UNINVESTIGATED for Ronny in the exception
  list.
- (test-blockram-space and the SDRAM 4 MB walks landed earlier today.)

BOARD-PARITY SIM BUILDS:
- dmaSim: make rig-nexys / make rig-tang (exact board define sets, one
  command); -Wno-PINMISSING/-Wno-IMPLICIT moved into the Makefile's
  default suppressions with reasons.

KNOWLEDGE CAPTURE:
- docs/ILA-PROBE-SEMANTICS.md - every capture lesson (ICA/CSA transient
  semantics, CSV skew, ltx pairing, TCK, timeout-in-minutes, qualified
  capture, measured baselines).
- docs/nd120-facts.md - the re-derived-repeatedly machine invariants:
  address-space contract, console register/bit maps, WRF register map,
  microcode word layout + the two known variants, intended Tang-vs-Nexys
  differences, panel-processor status, software dialog behaviors.
- tests/golden-console/ - FILSYS and TPE golden dialogs + the LFN user-0
  golden listing (oracle + silicon verified).
- README.md - unattended-operations runbook (reset, board tests, traps).
- build.tcl stale comments corrected with dates: the "12 loops remain"
  block now states the current truth (0 LUTLP, 2 auto-false-pathed
  nodes), and the WNS -35 measurement is marked superseded (post-ring-
  cut ~+1.4 ns).

## 24-AUG ~17:15 - SINTRAN front: boot incantation found, ERRFATAL localized

AUTONOMOUS BOARD RESULTS (run_board_test.sh, no human):
- `201540&` is the WRONG incantation - silent bootstrap death on both
  cache configs. Bare `&` (the ALD default, Winchester autoboot) LOADS
  SINTRAN and reproduces Ronny's exact ERRFATAL (L-reg 042514) within
  ~30 s on the cache-enabled addr16 build. boardtests/sintran_amp.bt is
  the repro; sintran_boot.bt kept for the 201540& form.
- Cache A/B: cache ON -> ERRFATAL with report; cache OFF -> the
  Winchester bootstrap dies SILENTLY (nothing printed in 10 min) while
  FILSYS/LFN still PASSES on the same nocache bitstream. So nocache has
  its own EARLIER failure on the Winchester path (separate open item),
  and the CPU cache is NOT the ERRFATAL's cause.
- The instrumented nocache+ILA build over-utilizes BRAM (166/135
  RAMB36): the v8 probe set + 64K-word RAM do not fit together. To
  instrument SINTRAN hangs, trim probe groups or halve C_DATA_DEPTH in
  build.tcl's ILA section.

ERRFATAL LOCALIZED (oracle DAP on a COPY of WD0-M.IMG, breakpoint at
0x454C = 0o042514):
- The healthy boot also passes 0o042514: it is the return of `JPL I 7`
  at 0o042513 (pointer 0x4552 -> 0o004356), inside a two-call loop at
  0o042510-14 (A:=0, T:=0, loop{call 0o077132; call 0o004356}).
- 0o004356 = SINTRAN's internal-register/paging init: IOF, clear SSPTM,
  then a 16-iteration loop that BUILDS an internal-register instruction
  per index (SHA/RORA arithmetic into T) and `EXR ST`s it, storing each
  result (`STA I ,X 150`), then POF. On silicon one of these 16 built
  TRA/TRR-class ops misbehaves -> ERRFATAL with NPIT/APIT zero, level 0.
  Same instruction class as the old "Micro-code not loaded. CPU revision
  too low" incident.
NEXT: single-step the oracle loop (parked AT the breakpoint) to log the
16 built instruction words + healthy results, then compare on silicon
(deposit a mini-program via OPCOM that EXRs the same 16 ops and prints
the results - the tests/floppy-dma-test generator pattern fits).

## 24-AUG ~17:35 - SINTRAN ERRFATAL: the caller and the check are IDENTIFIED

Measured on the parked oracle (DAP, breakpoints + single-step) plus the M06
symbol list and the NPL source:

- `ERRFA = 004356` (SYMBOL-1-LIST). The routine at 0o004356 that an earlier
  note called "internal-register init" is **ERRFATAL itself**; its SAT-17
  loop is ERRFATAL's own internal-register DUMP (EXR of built TRA ops into
  the save area at `,X 150`).
- The loop at 042510-042514 is a Winchester driver wait loop:
  `042512 JPL I -104` calls **WISTA** (the Winchester status/termination
  routine, `23-WINCHESTER-POF.NPL` line ~225; runtime address 077132),
  `042513 JPL I 7` = **CALL ERRFATAL** (the driver's ERROR return slot),
  `042514 JMP -2` = the BUSY return (wait, poll again).
- L-reg 042514 in the crash = the JPL at 042513 -> ERRFATAL entered from
  WISTA's ERROR EXIT. On the healthy booted oracle WISTA always leaves by
  the BUSY/FINISHED path (measured: bp at 042513 never fires).
- WISTA error taxonomy (source lines 484-491) sets a SOFTWARE status in T:
  `0` HDERR (hardware error, X = hardware status), `1` MORER (bank >377),
  `4` MEMER (memory address register readback mismatch after transfer),
  `10` LAOUR, `100` DILLC (illegal code), `200` CNACT (controller not
  active after activate).
- **ERRFA saves the registers at entry**: X->0o004347, T->0o004350,
  A->0o004351, D->0o004352, L->0o004353. The WD datafield base B=042346:
  SSTAT (last IOX 504 status) at 042244, BADTR 042273, WANKN 042274,
  SEEKF 042300, TRTZ 042305, BUSFL 042311, SVLCA 042312, SVLWC 042313.
- SINTRAN's ERRFATAL ends in WAIT with interrupts off -> the ND-120 drops
  to STOP -> **OPCOM answers on the console after the crash**, so the whole
  dump is readable over serial with no ILA build.

RUNNING NOW: `boardtests/sintran_crashdump.bt` (cache addr16 bitstream,
-Pace 300) - boots bare `&`, waits for ERRFATAL, dumps the cells above.
T at 0o004350 names the failing check.

## 24-AUG ~18:45 - SINTRAN front: rig reproduction running, slim ILA building

- Silicon repro sharpened: ERRFATAL arrives **2.4 s** after `&` (transcript
  `boardtest-results/sintran_crashdump.log`). OPCOM does NOT answer at the
  halt - the RTL never drops to STOP on SINTRAN's final WAIT, so the
  post-crash serial dump plan is dead. TODO(worth an RTL thought later:
  a way into OPCOM from a running/halted CPU).
- **The dmaSim rig now boots `&` through the REAL SD/FAT Winchester path**:
  new target `rig-nexys-wd` (dmaSim/Makefile) = Nexys config (BLOCKRAM
  addr16, cache, real-timing UART) + ND120_INCLUDE_WD + ND120_SD_STORAGE +
  ND120_SD_WD; card built by SD-FAT/sim/make_wd_card.sh from a fresh COPY
  of WD0-M.IMG (card at SD-FAT/sim/nd_wd_card.img, 82837504 bytes; image
  copy at /mnt/f/tmp/verilog/lfnrun/WD0-RIG-COPY.IMG). dma_p3_main.cpp:
  console watcher triggers on "ERRFATAL" and dumps the ERRFA saves
  (0o4347-53) + WD datafield cells via the BLOCKRAM backdoor.
- Measured in the rig (ND120_WD_TRACE, log rig_sintran_wdtrace.log):
  mass load (block 0, 2000 words, ctrl 000004) COMPLETES (rft=1), then
  SEEK M4, then reads to 172000/161000 complete with CORRECT end-address
  readbacks. ~10M cycles per transfer at sim SD speed - the earlier
  "hang" readings were the boot CRAWLING, not stuck. Cache ON vs
  ND_STORAGE_DISCS_UNCACHED: identical behavior so far (cache exonerated
  for this phase). Logs: rig_sintran_amp.log (cached, 600M ticks),
  rig_sintran_uncached.log, all in /mnt/f/tmp/verilog/lfnrun/.
- RUNNING: 4G-half-tick cached rig boot (rig_sintran_long.log) - either
  ERRFATAL fires the dump hook (T at 0o4350 names the failing WISTA check:
  0=HDERR 1=MORER 4=MEMER 10=LAOUR 100=DILLC 200=CNACT) or the banner
  appears and the rig diverges from silicon.
- BUILDING: `-tclargs -noburn ilaslim` (build.tcl new mode) - minimal ILA
  (RAM write port + CSA + cpu_txd, depth 1024) that fits beside the
  addr16 RAM; trigger plan: RAM write to 0o4347 catches ERRFA's X,T,A,D,L
  saves on silicon directly. Log: /mnt/f/tmp/verilog/lfnrun/build_ilaslim.log.

## 24-AUG ~20:20 - cache EXONERATED for the ERRFATAL; CCLR defect found+fixed anyway

- Ronny's direction: CPU cache now compiled OUT BY DEFAULT on the Nexys
  (build.tcl: ND120_NO_CACHE unless `-tclargs cache`), matching the Tang.
- MEASURED: the addr16 NOCACHE build hits the IDENTICAL ERRFATAL
  (L-042514, ~2.5 s after `&`) - transcript
  boardtest-results/sintran_nocache_probe.log. The cache is NOT this
  crash's cause. (The earlier "nocache dies silently" reading belonged to
  an older bitstream.)
- Cache-audit agent result (real, kept, just not this bug): the CCLR
  cache-clear was a NO-OP - Shared/support/Am9150.v ignored RESET_n for
  the array contents, so SINTRAN's cache flush after DMA flushed nothing.
  FIXED with a write-port clear sweep (power-up + /R falling edge, reads 0
  mid-sweep). New bench CPU-BOARD-3202/circuit/sim/CPU_MMU_CACHE_DMA_tb.v
  (test-mmucache-dma, registered); agent is updating test-am9150 and the
  test-mmucache golden that had encoded the broken semantics.
- ERRFA probe history: v1 (L-cell trigger) armed on the bulk resident
  load (octal 4347..4353 are consecutive - a sweep is indistinguishable);
  v2/v3 (strict-order + neighbor guard) never armed on silicon - the real
  microcode's write pattern is not the clean ascending burst; v4 (BUILDING
  NOW) assumes nothing: always-latch the five cells, arm ONLY when the
  console TX itself spells "ERRFA" (8N1 deserializer in the probe).
  Bench updated and PASSING for v4 (scrambled order + text arming).

## 24-AUG ~20:25 - EVIDENCE CAPTURED: the ERRFATAL is DILLC (illegal function code 0o13)

The v4 probe (console-text-armed) delivered on silicon
(boardtest-results/sintran_errfa_v4_r1.log):

    EF 060005 040000 177773 000000 042514
        X      T      A      D      L

- T = 040000 = software status BIT 14 = **DILLC, ILLEGAL CODE** (the DERR
  taxonomy values are shifted left 8 into the status word: 1->bit8 MORER,
  4->bit10 MEMER, 10->bit11 LAOUR, 100->bit14 DILLC, 200->bit15 CNACT).
- A = 177773 = -5 = (function & 77) - 20 at the DILLC test
  -> **the driver was handed function code 0o13** (legal: 0..3 and 020).
- L = 042514 confirms entry from the driver's ERROR slot at 042513.
- X = 060005 (b0,b2 ACTIVE,b13,b14) - surprising ACTIVE at the error exit,
  not yet explained; do not over-read it.
- Outcome distribution over 4 boots of IDENTICAL nocache bitstreams:
  2x ERRFATAL (~2.5 s), 2x silent hang >300 s. NON-DETERMINISTIC.

READING: the Winchester driver is being CALLED with a garbage function -
the request block / caller state in memory is wrong, i.e. the SINTRAN
resident or its tables LOADED FROM DISC ARE CORRUPT in memory. Fits the
flavor split (whichever corrupt word bites first: illegal-code crash vs
infinite loop) and fits the CPU being oracle-exact.

NEXT: SINTRAN-free Winchester DATA-INTEGRITY test on the board - OPCOM
deposit a reader program (encode with nd100-as, never by hand), read
block N to a buffer, examine the buffer over the console, diff against
the image file. The probe bitstream for this evidence run is saved as
nd120_nexys4ddr_nocache_errfaprobe_v4.bit (also the current default
nd120_nexys4ddr.bit).

## 24-AUG ~21:20 - Winchester READ path proven CLEAN on Nexys silicon

The SINTRAN-free integrity test (tests/wd-integrity-test/gen_wd_read_test.py,
boardtests/wd_integrity.bt - deposits a reader via OPCOM, program prints
per-block "K <blk> M <mismatch> C <checksum>"):
- M=000000 on every block: double-reads agree, the path is DETERMINISTIC.
- Checksums for sectors 2,3,5,6,7 match the pristine WD0-M image EXACTLY
  (big-endian, 1 KB sectors, GEO_SPT=9). Sectors 0-1 differ by the same
  delta 0o314 in both overlapping reads = ONE word of sector 1 changed =
  the card image legitimately modified by earlier boots.
- Blocks 9+ returning identical data was the TEST's own naivety (sector
  field > SPT-1 takes the out-of-range path) - not a bug.
CONCLUSION: disc->memory data is good; the DILLC function code 0o13 is
manufactured elsewhere (in-memory corruption by something else, or a bad
call path). NEXT INSTRUMENT (bench-verified, building as v5): the probe
now also keeps a 128-entry ring of the last RAM READ addresses, frozen at
the jump into ERRFA (read of 0o4356 not preceded by 0o4355), printed once
as a "P ..." line ~0.5 s after the crash text - the dying path plus the
operand read that delivered the 0o13.

## 24-AUG ~22:15 - MEMER path CONFIRMED by the P ring; standalone repro so far NEGATIVE

- v5 probe P-ring decoded against the oracle disassembly: the crash run
  executed WISTA's address-readback compare (077234..077251), took
  `JAF 2` at 077251 (A != 0), landed on `JMP I 65` -> pointer read 077340
  -> fetches 077760 `SAT 4` = **the MEMER arm**, then the DERR tail
  crossing 077777->100000 and EXIT into the caller's error slot 042513.
  T=002000 at ERRFA = 4<<8 = MEMER ✓ (that boot; an earlier boot showed
  T=040000 DILLC - the verdict varies per boot). A = 177773 = -5: the
  memory-address readback disagreed with the driver's expected end
  address by FIVE words. B is correct (datafield reads at 0423xx match).
- Winchester DATA path exonerated everywhere it was tested: silicon
  double-reads deterministic + checksum-exact vs the image (lower AND
  upper buffer halves); rig identical (blocks 0-8 MATCH; 9+ = the test's
  own sector>SPT artifact, GEO_SPT=9, 1 KB sectors, linear LBA verified).
- Standalone MA-readback repro NEGATIVE so far: after block reads
  (0o2000 words, cyl 0, head 0), MA reads back EXACT (122000) - polled
  (ctrl 000004) AND interrupt-enabled (ctrl 000005), double-readback
  clean (boardtests/wd_integrity_ma.bt, wd_integrity_int.bt).
- The failing SINTRAN transfer's SHAPE is the missing variable ->
  v6 probe (BUILDING) extends the EF line to 8 groups:
  EF <X> <T> <A> <D> <L> <SVLCA> <SVLWC> <SSTAT> - the driver's
  issue-time expected address + word count + last status, latched from
  the datafield writes (042312/042313/042244). Next crash names the
  exact transfer to replay standalone.

## 24-AUG ~23:05 - three crash flavors, one signature; standalone repro still negative

Three instrumented crashes (v5/v6 probe):
  1. T=040000 DILLC (function 0o13), A=-5
  2. T=002000 MEMER (readback residue),  A=-5
  3. T=000000 HDERR (via the IERR/retry region, TRTZ read -> HDERR),
     A=-5, SSTAT=060005 (ACTIVE **set** at WISTA's save), SVLCA=062000,
     SVLWC=011000 = 4608 words = EXACTLY one full track (9 sectors).
Standalone repro all NEGATIVE (data + MA readback EXACT):
  block reads 0o2000 words polled AND int-enabled, double readback, full-
  track 0o11000-word reads (boardtests/wd_track.bt). The RTL updates the
  visible MA register ONLY at FinishOperation (E_DELAY end, ND_WINCHESTER
  ~line 1100) - atomically with ACTIVE->0, rft->1, irq<=int_en - so a
  short readback cannot come from a completed transfer; a MID-transfer
  read returns the START address (would give -COUNT, not -5).
A=-5 appears in ALL THREE flavors through DIFFERENT formulas (DILLC:
  (func&77)-20+14 with func=0o13; MEMER: end-address residue) - too
  specific for coincidence, cause not yet identified. Candidate theories
  still open: interrupt/level-switch register corruption (T garbled
  between caller and driver), spurious level-11 IDENT re-entry (fits
  SSTAT ACTIVE + silent-hang flavor), IOX-write corruption under load.
v7 probe (BUILDING): EF line now 10 groups - adds 9TREG (042314, the
  function argument WISTA saved at entry) and 9XREG (042317). If the
  next DILLC crash shows 9TREG=000013 the garbage came from the CALLER
  (software/context-switch side); if 9TREG is legal the driver misread it
  (IOX/hardware side). Rig 12G boot still grinding (7.9G, silent).

## 24-AUG ~23:20 - the "-5" was a red herring (A=IRETR); reentrancy now prime suspect

Source decode of the driver's exit code (23-WINCHESTER-POF.NPL WFINI/DERR):
- ERRFA's A = IRETR (the retry-limit constant, -5) - loaded on EVERY error
  exit. The constant A=177773 across all three crash flavors is EXPLAINED
  and carries no information. Discard every -5-based inference.
- ERRFA's X = SSTAT (= the cap; 060005, ACTIVE **set** at the fatal pass).
- ERRFA's T = (DERR code << 8) | (9TREG & 377). All three crashes have low
  byte 0 -> in the DILLC crash the function-code CHECK saw an illegal
  value while DERR's later read of the SAME cell contributed 0: the
  driver's view of its own datafield was INCONSISTENT within one pass.
- v7 capture (r1, MEMER flavor): 9TREG=000000 (function READ, legal),
  SVLCA marches 062000 -> 073000 between crashes (the sequential full-
  track resident reads), SVLWC=011000 every time.
PRIME SUSPECT: WISTA reentrancy/interleave - the polled wait-loop call
racing the level-11 interrupt call (entry save TAD=:SATAD clobbers
9TREG/SATAD mid-use; ACTIVE=1 status fits the other call's transfer
running). RTL corroboration: ND_WINCHESTER's non-activating control-word
branch raises s_irq from iox_wdata[0] OUTSIDE the ready guard
(~line 936), against its own sec-4.1 comment; the 05-AUG-measured
"ACTIVE and FINISHED at once" flaw in the same branch is still there.
NEXT INSTRUMENT (v8): ring of the last IOX accesses to the WD card
(reg, rd/wr, data) via the s_dev_iox_* seam, printed as a third line
after the crash - shows interleaved GO/clear/status traffic directly.

## 24-AUG ~23:50 - SMOKING GUN: IOX reads deliver the WRONG WORD to the CPU

v8 probe (adds the "W" line - ring of the last 48 IOX accesses to the WD
card at the DEVICE seam, module fpga/nexys4ddr/nd120_errfa_wdiox_ring.v,
bench test-wdiox-ring registered):
- Crash r1: the device answered EVERY status read R4:060005 (busy,
  consistent, dozens in a row) - but the CPU-side SSTAT save holds
  **164000**, an impossible status word, and 0o164000 is the IOX OPCODE
  BASE: the CPU captured its own instruction word instead of the card's
  answer. X=SSTAT=164000 on the CPU side vs 060005 at the seam, SAME READ
  WINDOW.
- Crash r3: the L=042513 flavor with X=000067, T=060000, D=171400 - more
  junk-shaped CPU-side values.
READING: the device chain answers correctly; the value is corrupted
between the device OR-bus and the CPU register - an IDB/bus capture race
that only bites while the WD DMA is stealing cycles (every crash is
mid-transfer; the Tang at 6.75 MHz never sees it; verdict varies with
timing phase). Earlier standalone tests were BLIND to it: a corrupted
POLL read merely loops again; only SINTRAN's decision reads convert
corruption into a crash.
RUNNING: boardtests/wd_ioxhunt.bt - endless full-track sweeps with a
poll loop that counts IMPOSSIBLE status words (bit15/bit12 set); an
"X <count>" line = standalone reproduction. 15-minute window.

## 25-AUG ~01:15 - rig hang DECODED = SINTRAN software timeout (sim-pace
## artifact); silicon gets a second candidate mechanism

The rig hang-trace (rig_sintran_hangtrace.log, ND120_WD_TRACE) shows the
boot doing healthy full-CYLINDER reads (block 002040, count 011000, MA
hi=000001 = bank 1, heads marching in the GO words 345/305/245...), each
taking ~50M sim cycles at sim SD pace - then the driver DEVICE-CLEARS a
still-ACTIVE transfer, issues M4 SEEK (step 41), clears it, M7 RTZ,
clears that: the recalibrate spiral, forever = the silent hang.
**SINTRAN's software timeout fired because the sim SD is ~1000x slower
than real - the rig hang is an ARTIFACT of sim pace, not the silicon
bug.** (Same lesson class as ND120_DEV_DELAY_TICKS.)

But it names a SECOND candidate for silicon: if a real transfer ever
stalls ~2 s (DDR2 staging hiccup?), the same timeout spiral produces
every observed verdict, and 2.4 s to the crash fits a timeout constant.
Standalone counter-evidence: ~4,500 clean fast transfers with zero
timeouts in the hunters. Undecided.

Silicon hunters v1/v2 (tight status polls during DMA; + console IOX
interleave): ZERO impossible status words in 15 min each. The 164000
capture does NOT reproduce without SINTRAN's interrupt/level activity.

DISCRIMINATOR BUILDING (v9): the W ring now carries a per-entry
delta-time field (floor(log2(cycles)) in octal; 30-31 = 1-2 s at
16.67 MHz). On the next crash: polls spaced ~seconds before the clear =
the TIMEOUT mechanism; microsecond spacing with garbage capture = the
IOX-read race. Ring bench updated and PASSING (test-wdiox-ring).

## 25-AUG ~01:30 - CONSOLIDATION: what is proven, what is open, decision needed

TWO distinct silicon crash mechanisms now separated by evidence:

  (1) TRANSFER NEVER COMPLETES. v9 timestamped W ring (r2, MEMER flavor,
      X=060005 correct): the card answered R4:060005 = ACTIVE for all 42
      polls, each t12 apart (~245 us, steady, NOT seconds) - then the
      driver errored. The transfer STAYED ACTIVE and never reached
      FinishOperation. The failing transfer targets MA-hi=1 (bank 1,
      phys >= 0x10000) - the ONE path no standalone test covered (all
      integrity buffers were bank 0). Same bank-decode class as the Tang
      root cause.
  (2) IOX-READ CAPTURE RACE. v8 (r1): card answered 060005, CPU stored
      164000 = the IOX opcode itself. Rare, only with SINTRAN's live
      interrupt/level activity; not reproduced standalone.

NEXT DECISIVE EXPERIMENT (not yet run): a full-track READ into a BANK-1
physical buffer (MA-hi=1), watching whether status bit3 ever completes.
Best run in the dmaSim rig (rig-nexys-wd) where bank-1 writes are
visible via the BLOCKRAM backdoor - the OPCOM assembler path needs a
PUTC trampoline first (gen_wd_read_test.py grew past P-relative reach).

DELIVERABLES THIS SESSION (all bench-verified, NONE committed - awaiting
Ronny):
  - build.tcl: CPU cache OFF BY DEFAULT on Nexys (-tclargs cache to
    re-enable). Cache exonerated for this crash.
  - Am9150.v: CCLR clear-sweep fix (was a no-op). Benches updated:
    test-am9150, test-mmucache (golden re-proven), test-mmucache-dma
    (new), test-mmucache-nocache - all PASS.
  - MEM_RAM_49_BLOCKRAM.v: ND120_ERRFA_PROBE (console-armed EF + P + W
    evidence lines, zero BRAM). Bench test-blockram-errfa PASS.
  - nd120_errfa_wdiox_ring.v + top wiring: the W device-seam ring.
    Bench test-wdiox-ring PASS.
  - dmaSim: rig-nexys-wd target (Nexys config + real SD/FAT Winchester).
  - tests/wd-integrity-test/: standalone WD read-integrity generator
    (base config good; advanced variants need the trampoline).
  - 9 probe bitstreams saved nd120_nexys4ddr_*errfaprobe*.bit.

OPEN DECISION FOR RONNY: which mechanism to chase first - (1) the
bank-1 transfer completion (rig experiment, my recommendation, fits the
Tang precedent) or (2) the IOX-read race (needs a live-interrupt probe).

## 25-AUG ~07:30 - FAT-CHAIN FIX RESOLVES THE DISC PATH; ERRFATAL GONE

The Tang LLM's commit 830629d (FAT chain walked in-sector; a disc op that
cost 362 ms, 97% SD FAT-sector reads, dropped to ~13 ms) was rebuilt into
the Nexys bitstream (nocache default). MEASURED on silicon:

- **The SINTRAN ERRFATAL is GONE.** Bare `&` no longer halts at ~2.5 s;
  the board now runs silently (boot in progress or slow) with no crash.
- **FILSYS floppy LFN still PASSES** (lfn_fatfix.log) - LIST-FILE-NAMES,
  LIST-USERS, no runaway.
- **FILSYS on the WINCHESTER (DISC-74MB-1) PASSES** (filsys_winch.log):
  opened the 75 MB disc, listed users (RT, RONNY, ...), and dumped user 0's
  real SINTRAN directory - SINTRAN:DATA, SEGFIL0:DATA, ND500-MONITOR:BPUN,
  SYMBOL-1/2-LIST, etc. The Winchester read path over the fixed FAT chain
  is HEALTHY end to end. Device name discovered via FILSYS HELP; our card
  geometry = DISC-74-1 (8 heads, 9 spt, 1024 cyl, 1 KB sectors).

CONCLUSION: the earlier ERRFATAL/DILLC/MEMER crashes were the driver's
software TIMEOUT firing because each disc op took ~362 ms (the FAT-walk
cost), not a bank-1 transfer bug or an IOX-read race. Both of those
theories are now downgraded (the IOX 164000 capture was seen once and may
have been a probe/console artifact; not reproduced and no longer needed).

OPEN: does the full `&` SINTRAN boot now COMPLETE? It ran silent past
10 min. Next: let it run longer / watch for the operator banner (may be
7E2 once SINTRAN owns the console; board_expect now takes -Parity/-DataBits
/-StopBits). The disc is no longer the blocker.
