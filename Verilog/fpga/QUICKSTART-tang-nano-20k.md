# Quickstart - ND-120 on the Sipeed Tang Nano 20K

Run the 1988 Norsk Data ND-120 on this board from a ready-built bitstream -
no FPGA toolchain needed. One small open-source tool flashes the board
once; after that it boots the ND-120 at every power-on with no PC attached.

What you need:

- Sipeed Tang Nano 20K
- A USB-C cable (powers the board, carries programming AND the serial
  console - the board shows up as two serial ports)
- A microSD card, FAT32, for the Winchester disc image
- A serial terminal program (picocom, PuTTY, TeraTerm, ...)
- A bitstream from the GitHub Release (the filename tells you the CPU
  clock; the console is 115200 on every release file):
  - `nd120_tang20k_fast20_20MHz_115200.fs` - fast build (20.25 MHz CPU,
    timing-clean, boots SINTRAN in ~40 s)
  - `nd120_tang20k_slow_6.75MHz_115200.fs` - safe build (6.75 MHz CPU,
    the long-validated speed)

Unlike the Nexys 4 DDR, this board cannot load its bitstream from the SD
card - the SD slot is wired to the FPGA fabric (the ND-120 uses it for
the disc), not to the configuration controller. Flashing the onboard SPI
flash once gives the same convenience: the board configures itself at
every power-on.

## 1. Install openFPGALoader

Open source, small, no licence:

- Debian/Ubuntu/WSL: `sudo apt install openfpgaloader`
- macOS: `brew install openfpgaloader`
- Windows: ships in the OSS CAD Suite
  (github.com/YosysHQ/oss-cad-suite-build), or use Sipeed's documented
  tools; the Gowin Programmer GUI also flashes `.fs` files if you have
  Gowin EDA installed.

## 2. Flash the bitstream

```
openFPGALoader -b tangnano20k -f nd120_tang20k_<...>.fs
```

The `-f` writes the onboard SPI flash: the ND-120 now starts at every
power-on, no PC needed. (Without `-f` it loads volatile SRAM instead -
gone at power-off - useful for trying the other bitstream quickly.)

WSL note: the board must be attached to WSL first
(`usbipd attach --wsl --busid <id>` on the Windows side; in this repo
`Verilog/fpga/tang-nano-20k/usb-attach.sh` does it).

## 3. Disc image

Copy a Winchester disc image onto the FAT32 microSD (root directory) and
insert it. The image is **not** part of the release - it contains
SINTRAN III, which is not this project's to distribute. The ND software
preservation community keeps images; `ndtool` builds and inspects them.

## 4. Console and boot

The board exposes TWO serial ports over the one USB cable; the console
is the SECOND one (on Linux typically `/dev/ttyUSB1`). Settings:
**115200 baud, 7 data bits, EVEN parity, 1 stop bit**, no flow control.

```
picocom -b 115200 -y e -d 7 -p 1 /dev/ttyUSB1
```

(Bitstreams older than 26-AUG-2026 used 9600.)

1. Press ENTER - the machine's OPCOM console answers. That is the
   no-disc smoke test: bitstream and console proven.
2. Type `20500&` to boot the operating system.
3. `SINTRAN III RUNNING` and the Watchdog banner follow (~40 s on the
   fast build); log in and enjoy 1988.

## Troubleshooting

| Symptom | Cause |
|---|---|
| Terminal shows `?`-garbage | 8N1 framing - set 7 data bits, EVEN parity, 1 stop bit |
| Nothing on the terminal | Wrong port (use the second one) or wrong baud (release = 115200; pre-26-AUG builds = 9600) |
| OPCOM answers, `20500&` prints nothing | No disc image in the card's FAT root, or card not FAT32 |
| openFPGALoader does not see the board | WSL: board not usbipd-attached; any OS: cable is power-only |
| Board reverts to old design after power-cycle | Flashed without `-f` (volatile SRAM load) - repeat with `-f` |
