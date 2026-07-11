# NORD-100 bus and DMA protocol - specification for the Verilog DMA engine

Source: ND-06.016.01 "NORD-100 Input/Output System" (the I/O manual).
Every load-bearing claim cites the manual's section number so it can be
verified against the original. Cross-references (marked as such) are
Verilog/simDevices/NDBus.cpp (C model of the device side of our exported
bus) and Verilog/docs/nd100x-device-semantics.md; one quote from a second
manual, ND-06.026 (NORD-100 Functional Description), is reconciled in
section 4.4.

Naming: the manual writes active-low signals with a subscript zero
(e.g. BAPR0, Appendix F.1). This document writes plain BAPR etc. and
states polarity explicitly. In our Verilog the same signals carry the
`_n` suffix (BAPR_n, BDRY_n, ...).

Contents:

1. Bus overview
2. Bus signal reference table
3. Bus allocation - the Bus Control Unit (BCU)
4. The memory cycle on the bus (what a DMA master generates)
5. DMA transfer anatomy (controller side)
6. DMA programming model (I.3.7)
7. IOX and IDENT cycles (context the DMA engine coexists with)
8. Verilog implementation notes - per-clock contract
9. Gaps and open questions
10. Timing diagrams (from the original PDF figures)


## 1. NORD-100 bus overview

The NORD-100 bus is the single backplane highway connecting every module
in the machine: the CPU module, the memory system (with memory
management / cache on the CPU side), and the I/O device controllers
(II.1, Figure II.1). I/O controllers plug directly into the same printed
backplane as CPU and memory; slot positions are not predefined
(I.2.2.2.1).

Participants and their roles:

- NORD-100 CPU - bus master for instruction fetch, operand read/write,
  indirect address read, programmed I/O (IOX/IOXT), and access to
  external system control registers (II.4.1.1.1). The Bus Control Unit
  (BCU, the allocation arbiter) is physically on the CPU module (II.3).
- Programmed Input/Output (PIO) interfaces - slaves only. Every word
  or byte moves through the CPU A register under program control
  (I.2.2.2.2).
- Direct Memory Access (DMA) controllers - I/O interfaces that can
  become bus master and exchange data directly with the memory system,
  one word per bus allocation (I.2.2.2.2, II.2). A DMA controller is
  still an IOX slave for its own control/status registers (III.2.6).
- Memory - always a slave. It never requests the bus.
- Memory refresh - a third "bus user": a dataless, addressless refresh
  cycle allocated like any other bus cycle (II.3, II.4.1.1.3).

So the set of possible bus masters is exactly: CPU, DMA controllers,
and refresh (II.2, II.4.1). The event of exchanging one word is one bus
cycle; a bus cycle is always preceded by an allocation and terminated
with a release (II.3). Allocation is handled by the BCU; the transfer
itself is a completely asynchronous handshake between the granted bus
user and its accessed device (memory or I/O interface) - the BCU is
passive during the transfer except for a timeout watchdog (II.3, II.4.2,
II.5).

The data path is BD0-BD23, a 24-bit multiplexed address/data bus, BD0
least significant (Appendix F, F.1). Addresses and data share these
lines, which is why every bus cycle splits into an address cycle
followed by a data cycle (II.5.1).

Electrical discipline (Appendix F, page F-1, and F.1): all backplane
logic signals are active low TTL. Logical "1" (active) = 0 to 0.5 V,
logical "0" (inactive) = 2.4 to 5.0 V. Several control lines are
wired-OR (open collector), meaning any card may pull them low:
BAPR, BDRY, BINPUT, BREQ, BMCL, BINT10-13,15, BERROR are explicitly
listed as wired-OR lines (Appendix F.2). Max load 0.8 mA per slot;
receivers with hysteresis recommended on lines that are active while
BD switches (Appendix F, page F-1).


## 2. Bus signal reference table

Sources: backplane table (Appendix F, page F-2) with source/user codes
C = CPU or bus receiver, M = memory, I = I/O interface, P = power,
E = future extensions; and the alphabetical signal list (Appendix F.2).
"Driver" below = who asserts the line in the cycles we care about.

| Signal | Driver | Meaning / when asserted |
|---|---|---|
| BD0-23 | current sender (CPU, DMA controller, memory, or I/O interface) | Multiplexed address/data bus, bit 0 LSB (F.2). Carries: 24-bit physical memory address or 16-bit device register address or interrupt level code during the address cycle; data or ident code during the data cycle (II.5.1.1, II.5.1.2). |
| BAPR | bus master (CPU or granted DMA controller) | Bus Address PResent - address strobe. Asserted while BD carries the address (II.5.1.1, F.2). All modules buffer BD on the leading edge of BAPR (III.2.7, page III-2-14). Wired-OR. |
| BINPUT | direction: DMA controller on memory write (V.4 Case 2); I/O interface on IOX input (III.2.4 Case 2) | "Bus input" = data flows INTO the receiver named from the CPU/memory point of view. For a DMA memory cycle: BINPUT inactive = memory read, BINPUT active = memory write (V.4). For IOX: the addressed interface asserts BINPUT to say "the accessed register is an input register, I will transmit data", then must wait for BINACK before enabling data and BDRY (III.2.4, F.2). Wired-OR. |
| BDAP | bus master (CPU or granted DMA controller); see reconciliation in 4.4 | Bus DAta Present - "data is present during DMA or memory cycles" (F.2). Memory write: asserted when write data is valid on BD (V.4 Case 2). Memory read: asserted when the master has removed its address from BD, telling memory it may now drive read data onto BD (V.4 Case 1). |
| BDRY | the accessed device (memory or addressed I/O interface) | Bus Data ReadY - "data are ready or have been accepted, given by answering device" (F.2). Read: data valid on BD (master strobes BD on BDRY leading edge). Write: data accepted. Leading edge terminates the grant, trailing edge terminates/releases the bus cycle and resets the BCU timeout timer (V.4, II.4.2). Wired-OR. |
| BMEM | BCU (CPU module) | Bus MEMory cycle - "signals that a bus cycle accesses memory. Generated by controlling unit" (F.2). Asserted by the BCU when it grants a DMA request (or a CPU memory reference): enables the memory system and freezes DMA request status for the grant search (V.4 Case 1). |
| BREQ | any DMA controller (wired-OR, any slot) | Request for a DMA cycle (F.2, II.4.1.1.2, V.2). Asserted when the controller has a word to write to memory or needs a word from memory; held until the grant arrives and released at INGRANT reception (corrected from figure, was: "held until served" - Figures V.4.1/V.4.2 draw the BREQ trailing edge at the INGRANT leading edge; see section 10.8). |
| INGRANT / OUTGRANT | BCU originates OUTGRANT; each card forwards | DMA allocation acknowledge, daisy chained. "Response to BREQ, indicating that the bus is available for a DMA cycle. An interface which issued BREQ prior to the last leading edge of BMEM may use the bus for a single memory read or write cycle. Otherwise, INGRANT is passed onto OUTGRANT which is connected to INGRANT of the next lower priority card position (further removed from controlling unit). INGRANT originates as OUTGRANT from controlling unit." (F.2). Also V.3. |
| BIOXE | CPU bus handshake logic | I/O eXecute Enable - strobe enabling data transfer to/from an I/O interface; generated by controlling unit (F.2). Asserted in the IOX data cycle when CPU write data is valid on BD; on its leading edge every interface compares the buffered device address with its own (III.2.4, III.2.7). Deasserted when the CPU has seen BDRY; the interface must then drop BDRY (III.2.4, page III-2-9). |
| BINACK | CPU bus handshake logic | Bus INput ACKnowledge - direct feedback to the interface that asserted BINPUT: the CPU has stopped driving BD, the interface may now enable its input register onto BD and then assert BDRY (III.2.4 Case 2, F.2). |
| INIDENT / OUTIDENT | CPU originates OUTIDENT; each card forwards | IDENT search chain, daisy chained like the grant chain. "Response to BINT10-13, together with address bits 0-5 which specify BINT number. An interface which issued BINT on the specified level prior to the last leading edge of BAPR shall respond by enabling its IDENT CODE onto the BD bus. Otherwise, INIDENT is passed on to OUTIDENT..." (F.2, IV.2.2). |
| BINT10-13, BINT15 | any interface (wired-OR) | Interrupt request lines, level 10 lowest priority (F.2). Driven by an interface with ready-for-transfer or error condition and the corresponding enable bit set (I.4.5.5.2). |
| BMCL | CPU / power logic (wired-OR) | Bus Master CLear - logic initialization at power up and Master Clear button (F.2). |
| BERROR | memory (wired-OR) | Error detected during a bus cycle, e.g. fatal memory error (F.2). |
| BPERR | memory | Bus Parity ERRor - fatal or correctable memory error, per the error correction (ECC) register (F.2). |
| BMINH | controlling unit | Bus Memory INHibit - blocks memory access during power up/down in battery-backed systems (F.2). |
| BCRQ, INCONTR / OUTCONTR | future extensions only | Bus Control ReQuest plus its daisy-chained acknowledge - a mechanism for a unit to take full control of the bus. Marked "for future extensions" (F.2); source/user code E in the backplane table. Not used by the DMA protocol in this manual. |
| RUN, STOP, CONTINUE, LOAD, RESTART | CPU crate only | Operator/console lines, not part of data transfer (F.2). |
| PA0-3 | backplane | Card position code, defines device numbers of process interfaces (F.2). |

