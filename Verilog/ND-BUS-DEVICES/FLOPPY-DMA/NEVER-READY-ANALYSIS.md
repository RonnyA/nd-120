# "Device 156362 Never Ready. Status:000003" - Root-Cause Analysis

Analysis of the TPE (210523I01) boot-then-timeout failure seen in the runSim
Verilator session after `1560&` mass-storage boot. The boot itself works (the
RTL boot-mode byte-server loads and starts the program, "No notes exist." is
printed), but the TPE monitor never prints its banner and, after a long
software timeout, prints:

    Device 156362 Never Ready.   Status:000003

Reference (known-good) model:
  /home/ronny/repos/nd100x/src/devices/floppy/deviceFloppyDMA.h
  /home/ronny/repos/nd100x/src/devices/floppy/deviceFloppyDMA.c
Our RTL:
  Verilog/ND-BUS-DEVICES/FLOPPY-DMA/circuit/ND_FLOPPY_DMA.v
  Verilog/ND-BUS-DEVICES/BUS-IF/circuit/ND_BUS_SLAVE.v
  Verilog/ND120_TOP.v (ND120_VERILOG_DEVICES section)
Sim harness (C++ side of the bus):
  Verilog/simDevices/NDBus.cpp
  Verilog/simDevices/NDDevices.cpp

No RTL or C code was modified. This document is analysis + fix proposal only.

---------------------------------------------------------------------------
1. THE REGISTER MAP (from the nd100x C emulator, controller type 3112 "DMA")
---------------------------------------------------------------------------

From /home/ronny/repos/nd100x/src/devices/floppy/deviceFloppyDMA.h (enum
FloppyDMARegisters) and deviceFloppyDMA.c (FloppyDMA_Read / FloppyDMA_Write):

  offset  IOX addr  dir   meaning
  +0      1560      R     Read data       (C model returns constant 0x0001)
  +1      1561      -     not used
  +2      1562      R     Read STATUS REGISTER 1 (hardware status)
  +3      1563      W     LOAD CONTROL WORD
  +4      1564      R     Read STATUS REGISTER 2 (format word)
  +5      1565      W     LOAD POINTER HIGH  (command-block address bits 23-16)
  +6      1566      -     not used
  +7      1567      W     LOAD POINTER LOW   (command-block address bits 15-0)

STATUS REGISTER 1 (read +2), bit meanings (StatusRegister1 union):
  bit 0   not used (always 0)
  bit 1   interrupt enabled
  bit 2   device active (controller busy)
  bit 3   ready for transfer (RFT)  <- THE ready bit the driver waits for
  bit 4   inclusive OR of error bits
  bit 5   deleted record / EOF
  bit 6   retry on controller
  bit 7   hard error (no memory contact)
  b8-14   error code
  bit 15  dual density controller - ALWAYS 1 (CalculateStatusRegister1 forces
          it; this is how the driver detects the DMA-type controller)

CONTROL WORD (write +3), bit meanings (ControlWord union):
  bit 1   enable interrupt        (copied into status1 bit 1 on every write)
  bit 2   activate autoload       (boot)
  bit 3   test mode
  bit 4   device clear            (sets RFT=1, clears errors)
  bit 5   enable streamer
  bit 8   execute command         (go: fetch command block via DMA and run)

So the observed trace "write +5, write +7, write +3, poll +2 x7" is the
canonical driver sequence: set the 24-bit command-block pointer (high, low),
write EXECUTE (+ optionally ENABLE INTERRUPT) into the control word, then
poll STATUS 1 waiting for bit 3 (RFT) with bit 2 (active) clear.

COMMAND BLOCK (12 words in ND memory at the pointer; header comment in
deviceFloppyDMA.h, matches SINTRAN J source page 411):
  w0  command word (b0-5 function, b6-7 drive, b8-9 format, b10 double sided,
      b11 double density)
  w1  disk address (logical sector)
  w2  memory address high    w3  memory address low
  w4  options / word count high (b15: 1=word count, 0=sector count)
  w5  word/sector count
  w6  STATUS 1   (written back by the controller)   = FSTA1 in SINTRAN
  w7  STATUS 2   (written back by the controller)   = FSTA2
  w8  last memory address high    w9  last memory address low
  w10 remaining words high        w11 remaining words low

