# ND-120 OPCOM Boot Reference

Source: Microcode analysis and ALD register documentation from `CPU-BOARD-3202/circuit/IO_REG_41.v`

## How to boot from OPCOM

At the OPCOM `#` prompt, type one of:
- **`&`** or **`$`** (without preceding value) -- load and/or run using the hardware ALD switch setting
- **`<value>&`** -- load from a specific device/address (overrides ALD switch)

The value you type determines the device, load method, and whether it runs after loading.

## Boot values (all values are octal)

| OPCOM Command | Device Address | Load Format    | Action    | Device                        |
|---------------|---------------|----------------|-----------|-------------------------------|
| `400&`        | 0400          | BPUN           | Load only | Paper Tape Reader (primary)   |
| `1560&`       | 1560          | BPUN           | Load only | Floppy/streamer controller (primary) |
| `1570&`       | 1570          | BPUN           | Load only | Floppy/streamer controller (secondary) |
| `1600&`       | 1600          | BPUN           | Load only | HDLC                          |
| `20500&`      | 0500          | Bootstrap      | Load + Run| Winchester Disk               |
| `21540&`      | 1540          | Bootstrap      | Load + Run| SMD Disk                      |
| `21560&`      | 1560          | Bootstrap      | Load + Run| Floppy/streamer controller; on an ND-3201 card this boots SCSI (see below) |
| `100400&`     | 0400          | Binary         | Load only | Paper Tape Reader             |
| `101560&`     | 1560          | Binary         | Load only | Floppy/streamer controller    |
| `101600&`     | 1600          | Binary         | Load only | HDLC                          |
| `120500&`     | 0500          | Mass storage   | Load only | Winchester Disk               |
| `121540&`     | 1540          | Mass storage   | Load only | SMD Disk                      |
| `121560&`     | 1560          | Mass storage   | Load only | Floppy/streamer controller    |

"Bootstrap" and "Mass storage" are both used for values with bit 13 set. They
have not been shown to be the same load; the ALD table and the CPU 3095 board
call 21560 a mass storage load.

The floppy/streamer controller is the ND-3106/3112 (device 1560 or 1570 by
thumbwheel, ND-11.021.1). Its manual names both loads: the status register is
duplicated "to make it possible for microprograms in the ND-100 CPU to perform
both Binary Format Load and Mass Storage Load (1560x and 21560)".

## How the boot value is encoded (octal)

What the two tables show, read from the pattern of the values - NOT from the
microcode, and not verified:

```
Bits 0-12:   Device IOX address (e.g., 0400, 0500, 1540, 1560, 1600)
Bit 13:      set on every bootstrap / mass storage value
             (20500, 21540, 21560, 120500, 121540, 121560)
Bit 15:      set on every ALD switch 0-7 value (100000, 101560, 120500,
             121540, 100400, 101600, 121560), which are exactly the
             "load only" positions
```

An earlier version of this section said bits 14-16 hold a load mode with
1 = binary and 2 = mass storage. That does not fit the tables: the binary
values (100400, 101560, 101600) have bit 15 set, not bit 14.

Switch 8 and switch 15 both hold the value 0, yet one runs and one stops, so
the value alone does not decide that. What does is not known.

Run after load is determined by the ALD switch position:
- ALD switch positions 8-15: load **and run** from address 20 (octal)
- ALD switch positions 2-7: load only (CPU stops after load)

## Device address summary (octal)

| Device              | Primary Address | Secondary Address | Int Level | IDENT Code |
|---------------------|-----------------|-------------------|-----------|------------|
| Paper Tape Reader   | 0400-0403       | 0404-0407         | 12        | 02 / 022   |
| Winchester Disk     | 0500-05xx       | --                | --        | --         |
| SMD Disk            | 1540-15xx       | --                | --        | --         |
| Floppy/streamer (3106/3112) | 1560-1567 | 1570-1577     | 11        | 021 / 022  |
| HDLC                | 1600-16xx       | --                | --        | --         |
| SCSI (ND-3201), bus 1-4 | 144300-144377 / 144400 / 144500 / 144600 | -- | -- | 140440-140443 |

## ALD hardware switch positions

The ALD switch is a physical rotary switch on the CPU board. Its position determines the default action when `&` or `$` is typed without a value, or when the LOAD button is pressed, or after a power failure with standby power lost.

| Switch | ALD Vector | ALD Value (octal) | Description                                         |
|--------|------------|-------------------|-----------------------------------------------------|
| 15     | x0         | 0                 | No load. CPU stops.                                 |
| 14     | x1         | 1560              | BPUN load from floppy (1560) and run                |
| 13     | x2         | 20500             | Bootstrap load from Winchester disk (500) and run   |
| 12     | x3         | 21540             | Bootstrap load from SMD disk (1540) and run         |
| 11     | x4         | 400               | BPUN load from paper tape (400) and run             |
| 10     | x5         | 1600              | BPUN load from HDLC (1600) and run                  |
| 9      | x6         | 21560             | Mass storage load from 1560 and run. "SCSI controller 1, only available on the ND-110/120 CPU" - see "21560 on a machine with an ND-3201" |
| 8      | x7         | 0                 | Run only (no load)                                  |
| 7      | x8         | 100000            | No load. CPU stops.                                 |
| 6      | x9         | 101560            | Binary load from 1560                               |
| 5      | xA         | 120500            | Mass storage from 500 (Winchester)                  |
| 4      | xB         | 121540            | Mass storage from 1540 (SMD disk)                   |
| 3      | xC         | 100400            | Binary load from 400 (paper tape reader)            |
| 2      | xD         | 101600            | Binary load from 1600 (HDLC)                        |
| 1      | xE         | 121560            | Mass storage from 1560                              |
| 0      | xF         | 100000            | No load. CPU stops.                                 |