Signals internal to the CPU module but named in the protocol
description: BUSRQ (CPU allocation request to the BCU, II.4.1.1.1) and
RFREQ (refresh request, 15 microsecond oscillator, II.4.1.1.3). They do
not appear on the backplane.

Note: there is no semaphore request line (no "SEMRQ") anywhere in this
manual; the closest thing to a bus-lock facility is the unimplemented
BCRQ/INCONTR/OUTCONTR extension. See section 9.


## 3. Bus allocation - the Bus Control Unit (BCU)

### 3.1 Requests

Three request lines enter the BCU priority arbiter (II.4.1.1):

- BUSRQ - CPU microprogram, for the six CPU access types (II.4.1.1.1).
- BREQ - DMA request; one shared wired-OR line for all DMA
  controllers, drivable from any slot (II.4.1.1.2, V.2).
- RFREQ - refresh, every 15 microseconds (II.4.1.1.3).

Requests are fully asynchronous and may collide (II.4.1).

### 3.2 Priority rules

(II.4.1.2)

- An already allocated bus is not interruptable - allocation is for
  one full cycle, no preemption.
- A cycle exceeding 8 microseconds is aborted by the BCU (see 3.4).
- Bus idle, single request: first come, first served.
- Simultaneous requests: RFREQ and BREQ are both treated as "DMA
  requests", RFREQ having the higher priority of the two. Between the
  DMA side and BUSRQ, priority goes to the side that did NOT have the
  previous cycle (toggled priority). This is the cycle-steal
  mechanism: a DMA controller can never be starved by the CPU, and
  vice versa - with both sides continuously requesting, they alternate
  (II.4.1.2, Examples 1-3 on pages II-4-7/8; Example 3 is explicitly
  labeled "DMA cycle steal"). Indicative cycle lengths from the
  examples: refresh cycle 320 ns, CPU cycle 200-320 ns, DMA cycle
  ~550 ns (10 MB disk) to 650 ns.

### 3.3 The DMA grant handshake (request -> BMEM -> INGRANT/OUTGRANT)

Exact order, from V.3, V.4 Case 1 and the F.2 INGRANT definition:

1. Controller asserts BREQ (wired-OR) and waits (V.2, V.3).
2. When the bus is free for a DMA cycle, the BCU asserts BMEM. The
   LEADING edge of BMEM freezes the DMA request status on all DMA
   controllers: only a controller whose BREQ was active before that
   edge participates in this grant round. This guarantees a stable
   test condition for the daisy chain (V.4 Case 1, F.2 INGRANT).
   BMEM also enables the memory system (V.4 Case 1).
