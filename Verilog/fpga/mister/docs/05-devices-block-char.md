# Phase 4 — Devices: Block (disks) and Character (console), with the PDP2011 Case Study

Goal: floppy/HDD as image files on the Linux side, OPCOM on a real terminal,
microcode from files. All links verified 2026-07-08.

## 1. Block devices — the hps_io protocol

Source of truth: `sys/hps_io.sv`
(https://raw.githubusercontent.com/MiSTer-devel/Template_MiSTer/master/sys/hps_io.sv)
and the official overview
(https://mister-devel.github.io/MkDocs_MiSTer/developer/hps_io/).

When the user mounts an image via an `S` menu slot, Linux opens the file and from
then on services sector requests from your logic. Per-drive signals (arrays sized
by the `VDNUM` parameter, up to 10 drives; up to 4 images mounted simultaneously per
the porting docs):

| Signal | Dir (core view) | Width | Meaning |
|---|---|---|---|
| `img_mounted[n]` | in | 1 | pulses when slot n (un)mounts |
| `img_readonly` | in | 1 | valid during img_mounted pulse |
| `img_size` | in | 64 | bytes; 0 = unmounted. valid during pulse |
| `sd_lba[n]` | out | 32 | block number to transfer |
| `sd_blk_cnt[n]` | out | 6 | blocks-1 per request (total <= 16 KB) |
| `sd_rd[n]` / `sd_wr[n]` | out | 1 | request read / write |
| `sd_ack[n]` | in | 1 | high while Linux services the request |
| `sd_buff_addr` | in | 13 (8-bit) / 12 (16-bit) | address into YOUR buffer RAM |
| `sd_buff_dout` | in | 8/16 | data from image (reads) |
| `sd_buff_wr` | in | 1 | write strobe for sd_buff_dout |
| `sd_buff_din[n]` | out | 8/16 | data to image (writes) |

Protocol: raise `sd_rd[n]` with `sd_lba[n]` valid → Linux polls, asserts
`sd_ack[n]`, streams the sector through the buffer port (the comments say the port
is designed for a 2-port altsyncram — you supply a small dual-port BRAM as the
sector buffer) → drop your request on ack. Block size defaults to 512 bytes
(`BLKSZ` parameter). The disk image is a **flat sequence of blocks** — exactly what
a file on the SD card provides.

## 2. Case study: how PDP2011 does its disks

Repo: https://github.com/MiSTer-Enhanced/PDP2011_MiSTer (current repo; original
port: https://github.com/birdybro/PDP2011_MiSTer). Wrapper:
https://raw.githubusercontent.com/MiSTer-Enhanced/PDP2011_MiSTer/main/pdp2011.sv

The clever part: **the disk controllers were not rewritten for MiSTer.** PDP2011's
original RK11/RL11/RH70 controllers (`rtl/rk11.vhd`, `rtl/rl11.vhd`,
`rtl/rh11.vhd`) natively speak SPI-SD-card protocol through a shared driver
(`rtl/sdspi.vhd`, full CMD0/CMD8/ACMD41/CMD17/CMD24 init+transfer FSM). The MiSTer
port inserts the framework's **`sys/sd_card.sv` SD-card emulator** between each
controller's SPI pins and hps_io — a fake SDHC card in fabric, backed by the
Linux-mounted image:

```verilog
hps_io #(.CONF_STR(CONF_STR), .WIDE(1), .VDNUM(3), .PS2DIV(3125)) hps_io (...);

sd_card #(.WIDE(1)) sd_card_rk (
    .clk_sys(clk_100mhz), .clk_spi(clk_100mhz), .reset(reset), .sdhc(1),
    .sd_lba(sd_lba[0]), .sd_rd(sd_rd[0]), .sd_wr(sd_wr[0]), .sd_ack(sd_ack[0]),
    .sd_buff_addr(sd_buff_addr), .sd_buff_din(sd_buff_din[0]),
    .sd_buff_dout(sd_buff_dout), .sd_buff_wr(sd_buff_wr),
    .sck(rk_sclk), .ss(rk_cs | ~vsd_sel_rk), .mosi(rk_mosi), .miso(rk_miso)
);

always @(posedge clk_100mhz) begin
    if(img_mounted[0]) vsd_sel_rk <= |img_size;   // mount -> controller enabled
    ...
end
assign have_rk = vsd_sel_rk;
```

Inside `rk11.vhd`: Unibus registers (RKCS/RKWC/RKBA/RKDA...) are decoded; the GO
bit starts a transfer; geometry (drive/cyl/head/sector) is flattened to a linear
block address; a bus-master FSM DMAs words between memory and the sdspi 256-word
sector buffer.

**Lesson for the ND-120:** model the ND floppy/SMD controller with a simple
sector-level handshake (block address, start, done, 256-word buffer) and drive
`sd_lba/sd_rd/sd_wr/sd_buff_*` **directly** — the SPI layer in PDP2011 is
historical baggage from its standalone-FPGA origin; we don't need `sd_card.sv` at
all unless we want to reuse an SPI-speaking controller. The ND controller's job is
the same as rk11's: translate IOX register writes + DMA into "read/write block N of
drive D".

Two extra tricks from PDP2011 worth copying:
- mount pulse → controller present/absent at runtime (`have_rk` style enables);
- an OSD option can redirect a controller to the **physical** secondary SD slot
  (`SD_SCK/SD_MOSI/SD_CS/SD_MISO` emu ports) for real-media access later.

## 3. File upload (ioctl) — the microcode path

From `hps_io.sv` (same source): the `F` menu entries and boot files arrive as a
byte/word stream:

- `ioctl_download` — high during transfer; `ioctl_index[15:0]` — which menu entry
  (F1 → 1...; `boot.rom` auto-loads as index 0 at core start);
- `ioctl_wr` strobe + `ioctl_addr[26:0]` + `ioctl_dout[7:0 or 15:0]`;
- `ioctl_wait` — throttle the stream if your write port is slow;
- `ioctl_file_ext[31:0]` — the actual extension picked;
- upload in the other direction exists too (`ioctl_upload`/`ioctl_din`) — could
  dump machine state or memory to a file for offline diffing against Verilator.

ND-120 use: replace baked-in `AM27256_45132L.hex` / WCS hex init with an ioctl
receiver that writes the WCS/EPROM RAMs while holding the CPU in MCL. Name the file
`boot.rom` in `/media/fat/games/ND120/` and index-0 auto-load gives "microcode
loads at core start" with no user action. **[the exact boot.rom per-core folder
lookup is standard practice via the games path
(https://mister-devel.github.io/MkDocs_MiSTer/cores/paths/) — verify the filename
convention on first use]**

## 4. Character devices — OPCOM console and beyond

Three options, all real (validated):

1. **Framework UART** (recommended first): `emu` has
   `UART_RXD/TXD/CTS/RTS/DTR/DSR`. Per the official emu docs
   (https://mister-devel.github.io/MkDocs_MiSTer/developer/emu/ and the wiki emu
   page): "Serial is passed to the linux arm side of the MiSTer. On the arm side,
   software decides what to do with the data. ie: send it to shell, ppp, MIDI,
   etc." — enabled/configured by the `UART<speeds>` token in the CONF_STR header
   (PDP2011: `"PDP2011;UART19200;"`). Wire the ND-120 current-loop/UART console
   (OPCOM) here; on the Linux side you attach a terminal to it via the OSD.
2. **User port as raw UART**: `USER_IN[6:0]`/`USER_OUT[6:0]` on the I/O board's
   USB3-style user port (open-drain; set USER_OUT bit to 1 to read USER_IN) — a
   direct cable to a USB-serial adapter, independent of the Linux side. Good as a
   debug side-channel.
3. **Built-in video terminal** (later, and very much in the ND spirit): PDP2011
   ships a VT100/VT105 (`rtl/vt.vhd` + `rtl/vga.vhd` + `rtl/ps2.vhd`) rendered via
   the framework video chain, with an OSD switch choosing whether the console
   KL11 talks to the on-screen VT or the external UART. An ND "Tandberg terminal
   on HDMI + USB keyboard" would follow exactly that pattern; `hps_io` provides
   `ps2_key` for the keyboard. Video helpers:
   https://mister-devel.github.io/MkDocs_MiSTer/developer/video_mixer/

PDP2011 instantiates four KL11 serial units and muxes unit 0/1 between the VT and
the external UART with one status bit — a good template for OPCOM + extra ND
terminal ports.

## 5. Main memory for ramSize=2 (6 MB)

Two validated options:

- **HPS DDR3 via the `DDRAM_*` emu ports** (64-bit data, `DDRAM_ADDR[28:0]` in
  64-bit words, bursts, `DDRAM_BUSY`/`DDRAM_DOUT_READY` flow control). ao486 uses
  it as x86 main memory — verified in its source
  (https://raw.githubusercontent.com/MiSTer-devel/ao486_MiSTer/master/ao486.sv),
  which pins a window with `assign DDRAM_ADDR[28:25] = 4'h3;` and leaves SDRAM
  unused. Higher/variable latency, but at original ND bus speed that is absorbed;
  no add-on board needed. The porting docs warn DDR3 needs careful reset handling
  ("or hard hangs").
- **SDRAM add-on board**: raw pins on `SDRAM_*`; there is no shared framework
  controller — cores bring their own (PDP2011's is inside `rtl/mister_top.vhd`:
  init/refresh FSM, 16-bit data). Our Tang Nano 20K SDRAM bridge work transfers
  almost directly. Deterministic latency, costs an add-on board.

Recommendation: start with BRAM (24 KB config boots OPCOM), then DDRAM — it needs
no purchase and ao486 proves it at far higher demands than ours.

## Phase 4 exit criteria

- [ ] Microcode loads via ioctl (F-entry or boot.rom), CPU boots to OPCOM.
- [ ] 6 MB main memory on DDRAM (or SDRAM) passes the memory test that currently
      runs in Verilator.
- [ ] Floppy image mounts from the OSD; ND floppy controller reads sector 0
      (verify content by checksumming the same file over ssh).
- [ ] SINTRAN (or the test-and-boot floppy) boots from an image file.
