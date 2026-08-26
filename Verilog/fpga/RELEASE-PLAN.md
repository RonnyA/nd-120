# Bitstream release plan

Decided 26-AUG-2026 (Ronny): GitHub Releases carry ready-built bitstreams so
nobody has to install Vivado or Gowin EDA to run the ND-120. Disc image is
NOT distributed - instructions only. Four bitstreams in release 1. The
Nexys SD-card config path gets a hardware verification BEFORE it is
documented as the primary path.

## What ships in release 1

Attached to a GitHub Release on a tagged commit (binaries never enter git
history):

ALL releases run the console at 115200 7E2 (Ronny, 26-AUG) - one terminal
setting for every file, no per-file baud confusion:

| File | Board | CPU clock | Status behind it |
|---|---|---|---|
| `nd120_nexys4ddr_45MHz_115200.bit` | Nexys 4 DDR | 45.45 MHz | **refreshed 27-AUG with the SD power-cycle fix** (WNS +0.064); silicon-verified three ways: JTAG boot, MACL-then-boot, SD-card-config-then-boot |
| `nd120_nexys4ddr_16MHz_115200.bit` | Nexys 4 DDR | 16.667 MHz | safe build, rebuilt 27-AUG with the SD power-cycle fix |
| `nd120_tang20k_fast20_20MHz_115200.fs` | Tang Nano 20K | 20.25 MHz | boots SINTRAN, timing-clean - the exact silicon-verified artifact |
| `nd120_tang20k_slow_6.75MHz_115200.fs` | Tang Nano 20K | 6.75 MHz | safe build, fresh 26-AUG build at 115200 |
| `SHA256SUMS` | - | - | checksums of the four above |

Filenames still carry board + clock + baud. Release notes state each
artifact's source commit SHA and timing verdict, and link the quickstarts.
Staging area for the artifacts before the GitHub Release:
`fpga/release-staging/` (gitignored).

## How users load them

**Nexys 4 DDR - the "copy two files" path (pending one verification):**
the board's own config controller loads a `.bit` from a FAT microSD at
power-on (Digilent reference manual, JP1 jumper set to USB/SD). Our design
then uses the same card for the disc image, so ONE card carries both:

1. Format microSD as FAT32; copy the `.bit` and the disc image to the root.
2. Move jumper JP1 to USB/SD (one-time).
3. Insert card, power on, open the terminal. No software installed at all.

VERIFIED 26-AUG-2026 on the board (Ronny): config from the card succeeds
and the SD stack mounts the disc image afterwards - one card carries
both. Two jumpers: JP1 cap to pins 3-4 ("USB/SD") AND JP2 to the SD
side. Fallback path: Vivado Lab Tools or openFPGALoader over USB-JTAG.

**Tang Nano 20K - one command, once:** the SD slot goes to fabric pins,
not to configuration, so there is no SD-config on this board. Instead:

1. Install openFPGALoader (in oss-cad-suite; also `apt install
   openfpgaloader` / `brew install openfpgaloader`).
2. `openFPGALoader -b tangnano20k -f nd120_tang20k_<...>.fs` - the `-f`
   writes onboard SPI flash, so the board boots the ND-120 at every
   power-on from then on, no PC needed.
3. Disc image on the microSD, terminal on the second USB serial port.
   Alternative for Windows-only users: the Gowin Programmer GUI.

**Disc image (both boards):** NOT in the release (Ronny, decision 1).
The quickstarts explain what the machine needs (a Winchester image on the
card's FAT root), point at the ND software preservation community for
images, and at `ndtool` for building/inspecting them. A bitstream without
an image still comes up in OPCOM - the quickstart shows that as the
"it works" smoke test.

## Documents to write

| File | Content |
|---|---|
| `fpga/QUICKSTART-nexys4ddr.md` | **WRITTEN 26-AUG** - both deployment paths (USB volatile/QSPI-persistent + microSD config with an UNVERIFIED banner and the test checklist), terminal settings, OPCOM smoke test, `20500&`, troubleshooting |
| `fpga/QUICKSTART-tang-nano-20k.md` | **WRITTEN 26-AUG** - openFPGALoader install matrix, persistent `-f` flash, WSL usbipd note, second-serial-port console, boot walkthrough, troubleshooting |
| Release-notes template | source commit, file table above, link to quickstarts, changed-since-last list |

Terminal settings table (both quickstarts): 7 data bits, EVEN parity,
2 stop bits, no flow control; baud from the filename. Example lines for
picocom and PuTTY.

## Work list, in order

1. DONE 26-AUG (Ronny, on the board): SD-config verified working - JP1
   cap on pins 3-4 (far right, "USB/SD"; factory default is 1-2) AND JP2
   on the SD side; FPGA configures from the card and the ND-120 boots
   from the same card. Quickstart Path 2 updated with the verified steps.
2. Rebuild the four release bitstreams from ONE tagged commit (the safe
   Nexys build needs a rebuild at clk 16 - the current .bit on disk is
   45.45 MHz; the Tang slow build likewise) and record each build's own
   timing verdict.
3. Write the two quickstarts, walk them once as a user would.
4. Tag, create the GitHub Release, attach files + SHA256SUMS, paste notes.
5. Add a "Releases" pointer to the main `README.md` and `fpga/README.md`.

## Open questions (parked, not blocking release 1)

- Release cadence/naming: date tag chosen at step 4: `bitstreams-2026-08`.
- Basys3/Cmod A7 artifacts (OPCOM-only demos) - maybe release 2.
- CI-built releases: blocked (Vivado size/licence in CI; OSS Tang flow
  still blocked by the comb loops). Revisit after the IDB ring cut.
