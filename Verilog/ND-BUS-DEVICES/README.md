# ND-BUS-DEVICES - external ND-100 bus devices

Devices that attach to the ND-100 external bus of the CPU board, the way
real ND-100 bus controller cards did. Nothing in here touches the CPU
trees (DELILAH-CPU/, DECODE-GateArray/, CPU-BOARD-3202/) - the devices
connect to the bus ports that ND120_TOP.v already exposes.

Reference behavior: `Verilog/simDevices/NDBus.cpp` (bus handshake) and
`Verilog/simDevices/NDDevices.cpp` (device registers) - the WORKING C
models that runSim boots with today. The Verilog devices must match them;
the runSim console golden gates the swap.

Master plan: `Verilog/docs/device-bus-todo.md`.

## Structure

```
BUS-IF/     ND_BUS_SLAVE.v - the one bus adapter: BAPR/BIOXE/BINPUT/
            BINACK/BDAP/BDRY/OUTIDENT handshake FSM + BINT10-13 drivers.
            Presents a simple synchronous device bus to the device cores.
TAPE-400/   ND_TAPE_400.v - papertape reader, IOX 400-403, ident 02,
            level 12. Byte source is a port (file model in sim, SD-FAT
            streamer on hardware).
FLOPPY/     floppy PIO controller, IOX 1560-1567, ident 021, level 11.
```

## Device bus (between ND_BUS_SLAVE and the device cores)

All in the sysclk domain. Read data is an OR-bus: a core drives 0 when
not addressed (FPGA rule - no z).

```
iox_addr[15:0]   IOX address (11 significant bits), valid with strobes
iox_wr           1-cycle write strobe, iox_wdata valid
iox_rd           1-cycle read strobe; addressed core must present
                 iox_rdata combinationally during the strobe
int_pending_10..13  level lines, OR of all cores (drives BINT1x_n)
ident_strobe     1-cycle IDENT poll, ident_level = 10..13
ident_grant_in/out  daisy chain priority (first core wins);
                 a granted core with a pending interrupt on that level
                 answers with its ident code and CLEARS its pending bit
                 and its interrupt-enable bit (same rule as the C model)
```

## Chain ordering - the cascade rule (ND-06.016.01 V.3, IV.2.3, F.2)

Both cascades on the real backplane - the DMA grant token
(INGRANT/OUTGRANT) and the IDENT search token (BINIDENT/BOUTIDENT) -
follow SLOT POSITION: the token originates at the CPU and daisy-chains
outward, so THE CONTROLLER CARD CLOSEST TO THE CPU WINS when several
request/interrupt at once. Empty slots break the chain; modules that do
not participate strap the token straight through (V.3 notes 1-3).

Our Verilog convention (the "slot order"): chain position = the order
the device instances are ATTACHED in the top level. The first instance
wired to the CPU-side token (ident_grant_in = 1'b1 for IDENT, INGRANT_n
from the CPU's OUTGRANT_n for DMA) is "closest to the CPU" = highest
priority; each instance's grant_out feeds the next one's grant_in.
Priority is therefore changed by REWIRING THE CHAIN ONLY - swap the
order of the grant hookups at the top; nothing inside the devices, no
parameters, no other signals move. That is the knob to "rotate" device
priority when needed.

Freeze rule (same pattern in both cascades): DMA requests freeze at the
BMEM leading edge; interrupt status for IDENT freezes at BAPR of the
IDENT address cycle (IV.2.3, "STOPIDENT" = interrupt-on-level AND the
status frozen at BAPR). A request/interrupt raised after the freeze
edge waits for the next round. ND_DMA_MASTER implements the DMA freeze
exactly; the IDENT path samples pending during the ident strobe (one
sysclk after the level code was captured at BAPR) - synchronous
equivalent of the 100 ns settle window the manual gives the interfaces.

## IDENT / interrupt rules (from NDDevices.cpp, confirmed vs nd100x)

- A device raises its assigned level's pending flag when its interrupt
  condition is true (tape: interruptEnabled AND readyForTransfer).
- BINT<level>_n is simply the NOR of every device's pending flag for
  that level (NDBus.cpp intended this; its `== 1` comparison bug meant
  the C sim never asserted the lines - the Verilog implements the
  intent).
- IDENT PL<level>: the bus captures the level from the address strobed
  at BAPR (004->10, 011->11, 022->12, 043->13). The FIRST device in the
  daisy chain with a pending interrupt on that exact level returns its
  ident code, and clearing happens AT THAT MOMENT (grant time), not at
  OUTIDENT release.
- A device with no pending interrupt on the polled level passes the
  grant on and returns nothing.
