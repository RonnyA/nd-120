# Using the ND-120 core on a MEGA65

**Full path:** `Verilog/fpga/mega65/docs/01-using-the-core.md`

The MEGA65 counterpart of the MiSTer's `docs/03-deploy-and-test.md` +
`docs/04-core-config-menu.md`: how the core gets onto the machine, how disc
images get to it, and every line of the menu. Everything here is read from
the framework's own source (`m2m/M2M/rom/*.asm`, `vdrives.vhd`) and our
`CORE/vhdl/config.vhd`; what has NOT been tried on a real MEGA65 is marked.

## 1. Files

| File | Where it comes from | Where it goes |
|---|---|---|
| `nd120_mega65_rev3_13MHz_115200.cor` (R3/R3A) or `nd120_mega65_r6_20MHz_115200.cor` (R4/R5/R6) | `make all BOARD=r3|r6` -> `build/<board>/`, staged in `fpga/release-staging/` | anywhere on the SD card; the flash menu browses for it |
| Disc images: Winchester, floppy, paper tape | yours (`ndtool` builds and inspects them; SINTRAN images are not distributed) | `/nd120/` on the SD card |
| `nd120cfg` (35 bytes) | `sdcard/nd120/nd120cfg` in this folder | `/nd120/nd120cfg` - makes the menu settings persistent (section 4) |

The SD card is FAT32. Either slot works; with cards in both, the EXTERNAL
(back) slot takes precedence (`M2M/vhdl/QNICE/sdmux.vhd`).
Untried on a MEGA65: the R3 file on an R3, the R6 file on an R6.

## 2. Getting the core onto the machine

The MEGA65 flashes cores from its own menu; nothing runs on a PC.

