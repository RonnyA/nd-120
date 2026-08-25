# DISC-TEMA on the Tang SMD: "Disc unit not ready / Controller not active"

Status: analysis, 01-AUG-2026. Silicon evidence from Ronny's TANG_SMD build
(flashed 01-AUG 11:20), TPE J02 DISC-TEMA, `du-di-c` on DISC-75-1 unit 0.

## What the silicon reported

```
***ERROR*** DISC-75MB-1 Unit 0
Hardware Status:    020001b   Disc unit not ready / Not on cylinder
Additional Status:  100000b   Controller not active after activate
Operation was:      Read      (data all zeros, repeats for sector 0, 1, 2, ...)
```

Decode of `020001` against the status word (`ND_SMD.v` header, oracle
`SMDStatusRegister` in the nd100x reference `src/devices/smd/deviceSMD.h`):

| bit | meaning | value |
|-----|---------|-------|
| 0  | interrupt enabled      | 1 |
| 2  | active                 | 0 |
| 3  | ready for transfer     | 0 |
| 4  | inclusive-OR of errors | 0 |
| 5,6,7,8,10 | illegal load / timeout / hw-error-2 / addr mismatch / comparer | all 0 |
| 13 | disk unit NOT ready    | 1 |
| 14 | on cylinder            | 0 |

## Which code path produces exactly that

In `ND-BUS-DEVICES/SMD/circuit/ND_SMD.v` there is exactly one path that ends
with active=0, ready=0, not-ready=1, on-cylinder=0 and NO error bit set: the
`err_active` task reached from a backend/DMA fault during the transfer -

* `E_DISK_RD` + `disk_err_in`  -> media read fault
* `E_MEM_WR` / `E_MEM_RD` + `dma_err` -> ND bus / memory fault

Both call `err_active`, which clears `s_on_cyl[unit]`, sets
`s_not_ready[unit]`, clears active and ready, and sets no error status bit.

The other candidates are excluded by the reported value:

* address mismatch would also show bit 8 + bit 4 (`000420`),
* "drive not selected" would show bit 7 + bit 4 (`000220`),
* a device clear would leave on-cylinder = 1 for a selected unit 0-3,
* never having left boot mode would leave interrupt-enable (bit 0) = 0.

Interrupt-enable = 1 also proves a control word WAS written (so the controller
did leave boot mode) and that the GO reached the transfer engine.

**Conclusion: the transfer engine started and the disk-image backend (or the
DMA master) answered with an error.** This is not a status-word semantics
divergence - the read really failed.

## What can make the backend answer error on the Tang

`SD-FAT/circuit/nd_storage_disc_adapter.v` raises `disk_err` for:

1. `!c_open_ok` - SMD0.IMG could not be opened on the SD card,
2. out of range - chunk end past `c_size_bytes`,
3. a write that is not one full aligned 1024-word block,
4. `c_err` from `nd_storage` (SD/engine failure).

For a READ at cylinder 0 / head 0 / sector 0 only (1) and (4) can fire, so the
first thing to check on the card is whether `SMD0.IMG` exists, is contiguous,
and is within the slot limit of 2,818,048 bytes.

## Two further findings, both real

**A. The image position mapping is NOT the oracle's CHS -> LBA.**
The adapter (and, identically, the unit-tb model and the Verilator C backend)
uses

```
word offset = blkaddr2 * 2048 + blkaddr1 * 64
```

while the nd100x oracle uses

```
lba  = (cylinder * headsPrCylinder + head) * sectorsPrTrack + sector
byte = lba * bytesPrSector          (1024 for the 75 MB disk)
```

With the 75 MB geometry a cylinder is 5 * 18 * 512 = 46080 words, not 2048, and
a head step is 18 * 512 = 9216 words, not 16384. Block 0 is identical under both
mappings, which is why the `1540&` boot works and why nothing caught this
before. Any real driver (and DISC-TEMA) reads the wrong words. Fixing it means
changing three places that must stay in agreement: the adapter, the unit-tb
model in `ND-BUS-DEVICES/SMD/sim/nd_smd_tb.v`, and `process_verilog_smd()` in
`simDevices/NDBus.cpp`.

