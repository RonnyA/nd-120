# PLAN - MiSTer main memory on the SDRAM module (4 MB)

> Living plan, outstanding work only. Started 01-SEP-2026; implemented
> 02-SEP-2026 in `7e1e35f`. Requirement from Ronny: 4 MB of main memory,
> the WCS untouched.

## Next

Ronny boots SINTRAN with `&` on v53 (flashed 02-SEP-2026 03:00, plain core
load, WD0 attached by boot2.vhd only): the opening lines must be clean
and the HDD lamps must show activity. v52 (7E1) built clean but was not
flashed - v53 carries 7E1 + lamps + banner; 0 errors, TNS 0.000, worst
slack +0.480 ns.

v51 FLASHED 02-SEP-2026 02:08: 0 errors, TNS 0.000 on EVERY clock (worst
slack +0.792 ns - the FPGA_CLK2_50 async group did it), M10K 165/553. The
banner now reads "build f3a10b3+ 02-Sep-2026 01:50" / "MiSTer DE10-Nano -
20.00 MHz - SDRAM 4 MB - no cache".

## Default mount / automount - ROOT-CAUSED on the board 02-SEP-2026

Requirement: WD0.IMG on Winchester unit 0 by default. First tried the
framework automount (`/media/fat/games/ND120/boot2.vhd -> slot 2`). On the
board the plain core load left `MNT=00000` - the automount did NOT attach
anything. An on-console probe (`rtl/nd120_storage_probe.v`, define
`ND120_STORAGE_PROBE`) prints the five MOUNTED flags and sticky WDISK
req/done/err counts; it showed:
  - plain load (automount): `MNT=00000` - nothing mounted.
  - `load_core ND120-storage-test.mgl`: `MNT` climbs 10000 -> 11000 ->
    11100 -> 11101 as the MGL mounts floppy0, floppy1, WD0, tape (bit order
    fd0 fd1 WD0 WD1 tape; WD1 has no image). WD0 IS mounted.
So the RTL storage path, the mount recording and the probe all work; the
`boot<n>.vhd` automount simply does not fire for this core (a framework/
launch matter, not RTL). The stuck-R the user saw earlier was the
NOT-mounted path, not a hang in a mounted read. Sim had already exonerated
the reset CDC (test-storage-reset).

DECISION: the working default is the MGL (`ND120-storage-test.mgl`), which
mounts WD0 + both floppies + the tape on load. boot2.vhd removed (78 MB,
inert). The probe module stays in the tree, define OFF.

## ROOT CAUSE of the dropped boot characters