1. Copy the `.cor` for your board revision to the card.
   - R3 / R3A: most machines bought before 2024.
   - R6: machines shipped 2024 or later (serial numbers above 1000). R4/R5
     use the R6 memory layout but need their own build (`BOARD=r4|r5`);
     the flash menu refuses a `.cor` built for another model ("Core
     hardware model mismatch!"), so nothing can be flashed wrongly.
   - Not sure: hold **RESTORE** ~2 s, press **HELP**; "MEGA65 MODEL".
2. Power on holding **NO SCROLL** -> the core menu.
3. **CTRL + slot number** (1..7; the guide recommends keeping slot 1 for
   the stock MEGA65 core), choose the file, wait for the confirmation
   (a minute or two). Do not reset or power off meanwhile.
4. Run it: power on holding **NO SCROLL**, press the slot number. The
   core stays selected across the reset button; a plain power cycle
   returns to the default core. Flashing is per slot and reversible.

The `.cor` header carries the core name ("ND-120 SINTRAN III") and the
build stamp (git hash + date, the same as on the power-on banner), which
the flash menu shows - so the flashed build is identifiable there too.

## 3. What happens at start-up

1. The framework's welcome page (our text: what the core is, how to boot).
   **Space** closes it. It shows again after every reset
   (`WELCOME_AT_RESET` in `config.vhd`).
2. The terminal: green 80x25 text, the banner (`ND-120 ...`, git hash +
   build date, `MEGA65 R3 - 13.33 MHz - HyperRAM 4 MB - cache on` or the
   R6 line), the operator panel below the text.
3. The case **power LED** is the CPU's self-test verdict: blue while the
   framework holds a long reset, **amber** while the ND-120 is in Master
   Clear / self-test (or halted in STERR), **green** when the microcode
   reaches MACL2 - self-test passed, OPCOM alive. This is the CPU board's
   own green lamp (`ND3202D` LED[1]) brought out to the case.
4. **RETURN** at the terminal: the OPCOM prompt. CPU + memory + console
   proven, no disc needed.

## 4. The menu (HELP key)

**HELP** opens and closes it; **RUN/STOP** goes back one level (out of a
submenu or the file browser); cursor keys move, **RETURN** selects,
**Space** is the alternative select (`M2M/rom/menu.asm`). The layout is `CORE/vhdl/config.vhd` (`OPTM_ITEMS`);
the line numbers are the `C_MENU_*` constants in `mega65.vhd`.

| Line | Item | What it does | Default |
|---|---|---|---|
| | **ND-120** | headline | |
| 2-5 | `Text: green` / `amber` / `white` / `cyan` | console text colour, one of four (`text_colour` into the terminal glue; the panel's lamps keep their own colours) | green |
| 7 | `Operator panel` | on/off: the panel strip under the text (program level, ACTLV, PONI/IONI/ring lamps, CPU R/G, HDD/FLOPPY activity, MIPS) | on |
| 8 | `CPU cache` | on/off at run time: the ND-120's own cache (`CACHE_SW`). Built in either way; this is the same switch as the Nexys's sw[4] | on |
| | **Drives** | headline | |
| 12 | `Floppy 0:` *file* | mount an image on floppy drive 0 (ND_FLOPPY_DMA drive 0) | `<Mount Drive>` |
| 13 | `Floppy 1:` *file* | floppy drive 1 | |
| 14 | `Winch. 0:` *file* | Winchester unit 0 - the SINTRAN boot disc, `20500&` | |
| 15 | `Winch. 1:` *file* | Winchester unit 1 | |
| 16 | `Tape:` *file* | the paper-tape reader (ND_TAPE_400); the file is read from byte 0 | |
| 18 | `HDMI: ` *mode* | submenu: `720p 50 Hz 16:9`, `720p 60 Hz 16:9`, `576p 50 Hz 4:3`, `576p 50 Hz 5:4`, `640x480 60 Hz`, `720x480 59.94 Hz`, `800x600 60 Hz` - the HDMI output mode; the console's native 800x600@60 is scaled to it by the framework. VGA always shows the native mode | 720p 60 Hz |
| 31 | `HDMI: CRT emulation` | the framework's scanline/polyphase filter on HDMI | off |
| 32 | `HDMI: Zoom-in` | the framework's crop/zoom on HDMI | off |
| 34 | `Close Menu` | | |

**Mounting an image:** select a drive line, RETURN; the file browser opens
in `/nd120/` (`DIR_START` in `config.vhd`), RETURN on a file mounts it and
the line shows the filename. On a line that already has an image, RETURN
REPLACES the image (the drive stays "switched on") and **Space** unmounts
it ("switches the drive off") - `M2M/rom/shell.asm` HANDLE_MOUNTING.
Slot order is fixed: the five lines are storage clients 0..4 of
`rtl/nd_storage_mega65_devices.v`, exactly the MiSTer's five OSD slots.

A request on a slot with no image is answered with "not ready" by the
controller (no hang): `20500&` with nothing on Winchester 0 prints nothing.

**Which floppy format:** taken from the image size, as on the Tang/Nexys/
MiSTer (`nd_storage_mega65_devices.v`): 315392 bytes = 8-inch 512 B/sector,
anything else = the 1.2 MB 1024 B/sector double-sided double-density format.

**Write-back:** writes go to the image file on the card through the
framework's write cache (flushed after ~2 s of quiet, `VD_ANTI_THRASHING_DELAY`);
the drive LED is the ND-120's disc activity. Read-only files are honoured
(a write is refused with WRPROT). Keep copies of your images.

### Persistence - what survives a power cycle

Read from `M2M/rom/options.asm` (not yet seen running on a MEGA65):

- **Settings (colour, panel, cache, HDMI mode, CRT, zoom) persist** IF the
  file `/nd120/nd120cfg` exists on the card, is exactly 35 bytes (one per
  menu line, `OPTM_SIZE`) and its first byte is not 0xFF. A freshly made
  file is all 0xFF, so the defaults apply until the first change, which is
  then written back on every menu change ("<Saving>" shows briefly). The
  file is `sdcard/nd120/nd120cfg` in this folder (also in
  `build/delivery/`); copy it to `/nd120/` on the card. Without it,
  settings reset to the defaults at every power-on. Regenerate it whenever
  `OPTM_SIZE` changes (`m2m/M2M/tools/make_config.sh <file> 35`).
- **Mounts do NOT persist.** The firmware writes a 0 for every
  `OPTM_G_MOUNT_DRV` line when it saves (`_ROSMS_4A`, "exclude
  OPTM_G_MOUNT_DRV items"), so after a power cycle the drives are empty and
  the images must be mounted again from the menu. There is no automount
  in this core (the MiSTer's MGL launch has no equivalent here yet).

## 5. Booting SINTRAN

1. Mount the Winchester image on `Winch. 0` (and whatever else), close the
   menu.
2. At the OPCOM prompt: `20500&` RETURN. First lines within ~30 s,
   `SINTRAN III RUNNING`, the Watchdog banner, log in.
3. Floppy 0 boots with `1560&`.

The console is a TDV2200 (terminal type 93): the keys type what the MEGA65
keycaps say, INST/DEL is Backspace (DEL), shift+INST/DEL is Insert,
CLR/HOME is Home, the cursor keys and F1-F8 send the TDV codes (shift =
the even F-key), F9/F10 = HJELP/FUNK, F11/F12 = SKRIV/ANGRE, HELP = HJELP,
CTRL+letter = control character, CAPS LOCK latches, left-arrow key = `_`,
up-arrow key = `^`, pound = `\`. Full table and the why:
`rtl/m65_keys_to_ps2.v`.

## 6. Differences from the MiSTer core, for someone who knows that one

| | MiSTer | MEGA65 |
|---|---|---|
| Images served by | the ARM (Linux) through `hps_io` | the framework's QNICE soft CPU through `vdrives` - speed unmeasured |
| Selecting images | OSD `S<n>` lines or an `.mgl` launch file (automount) | menu Drives lines only; no automount |
| Persistence | MiSTer config | `/nd120/nd120cfg` for settings; mounts never |
| Console | screen + the board's serial port | screen only (no serial port on a MEGA65) |
| Colour | OSD "Console colour" | menu `Text:` lines |
| CPU clock | 20 MHz | 20 MHz (R4-R6), 13.33 MHz (R3) |
| Boot verdict | board LEDs | case power LED amber/green |

## 7. What to report from a first run

A photo of the banner, one after `20500&`, the power LED colour, VGA or
HDMI, the MEGA65 model - and whether the settings survived a power cycle
with `nd120cfg` on the card (the one thing in section 4 that is read from
source, not seen on a machine).
