# ND-120 MiSTer core (DE10-Nano)

Port of the ND-120 CPU board to the [MiSTer FPGA](https://mister-devel.github.io/MkDocs_MiSTer/) platform.

**Start here: [docs/00-overview.md](docs/00-overview.md)** — a phase-by-phase plan
(setup, building, deploy/test, OSD menu, block/char devices, debugging) with every
external link validated. `docs/07-links.md` is the full link collection.

- **Board:** Terasic DE10-Nano — Intel Cyclone V SoC `5CSEBA6U23I7` (~110K LE FPGA fabric + dual-core ARM Cortex-A9 "HPS" running Linux, 1GB DDR3 on the HPS side).
- **Goal:** ND-120 CPU core with floppy/HDD images served as files from the Linux (HPS) side via the MiSTer `hps_io` block-device protocol, OPCOM console over the framework UART, microcode uploaded from the HPS at core load.

## Status

Planning. Nothing builds yet. Prerequisite: the latch-to-FF / clock-enable work must boot on FPGA first (see `Verilog/TODO.md`) — Cyclone V has the same constraints as the Artix-7 (no transparent latches, no internal tri-states, no gated clocks), so all `FPGA_FF_MODE` work carries over directly.

## Toolchain

- **Quartus Prime Lite 17.0.2** — free, no license. MiSTer standardizes on this exact version; do not use newer Quartus (project-file incompatibilities, no benefit for Cyclone V).
- **Docker (preferred):** the community image `raetro/quartus:17.0` (Docker Hub, or `ghcr.io/raetro/quartus:17.0`) from https://github.com/raetro/sdk-docker-fpga runs headless synthesis:

  ```bash
  # from Verilog/fpga/mister/
  docker run --rm -v "$PWD":/build raetro/quartus:17.0 \
      quartus_sh --flow compile nd120
  ```

  Output is `output_files/nd120.rbf`; copy it to the MiSTer SD card (or scp to the board) and load it from the OSD. No programming cable needed.

## Planned layout (from MiSTer-devel/Template_MiSTer)

```
mister/
  nd120.qpf / nd120.qsf   Quartus project (renamed from Template)
  files.qip               list of all RTL files (points at ../../ sources)
  sys/                    MiSTer framework - copied from Template, never edited
  nd120.sv                the `emu` module: ND3202D instance, PLL, hps_io wiring
  rtl/                    MiSTer-specific glue (PLL, block-device controllers)
```

## Port plan

1. Fork/copy `MiSTer-devel/Template_MiSTer`, instantiate `ND3202D` inside `emu`,
   clocks from one PLL (50 MHz in -> ~39.06 MHz CPU/bus domain), small BRAM RAM
   config first, OPCOM UART on the framework serial. Milestone: OPCOM prompt.
2. Main memory: 6MB (`ramSize=2`) via HPS DDR3 (`f2sdram` bridge, as ao486 does)
   or the SDRAM add-on board. DDR3 latency is fine at original ND bus speed.
3. Microcode: upload WCS/EPROM images from HPS via the `ioctl` download path
   (arcade-ROM mechanism) instead of baked-in hex init.
4. Floppy/HDD: thin controllers translating ND IOX/DMA commands to the
   `sd_rd`/`sd_wr`/`sd_buff` 512-byte block protocol; the HPS mounts image
   files and serves the sectors. Reference cores:
   [PDP2011](https://github.com/MiSTer-Enhanced/PDP2011_MiSTer) (dissected in
   docs/05-devices-block-char.md), ao486.

## References

- Template: https://github.com/MiSTer-devel/Template_MiSTer
- emu module docs: https://mister-devel.github.io/MkDocs_MiSTer/developer/emu/
- Compile docs: https://mister-devel.github.io/MkDocs_MiSTer/developer/mistercompile/
- Docker image: https://github.com/raetro/sdk-docker-fpga