STATUS WORD 2 (w7, and IOX +4) is the FORMAT word:
  bits 0-1  bytes per sector: 00=512, 01=256, 10=128, 11=1024
  bit  2    double sided
  bit  3    double density
  bits 8-9  last accessed (selected) unit

---------------------------------------------------------------------------
2. DECODING THE MESSAGE
---------------------------------------------------------------------------

Status:000003
-------------
000003 octal = bits 0 and 1 set. This CANNOT be a raw STATUS REGISTER 1
value: in both the C model and our RTL, bit 15 (dual density) is forced to 1
on every read, so any hardware status-1 read is >= 100000 octal, and bit 0
is never driven. It decodes cleanly, however, as STATUS WORD 2 (the format
word): bytes-per-sector field = 3 (1024 bytes/sector) with double-sided = 0
and double-density = 0. That combination is physically self-contradictory
(1024 B/s is the DS/DD 17b format) - it is not a value the real controller,
or the nd100x C model, ever produces:

  - The C model's READ FORMAT (function 0x22, deviceFloppyDMA.c lines
    506-542) derives status2 from the mounted image size. The TPE diskette
    image (Nd-210523I01-XX-01D.img / 210523I01-XX-01D.img) is exactly
    1,261,568 bytes, so the C model returns status2 = 017 octal
    (1024 B/s + double sided + double density).
  - Our RTL (ND_FLOPPY_DMA.v line 145) computes
    s_rsr2 = {12'd0, cmdword[11], cmdword[10], cmdword[9:8]} - i.e. it just
    ECHOES the command-word format bits, and E_WBACK writes that echo into
    CB+7 (line 484). A command word with format field = 3 and the DS/DD bits
    zero yields exactly 000003.

So "Status:000003" is a fingerprint of our RTL's status-2 echo. The TPE
driver's documented exit convention (comment block in deviceFloppyDMA.h,
"BFDIS" driver: T = hardware status, X = STATUS 1, D = STATUS 2) prints
STATUS 2 in this class of error message.

Device 156362
-------------
156362 octal (0xDCF2) is NOT an IOX address: the IOX device field is 11 bits
(max 03777), so readings like "device 1563" / "1562" as a literal register
address do not survive scrutiny - the whole 16-bit number is one value.
The two credible decodes are:

  (a) A MEMORY ADDRESS in the TPE monitor's data area (56562 decimal, well
      inside 64 KW). TPE error reporters commonly print the address of the
      datafield / status word being waited on. If the command block was at
      156354 octal, then CB+6 (STATUS 1 / FSTA1) is exactly 156362. This is
      directly checkable against the captured IOX trace: the data value of
      the "write +7" (pointer low) should be 156354 octal. If it is, the
      message means "the status word at 156354+6 never showed ready".
  (b) A garbage/corrupted device-number field: TPE has messages of the form
      "**** Error - device number 'NNNNNNB never ready for transfer" (found
      at file offset 0x10062 in
      Verilog/ND-BUS-DEVICES/testdata/210523I01-XX-01D.img).
      If the printed field came from a datafield our DMA writeback stomped
      or never filled, the number is meaningless noise.

The literal string "Never Ready.   Status:" does not occur as contiguous
ASCII anywhere on the diskette image or in TPE-MON-100-B00.BPUN (searched in
both byte orders and with the parity bit stripped), so the exact formatter
could not be pinned down; decode (a) is the one that is mechanically
verifiable from the existing trace and should be checked first.

Either way, "Never Ready" itself is unambiguous: the driver's ready
condition - STATUS WORD 1 bit 3 (CONTROLLER READY) set with bit 2
(CONTROLLER BUSY) clear - was never observed.

---------------------------------------------------------------------------
3. HOW COMPLETION IS SIGNALED IN THE KNOWN-GOOD C EMULATOR
---------------------------------------------------------------------------

