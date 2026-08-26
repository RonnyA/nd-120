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
| `nd120_nexys4ddr_45MHz_115200.bit` | Nexys 4 DDR | 45.45 MHz | boots SINTRAN, deployed 26-AUG - the exact silicon-verified artifact, NOT rebuilt (rebuilds re-roll the thin +0.020 ns closure) |
| `nd120_nexys4ddr_16MHz_115200.bit` | Nexys 4 DDR | 16.667 MHz | safe build (huge timing margin), fresh 26-AUG build at 115200 |
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

VERIFY FIRST (needs Ronny at the board): one power-on with JP1 moved and
both files on the card - config must succeed AND the SD stack must still
mount the disc image afterwards. Until that run passes, the documented
path is JTAG. Fallback path either way: `openFPGALoader -b nexys_a7_100`
or Vivado Lab Tools (free, ~3 GB) over USB-JTAG.

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
| `fpga/QUICKSTART-tang-nano-20k.md` | download -> openFPGALoader install matrix (Linux/Mac/Windows) -> flash command -> terminal -> same boot walkthrough |
| Release-notes template | source commit, file table above, link to quickstarts, changed-since-last list |

Terminal settings table (both quickstarts): 7 data bits, EVEN parity,
2 stop bits, no flow control; baud from the filename. Example lines for
picocom and PuTTY.

## Work list, in order

1. Ronny: JP1 SD-config verification on the Nexys (15 min at the board).
2. Rebuild the four release bitstreams from ONE tagged commit (the safe
   Nexys build needs a rebuild at clk 16 - the current .bit on disk is
   45.45 MHz; the Tang slow build likewise) and record each build's own
   timing verdict.
3. Write the two quickstarts, walk them once as a user would.
4. Tag, create the GitHub Release, attach files + SHA256SUMS, paste notes.
5. Add a "Releases" pointer to the main `README.md` and `fpga/README.md`.

## Open questions (parked, not blocking release 1)

- Release cadence/naming: date tag (`bitstreams-2026-08`) vs semver -
  decide at step 4.
- Basys3/Cmod A7 artifacts (OPCOM-only demos) - maybe release 2.
- CI-built releases: blocked (Vivado size/licence in CI; OSS Tang flow
  still blocked by the comb loops). Revisit after the IDB ring cut.
