# Winchester oracle traces

**Full path:** `Verilog/ND-BUS-DEVICES/WINCHESTER/oracle/`

Reference IOX traces for the Winchester controller, captured from a
**working** machine. They exist so a silicon or Verilator run can be diffed
against known-good behaviour instead of against somebody's memory of it.

These were regenerated from scratch more than once because the only copy
lived in a temporary directory that was deleted with the session. They are
committed now.

## `fsi-lifi-nd100x.trace`

72 IOX accesses: the File System Investigator (FILSYS-INV-Q04) opening the
Winchester and reading the SINTRAN directory, captured from the **nd100x C
emulator**, which performs this successfully end to end.

The opening sequence, which any working implementation must reproduce:

| # | Access | Meaning |
|---|--------|---------|
| 1 | `READ +4 -> 020000` | status: idle. This value is NORMAL at power-on, not a fault |
| 2 | `WRITE +5 = 034005` | M7 return-to-zero |
| 3 | `READ +4 -> 060005` | status: ACTIVE (b2) while the seek runs |
| 4 | interrupt, level 11 | operation complete |
| 5 | `READ +4 -> 060011` | status: on-cylinder + finished + int-enabled |
| 6 | `WRITE +7 = 0` etc. | word count, block address, memory address... |
| 7 | `WRITE +5 = 5` | GO, M0-Read, LBA 0, 1024 words |

### How it was captured

```bash
cd ~/repos/nd100x
ND100X_WD_DEBUG=1 ./build_linux/bin/nd100x --pipe \
    --boot=bpun --image=images/FILSYS-INV-Q04.BPUN \
    --wd0=<a COPY of WD0.IMG> 2> fsi-lifi-nd100x.trace
```

Answer `DISC-74MB-1`, unit `0`, then `LI-FI`.

**Always use a copy of the image.** The FSI is read-only, but the SINTRAN
boot path (`20500&`) writes back to LBA 0.

## Comparing a capture against it

`Verilog/tools/wdtrace.py` decodes the Tang's on-chip trace ring and diffs it
against this file:

```bash
# first argument is the SILICON capture (5-hex-digit ring dump),
# second is this oracle file - not the other way round
python3 ../../../tools/wdtrace.py captured.txt fsi-lifi-nd100x.trace
```

Capture the silicon side with the committed console driver, which streams to
disk as bytes arrive (a one-shot ring dump piped through `tail` loses its
head - that mistake cost two capture attempts):

```bash
python3 ../../../tools/ndconsole.py --seconds 180 --out captured.txt 'LI-FI'
```

The ring packs FIVE record kinds, and reading it as read/write only produced
two wrong conclusions before it was noticed - a dump full of `C01xx` records
is not an empty ring, it is **foreign IOX**, another device's address going
past on the bus (`C0100`/`C0102`/`C0103` are octal 400/402/403, the paper
tape reader). See the decoder's own docstring and the `trace_rec` assignment
in `../circuit/ND_WINCHESTER.v`.

## Status values worth recognising

| Octal | Bits | Meaning |
|-------|------|---------|
| `020000` | b13 | idle. Power-on state - NOT an error |
| `060005` | b14,b13,b2,b0 | on-cylinder, ACTIVE, interrupt enabled |
| `060011` | b14,b13,b3,b0 | on-cylinder, FINISHED, interrupt enabled |
| `060010` | b14,b13,b3 | on-cylinder, finished, interrupt disabled |

Bit 13 is always 1 on the 3041 (controller identity), which is why every
healthy value starts with `02` or `06`.