deviceFloppyDMA.c, ExecuteFloppyGo + ReadEnd:

  1. On control-word write with EXECUTE: the whole transfer runs
     synchronously (command-block fetch, data DMA, and a FIRST writeback of
     w6-w11 - at that moment status1 still has RFT=0).
  2. A completion callback is queued: Device_QueueIODelay(IODELAY_FLOPPY=300
     ticks, ReadEnd, ...).
  3. ReadEnd (lines 623-637) then does THREE things:
       a. status1: deviceActive=0, readyForTransfer=1;
       b. RE-WRITES CB+6 with CalculateStatusRegister1() - i.e. the memory
          status block NOW says ready (bit 3 = 1, bit 15 = 1, bit 2 = 0);
       c. raises the LEVEL-11 interrupt if interrupt-enabled
          (Device_SetInterruptStatus(intEnabled && RFT, level 11)).
  4. On IDENT level 11 (FloppyDMA_Ident, lines 211-224) the device returns
     ident code 021 octal and clears interrupt-enable + pending.

So the TPE driver has two ways to see completion, and the C model provides
both: (1) the re-written STATUS 1 word in the command block in memory, and
(2) a level-11 interrupt answered by IDENT code 021. The observed trace
(only 7 status polls, then NO further IOX traffic, then a timeout much
later) shows the driver gave up on the bounded IOX poll and settled into
waiting on memory/interrupt - exactly the part our RTL gets wrong.

---------------------------------------------------------------------------
4. OUR RTL VS THE C MODEL - THE MISMATCHES
---------------------------------------------------------------------------

File: Verilog/ND-BUS-DEVICES/FLOPPY-DMA/circuit/ND_FLOPPY_DMA.v

What already matches:
  - +2 read returns the full RSR1 with bit 15 = 1 in ALL modes, including
    after/inside boot mode (lines 125-134, 179). The old boot-mode-only
    {err<<4, rft<<3} status is gone from the current file.
  - Boot mode is left on device clear (control bit 4) or a real EXECUTE
    (control bit 8) - lines 280-329 - so the TPE driver's first EXECUTE
    write cleanly terminates the BPUN byte-server.
  - +5 = pointer high, +7 = pointer low, +3 = control word: identical
    semantics to the C model (lines 274-334).
  - Interrupt condition s_pending = int_enabled && RFT (line 162), BINT11
    line, and IDENT code 021 at level 11 are implemented (lines 162-171)
    and pass the module testbench (BINT11 assertion + IDENT 021 checks in
    Verilog/ND-BUS-DEVICES/FLOPPY-DMA/sim/nd_floppy_dma_tb.v
    lines 418-428).

MISMATCH A - the root cause: the status writeback happens while still busy,
and is never repeated after completion.
  RTL sequence: E_WBACK (writes CB w6-w11) runs BEFORE E_DELAY, and
  E_DELAY's expiry (lines 504-511) only updates the INTERNAL s_active/s_rft
  flip-flops - it never touches memory again. At E_WBACK time s_rft = 0 and
  s_active = 1 (they were set at EXECUTE, lines 322-324, and are only
  cleared in E_DELAY). Therefore the STATUS 1 word our controller leaves at
  CB+6 is permanently:
      bit 15 = 1, bit 3 (READY) = 0, bit 2 (BUSY) = 1
  The C model's ReadEnd re-writes CB+6 with READY=1/BUSY=0 at completion.
  A driver that waits on FSTA1 in memory (which is what the no-more-IOX
  trace implies TPE does) therefore sees "controller busy, never ready"
  forever -> "Device ... Never Ready" after its software timeout.
  Note the module testbench only checks bit 15 of CB+6 after completion
  (nd_floppy_dma_tb.v line 391), so this exact bug slips through it.

MISMATCH B - READ FORMAT (function 0x22) is a stub, and status 2 is an echo.
  The C model derives status2 from the mounted media (1,261,568-byte TPE
  image -> 017 octal). Our RTL lumps 0x22 in with "other functions: no-op
  completion" (lines 372-377) and writes CB+7 = s_rsr2 = a combinational
  echo of the command-word bits (line 145, write at line 484). The same
  echo is returned on IOX +4 reads. This is what produces the impossible
  "Status:000003" (1024 B/s but single-sided/single-density) and plausibly
  also derails the TPE monitor's media probing before the banner
  ("No notes exist." fits a directory read done with wrong geometry
  assumptions). Also: the C model puts the selected unit in status2 bits
  8-9 at command setup (deviceFloppyDMA.c line 371); we never do.

