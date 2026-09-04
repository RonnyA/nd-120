# ND-120 on MEGA65 - note for the tester

Thank you for testing this. This core is the **whole ND-120 minicomputer**:
the 1988 Norsk Data ND-120 CPU board with 4 MB of memory, a Tandberg TDV2200
terminal on your MEGA65's screen and keyboard, and two floppy drives, two
Winchester discs and a paper-tape reader served from image files on the SD
card. It boots SINTRAN III from a Winchester image.

## Which file

One `.cor` per board revision. Flash only the one for YOUR model - the
MEGA65 refuses the wrong one ("Core hardware model mismatch!"):

| Your MEGA65 model | File | Main memory it uses | CPU clock |
|---|---|---|---|
| R3 / R3A (most machines bought before 2024) | `nd120_mega65_rev3_13MHz_115200.cor` | the 8 MB HyperRAM | 13.3 MHz |
| R6 (machines shipped 2024 or later, serial > 1000) | `nd120_mega65_r6_20MHz_115200.cor` | the 64 MB SDRAM | 20 MHz |

Not sure which you have: hold **RESTORE** for ~2 seconds (the freezer
opens), press **HELP**; "MEGA65 MODEL" is on that screen.

## How to flash (standard MEGA65 procedure, nothing installed on your machine)

1. Copy the `.cor` onto a micro-SD card (FAT32; internal or external slot).
2. Make a folder `/nd120` on the card, copy `nd120cfg` into it (keeps the menu settings), and put the disc images in it (the
   Winchester image with SINTRAN III on it at least; floppy and tape images
   if you have them).
3. Power on while holding **NO SCROLL** - the core menu appears.
4. Press **CTRL + a slot number** (any slot except 0; keep slot 1 for the
   stock MEGA65 core), pick the `.cor`.
5. **Do not reset or power off until the confirmation message** - flashing
   takes a minute or two.
6. To run it: power on holding **NO SCROLL**, press the slot number. A plain
   power cycle returns to the stock core. Nothing here is permanent.

## What you should see, and what to do

1. The framework's welcome page. Press **Space**.
2. A green 80x25 terminal with a power-on banner ("ND-120 ...", a git hash
   + date line, and "MEGA65 R3" or "MEGA65 R6" - that line tells us which
   file you flashed). Under the text: the operator panel (program level,
   lamps, MIPS).
3. **The case power LED is the CPU's verdict:** amber while the CPU runs
   its self-test, **green when it passed**. Red/amber that never turns
   green means the CPU did not come up - please tell us.
4. Press **RETURN**. The microprogram answers with the OPCOM prompt. That
   proves CPU, memory and console.
5. Press **HELP** - the menu. Under **Drives**, mount your Winchester image
   on **Winch. 0** (and any others). Close the menu.
6. At the OPCOM prompt type **`20500&`** and RETURN. SINTRAN III boots from
   Winchester 0; the first lines appear within about 30 seconds, then
   "SINTRAN III RUNNING" and the login. Log in and use it - LIST-FILES,
   PED, whatever you like. Floppy 0 boots with `1560&`.

Keys type what the MEGA65 keycaps say, shifted symbols included. INST/DEL
is Backspace, CLR/HOME is Home, the cursor keys and F1-F8 send the TDV2200
codes. CAPS LOCK works as the keycap does. **RUN/STOP is EXIT** - the
TDV2200's SLUTT key, the way out of PED and other SINTRAN programs (ALT+X
is the same key). HELP opens the core's own menu; RUN/STOP inside that
menu just goes back a level.

## What to send back

1. A **photo of the screen** with the banner, and one after `20500&` (the
   SINTRAN start-up text, or whatever happened instead).
2. The **power LED colour** after a few seconds (amber / green).
3. Which output: **VGA or HDMI**.
4. Your MEGA65 model.

If the screen stays black: does the **HELP** menu still appear? That tells
us whether the framework is alive and only the ND-120 is dark, or the whole
core failed. Please do not spend time debugging - report what you saw.

## Known limits of this first build

- Nothing here has run on a real MEGA65 yet - you are the first. Every part
  of it has run on the DE10-Nano (MiSTer) or the Nexys 4 DDR, and in
  simulation, but this exact combination has not.
- Disc images are served by the framework's own small CPU reading the SD
  card; SINTRAN paging speed on that path is unmeasured. It may feel slow.
- Writes to the images go to the SD card. Keep a copy of your images.
