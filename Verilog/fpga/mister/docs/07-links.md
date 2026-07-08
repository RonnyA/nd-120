# Validated Link Collection

Every link below was fetched and returned real content on 2026-07-08 (a few via
curl with a browser user agent where noted). Links we tried that FAILED are listed
at the bottom so nobody wastes time on them.

## Official MiSTer documentation (mister-devel.github.io)

| Page | URL |
|---|---|
| Docs root | https://mister-devel.github.io/MkDocs_MiSTer/ |
| Requirements (hardware) | https://mister-devel.github.io/MkDocs_MiSTer/setup/requirements/ |
| SD card install (Mr. Fusion) | https://mister-devel.github.io/MkDocs_MiSTer/setup/software/ |
| Updater / downloader | https://mister-devel.github.io/MkDocs_MiSTer/setup/updater/ |
| Network access (ssh root/1) | https://mister-devel.github.io/MkDocs_MiSTer/advanced/network/ |
| Compiling for MiSTer (Quartus 17.0.2) | https://mister-devel.github.io/MkDocs_MiSTer/developer/mistercompile/ |
| The emu module | https://mister-devel.github.io/MkDocs_MiSTer/developer/emu/ |
| Porting cores guide | https://mister-devel.github.io/MkDocs_MiSTer/developer/porting/ |
| Config string (OSD menu) | https://mister-devel.github.io/MkDocs_MiSTer/developer/conf_str/ |
| hps_io overview | https://mister-devel.github.io/MkDocs_MiSTer/developer/hps_io/ |
| Debugging (JTAG/USB-Blaster) | https://mister-devel.github.io/MkDocs_MiSTer/developer/debugging/ |
| video_mixer helper | https://mister-devel.github.io/MkDocs_MiSTer/developer/video_mixer/ |
| video_freak helper | https://mister-devel.github.io/MkDocs_MiSTer/developer/video_freak/ |
| Useful HDL snippets (CE generators) | https://mister-devel.github.io/MkDocs_MiSTer/developer/snippets/ |
| Code style guidelines | https://mister-devel.github.io/MkDocs_MiSTer/developer/principles/ |
| Core internal names (INI overrides) | https://mister-devel.github.io/MkDocs_MiSTer/developer/corenames/ |
| Component/chip catalog across cores | https://mister-devel.github.io/MkDocs_MiSTer/developer/component/ |
| Developer links hub | https://mister-devel.github.io/MkDocs_MiSTer/developer/links/ |
| What is a core (.rbf) | https://mister-devel.github.io/MkDocs_MiSTer/cores/what/ |
| Directory/games paths | https://mister-devel.github.io/MkDocs_MiSTer/cores/paths/ |
| Computer cores folder table | https://mister-devel.github.io/MkDocs_MiSTer/cores/computer/ |
| File transfer (FTP/Samba/SCP) | https://mister-devel.github.io/MkDocs_MiSTer/setup/games/ |
| FAQ (folder conventions) | https://mister-devel.github.io/MkDocs_MiSTer/basics/faq/ |

## Framework source (GitHub)

| What | URL |
|---|---|
| Template_MiSTer (start here) | https://github.com/MiSTer-devel/Template_MiSTer |
| Template.sv (the emu example) | https://raw.githubusercontent.com/MiSTer-devel/Template_MiSTer/master/Template.sv |
| emu port list | https://raw.githubusercontent.com/MiSTer-devel/Template_MiSTer/master/sys/emu_ports.vh |
| hps_io.sv (block dev + ioctl protocol) | https://raw.githubusercontent.com/MiSTer-devel/Template_MiSTer/master/sys/hps_io.sv |
| sys/ contents | https://github.com/MiSTer-devel/Template_MiSTer/tree/master/sys |
| Main_MiSTer (Linux side) | https://github.com/MiSTer-devel/Main_MiSTer |
| Main_MiSTer user_io.cpp (CONF_STR parsing, image mounting) | https://raw.githubusercontent.com/MiSTer-devel/Main_MiSTer/master/user_io.cpp |
| Main_MiSTer per-core support/ helpers | https://github.com/MiSTer-devel/Main_MiSTer/tree/master/support |
| Wiki: core configuration string | https://github.com/MiSTer-devel/Wiki_MiSTer/wiki/Core-configuration-string |

## Case-study cores