MISMATCH C - minor semantic differences (not the hang, but worth aligning):
  - +0 read outside boot mode returns 0; the C model returns 0x0001
    (FloppyDMA_Read case FLOPPY_DMA_READ_DATA).
  - Control word with BOTH bit 2 (autoload) and bit 8 (execute) set: the C
    model takes the autoload branch first (if/else if in FloppyDMA_Write);
    our RTL condition `iox_wdata[2] && !iox_wdata[8]` gives execute
    priority.
  - A control write while the engine is NOT idle is silently dropped
    (both branches require s_eng == E_IDLE); the C model always latches
    the control word and acts on it.

---------------------------------------------------------------------------
5. THE INTERRUPT / IDENT PATH (task 4)
---------------------------------------------------------------------------

Wiring audit, all confirmed present and consistent:

  - ND_FLOPPY_DMA drives int_pending[1] (= level 11) from
    s_int_enabled && s_rft (ND_FLOPPY_DMA.v lines 162-166).
  - Verilog/ND-BUS-DEVICES/BUS-IF/circuit/ND_BUS_SLAVE.v
    drives BINT11_n = ~int_pending[1] (line 70) and answers OUTIDENT: level
    decoded from the BAPR-strobed address (004/011/022/043 -> 10..13, lines
    82-85), granted core answers with ident_hit/ident_code, slave puts the
    code on BD via BINPUT/BINACK (lines 137-176).
  - Verilog/ND120_TOP.v instantiates the
    floppy with IDENT_CODE 021 / INT_LEVEL 11 (lines 504-508), ident grant
    chain tape -> floppy -> SMD (lines 436-437, 519-520, 596), and
    wire-ANDs the device BINT lines into the CPU bus inputs (lines
    690-693). The module tb proves BINT11 assertion and IDENT=021 end to
    end at the slave-bus level.

  So the RTL CAN raise level 11 and answer IDENT with 021 - the path is
  implemented, not missing. It only fires when the driver's control word
  set bit 1 (enable interrupt) and the engine reaches E_DELAY completion.

  The console lines "No device found for IDENT level: 11" and
  "IDENT LVL[11]=0" are printed by the C++ side:
  DeviceManager::IDENT in
  Verilog/simDevices/NDDevices.cpp (line 1127)
  called from the OUTIDENT edge handler in
  Verilog/simDevices/NDBus.cpp (lines 86-126).
  In ND120_VERILOG_DEVICES builds the C++ DeviceManager is EMPTY (addDevices
  registers the C models only when ND120_VERILOG_DEVICES is NOT defined), so
  those prints are expected noise on every IDENT and say nothing about the
  Verilog path - the Verilog slave answers in parallel on the same bus.
  They DO confirm the CPU executed an IDENT on level 11 at least once.

  Latent (currently inert) harness bug worth noting: NDBus.cpp lines
  237-240 set the top-level BINT inputs with
      top->BINT11_n = !((interruptBits & 1<<11) == 1);
  `(x & 0x800) == 1` is never true, so a C-model device could never assert
  an interrupt line. Harmless today (manager empty; RTL BINT lines are
  wire-ANDed separately in ND120_TOP), but it should be `!= 0` if C-model
  devices are ever re-enabled.

---------------------------------------------------------------------------
6. FAILURE NARRATIVE (putting it together)
---------------------------------------------------------------------------

  1. `1560&` boot: microcode BPUN loader uses control bit 2 + status polls +
     reads of +0; our boot byte-server handles this correctly. Program
     loads and starts.
  2. TPE monitor's floppy driver issues its first real command:
     write +5 (pointer high), +7 (pointer low), +3 (control: EXECUTE, and
     likely ENABLE INTERRUPT). Our engine leaves boot mode, fetches the
     command block, executes (or stubs) the function, DMA-writes w6-w11 -
     with STATUS 1 = busy/not-ready (MISMATCH A) and STATUS 2 = command-word
     echo (MISMATCH B) - then waits out E_DELAY and sets internal RFT.
  3. The driver's bounded IOX poll (7 reads of +2) expires before/around
     completion; it falls back to waiting on the status block in memory
     (and/or the completion interrupt). The memory word at CB+6 says BUSY,
     NOT READY - forever, because we never re-write it (MISMATCH A).
  4. The second command sequence repeats the story; the monitor concludes
     "No notes exist." and later its long software timer expires:
     "Device 156362 Never Ready.   Status:000003" - the status printed
     being the format/status-2 word our stub wrote (000003, MISMATCH B),
     and 156362 most plausibly the address of the status word it waited on
     (command block at 156354; verify against the +7 write data in the
     trace).