## Quick reference: common boot scenarios

| I want to...                      | Type at OPCOM `#` prompt |
|-----------------------------------|--------------------------|
| Boot from the controller at 1560  | `21560&`                 |
| Boot from SMD disk                | `21540&`                 |
| Boot from Winchester disk         | `20500&`                 |
| Load BPUN from paper tape         | `400&`                   |
| Load BPUN from floppy             | `1560&`                  |
| Boot from custom device address   | `2<addr>&` (set bit 13)  |
| Use ALD switch default            | `&`                      |

## Notes

- Run always starts from address 20 (octal) -- the power fail restart vector
- BPUN = Binary Paper tape Universal Norsk data format
- Bootstrap = reads boot sector from the disk device
- The content of internal register I12 reflects the ALD settings
- To bootstrap from an arbitrary device address, set bit 13: e.g., device 1550 becomes `21550&`

### Provenance of the switch-9 row

Switch 9 was read off a real **CPU 3095** board: the switch in position 9 gives
internal register **I12 = 21560B**, a mass storage load from 1560B. The setting
names a device address and a load format. 1560 is the floppy/streamer
controller's address; how that becomes a SCSI boot on a machine with an
ND-3201 card is in the next section. This table previously described that row as "Run only (no load)",
which was wrong on two counts - it contradicted the measured board and it
contradicted this document's own rule that switch settings 8 to 15 load AND
run.

Two things nearby are still unverified against hardware and should not be
trusted the way the switch-9 row now can be:

- The tail comment in `Verilog/CPU-BOARD-3202/circuit/IO_REG_41.v` says
  "ALD settings 4, 5, 12 and 13 specify a bootstrap load from a disk". Those
  four are the Winchester and SMD rows; the 1560 rows (switch 9 and switch 1)
  are NOT in that list even though switch 9 demonstrably performs a mass
  storage load. Either the list predates SCSI at 1560 or it is incomplete.
- The remaining "Run only (no load)" entry (switch 8, ALD value 0) has not been
  checked on a board.

### 21560 on a machine with an ND-3201

The ND-3201 SCSI card is two controllers on one board: an NCR 5386 SCSI half
that the ND-100 drives itself over IOX at 144300 (SCSI bus 1), and a Z80
floppy half that is essentially an ND-3112. The Z80 never touches the NCR.

Its Z80 ROM (45900E) still makes a mass storage load boot from SCSI. Read from
the ROM bytes:

- The host-command handler (Z80 `0x02AB`) sends the autoload command - the
  same `IN (0x52); CP 4` test that the 3112 firmware uses for control word
  bit 2, "Activate Autoload" - to the handler at Z80 `0x15B6`.
- That handler does not look at the floppy. It DMAs 0x4A8 bytes of its own
  ROM (Z80 `0x15DF`-`0x1A86`) into ND memory at word 6000, then writes the two
  words `125001 006035` at ND address 0: `JMP I *+1` through word 1, i.e. a
  jump to 6035. Then it reports the command done.
- The planted program at 6000-7123 is an ND-100 SCSI driver. Word 6014 holds
  144300 (SCSI bus 1, the only SCSI address in the ROM). From its entry at 6035
  it drives the NCR registers with `IOXT` (150415): WCONT 144305, WDESI 144347,
  the transfer counter 144371/144373/144375, and WNCOM 144343 with command
  0x09 (Select without ATN - NCR 5386 datasheet code 01001). It does no I/O to 1560.

So on such a machine `21560&` (or ALD switch 9) loads that driver, the CPU
starts at address 0, jumps to 6035, and the ND-100 reads the SCSI disc through
the NCR itself. This is why the board's own note calls switch 9 "SCSI
controller 1".

| Step | Status |
|---|---|
| The CPU's mass load writes the control word with bit 2 (WCONT = 4) | From the microcode analysis in `Verilog/floppyTester/CONFORMANCE.md` |
| That control word reaches the 3201's `CP 4` test on Z80 port 0x52 | NOT verified: which ND register value lands on port 0x52 |
| The 3201 floppy half answers at 1560 (thumbwheel TH3) | NOT verified |
| The handler plants the driver at 6000 and `JMP I` at 0 | Read from the ROM bytes |
| The driver uses 144300 and drives the NCR with IOXT | Read from the ROM bytes |
| Which disc blocks the driver reads, and where it jumps after | NOT traced yet |