| What | URL |
|---|---|
| PDP2011 MiSTer (current) | https://github.com/MiSTer-Enhanced/PDP2011_MiSTer |
| PDP2011 emu wrapper (CONF_STR, sd_card wiring) | https://raw.githubusercontent.com/MiSTer-Enhanced/PDP2011_MiSTer/main/pdp2011.sv |
| PDP2011 rk11.vhd (controller -> blocks) | https://raw.githubusercontent.com/MiSTer-Enhanced/PDP2011_MiSTer/main/rtl/rk11.vhd |
| PDP2011 sdspi.vhd (SPI block driver) | https://raw.githubusercontent.com/MiSTer-Enhanced/PDP2011_MiSTer/main/rtl/sdspi.vhd |
| PDP2011 mister_top.vhd (SDRAM ctrl, console mux) | https://raw.githubusercontent.com/MiSTer-Enhanced/PDP2011_MiSTer/main/rtl/mister_top.vhd |
| PDP2011 original port | https://github.com/birdybro/PDP2011_MiSTer |
| PDP2011 upstream project (non-MiSTer) | https://pdp2011.sytse.net/ |
| ao486 (DDR3 as main memory) | https://github.com/MiSTer-devel/ao486_MiSTer |
| ao486 emu wrapper (DDRAM usage) | https://raw.githubusercontent.com/MiSTer-devel/ao486_MiSTer/master/ao486.sv |

## Toolchain

| What | URL |
|---|---|
| Docker image source (raetro) | https://github.com/raetro/sdk-docker-fpga |
| Docker Hub: raetro/quartus (tag 17.0 = v17.0.2.602, ~6 GB) | https://hub.docker.com/r/raetro/quartus |
| Alternative docker wrapper | https://github.com/JupSys/quartus-mister |
| Quartus Lite 17.0.2 Linux tar (~8.2 GiB, verified live) | https://downloads.intel.com/akdlm/software/acdsinst/17.0std.2/602/ib_tar/Quartus-lite-17.0.2.602-linux.tar |
| Quartus-on-Linux setup guide (no license for Lite) | https://fisherxue.github.io/QuartusModelSimSetupLinux/ |
| libpng12 fix for modern Ubuntu | https://www.linuxuprising.com/2018/05/fix-libpng12-0-missing-in-ubuntu-1804.html |

## Deploy / control / debug

| What | URL |
|---|---|
| MiSTer_Batch_Control (mbc, scripted control on the MiSTer) | https://github.com/pocomane/MiSTer_Batch_Control |
| scp-deploy example writeup | https://gabriellawrence.com/posts/MiSTerVGA/index.html |
| SignalTap-on-MiSTer guide (403s bots; open in a browser) | https://misterfpga.org/viewtopic.php?t=621 |
| Verilator harness for MiSTer cores | https://github.com/JimmyStones/Verilator_Template |

## Learning / community

| What | URL |
|---|---|
| alanswx tutorials (lessons, DDRAM/SDRAM demos, Verilator example) | https://github.com/alanswx/Tutorials_MiSTer |
| pram0d core-dev series part 1 | https://pram0d.com/2022/07/26/fpga-core-development-series-part-1/ |
| Forum | https://misterfpga.org/ |
| Forum dev section ("Development for MiSTer") | https://misterfpga.org/viewforum.php?f=28 |
| Official Discord invite | https://discord.com/invite/misterfpga/ |

## Failed / do-not-cite URLs (tried 2026-07-08)

- `https://mister-devel.github.io/MkDocs_MiSTer/developer/compiling/` — 404 (use `/developer/mistercompile/`)
- `https://github.com/MiSTer-devel/Main_MiSTer/wiki/USB-Blaster-(debugging)` — GitHub wiki fails to render for fetchers; same content is on the official debugging docs page
- `https://fpgasoftware.intel.com/17.0/?edition=lite` — Intel download center retired (redirects to 404); use the direct downloads.intel.com tar above
- Intel support/software-kit pages (`intel.com/content/...`) — 403 bot-blocked
- `https://wiki.archlinux.org/title/Intel_Quartus_Prime` — anti-bot challenge
- `raw.githubusercontent.com/.../Template_MiSTer/master/sys/ddram.sv` — 404 (no such file; DDR bridging lives in `sys_top.v`/`ddr_svc.sv`/`sysmem.sv`)

Unverified (search-snippet only — fetch before trusting): pram0d part 2, MiSTer
Retro Wolf YouTube series, projectf.io tutorials, forum threads t=2515 and t=242,
alanswx per-core Verilator repos, Zaparoo docs.