---------------------------------------------------------------------------
7. FIX PROPOSAL (register semantics + interrupt/ident wiring)
---------------------------------------------------------------------------

All changes in
Verilog/ND-BUS-DEVICES/FLOPPY-DMA/circuit/ND_FLOPPY_DMA.v
(no bus-slave or top-level changes needed; the interrupt/ident wiring is
already correct):

  F1. Final status re-write (fixes MISMATCH A, mirrors C ReadEnd):
      Add one state, e.g. E_FINAL, entered when E_DELAY expires. In the
      E_DELAY expiry branch set s_active <= 0 and s_rft <= 1 (as today) and
      go to E_FINAL instead of E_IDLE. E_FINAL issues a single DMA write of
      CB+6 = s_rsr1 (which now evaluates with READY=1, BUSY=0, bit15=1,
      current error bits) and then goes to E_IDLE. Skip E_FINAL for the
      autoload/boot path (the boot loader does not use a command block),
      i.e. only when the completed operation came through E_WBACK.
      The interrupt condition needs no change: s_pending goes high with
      s_rft at delay expiry, matching the C model's ordering (ReadEnd sets
      RFT, re-writes memory, raises the interrupt in one tick).

  F2. Real STATUS 2 register (fixes MISMATCH B):
      Replace the combinational s_rsr2 echo with a register s_status2:
        - loaded at command decode with {6'b0, s_cb_drive, 8'b0} (selected
          unit in bits 8-9, like deviceFloppyDMA.c line 371);
        - for function 0x22 (READ FORMAT), loaded with the media format
          {12'b0, media_dd, media_ds, media_bps[1:0]};
        - written to CB+7 in E_WBACK and (unchanged) in the E_FINAL state's
          view; returned on IOX +4 reads.
      Media info source: the disk backend already knows the image (it maps
      logical sectors to the image). Add an input, e.g.
        input wire [3:0] disk_media_fmt  // {doubleDensity, doubleSided, bps[1:0]}
      driven by the harness/backend from the image size exactly like
      deviceFloppyDMA.c lines 528-540: size 315392 -> 4'b0000 (8-inch,
      512 B/s), size >= 1261568 -> 4'b1111 (1024 B/s, DS, DD). Wire it
      through ND120_TOP's FDISK_* port group and the runSim floppy backend
      in Verilog/simDevices/NDBus.cpp
      (process_verilog_floppy). Default to 4'b1111 if unknown so the TPE
      1.2MB workflow works even before the harness change.

  F3. Small fidelity alignments (MISMATCH C):
      - IOX +0 read outside boot mode: return 16'd1 (C model constant).
      - Give control bit 2 (autoload) priority over bit 8 (execute) when
        both are set, matching the C model's if/else order.
      - (Optional) latch the control word even when busy so a device-clear
        during a transfer behaves like the C model.

  F4. Harness hygiene (separate file, optional):
      Verilog/simDevices/NDBus.cpp lines
      237-240: change `== 1` to `!= 0` in the four BINT assignments, and
      consider gating the "No device found for IDENT level" print behind
      DEBUG_BIF in ND120_VERILOG_DEVICES builds to stop the misleading
      noise.

  Verification plan (per repo conventions, testbench lives next to the
  module and must be registered in
  Verilog/tests/run_all_tests.sh):
      1. Extend
         Verilog/ND-BUS-DEVICES/FLOPPY-DMA/sim/nd_floppy_dma_tb.v
         with: (a) after completion delay, memory[CB+6] must have bit 3 = 1
         and bit 2 = 0 (today only bit 15 is checked - that is how the bug
         escaped); (b) a READ FORMAT (0x22) command whose CB+7 comes back
         as 000017 with the 1.2MB media descriptor; (c) IOX +4 returns the
         latched status2.
      2. Re-run the runSim `1560&` boot and confirm the TPE banner
         ("TPE Monitor, ND-100 series") and prompt appear.
      3. From the existing IOX trace, read the data value of the +7
         (pointer low) write: if it is 156354 octal, the "156362" decode
         (address of CB+6/FSTA1) is confirmed; record the result here.