**B. The SMD slot cannot hold a 75 MB disk.**
2,818,048 bytes = 2752 sectors of 1024 bytes = cylinders 0..30 of the 75 MB
geometry. A DISC-TEMA full-surface test will run past the image and get
out-of-range errors no matter what else is fixed.

## Change made (this pass)

`ND_SMD.v`: status bit 11 is now driven as **DMA channel error** (the name the
oracle's status union already gives bit 11; it is reserved/never set there
because the oracle's transfer is a memcpy). It is set only on the `dma_err`
paths, cleared by reset and by a device clear, and deliberately kept OUT of the
inclusive-OR (bit 4), matching the oracle's `hardwareError` composition.

Effect: on the next silicon run the same failure reports `020001` if the SD/disk
image side failed, or `024001` if the ND bus / memory DMA failed. That splits
the two remaining root causes with one run.

Verified after the change: the three SMD unit testbenches
(`ND-BUS-DEVICES/SMD/sim`, targets `test-smd`, `test-smd-iox`, `test-smd-p2`)
all report `TB_RESULT: PASS`, so bit 11 is behaviour-neutral for everything
else.

## ROOT CAUSE FOUND: the controller finishes too fast (fixed)

DISC-TEMA runs in the Verilator sim (boot the floppy with `1560&`, `dis` at the
TPE prompt, disc name `DISC-75MB-1`, then `du-di-c`, unit 0), and it reproduces
the silicon failure exactly:

```
ERROR !!!  DISC-75MB-1
Disc system : 1 Unit : 0   Cylinder: 0  Surface: 0 Sector: 0
Additional Status 100000
 Controller not active after activate
Operation was: Test for spare track
```

The trace shows the whole setup is correct - block address I `000000`, block
address II `001465` (cylinder), word count by two `+7` writes (`000000` HI then
`001000` LO = 512 words) - and then the control word `010005` at cyc 585774362:
interrupt enable, ACTIVE, device operation 2 (read parity, the spare-track
test). The controller asserts active, takes the stub completion path and is
DONE 10 clocks later. DISC-TEMA reads the status 5,900 clocks after the
activate and gets `040011`: on-cylinder, ready, **active = 0**. It concludes the
controller never took the command, and it is right to: no real 75 MB drive
completes an operation in 1.5 us.

`DELAY_TICKS` (how long the controller stays active after a GO) defaulted to 10
sysclk, taken from the oracle's `IODELAY_HDD_SMD = 10` - but that is a coarse
device-manager tick in nd100x, not ten clock cycles.

Fix: the core instantiation in `ND120_CORE.v` now passes
`DELAY_TICKS = 16'd50000` (7.4 ms at the Tang's 6.75 MHz bring-up clock,
1.85 ms at 27 MHz - slower than the test's check, far quicker than a real
seek). The module default is left alone so the unit testbenches stay fast.

Verified, same sequence and image:

```
GO   cyc=577455079  WR +5 val=010005
     cyc=577455183  RD +4 -> 040005    active=1
     cyc=577602030  RD +4 -> 040011    active=0, ready (completed)
```

No error; DISC-TEMA moves on to its next prompt. `make test-smd-boot` still
passes with the longer active window.

One difference from the silicon transcript: on the Tang the report also carried
"Hardware Status: 020001b / Disc unit not ready", which the sim does not show.
That half is still the storage-backend error path described below, and status
bit 11 will separate it on the next flashed build.

## Traced evidence from the sim (`ND120_SMD_TRACE`)

`ND_SMD.v` now carries a simulation-only IOX trace behind
`` `ifdef ND120_SMD_TRACE ``. Build it with

```
make -C runSim compile USE_LATCHES=0 VERILOG_TAPE=1 SD_STORAGE=0 \
     EXTRA_VDEFINES="-DND120_SMD_TRACE"
```

and drive the console with the load command (the driver used for the runs
below types one character every 0.3 s after the OPCOM `#` appears).

### `21540&` - mass storage load

```
WR +1 val=000000 boot=1 mawff=0     <- boot mode left on the first +1
WR +1 val=000000 boot=0 mawff=1
WR +3 val=000000 boot=0
WR +7 val=002000 boot=0 wcwff=0     <- ONE write, 1024 words
WR +5 val=000004 boot=0             <- GO, M0 read, unit 0
RD +4 -> 040010  active=0 rft=1     <- on-cylinder + ready, nothing transferred
```

Two conclusions. First, the boot-mode fix works: the register writes now land
instead of being discarded. Second, the word count is written ONCE, and with
the 15 MHz flip-flop protocol the first write is the HI byte, so `002000 & 0xFF`
= 0 and the low 16 bits stay zero - the GO completes instantly with a zero word
count.

Both references model the same HI-first write order, but both also switch the
flip-flops OFF for the older controllers: `HAVE_WORDCOUNTRER_FLIPFLOP = false`
for `BIG_DISC_CONTR` and `ECC_DISC_CONTR` in
`RetroCore/Emulated.HW/ND/CPU/NDBUS/NDBusDiscControllerSMD.cs`, where a single
write loads the full 16-bit value. That file's own comment says the ECC disk
controller serves the "38, 75, 288, 150 MBYTE" drives - and DISC-TEMA is
testing a 75 MB unit. So a single `+7` write is consistent with the device at
1540 being the ECC controller rather than the 15 MHz SMD interface this RTL
models. Deciding that is an owner call: it is a controller-type parameter, not
an inverted HI/LO order.

### `1540&` - BPUN byte-server

The pre-fix trace showed the loader polling `+2`, seeing the RESET value of
ready (1) while the first block read was still in flight, and reading `+0`
before the fetch completed. The value it got happened to be correct (the sim's
C backend had already filled the buffer), so nothing was corrupted in sim - but
the race is real, and on the Tang the SD backend is far slower than that C
model. Fixed: the first fetch now drops ready exactly like the wrap-around
fetch does.

## Gate result after the fixes

`make test-smd-boot` now PASSES:

```
[binload] RAM check @002000: 170477 004011 151000 ... 000077 ...
  SMD BOOT GATE PASSED (1540& BPUN-booted and EXECUTED the program)
```

The three program words are in memory at 002000 and `000077` is the value the
program stores when it actually runs. The gate is now also part of `test-full`
(it was not, because it could never terminate).

## SOLVED: why `make test-smd-boot` ran for six hours

Not an RTL fault and not a slow boot. `Run120.cpp`'s main loop is `while (true)`
and the `[binload] RAM check` line - the only thing the gate greps for - is
printed AFTER that loop exits, which happens only when `ND120_MAX_CNT` is set.
The floppy stdin gate one target above sets it (`Verilog/Makefile`,
`ND120_MAX_CNT=120000000`); the SMD gate did not, so the simulator ran forever
no matter how well the boot went. Fixed by adding the same variable to the
`test-smd-boot` recipe.

The boot itself is fast and correct. Traced, the loader reads 23 words in about
5,600 CPU clocks (a few milliseconds of simulated time) - and 23 words is the
WHOLE image `tests/gen_fboot_img.py` produces: the leader "2000\r2000!", load
address, word count, the three program words (SAA 77 / STA +11 / WAIT),
checksum and the autostart action word. The trailing `WAIT` drops the priority
level, which is why the console returns to `#`.

Two earlier readings of this log were wrong and are recorded here so they are
not repeated: the cycle counter only prints when the SMD is accessed, so an
idle machine at the `#` prompt looks like a frozen simulator; and the "roughly
10 s per word, three hours to boot" figure derived from that was an artifact,
not a measurement.