3. The BCU issues the allocation acknowledge OUTGRANT about 100 ns
   after the BMEM leading edge ("DELAY approx. 100 ns" between "DMA
   ALLOCATED" and "START SEARCH" in the BCU column of Figure V.5.1).
   It enters slot n as INGRANT; the card in slot n either takes it
   (if it had a frozen request) or forwards it as its OUTGRANT to
   slot n+1 (V.3, Figure V.3.1).
4. The first module in the chain with DMA request set stops the
   search and establishes itself as granted; it may perform exactly
   one word exchange (one memory read or write cycle) (V.3, F.2
   INGRANT). On receiving INGRANT the granted controller RELEASES
   BREQ - in both Figure V.4.1 and Figure V.4.2 the BREQ trailing
   edge coincides with the INGRANT leading edge, i.e. the request is
   dropped at grant, not held through the transfer (corrected from
   figure, was: "held until served" / "held continuously until the
   transfer completes"). The wired-OR line may of course stay active
   (drawn dashed in the figures): other, un-granted controllers keep
   pulling it for the next allocation round.
5. The leading edge of BDRY (see section 4) terminates the grant
   mechanism: the figures show causality arrows from the BDRY leading
   edge to the BMEM and INGRANT trailing edges - the BCU withdraws
   BMEM and the grant token at BDRY leading edge (Figures V.4.1,
   V.4.2). The trailing edge of BDRY terminates the bus cycle and
   frees the bus for the next allocation (V.4 Case 2, II.4.2). The
   granted controller's OUTGRANT is never asserted at all (flat
   inactive in both figures - the token is consumed, not forwarded).

Chain rules (Figure V.3.1 notes): empty slot positions break the
INGRANT/OUTGRANT chain; the module nearest the CPU has highest
priority; modules not using the chain must strap INGRANT to OUTGRANT.

### 3.4 Timeout and error reporting

The BCU starts a timer at allocation; BDRY resets it. A cycle
exceeding 8 microseconds is aborted, the bus released, and the fault
reported as internal interrupt level 14 - MOR (Memory Out of Range)
for memory access, IOX error for programmed I/O (II.4.2, Figure
II.4.2). A MOR during a DMA cycle is flagged in the PES (Parity Error
Status) register: bit 14 (DMA) set, bit 15 (fetch) not set (V.5).


## 4. The memory cycle as seen on the bus

This is what a DMA bus master must generate after being granted. A
NORD-100 bus cycle = address cycle then data cycle on the shared BD
lines (II.5.1). The address cycle has no handshake; the data cycle is
an asynchronous handshake initiated by the master ("start of data
cycle" = BDAP here) and terminated by the accessed device ("transfer
completed" = BDRY) (II.5.1.2).

### 4.1 Common address cycle (V.4 Case 1)

- The granted controller drives the 24-bit physical memory address
  onto BD0-23 and asserts BAPR.
- BINPUT carries the direction: inactive = memory read, active =
  memory write (V.4 Case 1 and Case 2).
- Memory strobes the address using BAPR (the general rule: all modules
  buffer BD at BAPR leading edge, III.2.7 page III-2-14; the memory
  flow chart in Figure V.5.1 shows "address valid" -> address logic).
- BAPR is a PULSE confined to the address window: in Figures V.4.1
  and V.4.2 the address becomes valid on BD first, then BAPR goes
  active, BAPR goes inactive again while the address is still on BD,
  and only then is the address removed. BAPR is fully inactive before
  the data cycle starts (see section 10.5/10.6).
- The master then removes the address from BD. This is done WITHOUT
  any feedback from memory (V.4 Case 1) - address hold is a pure
  timing obligation of the master. The manual gives no explicit hold
  number for DMA masters; for the CPU's own cycles the handshake logic
  holds the address about 50 ns after the BAPR leading edge (III.2.4,
  page III-2-8). See section 9.

### 4.2 Memory READ data cycle (DMA output to device) - V.4 Case 1, Figure V.4.1

1. Having removed its address from BD, the master asserts BDAP.
   In a read cycle BDAP means "the BD lines are free - memory may
   enable data onto BD" (V.4 Case 1).
2. Memory drives the read data onto BD and, when the data is valid,
   asserts BDRY (V.4 Case 1).
3. The master uses the leading edge of BDRY to strobe BD into its
   data buffer (V.4 Case 1).
4. In the BCU, BDRY means transfer completed; the bus is released and
   the next cycle may start at the TRAILING edge of BDRY (V.4 Case 1).
   Unwinding order per Figure V.4.1 (corrected from figure, was: "The
   master deasserts BDAP/BAPR/BREQ" at cycle end - BAPR and BREQ are
   in fact already inactive at this point, BAPR since the end of the
   address window and BREQ since the grant): BDRY leading edge ->
   master strobes the data and releases BDAP -> memory sees BDAP
   inactive, removes the data from BD and releases BDRY. The figure
   draws explicit causality arrows BDRY(lead) -> BDAP(trail) ->
   BDRY(trail). See section 10.5.

### 4.3 Memory WRITE data cycle (DMA input from device) - V.4 Case 2, Figure V.4.2

Identical allocation and address cycle; only the data cycle differs
(V.4 Case 2):

1. BINPUT is asserted (true) through the cycle: write (V.4 Case 2).
2. As the address cycle completes, the master drives the write data
   onto BD and asserts BDAP = "data present/valid" (V.4 Case 2).
3. Memory uses BDAP to strobe the data into its data buffer and
   asserts BDRY = "data accepted" (V.4 Case 2).
4. Leading edge of BDRY terminates the grant mechanism; trailing edge
   of BDRY terminates the bus cycle (V.4 Case 2). Unwinding order per
   Figure V.4.2 (corrected from figure, was: "The master removes data
   and deasserts BDAP/BAPR/BREQ" - BAPR and BREQ are already inactive
   here): BDRY leading edge ("data accepted") -> master releases BDAP
   -> memory releases BDRY; the master holds the write data on BD
   until it releases BDAP (the data bubble in the figure extends past
   the BDAP trailing edge, to about the BDRY trailing edge). BINPUT's
   trailing edge is drawn at the BDRY leading edge (see section 10.6).

Memory's side (Figure V.5.1, V.5): start on BMEM, take address at
"address valid", test BINPUT; if write, wait for BDAP, strobe data,
answer BDRY ("address accepted"/"data accepted"); if read, enable data
to BD after BDAP and answer BDRY. The only control signal memory ever
returns is BDRY (V.5).

### 4.4 Reconciliation with the ND-06.026 quote in NDBus.cpp

NDBus.cpp (bottom of file) quotes ND-06.026.1 EN page 126: "The CPU
sets /BINPUT false (high) for a memory read cycle and true (low) for a
memory write cycle. The 24-bit physical memory address is strobed onto
the bus (/BAPR). When valid data is available on the bus, the data
source (memory card for read; CPU for write) acknowledges with BDAP.
The memory card closes the memory cycle by signaling with /BDRY that
data has been transferred."

Agreement with this manual: direction encoding of BINPUT (V.4),
address strobed with BAPR (V.4 Case 1), memory closes the cycle with
BDRY (V.4, V.5, II.4.2). The CPU's memory cycle uses the same
handshake as a DMA master's - II.4.1.1.1 lists memory access among
BUSRQ reasons and V.4 calls the DMA transfer "an ordinary memory
reference cycle".

Divergence: ND-06.026 says the DATA SOURCE asserts BDAP ("memory card
for read"). ND-06.016 says the bus MASTER asserts BDAP in both
directions, with direction-dependent meaning: write = "data valid"
(V.4 Case 2), read = "BD released, memory may drive" (V.4 Case 1). The
backplane table (Appendix F page F-2, row c18) supports 016: BDAP is
sourced by CPU and I/O ("used" by memory and I/O), i.e. by masters,
not by memory. Resolution for our implementation: follow ND-06.016 -
the master drives BDAP in both read and write cycles; memory never
drives BDAP. The 026 sentence is read as loose prose (in a write the
CPU is both master and data source, so it is consistent; for the read
case 016's explicit timing diagram wins). Flagged in section 9 anyway.

### 4.5 Bus release

Trailing edge of BDRY releases the bus (V.4 Case 1 and 2, II.4.2).
In the IOX case the equivalent unwinding is: CPU drops BIOXE after
seeing BDRY, and the interface drops BDRY in response (III.2.4 page
III-2-9) - i.e. the answering device must hold BDRY until the master's
strobe goes away, then release it, and only then is the bus free.


## 5. DMA transfer anatomy - inside the controller

### 5.1 What a DMA controller contains

Standard transfer-parameter registers, loaded by IOX before a transfer
(I.3.7.1):

- Memory Address Register (MAR) - first (then current) memory address
  to read from (DMA output) or write into (DMA input).
- Block Address Register (BAR) - first address on the physical device
  (e.g. disk block).
- Word Count Register (WC) - number of words to transfer.
- Control register - device function (read/write/...), unit select,
  interrupt enables, and start (bit 2 = activate device).
- Status register - readable state, plus MAR and BAR readable for
  status check and test (I.3.7.1).

Data buffering: a FIFO data buffer between device and bus, "data
direct to memory" (Figure I.3.3). Each controller also has its own
request/grant logic dedicated to the BREQ/INGRANT handshake and the
memory reference (V.5).

### 5.2 One word per allocation

A DMA controller requests the bus when it "needs more data to output
or [has] a word ready to be written to computer memory" (II.4.1.1.2,
V.2). Once granted it "may transfer one word" (II.2); the bus is
allocated and released on a one-cycle basis, one word per cycle
(II.4.2); a granted interface "may use the bus for a single memory
read or write cycle" (F.2 INGRANT). There is no burst mode: a block
transfer is a sequence of independent single-word bus cycles, each
with its own BREQ / BMEM / INGRANT / memory-cycle / BDRY sequence,
interleaved with CPU and refresh cycles under the toggled-priority
rule (II.4.1.2). Multiple DMA controllers may be active concurrently,
sharing the DMA channel bandwidth (I.2.2.2.2).

### 5.3 Block transfer progression

Per word exchanged (Figure I.3.1 step 2, Figure I.3.3):

- MAR + 1 -> MAR (memory address increments by one)
- WC - 1 -> WC (word count decrements by one)
- repeat until WC = 0.

Data moves at the speed determined by the device; the CPU runs freely
in between (I.3.7.1 "Transfer").

### 5.4 Termination and completion interrupt

The transfer is complete when the word counter reaches zero (WCZ)
(I.3.7.1 "Termination", Figure I.3.4). Then:

- Status bit 3 (ready for transfer / "DMA transfer completed",
  I.3.5.2) is set.
- If the interrupt system is on (ION) and control register bit 0
  (interrupt on ready for transfer) is set, the controller interrupts
  on level 11 (I.3.7.1, Figure I.3.4; DMA completion level 11 also in
  I.4.4). Otherwise completion is found by polling status bit 3
  (I.3.7.1).
- The driver then checks status: error bits (status bit 4 = OR of
  errors, bits 5-15 device specific, I.3.5.2) and optionally verifies
  MARend - MARstart = WCstart (Figure I.3.1 step 3).

### 5.5 Error cases

- Memory out of range during a DMA cycle: no BDRY within 8
  microseconds -> BCU aborts, level 14 internal interrupt, PES bit 14
  (DMA) set, bit 15 (fetch) clear (II.4.2, V.5).
- Device-side errors: status bit 4 = inclusive OR of errors, detail
  in bits 5-15 (I.3.5.2); on the standard disk controller e.g. write
  protect violate, time out, address mismatch, parity error, compare
  error, DMA error (Appendix B.4 status word). Error interrupt is
  enabled by control bit 1 (I.3.5.3).
- Fatal/correctable memory errors are signalled on BERROR/BPERR
  (Appendix F.2); handling on the DMA master side is not described in
  this manual (see section 9).


## 6. DMA programming model summary (I.3.7)

Standard Norsk Data DMA controller conventions, from I.3.5 and I.3.7:

Step 1 - initialization (Figure I.3.1): the driver writes, via IOX,
A -> MAR, A -> BAR, A -> WC, then A -> control word (which selects
unit, mode of operation read/write, and sets bit 2 = activate).

Control register, standardized low bits (I.3.5.3): bit 0 = enable
interrupt on device ready for transfer, bit 1 = enable interrupt on
errors, bit 2 = activate device (start DMA transfer on DMA
controllers), bit 3 = test mode, bit 4 = device clear (resets control
and status of both channels), bits 5-15 device dependent (typically
bits 9-10 unit select, 11-14 device operation).

Status register, standardized (I.3.5.2): bits 0-2 = feedback of
control bits 0-2, bit 3 = ready for transfer (DMA: 1 = transfer
completed, 0 = transfer in progress), bit 4 = inclusive OR of errors,
bits 5-15 device dependent.

Concrete example - the standard 10 MB disk controller (Appendix B.4),
device register address base 500 octal (system I; system II adds 10
octal):

- IOX 500 read memory address (two consecutive IOX 500: first the
  least 16 bits, then the most significant 8 bits)
- IOX 501 load memory address (two consecutive IOX 501: FIRST the
  most significant 8 bits, THEN the least 16 bits)
- IOX 502 read sector counter
- IOX 503 load block address
- IOX 504 read status register
- IOX 505 load control word
- IOX 506 read block address (test mode only)
- IOX 507 load word counter register

The two-IOX address sequence is reset by Master Clear, device clear or
read status; during a transfer only the 16 LSBs of the address can be
read (B.4 footnote). Minimum transfer one sector = 200 octal words,
maximum one track = 25 sectors (B.4). Disk interrupt level 11, ident
code 1 for the first disk system (B.4 "Interrupt").

Device register addressing in general: the IOX device register address
= device number + register number; hardware compares the device number
field (bits 3-10 of the 11-bit IOX address field, bits 0-2 selecting
the register) against a thumbwheel-selected PROM value (I.3.4.3,
I.3.4.4, III.2.7, Figure III.2.8). Standard addresses and ident codes
are listed in Appendix A.

Cross-reference: docs/nd100x-device-semantics.md documents the same
conventions as implemented in the nd100x emulator (SMD base 1540 ident
017 level 11, floppy DMA base 1560 ident 021 level 11, IOX address LSB
even = read / odd = write), consistent with the manual's scheme.


## 7. IOX and IDENT cycles (coexistence context)

A DMA engine shares the bus with these two CPU-mastered cycle types;
their signal usage is what the signal table in section 2 must cover.

IOX output (CPU -> interface), III.2.4 Case 1 / Figure III.2.4:
address cycle (device register address + BAPR, CPU holds address
~50 ns after BAPR leading edge), then CPU drives A register data on BD
and asserts BIOXE; the address-matched interface strobes BD into the
selected register and answers BDRY; CPU drops BIOXE, interface drops
BDRY.

IOX input (interface -> CPU), III.2.4 Case 2 / Figure III.2.5: same
address cycle and same BIOXE start (CPU does not know the direction);
the addressed interface asserts BINPUT ("accessed register is an input
register"); CPU stops driving BD and answers BINACK; interface enables
the register onto BD and asserts BDRY; CPU strobes BD into its DBR on
BDRY leading edge. Timeout with no responder = IOX error, level 14
(II.4.2).

IDENT PLxx (interrupt vector fetch), IV.2.2/IV.2.3: address cycle
presents the level code on BD with BAPR (level encoded in address bits
0-5, F.2 INIDENT; the concrete codes 004/011/022/043 octal for levels
10-13 are from the nd100x/NDBus.cpp cross-reference, not this manual);
interrupt status is frozen at BAPR and interfaces get about 100 ns
from BAPR leading edge to settle their "interrupt on this level" flag
(IV.2.3); the CPU then sends the search token down the
INIDENT/OUTIDENT daisy chain; the first interface with the flag set
blocks propagation (STOPIDENT), enables its ident code onto BD and
asserts BDRY (IV.2.4); CPU strobes the ident code on BDRY leading edge
(IV.2.1). Same chain rules as the grant chain: no empty slots, nearest
CPU wins, unused cards strap in to out (Figure IV.2.4 notes).

Note the structural parallel the manual itself draws (V.3): BMEM
freezes BREQ status for the grant chain exactly as BAPR freezes
interrupt status for the ident chain.


## 8. Verilog implementation notes - per-clock signal contract

The manual's protocol is asynchronous, open-collector, and
daisy-chained. Inside the FPGA everything is one synchronous clock
domain and z-states do not exist (project convention: disabled drivers
output 0, not z). This section restates the protocol as a synchronous
contract for a DMA bus-master finite state machine (FSM). Polarity: use
`_n` signals at module boundaries to match the existing bus port names
(BAPR_n, BDRY_n, ...), active low as on the real backplane; internal
FSM logic is easier in active-high with inversion at the edge.

### 8.1 Re-expressing the analog/async constructs

- Wired-OR lines (BREQ, BDRY, BINPUT, BAPR, BINT10-13): model each as
  the OR of per-source active-high request signals (then invert to
  `_n`). Every potential driver outputs 0 when idle, never z.
- Daisy chains (INGRANT/OUTGRANT, INIDENT/OUTIDENT): the physical
  chain is combinational token passing. With all controllers in one
  netlist, implement as a fixed-priority arbiter over the frozen
  request vector - functionally identical to the chain (module nearest
  the CPU = lowest index = highest priority, V.3 Figure V.3.1 note 2).
  If a literal per-module chain is kept, it is a combinational path
  through every module; keep it short or register the token per stage
  ONLY if every stage does so consistently (the protocol has no timing
  requirement on chain propagation other than falling inside the
  cycle, so registered stages are legal - the grant is only sampled
  against the frozen request status).
- Edge semantics ("leading edge of BMEM", "leading edge of BDRY"):
  one-clock edge-detect pulses (q <= d; pulse = d & ~q). This project
  has already proven (memory-write regression, AM29C821 USE_SYSCLK=2)
  that level-sensitive reinterpretation of edge-strobe semantics
  corrupts state - always edge-detect strobes.
- Asynchronous handshake: since all parties share the clock, the
  handshake collapses to request/acknowledge levels sampled each
  clock. If a bus party ever lives in another clock domain, put 2-FF
  synchronizers on BDRY/BDAP/BAPR/BMEM/INGRANT and rely on the
  4-phase nature of the handshake (level held until acknowledged),
  which is Gray-safe by construction.
- BD multiplexed bus: one shared data structure with per-source output
  enables resolved by OR/mux; the FSM must guarantee it never drives
  BD outside its address window (BAPR asserted) or write-data window
  (BDAP asserted, write only).

### 8.2 DMA master FSM - state/signal contract

States: IDLE -> REQ -> WAIT_GRANT -> ADDR -> (READ_DATA | WRITE_DATA)
-> RELEASE -> IDLE.

IDLE
- All outputs inactive: breq=0, bapr=0, bdap=0, binput=0, bd_oe=0.
- Transition to REQ when the device side has a word to write or room
  for a read word AND WC != 0 (V.2, I.3.7.1).

REQ (assert request)
- breq=1, held continuously until the GRANT arrives (corrected from
  figure, was: "held continuously until the transfer completes" -
  Figures V.4.1/V.4.2 show the BREQ trailing edge exactly at the
  INGRANT leading edge). It is the frozen status at BMEM that grants,
  so dropping it before the grant forfeits the round; keeping it
  after the grant would (on the wired-OR line) look like a further
  pending request to the BCU.

WAIT_GRANT
- On the BCU's BMEM leading-edge pulse: capture req_frozen <= breq
  (V.4 Case 1 freeze rule). A request raised in the same clock as the
  BMEM edge must NOT participate (F.2 INGRANT: "issued BREQ prior to
  the last leading edge of BMEM").
- Granted when ingrant is active AND req_frozen is set. Then do not
  propagate outgrant (outgrant=0 while stopping the token; otherwise
  outgrant follows ingrant combinationally or one clock later,
  uniformly). (V.3, F.2 INGRANT.) A requester whose request was NOT
  frozen at the BMEM edge must keep passing the token ("CONNECT
  INGRANT TO OUTGRANT", Figure V.5.1) - blocking it would starve the
  legitimately frozen requester downstream.
- On grant: drop breq (breq=0; Figures V.4.1/V.4.2, BREQ trailing
  edge at INGRANT leading edge) and proceed to ADDR. Exactly one word
  may be transferred (II.2, F.2 INGRANT).

ADDR (address cycle - both directions)
- Drive bd = MAR value as 24-bit physical address, bd_oe=1; bapr=1;
  binput = 1 for memory write, 0 for memory read, and hold binput at
  that value for the whole cycle (V.4 Cases 1-2).
- Hold address for a fixed number of clocks, then remove it - no
  feedback from memory is given or expected (V.4 Case 1). Contract:
  hold address at least one full clock after bapr asserts so the
  memory model's BAPR-edge capture (III.2.7 rule) sees stable address;
  the original ~50 ns CPU hold (III.2.4) suggests >= 2 clocks at
  ~39 MHz is faithful. The manual gives no DMA-specific figure
  (section 9); the synchronous memory only needs one registered
  capture, so the testable contract is: address stable on bd from the
  clock bapr rises through the clock bdap rises (read) / never
  overlapped with data (see next states).
- bapr is a PULSE inside the address window and must be deasserted
  before bdap asserts (corrected from figure, was: "bapr stays
  asserted until cycle end (Figure V.4.1 shows BAPR spanning into the
  data cycle)" - the figure actually shows BAPR going inactive while
  the address is still on BD, well before the data cycle; see
  sections 10.5/10.6). Its capture edge is the leading one.

READ_DATA (binput=0)
- Stop driving bd (bd_oe=0) FIRST, then assert bdap=1 = "BD free,
  memory may drive" (V.4 Case 1). In synchronous terms: bd_oe must be
  0 in the same clock bdap first samples as 1 at the memory.
- Wait for bdry. On the bdry leading-edge pulse: data_buf <= bd
  (strobe read data, V.4 Case 1). Go to RELEASE.

WRITE_DATA (binput=1)
- Switch bd from address to write data (one clock of turnaround is
  acceptable; nothing samples bd between BAPR capture and BDAP), then
  assert bdap=1 = "data valid" (V.4 Case 2). Data and bdap must be
  stable together: memory strobes bd using bdap (V.4 Case 2), so in a
  synchronous memory model bd must be valid on every clock where
  bdap=1 until bdry is seen.
- Wait for bdry leading-edge pulse = data accepted. Go to RELEASE.

RELEASE
- Deassert bdap and bd_oe (and for write stop driving data; binput
  may be released here too - its trailing edge is drawn at the BDRY
  leading edge in Figure V.4.2). bapr and breq are already inactive
  at this point (corrected from figure, was: "Deassert bdap, bapr,
  breq, bd_oe" - bapr fell inactive at the end of the address window,
  breq at the grant).
  The grant is dead from bdry leading edge; the bus is free for the
  next allocation at bdry trailing edge (V.4 Cases 1-2, II.4.2). The
  answering device (memory) holds bdry until it sees the master's
  strobe (bdap) removed, then drops it - mirror of the BIOXE/BDRY
  unwinding rule (III.2.4 page III-2-9). Contract: master drops bdap
  within one clock of the bdry pulse; memory drops bdry within one
  clock of seeing bdap low; arbiter treats bdry falling edge as
  bus-free.
- Per-word bookkeeping: MAR <= MAR+1, WC <= WC-1 (Figure I.3.1). If
  WC != 0 and the device FIFO warrants it, go straight back to REQ
  (re-request; no burst - each word is a new allocation, section 5.2).
  If WC == 0: set status bit 3, raise level-11 interrupt if control
  bit 0 is set (I.3.7.1); FSM to IDLE.

### 8.3 BCU/arbiter side (for the testbench and the board model)

- Inputs busrq (CPU), breq (wired-OR), rfreq (15 us tick,
  II.4.1.1.3). One cycle at a time, no preemption (II.4.1.2).
- Tie-break: rfreq > breq within the DMA class; DMA class vs busrq by
  toggled priority - grant the side that did not have the previous
  cycle (II.4.1.2). Keep a 1-bit last_was_dma flip-flop.
- On granting the DMA class: pulse/assert bmem (leading edge =
  freeze), then assert outgrant into the chain (V.4 Case 1, V.3).
- Watchdog: counter armed at allocation, reset by bdry; at 8 us abort
  the cycle, release the bus, latch level-14 cause (MOR for memory
  cycles; set PES bit 14, clear bit 15, for DMA-originated cycles)
  (II.4.2, V.5). At BOARD_CLK_FREQ derive the count from the clock
  frequency constant, never hardcode (project rule from the OPCOM
  clock-calibration lesson).

### 8.4 Unit-test observables

Assertions a testbench should check against this spec:

1. breq never granted unless asserted before the bmem leading edge
   (F.2 INGRANT).
2. Exactly one bdry handshake (one word) per grant (II.2, II.4.2).
3. bd never driven by two sources in the same clock (wired-OR/mux
   exclusivity; III.2.4 BINACK exists precisely to prevent this in
   the IOX case).
4. Read: master's bd_oe low whenever bdap high (V.4 Case 1).
5. Write: bd stable and valid on all clocks with bdap high (V.4
   Case 2).
6. binput constant from address cycle to cycle end (V.4).
7. MAR/WC update exactly once per completed word; completion
   interrupt only at WC==0 with control bit 0 set, on level 11
   (I.3.7.1).
8. No bdry within 8 us -> abort path taken, PES bits per V.5.
9. Toggled priority: with busrq and breq both held, grants alternate
   (II.4.1.2).
10. breq released when the grant is accepted (trailing edge together
   with the INGRANT leading edge), and never asserted again before
   the next word's request (Figures V.4.1/V.4.2, section 10.8).
11. bapr inactive before bdap asserts - the address strobe is a pulse
   confined to the address window (Figures V.4.1/V.4.2, section 10.5).


## 9. Gaps and open questions

Things the manual does not specify, is ambiguous about, or where the
OCR of the scanned manual is unusable. Do not invent behavior here -
resolve against hardware schematics (Appendix G), ND-06.026, or
measurements before relying on details.

1. BDAP driver in memory READ cycles: ND-06.016 V.4 Case 1 (master
   drives BDAP) vs the ND-06.026 page 126 quote in NDBus.cpp (memory
   drives BDAP as data source). RESOLVED 11-JUL-2026 against our own
   schematic-faithful RTL: the RAM cycle-control PAL (PAL/PAL_44902A.v,
   "URAMC") contains an explicit wait state commented "PAUSE UNTIL
   BDAP OCCURS" for granted bus cycles, with the hold term
   QB & BGNT25 & BDAP50_n & BDRY50_n - the MEMORY WAITS FOR THE
   MASTER'S BDAP before completing the cycle, on reads and writes
   alike. ND-06.016 is correct for this board: the DMA master drives
   BDAP in both directions (read: after removing the address, meaning
   "BD lines free, memory may drive"; write: together with the data).
   The ND-06.026 wording matches only the IOX slave role, where the
   addressed device drives BDAP with its answer data.
2. Address hold time for DMA masters: STRUCTURALLY RESOLVED
   11-JUL-2026 from the original PDF figures (section 10). Figures
   V.4.1/V.4.2 show the ordering: address valid on BD -> BAPR leading
   edge -> BAPR trailing edge -> address removed from BD - i.e. the
   address is held past the BAPR trailing edge, and BAPR itself is a
   pulse inside the address window. What remains unspecified is the
   NUMERIC hold (the figures are not dimensioned); the 50 ns figure
   remains a CPU-handshake number (III.2.4). The synchronous contract
   in 8.2 (hold through BAPR capture) is consistent with the figure.
3. Exact trailing-edge ordering: RESOLVED 11-JUL-2026 from the
   original PDF Figures V.4.1 and V.4.2 (both cases identical, and
   the same pattern as BIOXE/BDRY in Figure III.2.4): BDRY leading
   edge -> master releases BDAP (read: after strobing the data;
   write: data may stay on BD slightly longer) -> memory releases
   BDRY (read: removing its data from BD at the same time). Causality
   arrows are drawn explicitly BDRY(lead)->BDAP(trail)->BDRY(trail).
   BAPR is already inactive since the address window and BREQ since
   the grant. The BDRY leading edge also withdraws BMEM and
   INGRANT/OUTGRANT (arrows in the allocation group). See section 10.
4. Setup/hold windows in nanoseconds: PARTIALLY RESOLVED 11-JUL-2026.
   The figures settle the qualitative setup relations (write data
   valid on BD BEFORE the BDAP leading edge; address valid BEFORE the
   BAPR leading edge; BINPUT active BEFORE the BAPR leading edge) but
   carry no nanosecond dimensions anywhere - no numeric setup/hold
   values exist in this manual for BD vs BDAP/BDRY. New number found:
   the BCU delays the OUTGRANT search approx. 100 ns after the BMEM
   leading edge (Figure V.5.1), which is the settling window for the
   request freeze. ASK RONNY if numeric bus setup/hold values exist
   in another document (e.g. ND-06.026 or the schematics in
   Appendix G) before depending on them.
5. Semaphore / bus lock: no SEMRQ or read-modify-write locked cycle
   exists in this manual. BCRQ/INCONTR/OUTCONTR ("full control over
   bus") are reserved for future extensions (F.2) with no protocol
   given. If the ND-110/ND-120 era bus added semaphore cycles, that
   must come from another document.
6. Whether BMEM is also asserted for CPU-mastered memory cycles is
   implied (F.2: "signals that a bus cycle accesses memory"; the
   ND-06.026 quote says the arbiter grants "/BMEM" to the CPU) but
   chapter II never states it explicitly; chapter V only describes
   BMEM in the DMA grant role. Our board model should treat BMEM as
   "memory cycle in progress, any master".
7. Behavior on BERROR/BPERR during a DMA cycle (does the master abort,
   retry, or just log?) is not described; only the PES reporting for
   MOR is (V.5).
8. The refresh cycle's exact bus signal sequence (address-less,
   data-less, II.3) is not detailed - presumably BMEM only. Irrelevant
   for our BRAM/SDRAM-backed memory but the arbiter must still budget
   the slot if we model RFREQ.
9. Word count register width and the maximum single transfer are
   device specific (disk: min one sector 200 octal words, max one
   track, B.4); the generic I.3.7 model gives no width. Our engine
   should parameterize WC width per device.
10. OCR quality: several manual pages are scanned figures that the
    OCR could not read and a few pages contain obvious OCR filler
    text (e.g. pages 96, 136, 168 of the markdown conversion contain
    unrelated fabricated tables). Nothing in this document is sourced
    from those pages; every citation above points at readable text.
    Anyone verifying against the .md file should ignore those pages
    and check the original PDF for the timing-diagram figures. The
    figures themselves have now been read from the original scanned
    PDF and are transcribed in section 10 (11-JUL-2026).


## 10. Timing diagrams (from the original PDF figures)

Read 11-JUL-2026 directly from the original scanned PDF
(ND-06.016.01, Bitsavers scan), at 300 dpi where edge ordering
mattered. PDF page numbers below are the scan's page numbers; manual
page numbers (II-4-4 etc.) are the printed ones. Everything in this
section is what the figures actually draw - where a figure is
ambiguous it is flagged "ASK RONNY", not guessed.

### 10.1 Drawing conventions (Appendix F.3, manual page F-8, PDF 220)

- All bus control signals are drawn active low. "Leading edge" =
  falling edge (inactive -> active), "trailing edge" = rising edge
  (active -> inactive). The convention figure marks both edges on a
  BREQ example: NOT ACTIVE / ACTIVE / NOT ACTIVE.
- BD0-23 is drawn as a line with a lens-shaped bubble: flat line =
  "no information", bubble = "BD-lines contains data".
- In the chapter figures, hatching inside a bubble or on a level
  means the interval where the value is present but not yet
  guaranteed/defined (the manual never defines hatching explicitly -
  interpretation from context, see 10.5/10.6).
- Dashed continuation of a wired-OR line (BREQ) = the line as other
  drivers may hold it, distinct from this controller's own drive.

### 10.2 Bus allocation figures (section II.4, PDF 92-95)

Figure II.4.1 (manual II-4-4): block diagram, not a timing diagram.
Three request inputs into the "NORD-100 BUS PRIORITY ALLOCATION
ARBITER" on the CPU module: CPU BUSRQ (internal), RFREQ from the
refresh oscillator (internal), and BREQ - DMA REQUEST arriving from
the NORD-100 bus through a pull-up resistor to Vcc, marked "WIRED OR".

Simplified request-line convention used in the II.4 examples (manual
II-4-5): a request line is drawn in four phases -

```
  BUSRQ ____/HHHHHH|OOOOOO\_______
        (1)   (2)    (3)     (4)
```

  (1) flat: not requesting; (2) hatched box: requesting but waiting
  (another bus activity in progress); (3) open box: the bus is
  allocated to this requester; (4) flat: cycle done, bus released.

Example 1 (manual II-4-5): requests arriving one by one after the
previous allocation is released. Annotated cycle lengths: refresh
320 ns, DMA (10 MB disk) 550 ns, CPU 200-320 ns. Period annotations:
RFREQ recurs approx. every 15 us; BREQ of a 10 MB disk recurs approx.
every 6 us; CPU re-request spacing "depends on CPU activity".

Example 2 (manual II-4-6): all three appear simultaneously, CPU had
the previous cycle: order becomes RFREQ (320 ns), then BREQ (650 ns),
then BUSRQ. BREQ re-request period annotated 1.4 us for a
37.5-288 MB disk, i.e. a fast controller re-requests roughly every
1.4 us and each word costs it ~650 ns of bus time.

Example 3 (manual II-4-6, "DMA cycle steal"): BUSRQ and BREQ appear
simultaneously, previous cycle was DMA (a refresh): BREQ (550 ns) is
served before BUSRQ - toggled priority in action.

What the examples show about BREQ waiting: a controller may assert
BREQ at any time, including while another master's cycle is running
(the hatched "waiting" phase); the request simply rides the wired-OR
line until the BCU's next DMA grant round. Nothing bad happens - the
assertion is asynchronous and only sampled at the next BMEM leading
edge.

Figure II.4.2 (manual II-4-7): bus termination flow. Arbiter grants
-> START TIMER (8 us bus cycle timer); RESET TIMER on BDRY ("bus
cycle completed from memory or I/O system"); on TIMEOUT -> ABORT
CYCLE / RELEASE BUS -> hardware-decoded internal interrupt level 14:
memory access -> MOR, programmed I/O access -> IOX error, neither ->
"unpredictable noise". (A note marks that systems with cache/shadow
memory reference the reset differently - "Reference to cache or
shadow memory" on the RESET TIMER input.)

### 10.3 Bus cycle overview (Figure II.5.1, manual II-5-1, PDF 97)

```
NORD-100 BUS: ----<address>--------<data>----
              |-- address cycle --|-- data cycle --|
              |------------- one bus cycle ------------|
           allocation                              release
```

One allocation = one bus cycle = one address subcycle then one data
subcycle on the shared BD lines, then release. Always this order, for
CPU and DMA transfers alike.

### 10.4 IOX timing - the CPU-master reference case
(Figures III.2.3/III.2.4/III.2.5, manual III-2-6/8/10, PDF 106/108/110)

Figure III.2.3 (PDF 106) is the block/flow diagram of the CPU bus
handshake logic: microprogram requests allocation (BUSRQ -> BCU),
BCU answers "CPU ALLOCATION ACKNOWLEDGE - IACT"; the handshake logic
then runs the address cycle (emitting BAPR) and the data cycle
(BIOXE out, BINPUT/BINACK in/out, BDRY in), with the microprogram
wait-looping on "address cycle completed" and "data cycle completed".
Data path: IDB <-> WDA buffer -> BD (outgoing), BD -> DBR -> IDB
(incoming).

IOX output (Figure III.2.4, manual III-2-8) - CPU writes a device
register. Event order as drawn (all signals active low; "v" = leading
edge, "^" = trailing edge):

```
Event:         E1      E2  E3        E4      E5    E6  E7
BD 0-23   --<DEV.REG.ADDR.>------<A-register>--------------
BAPR      ------v_____^------------------------------------
BIOXE     ----------------------v_____________^------------
BDRY      ---------------------------v___________^---------
```

  E1 device register address valid on BD ("ADDRESS VALID" dashed
     line is drawn at the BAPR leading edge, address bubble starts
     just before it)
  E2 BAPR leading edge - every interface buffers the address
  E3 BAPR trailing edge; text: address held about 50 ns after the
     BAPR leading edge; address then leaves BD
  E4 A-register data valid on BD, then E5 BIOXE leading edge
     ("OUTPUT DATA VALID" is drawn at the BIOXE leading edge; the
     data bubble starts before it - data setup before strobe).
     On BIOXE all interfaces compare the buffered address; the
     matching one strobes BD into the selected register.
  E6 BDRY leading edge = "OUTPUT DATA IS ACCEPTED BY ACCESSED I/O
     INTERFACE"
  E7 unwind, with explicit causality arrows in the figure:
     BDRY(lead) -> BIOXE(trail) -> BDRY(trail). CPU holds the data
     on BD until about the BIOXE trailing edge.

IOX input (Figure III.2.5, manual III-2-10, drawn rotated in the
scan). Same address cycle (E1-E3). Data cycle:

```
BD 0-23   ...--<A-reg.>-------<INPUT DATA>------------------
BIOXE     -----v____________________________^---------------
BINPUT    ---------v______________________________^---------
BINACK    -------------v_____________________^--------------
BDRY      ----------------------v________________^----------
```

  - The CPU starts the data cycle blind (direction unknown): it
    drives the A register on BD and asserts BIOXE exactly as in the
    output case ("INPUT DATA MAY BE ACCEPTED" annotation).
  - The addressed interface, having decoded an input register,
    asserts BINPUT.
  - The CPU handshake logic closes the WDA output (A register leaves
    BD) and asserts BINACK = "BD lines are free to accept data".
  - The interface enables the input register onto BD; when valid it
    asserts BDRY ("INPUT DATA VALID"). CPU strobes BD into DBR on the
    BDRY leading edge.
  - Unwind arrows mirror the output case: BDRY(lead) ->
    BIOXE(trail) -> interface releases BINPUT/BDRY/data, CPU releases
    BINACK. (The rotated scan makes the exact BINPUT/BINACK trailing
    order hard to call - the readable arrows are the BIOXE/BDRY
    pair. ASK RONNY only if the BINPUT/BINACK release order ever
    matters to an implementation; for the slave FSM "drop everything
    when BIOXE goes inactive" matches III.2.4's text.)

PIO slave side (Figures III.2.6/III.2.7, manual III-2-11/13, PDF
111/113): III.2.6 is the module organization (up to four devices
behind one standardized bus control logic). III.2.7 is the
interaction flow chart, slave side: buffer the address on BAPR ->
wait BIOXE -> compare device address ("DEVICE EQUAL?") -> no: do
nothing; yes: decode/select register -> "INPUT REGISTER?" -> no:
strobe BD into output register, answer BDRY ("DATA ACCEPTED"); yes:
assert BINPUT, wait BINACK, enable input register to BD, answer BDRY
("DATA VALID"). This is the exact slave-side contract our IOX slaves
implement.

### 10.5 DMA memory read (Figure V.4.1, manual V-4-2, PDF 140)

Signals top to bottom as printed: BREQ, BMEM, INGRANT, OUTGRANT
(brace: "ALLOCATION PROCEDURE"), BD0-23, BAPR, BINPUT, BDAP, BDRY
(brace: "MEMORY REFERENCE"). BREQ is drawn with a pull-up resistor
symbol and "WIRED OR".

```
Event:      E1   E2   E3      E4  E5    E6   E7      E8    E9   E10
BREQ    ----v____ff___^--------------------------------------------
            (dashed low continues: other controllers may hold BREQ)
BMEM    ---------v______________________________________^----------
INGRANT -------------v__________________________________^----------
OUTGRANT -----------------------------------------------------------  (never active)
BD      -------------------<MEM. ADDRESS>--<%%|DATA FROM MEM.>-----
BAPR    ------------------------v______^---------------------------
BINPUT  ------------------------------------------------------------  (stays inactive: read)
BDAP    ------------------------------------v_______________^------
BDRY    -----------------------------------------v_____________^---
```

  (ff = break marks in the original: the wait may be long; %% = the
  hatched leading part of the data bubble)

  E1  BREQ leading edge: the controller has a word to fetch. May
      happen any time, also mid-cycle of another master.
  E2  BMEM leading edge, annotated "DMA REQ. STATUS IS FROZEN".
      Also enables the memory system and starts the 8 us timer.
  E3  INGRANT leading edge at the granted controller, annotated "DMA
      TRANSFER MAY START ON GRANTED CONTROLLER". Drawn at the SAME
      x-position: the BREQ trailing edge - the granted controller
      releases BREQ upon accepting the grant. Its OUTGRANT stays
      inactive for the whole figure (token consumed). Per Figure
      V.5.1 the BCU starts the INGRANT/OUTGRANT search approx.
      100 ns after the BMEM leading edge.
  E4  master drives the 24-bit memory address onto BD (bubble starts
      before the BAPR leading edge - address setup before strobe).
      BINPUT stays inactive = read.
  E5  BAPR leading edge. E6 BAPR trailing edge - BAPR is a pulse
      inside the address window; the address remains on BD slightly
      past E6, then is removed.
  E7  address off BD; BDAP leading edge at the same dashed line,
      annotated "BD-LINES ARE FREE FOR DATA FROM MEMORY". (Read
      meaning of BDAP: bus turnaround permission, not data-valid.)
  E8  memory drives BD; the leading part of the DATA FROM MEM bubble
      is hatched = data present but not yet guaranteed valid. BDRY
      leading edge at the dashed line "DATA FROM MEMORY IS VALID ON
      BD". A long causality arrow runs from the BDRY leading edge up
      to the BMEM and INGRANT trailing edges: the BCU withdraws BMEM
      and the grant token on the BDRY leading edge.
  E9  master strobes BD into its data buffer on the BDRY leading
      edge, then releases BDAP (arrow BDRY(lead) -> BDAP(trail)),
      annotated "DATA FROM MEMORY IS ACCEPTED".
  E10 memory sees BDAP inactive: removes its data from BD and
      releases BDRY (arrow BDAP(trail) -> BDRY(trail)). Caption
      text: the bus is released and the next bus cycle may be
      initiated as BDRY goes off (trailing edge).

### 10.6 DMA memory write (Figure V.4.2, manual V-4-3, PDF 141)

Allocation identical to 10.5 (BREQ v ... BMEM v ... INGRANT v +
BREQ ^ ... OUTGRANT flat; BMEM/INGRANT withdrawn by the BDRY leading
edge, same arrows).

```
Event:        E4a  E5    E6  E4b   E7     E8    E9   E10
BD      ---------<MEM.ADDRESS>--<DATA TO MEMORY   >--------
BAPR    ------------v______^-------------------------------
BINPUT  -------v_______________________%%%%^---------------
BDAP    --------------------------v___________^------------
BDRY    -------------------------------v__________^--------
```

  E4a address on BD; BINPUT leading edge is drawn at the start of
      the address drive, BEFORE the BAPR leading edge - direction is
      valid when the address is strobed and held through the cycle.
  E5/E6 BAPR pulse inside the address window, as in the read case.
  E4b as the address cycle completes the master switches BD from
      address to write data (short gap between the two bubbles).
  E7  BDAP leading edge at the dashed line "BD-LINES CONTAINS VALID
      DATA TO MEMORY" - clearly AFTER the data bubble begins: data
      setup before the strobe. Memory strobes BD into its data
      buffer using BDAP (bold arrow up into the data bubble).
  E8  BDRY leading edge = "DATA ACCEPTED". Grant withdrawn (arrows
      to BMEM/INGRANT trailing edges). BINPUT's trailing edge is
      drawn here, at the BDRY leading edge; the stretch of BINPUT's
      active level immediately before it is hatched.
      RESOLVED (Ronny, 11-JUL-2026): BINPUT is an ADDRESS-PHASE
      signal only. The memory latches the transfer direction at BAPR;
      once BAPR is inactive BINPUT carries no meaning - the data
      phase is governed by BDAP (data present, memory reads BD) and
      BDRY (data accepted) alone. A master may therefore release
      BINPUT any time after the BAPR trailing edge. ND_DMA_MASTER
      does this by default (parameter BINPUT_HOLD=0, releasing BINPUT
      together with BAPR); the conservative hold-to-BDRY variant
      remains selectable (BINPUT_HOLD=1) and both are unit-tested.
  E9  master releases BDAP (arrow BDRY(lead) -> BDAP(trail)); the
      DATA TO MEMORY bubble extends slightly PAST the BDAP trailing
      edge - write data hold through the strobe release.
  E10 memory releases BDRY (arrow BDAP(trail) -> BDRY(trail)); bus
      free at the BDRY trailing edge. The data bubble ends at about
      this point.

### 10.7 DMA controller / BCU / memory flow (Figure V.5.1, manual
V-5-2, PDF 144 - printed rotated 90 degrees in the scan)

Three columns (DMA controllers / IN CPU MODULE / IN MEMORY MODULE)
exchanging exactly the backplane signals:

- DMA controller: SELECT READ/WRITE from "DATA NEEDED FROM MEMORY" or
  "DATA AVAILABLE TO MEMORY" -> set DMA REQUEST STATUS (drives BREQ)
  -> WAIT FOR INGRANT -> decision "DMA REQ. AT BMEM?" - NO: "CONNECT
  INGRANT TO OUTGRANT" (pass the token); YES: "START DMA TRANSFER" ->
  MEMORY ADDR. TO BD (+ ADDRESS VALID -> BAPR, + TRANSF. DIRECTION ->
  BINPUT) -> decision "BINPUT?" - YES (write): DATA TO BD, "DATA
  VALID ON BD" -> BDAP, then on BDRY: REMOVE DATA FROM BD; NO (read):
  "BD FREE FOR DATA" -> BDAP, then on BDRY: STROBE DATA TO INTERFACE.
- CPU module (BCU): BREQ -> PRIORITY ARBITER -> "DMA ALLOCATED"
  (drives BMEM) -> START CYCLE TIMER (reset by BDRY) and, through
  "DELAY approx. 100 ns", START SEARCH (drives OUTGRANT into the
  chain).
- Memory module: START MEMORY CYCLE on BMEM; ADDRESS LOGIC captures
  at "address valid" (BAPR); test BINPUT: write -> WAIT BDAP ->
  STROBE DATA TO MEMORY -> "DATA ACCEPTED" -> BDRY; read -> WAIT
  BDAP -> ENABLE DATA TO BD -> "DATA VALID" -> BDRY. The only control
  signal memory ever returns is BDRY.

This flow chart confirms: the freeze test is "DMA REQ. AT BMEM?", a
non-frozen requester must keep forwarding the token, and memory waits
for the MASTER's BDAP in both directions (consistent with the gap 1
resolution against PAL_44902A).

### 10.8 The BREQ lifecycle (consolidated from all figures)

1. Assert BREQ (wired-OR, any time, asynchronously) when a word is
   needed from or ready for memory (V.2; Figure V.5.1 "DMA REQUEST
   STATUS").
2. Asserting during another master's cycle is legal and normal - the
   request waits on the line (hatched "waiting" phase in the II.4
   examples) until the BCU's next DMA grant round.
3. Only a BREQ active before the BMEM leading edge participates in
   the grant round the BCU then runs (freeze rule, V.4/F.2); the
   OUTGRANT search token is launched approx. 100 ns after the BMEM
   leading edge (Figure V.5.1).
4. If frozen-in and first in the chain: INGRANT arrives; the
   controller consumes the token (OUTGRANT stays inactive) and
   RELEASES BREQ at that moment (BREQ trailing edge = INGRANT leading
   edge in Figures V.4.1 and V.4.2). BREQ is NOT held through the
   transfer.
5. If not frozen-in: keep BREQ asserted, keep passing the token, and
   wait for the next BMEM leading edge.
6. The transfer then runs with BREQ inactive; a block transfer
   re-asserts BREQ for every word (one word per allocation, II.2).
   Earliest re-assert point: the figures do not show a same-
   controller re-request during its own ongoing cycle - the examples
   only show re-requests after cycle end (6 us / 1.4 us periods).
   TO BE SETTLED BY TEST (plan agreed with Ronny 11-JUL-2026): the
   manual does not answer this, so both behaviors are implemented as
   a parameter on ND_DMA_MASTER (EARLY_REREQ: 0 = re-assert only
   after the BDRY trailing edge via the normal dma_req/dma_ack flow;
   1 = buffer the next request and re-assert BREQ already in the
   cycle tail, overlapping BDRY). Both variants pass the unit tb;
   the decision falls when both run against the REAL CPU-board
   arbiter (PAL_44801A) in the Verilator full-RTL gate - whichever
   the real equations accept (both, probably) and the faster one
   wins for the SMD.
7. Nothing acknowledges BREQ except the INGRANT token; if the BCU
   aborts a hung cycle (8 us timeout) the request simply competes in
   the next round.
