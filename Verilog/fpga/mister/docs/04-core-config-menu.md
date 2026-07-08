# Phase 3 — Core Configuration: CONF_STR, hps_io, the OSD Menu

Goal: understand exactly how the F12 menu is defined and how its selections reach
your logic. Punchline up front: **the menu is a string constant in your Verilog.
There is no Linux-side code to write.** Confirmed from both the official docs
(https://mister-devel.github.io/MkDocs_MiSTer/developer/conf_str/) and Main_MiSTer
source (`user_io.cpp` reads the string from the FPGA via `user_io_read_confstr()`
and `parse_config()` builds the whole menu from it —
https://github.com/MiSTer-devel/Main_MiSTer).

All links verified 2026-07-08.

## 1. How it plugs together

In your `emu` module (from Template.sv, verbatim shape):

```verilog
localparam CONF_STR = { ... the menu ... };

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
    .clk_sys(clk_sys),
    .HPS_BUS(HPS_BUS),
    .buttons(buttons),
    .status(status),           // OSD selections land here
    .status_menumask({...}),   // dynamic show/hide of entries
    .ps2_key(ps2_key),
    ...
);
```

- `hps_io.sv` lives in `sys/` (source:
  https://raw.githubusercontent.com/MiSTer-devel/Template_MiSTer/master/sys/hps_io.sv).
  Key parameters: `VDNUM` (number of virtual disk drives, 1-10), `WIDE` (16-bit vs
  8-bit file I/O), `BLKSZ` (block size code: 0=128 bytes ... 2=512 default ... 7=16384).
- The ARM reads CONF_STR byte-by-byte over `HPS_BUS` at core load; the OSD renders it.
- Official hps_io overview:
  https://mister-devel.github.io/MkDocs_MiSTer/developer/hps_io/

## 2. CONF_STR syntax (validated against the official wiki + live cores)

References: https://mister-devel.github.io/MkDocs_MiSTer/developer/conf_str/ and
https://github.com/MiSTer-devel/Wiki_MiSTer/wiki/Core-configuration-string

- `"<CoreName>;<options>;"` — header. Extras can ride in the header, e.g. PDP2011
  uses `"PDP2011;UART19200;"` — the `UART<speed>` token enables the framework UART
  menu/bridge (that's how we get OPCOM to a real terminal).
- `-;` — separator line.
- `O[hi:lo],Name,opt0,opt1,...` — option mapped to `status[hi:lo]`. 128 status bits
  exist (`status[127:0]` port); **bit 0 is reserved for reset by convention**.
- `T[i],Name;` — momentary trigger, pulses `status[i]` (e.g. `T[0],Reset;`).
- `R[i],Name;` — same, but closes the OSD.
- `S<slot>,<EXT1><EXT2>...,Label;` — **mount a disk image** into virtual-drive slot
  0-3. Extensions are 3 chars each, concatenated: `S0,DSKIMGVHD,Mount Drive;`.
  Mounting drives the `img_mounted/img_size` + `sd_*` block interface
  ([05-devices-block-char.md](05-devices-block-char.md)).
- `F[S]<index>,<EXT>,Label[,Address];` — **load a file** streamed into the core via
  the ioctl interface; `ioctl_index` tells you which F-entry sent it. `FS` = savable.
- `P<n>,Title;` + `P<n>O[...]...` — submenu pages.
- `H<n>`/`h<n>` hide and `D<n>`/`d<n>` disable entries based on
  `status_menumask[n]` (uppercase = when mask bit set, lowercase = when clear).
- `J[1],...` / `jn,`/`jp,` — joystick button definitions (not needed for ND-120).
- `V,v` + `` `BUILD_DATE `` — version string shown next to the core name.
- `I,...` info lines; `SS<base>:<size>` savestates (future exotica).

## 3. A real, complete example — PDP2011's menu (verbatim from its emu file)

Source: https://raw.githubusercontent.com/MiSTer-Enhanced/PDP2011_MiSTer/main/pdp2011.sv

```verilog
localparam CONF_STR = {
    "PDP2011;UART19200;",
    "-;",
    "S0,DSKIMG,Mount RK disk;",
    "S1,DSKIMG,Mount RL disk;",
    "S2,DSKIMG,Mount RM/RP (RH) disk;",
    "-;",
    "O[7:5],PDP-11 Model,20,34,44,45,70,94;",
    "-;",
    "O[2],Console,Virtual VT100,Serial 19200 baud;",
    "-;",
    "P1,Virtual VT100;",
    "P1O[9:8],Color,Green,Blue,White,Amber;",
    ...
    "T[0],Reset;",
    "R[0],Reset and close OSD;",
    "V,v",`BUILD_DATE
};
```

(abridged; full string in the source file). Note the pattern: S-slots for disks,
O-bits for machine configuration, a P1 page for terminal cosmetics, T/R reset.

## 4. Draft ND-120 CONF_STR

A starting point (adjust as the core grows) — **[our design, not validated
anywhere yet]**:

```verilog
localparam CONF_STR = {
    "ND120;UART9600:19200;",
    "-;",
    "F1,HEXBIN,Load WCS microcode;",       // ioctl -> WCS load path
    "S0,IMGDSK,Mount floppy;",             // block dev, drive 0
    "S1,IMGVHD,Mount SMD disk;",           // block dev, drive 1
    "-;",
    "O[2:1],ALD boot source,Floppy,SMD,OPCOM;",
    "O[3],CPU speed,Original,Fast;",
    "-;",
    "T[0],Master Clear;",
    "R[0],Master Clear and close OSD;",
    "V,v",`BUILD_DATE
};
```

Wiring notes:

- `status[0]` (T/R) OR the framework `RESET` input → MCL (Master Clear).
- `status[2:1]` → ALD switch equivalents (today's DIP/board constants).
- The `F1` entry arrives as an ioctl stream with `ioctl_index==1`; parse and write
  it into the WCS RAM while holding the CPU in reset
  ([05-devices-block-char.md](05-devices-block-char.md) §3 has the signal list).
- `hps_io` instance then needs `.VDNUM(2)` and the sd_* / img_* / ioctl_* ports
  connected.
- `status_menumask` can hide the SMD entry until that controller exists.

## 5. The status word, both directions

- `status[127:0]` — OSD selections → core.
- `status_in[127:0]` + `status_set` — core → OSD (e.g. reflect a mode the machine
  changed itself).
- `status_menumask[15:0]` — drives the `H/h/D/d` visibility rules.

## 6. When WOULD Linux-side code be needed?

Main_MiSTer has a `support/` directory of per-core helpers (x86/ao486 IDE, minimig,
CD-image formats like CHD/CUE, etc.), activated by core-name checks in
`user_io.cpp`. That exists only for cores needing host-side smarts — image-format
parsing or complex device config
(https://github.com/MiSTer-devel/Main_MiSTer/tree/master/support). A minicomputer
core with **raw disk images does not need any of it** — plain images are served by
the generic vhd path. If we ever want the Linux side to understand SINTRAN volume
formats or e.g. expose files as ND floppy images on the fly, THAT would be a
`support/nd120/` contribution to Main_MiSTer — strictly optional, much later.

## Phase 3 exit criteria

- [ ] F12 shows the ND-120 menu with Master Clear, options, and (greyed) mount slots.
- [ ] `status` bits observable in the core (route one to LED_USER to prove it).
- [ ] WCS microcode loads via the F1 entry and the machine boots identically to the
      baked-in-hex build.
