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
| `1560&`       | 1560          | BPUN           | Load only | Floppy Disk / SCSI (primary)  |
| `1570&`       | 1570          | BPUN           | Load only | Floppy Disk (secondary)       |
| `1600&`       | 1600          | BPUN           | Load only | HDLC                          |
| `20500&`      | 0500          | Bootstrap      | Load + Run| Winchester Disk               |
| `21540&`      | 1540          | Bootstrap      | Load + Run| SMD Disk                      |
| `21560&`      | 1560          | Bootstrap      | Load + Run| SCSI Disk / Floppy            |
| `100400&`     | 0400          | Binary         | Load only | Paper Tape Reader             |
| `101560&`     | 1560          | Binary         | Load only | SCSI Disk / Floppy            |
| `101600&`     | 1600          | Binary         | Load only | HDLC                          |
| `120500&`     | 0500          | Mass storage   | Load only | Winchester Disk               |
| `121540&`     | 1540          | Mass storage   | Load only | SMD Disk                      |
| `121560&`     | 1560          | Mass storage   | Load only | SCSI Disk / Floppy            |

## How the boot value is encoded (octal)

```
Bits 0-12:   Device IOX address (e.g., 0400, 0500, 1540, 1560, 1600)
Bit 13:      1 = Bootstrap load from disk (reads boot sector from device)
Bits 14-16:  Load mode:
               0 = BPUN (Binary Paper tape Universal Norsk data)
               1 = Binary load
               2 = Mass storage load
```

Run after load is determined by the ALD switch position:
- ALD switch positions 8-15: load **and run** from address 20 (octal)
- ALD switch positions 2-7: load only (CPU stops after load)

## Device address summary (octal)

| Device              | Primary Address | Secondary Address | Int Level | IDENT Code |
|---------------------|-----------------|-------------------|-----------|------------|
| Paper Tape Reader   | 0400-0403       | 0404-0407         | 12        | 02 / 022   |
| Winchester Disk     | 0500-05xx       | --                | --        | --         |
| SMD Disk            | 1540-15xx       | --                | --        | --         |
| Floppy / SCSI       | 1560-1567       | 1570-1577         | 11        | 021 / 022  |
| HDLC                | 1600-16xx       | --                | --        | --         |

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
| 9      | x6         | 21560             | Mass storage load from 1560 and run (whatever controller sits at 1560) |
| 8      | x7         | 0                 | Run only (no load)                                  |
| 7      | x8         | 100000            | No load. CPU stops.                                 |
| 6      | x9         | 101560            | Binary load from 1560 (SCSI boot)                   |
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
- Floppy and SCSI share device address 1560 -- only one can be physically present
- The content of internal register I12 reflects the ALD settings
- To bootstrap from an arbitrary device address, set bit 13: e.g., device 1550 becomes `21550&`

### Provenance of the switch-9 row

Switch 9 was read off a real **CPU 3095** board: the switch in position 9 gives
internal register **I12 = 21560B**, a mass storage load from 1560B. That is all
the setting means - it names a device address and a load format, NOT a disc
technology. SCSI is one controller that can answer at 1560; a floppy controller
is another, and the same setting serves whichever card is fitted in a given
machine. This table previously described that row as "Run only (no load)",
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
