# Debugging a MiSTer Core (when it fails on the board)

The discipline is the one this repo already practices for Basys3: Verilator is the
reference, the board is the suspect, and you instrument until they disagree at a
specific signal. What changes is the toolbox: SignalTap instead of Vivado ILA, JTAG
instead of the Digilent cable. All links verified 2026-07-08.

## 0. The ladder — cheapest signal first

1. LEDs (free, always works)
2. UART debug bytes (near-free)
3. Linux-side console / Main_MiSTer log (free, host view)
4. Verilator with MiSTer stubs (host machine, full visibility)
5. SignalTap (full on-chip visibility, costs a recompile)

## 1. LEDs

`emu` outputs (Template.sv + official emu docs
https://mister-devel.github.io/MkDocs_MiSTer/developer/emu/):

- `LED_USER` — 1 = on. Template's default blinks it from an activity counter.
- `LED_POWER[1:0]`, `LED_DISK[1:0]` — bit 1 = 1 gives the core sole control of that
  system LED (drive `2'b00` to leave it to the OS).

Same tricks as the Basys3 bring-up: heartbeat divider proves the PLL; a stuck-state
flag on LED_USER proves/disproves "the CPU is wedged before microcode word N".

## 2. UART debug

Two independent serial paths (see [05-devices-block-char.md](05-devices-block-char.md) §4):

- **Framework UART** (`UART_TXD` etc.) — routed to the Linux side; what the ARM does
  with it is configured from the OSD (CONF_STR `UART<speeds>` token). Fine for
  OPCOM; awkward as a *debug* channel while OPCOM uses it.
- **User port** `USER_OUT[6:0]` — raw pins on the I/O-board user port; hang a
  USB-serial adapter on it for a dedicated debug UART that bypasses Linux entirely.
  Open-drain: set the bit to 1 to read the corresponding USER_IN.

## 3. The MiSTer's own Linux console

ssh in (`root`/`1`, https://mister-devel.github.io/MkDocs_MiSTer/advanced/network/)
or attach HDMI+keyboard console. Main_MiSTer prints its activity (including every
`MiSTer_cmd` it receives) to the console — useful for "did my core even load",
"did the image mount", "is the ARM servicing sd_rd". The official USB-Blaster page
explicitly advises having a console attached when JTAG-loading cores (the ARM side
reboots after a JTAG upload).

## 4. Verilator with MiSTer framework stubs

**JimmyStones/Verilator_Template** (validated:
https://github.com/JimmyStones/Verilator_Template, and listed on the official
developer links page): Verilator + Dear ImGui harness that stubs the MiSTer
framework — run/pause/single-step, VGA output rendered in a window, simulated
hps_io ROM upload, input injection, `$display` to an on-screen console. Pins
Verilator v4.204; recommends WSL2 for verilating.

For the ND-120 this is conceptually our `runSim/` harness with hps_io stubs added.
Practical route: keep `runSim/` as the behavioral reference and add a thin
`hps_io`-stub C++ model to it (feed ioctl microcode, answer sd_rd with pread() on
an image file) rather than adopting the ImGui harness wholesale — but steal its
hps_io stubbing approach. Also validated: https://github.com/alanswx/Tutorials_MiSTer
includes a Verilator example (`verilator/detect2600_verilator`).

Debug loop stays the one from `Verilog/sim/FPGA_DEBUG_RUNBOOK.md`: reproduce in
Verilator first; if the board diverges, instrument the exact signal on both sides.

## 5. JTAG + SignalTap (the Vivado-ILA equivalent)

### JTAG upload

Official page: https://mister-devel.github.io/MkDocs_MiSTer/developer/debugging/

- Cable into the DE10-Nano's mini-USB **next to HDMI** (on-board USB-Blaster II,
  VID:PID 09fb:6810).
- Program directly from Quartus; MiSTer detects it and reloads the Linux side
  automatically (slower start, normal).
- udev rules (`/etc/udev/rules.d/92-usbblaster.rules`):

  ```
  SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6010", MODE="666"
  SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6810", MODE="666"
  ```

- WSL2: attach with `usbipd attach` first (same VID:PID dance as the FTDI boards —
  see `Verilog/fpga/tang-nano-20k/README.md` for the workflow).

### SignalTap II

Confirmed working on a live MiSTer core — community guide "MiSTer Developer's Guide
with Quartus SignalTap II": https://misterfpga.org/viewtopic.php?t=621 (forum 403s
non-browser user agents; open in a real browser). Workflow from that guide:

1. In Quartus: File > New > Verification/Debugging Files > **SignalTap II Logic
   Analyzer File**; name the instance.
2. Pick a capture clock — the guide used `emu|CLK_50M`; for us the PLL's CPU-domain
   clock is usually the right sampling clock. Sample depth 1K to start.
3. Add **post-fitting** nodes from your hierarchy: `|sys_top|emu:emu|nd120:...` —
   i.e. you probe *through* the framework wrapper, exactly like probing through
   `ND120_TOP` with Vivado ILA.
4. Set trigger conditions; disable capture on nodes you only trigger on (saves LEs).
5. Save the `.stp`, **recompile** (the probe logic is baked in — longer compile).
6. Tools > SignalTap II; JTAG chain should show `Hardware: DE-SoC [USB-1]`,
   `Device: @2: 5CSEBA6...`; program via the SOF Manager using
   `output_files/nd120.sof`, arm the trigger, capture.

Vivado-ILA habits that map 1:1: trigger on the CSA address of interest, capture the
IDB/CD buses, diff against the Verilator VCD at the same CSA sequence (the
`vcd_extract.py` workflow from the nd120-fpga skill applies unchanged on the
Verilator side).

## 6. Failure triage cheat-sheet

| Symptom | First suspects | Tool |
|---|---|---|
| Core won't load / menu static | .rbf mismatch, bad compile | Linux console, recompile |
| Loads, no OSD menu text | CONF_STR malformed (missing `;`) | eyeball string, diff vs PDP2011's |
| No LED heartbeat | PLL not locking, wrong pll.qip in files.qip | SignalTap on pll locked, LED divider |
| OPCOM silent | UART token missing in CONF_STR, baud mismatch, reset stuck | UART loopback, LED on MCL |
| Boots differently than Verilator | the classic latch/clock-enable divergence | runbook: `Verilog/sim/FPGA_DEBUG_RUNBOOK.md` + SignalTap at the diverging CSA |
| sd_rd never acked | image not mounted (`img_size==0`), VDNUM mismatch | Linux console, LED on img_mounted |
| DDR3 hangs hard | reset handling (porting docs warn exactly this) | SignalTap on DDRAM_BUSY/handshake |

## 7. Getting help

- Forum, "Development for MiSTer": https://misterfpga.org/viewforum.php?f=28
- Official Discord: https://discord.com/invite/misterfpga/
- A Norsk Data minicomputer core will be a novelty there — expect interest.
