# SD card layout - what the ND-120 can and cannot read

**Full path:** `Verilog/SD-FAT/CARD-LAYOUT.md`

The rules below are not conventions, they are limits of the clean-room FAT
reader in `Verilog/SD-FAT/circuit/sd_file_reader.v`. Breaking any of them
produces the same symptom - the client reports "file not found" and the
device behaves as if no medium is present - which is impossible to tell apart
from a broken controller without knowing these rules first. Getting this
wrong has cost more than one debugging session.

## The rules

**1. Every file must be in the ROOT directory.**
The reader never descends into a subdirectory. A card with
`/floppy/FLOPPY1.IMG` and `/wd/WD0.IMG` looks completely empty to the machine
even though the files are plainly there.

**2. Names must be 8.3, and the length must match exactly.**
The match is case-INSENSITIVE but LENGTH-EXACT. `WD0.IMG` is 7 characters and
matches; `WD0-M.IMG` does not match a client looking for `WD0.IMG`. Rename
the file on the card rather than hoping for a prefix match.

**3. A 4-character extension needs long-filename support.**
`.BPUN` is four characters, so FAT can only store it through a VFAT
long-filename entry. Builds that define `SDFAT_NO_LFN` cannot see such a file
at all. This is why the Tang's tape boot file is `BOOT.TAP` and not
`BOOT.BPUN` - see the `BOOT_NAME` override where `nd_storage_devices` is
instantiated in `Verilog/fpga/tang-nano-20k/src/ND120_TANG20K_TOP.v`.

**4. Files should be contiguous, but no longer have to be.**
Since 07-AUG-2026 the storage engine walks the FAT chain at runtime
(`nd_storage_engine.v`, the `F_RES`/`F_STEP`/`F_FAT_GO` states), so a
fragmented file is read correctly. The mount-time contiguity gate is retired
by default and only exists as a diagnostic build
(`-DSDFAT_FORCE_STORAGE_CHECK`). Contiguous files are still faster: every
chain hop past the memoised landing point costs an extra FAT sector read.

## Image files may be bigger than the drive

A disc image does not have to match its drive geometry exactly - an oversized
`WD0.IMG` or `SMD0.IMG` is fine and the extra bytes are never read. The
controller bounds every transfer against its own GEO_* parameters before the
storage stack is asked for anything, so a sector past the end of the drive
cannot be addressed at all.

The one limit is **128 MiB**: `nd_storage_mount.v` keeps the block count in
16 bits (`s_size[26:11]`), so a file at or above 2^27 bytes has its size
silently truncated and reads start being refused. Full explanation and the
per-size table: `Verilog/ND-BUS-DEVICES/README.md`, section "The image file
may be LARGER than the geometry".

## Which client opens which name

Defaults from `nd_storage.v`'s `FILEn_NAME` parameters. A board may override
any of them at instantiation.

| Client | Default filename | Device |
|--------|------------------|--------|
| 0 | `TAPE.BPUN` (Tang: `BOOT.TAP`) | paper tape reader, IOX 400 |
| 1 | `FLOPPY1.IMG` | floppy drive 0, IOX 1560 |
| 2 | `FLOPPY2.IMG` | floppy drive 1, IOX 1560 |
| 3 | `SMD0.IMG` | SMD unit 0, IOX 1540 |
| 4 | `SMD1.IMG` | SMD unit 1 |
| 5 | `SMD2.IMG` | SMD unit 2 |
| 6 | `WD0.IMG` | Winchester unit 0, IOX 500 |
| 7 | `WD1.IMG` | Winchester unit 1 |

Only the clients a given build includes are opened; the rest are tied idle.
See `TANG_FLOPPY` / `TANG_SMD` / `TANG_WD` in
`Verilog/fpga/tang-nano-20k/src/tang20k_defines.v`.

## Checking a card before blaming the hardware

```bash
# everything the machine can see must appear in THIS listing, at the top level
mdir -i /dev/sdX ::

# the filesystem itself must be clean
fsck.vfat -n /dev/sdX
```

If a file is missing from that listing, or its name is a different length
from the one in the table above, the machine is behaving correctly by
reporting it absent.

## When a file really is missing

The storage stack now says so precisely rather than failing anonymously: the
client completes with `err=1` and reason `NDS_ERR_NOTOPEN` (the card is fine,
the file is not on it) or `NDS_ERR_NOCARD` (no card at all). Each controller
maps that onto a status bit its own manual defines - the full table is in
`Verilog/SD-FAT/circuit/nd_storage_status.vh`.
