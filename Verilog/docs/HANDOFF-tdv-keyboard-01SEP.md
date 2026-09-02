# HANDOFF: TDV2200 keyboard + box-drawing, 01-SEP-2026

Real-hardware debugging session on the deployed Nexys 4 DDR (33.3 MHz, cache ON,
TDV2200 default terminal). Everything below is measured on the actual board via
new debug taps, not simulation, unless marked otherwise. Committed as part of
`f6e2982` (bundled into another concurrent session's commit by a git-index
collision - see "Known process problem" at the end - content verified intact).

## Status summary

| Item | Status | Evidence |
|---|---|---|
| Box-drawing lines (PED) | **Fixed, NOT yet visually confirmed on screen** | Root cause found and fixed (SS2), flashed, but session ended before user confirmed the actual screen |
| Up arrow | **Fixed** | Keyboard sends bare, non-E0-prefixed 0x75; added as a second table entry |
| Down arrow | **Fixed** | Same pattern, bare 0x72 |
| Right arrow | Already worked | Sends standard E0 74 |
| Left arrow | **Hardware fault, not fixable in firmware** | This keyboard's dedicated Left key AND its numpad equivalent both send 0x66 (Backspace's own scancode, not Left's 0x6B) - two different physical keys, byte-identical output |
| FUNC key | **Fixed** | Windows/GUI key (E0 1F) added as a second entry point to the same FUNK marker F10 sends |
| PageUp/PageDown | Already correct | Verified against RetroTerm's `TDV2200KeyRegistry.cs` directly - do NOT swap, see below |
| Insert | Scancode confirmed correct (E0 70), function unconfirmed | No visible indicator observed either way |
| Control panel LEDs (RED/GREEN CPU lamps) | **RESOLVED 01-SEP-2026 (build 24): GREEN lights** | The wiring verified here WAS correct - a concurrent session had removed the `~` inversions in `nd120_nexys4ddr_top.v`, so this item was observing that broken build. Inversions restored; see below |

## Root cause: box-drawing was never NDSS6 - it's SS2

The original implementation (session-early, committed as `3389975`) made `ESC 6`
(bare-digit NDSS6 designation) select a "Box" font page, based on a
31-AUG-2026 SCONF capture. That was real, but **SCONF and PED do not use the
same mechanism.**

A sticky debug latch (`dbg_saw_esc6` in `terminal_ctrl_tdv.v`, wired to `sw[4]`
on the Nexys 7-seg debug view) proved `ESC 6` is **never sent** during a full,
freshly-booted PED session on real hardware. Reading RetroTerm's actual source
(`E:\Dev\Ronny\RetroTerm\src\RetroTerm.Core\Terminal\Emulators\TDV\TDVEmulatorBase.cs`)
explained why: **G2 is hardwired to `GraphicsI` (the box-drawing table)
PERMANENTLY** - there is no G2 designation escape at all. PED reaches it with
**SS2 (`ESC N`)**, which single-shifts only the very next character through
whatever G2 currently is. This matches a live protocol trace captured earlier
in the session: repeated `ESC N <char>` pairs, one per graphics cell.

Independent confirmation: NDInsight's
`Developer/Workflow/VTM-TERMINAL-INTERFACES.md` (citing the real
PLANC-SCREEN-H library docs) says PED's `frame` primitive "paints the graphic
set (`lqqq...k` down the sides and corners)" - i.e. it prints VT100-alphabet
letters as DATA while a graphics shift is active, exactly matching SS2 +
GraphicsI, not a persistent G0 mode change.

**Fix** (`terminal_ctrl_tdv.v`): added `s_ss2_armed`, a single-shot flag set on
`ESC N` and cleared the instant `put_char` consumes it - true single-shift
semantics, one character only. Font page changed from 3 (TDV Box, built for
the now-confirmed-unused NDSS6 path) to 2 (DEC Special Graphics, already
proven correct on the VT100 side) in `terminal_top.v`'s `GFX_PAGE` parameter -
the cell format has only one graphics-attribute bit, so it can only point at
one page, and SS2/page-2 is the one actually used. NDSS6/`ESC 6` stays
implemented (harmless, in case some other program does send it) but no longer
drives page 3.

**Regression tests** added to `terminal_ctrl_tdv_tb.v`: SS2 sets the graphics
bit on exactly the one shifted character, and the bit clears after - both
pass. Full RTL discipline was followed (real evidence before the fix, tests
proving it, not a guess), but **the actual screen has not been visually
confirmed post-flash** - this is the single most important thing to check
first in any follow-up session.

## Keyboard: bare vs. E0-prefixed scancodes

This specific physical keyboard does not send the standard PS/2 Set-2
E0-prefixed codes for its dedicated arrow-cluster keys. Measured directly via
a new raw-scancode debug tap (`sw[5]`, with a 4-bit sequence counter so a
stale reading can't be mistaken for a live one):

| Key | Expected (E0-prefixed) | Actually sent | Fix |
|---|---|---|---|
| Up | E0 75 | bare 0x75 | Added bare 0x75 as a second table entry -> FS |
| Down | E0 72 | bare 0x72 | Added bare 0x72 as a second table entry -> VT |
| Right | E0 74 | E0 74 (correct) | none needed |
| Left | E0 6B | **0x66** (= Backspace's own code, not even Left's bare form) | **Not fixable** - see below |

Both additions are purely additive (the bare codes had no table entry before,
so this cannot regress anything) - see `ps2_ascii_table_tdv.v`.

**Left arrow: RESOLVED 02-SEP-2026, and it was NOT a keyboard fault.** The
earlier "both keys give 0x66" reading was a **6B-vs-66 misread on the 7-seg**
(`6` has a top bar, `b` does not). Re-measured on the raw-scancode tap and
A/B'd against Backspace: the Left key gives bare **`0x6B`**, DISTINCT from
Backspace's `0x66`. The real cause is the Nexys 4 DDR's onboard USB-to-PS/2
bridge, which DROPS THE E0 PREFIX for Up, Down AND Left (Right keeps it) - a
documented Digilent quirk (forum.digilent.com topic 16515), reproduced on
multiple keyboards against Digilent's own demo. The keyboard is fine; a PC
reading it directly sees proper extended keys. Fix: add bare `0x6B` -> BS (TDV
Left) to the MAIN table in `ps2_ascii_table_tdv.v`, exactly as Up (0x75) and
Down (0x72) already were. Purely additive, no conflict with Backspace.

## Debug infrastructure added (nd120_nexys4ddr_top.v)

All on the existing 7-segment debug display, selected by switches (documented
in the file's own header comment above `seg_value`):

- **`sw[4]`** - box-charset debug: `{14'b0, dbg_box_mode, dbg_saw_esc6}`.
  bit0 = ESC 6 ever received since power-on (sticky), bit1 = box mode
  currently active. `0000` = NDSS6 never sent (this is what PED showed).
- **`sw[5]`** - raw PS/2 scancode debug: `{seq[3:0], 2'b0, extended, release,
  code_data[7:0]}`. `seq` increments on every keyboard event - if it does NOT
  move when a key is pressed, that key sent nothing at all.
- **`sw[6]`** - decoded keyboard byte debug: `{seq2[3:0], 4'b0,
  ascii_data[7:0]}` - the byte/marker `ps2_keyboard_tdv` hands to
  `key_tdv2200.v`, i.e. AFTER the scancode table, not the raw scancode.
  E.g. F1 should read `00B2` (marker `0x80|50`).
- `sw[15:14]`, `sw[0]` - pre-existing debug views (FDISK counters, CSA/LA),
  unchanged.

These taps are cheap (a few LUTs/FFs each) and were the difference between
guessing and knowing on every bug in this session - keep them in for any
future TDV protocol work rather than removing them as "debug clutter."

## Open items

1. **Box-drawing: root-caused and fixed 01-SEP-2026 late evening (build
   26).** The mechanism was right all along (SS2 = `ESC N`, one per cell,
   confirmed on a live serial trace). Two wrong turns, both measured on the
   Nexys:
   - Build 24/early: SS2 pointed at the DEC page (page 2) -> PED's frames
     rendered as DIAMONDS (set 2's horizontal line is `0x60`, which is the
     diamond on the DEC page).
   - Build 25: SS2 given its OWN font page (page 4) plus a second cell bit
     (bit 13) -> the fifth page pushed the font ROM past a block-RAM
     boundary and **Vivado dropped it, aliasing page 4 onto page 0**, so PED
     came out as backticks (`0x60`) and the odd `e` (`0x65`). Proven from
     the build log: build 24 and 25 have identical BRAM counts (RAMB18 43,
     RAMB36 70), so the ROM never grew. The RTL and both testbenches were
     correct; the bug was synthesis-only, invisible in Verilator.
   - **Fix (build 26):** on a real TDV2200 the `ESC 6` Box set and the SS2
     G2 set are the SAME character set 2 (RetroCore maps both to bank 2), so
     they share ONE font page (page 3) and ONE cell bit (bit 12, the
     build-24 structure that synthesised cleanly). The ROM stays at four
     pages / 8192 bytes. Page 3 holds the real set 2 from RetroCore's
     `FontTDV2200.cs` (`Terminals/font/tdv2200_set2_from_retrocore.py`).
     `terminal_ctrl_tdv_tb` (36 checks) and `text_screen_tb` (frame 5, the
     graphics page) both pass. Visual confirmation of build 26 is the open
     item. **Rule learned: do not split Box and SS2 onto separate font pages
     without checking the BRAM report shows the ROM actually grew.**
2. **Test a second keyboard** to confirm the Left-arrow fault is
   keyboard-specific (matrix/wiring fault) and not something about this
   board's PS/2 receiver. If a second keyboard also shows `0x66` for Left,
   the fault is on the board side and needs new investigation - check for a
   USB-to-PS/2 adapter in the signal path first.
3. **CPU board RED/GREEN lamps - RESOLVED 01-SEP-2026.** GREEN lights
   correctly on build 24. The wiring inspected for this item was right; what
   was wrong was that a concurrent session had REMOVED the `~` inversions on
   `panel_cpu_red`/`panel_cpu_green` in `nd120_nexys4ddr_top.v`, on the theory
   that the IOC register comments ("red LED ON1", "green LED on1") meant the
   lamps were active-high. They are ACTIVE LOW, which the MiSTer port had
   already MEASURED on 31-AUG ("passing them straight through showed every
   lamp backwards", `fpga/mister/nd120.sv:511-518`) - and GREEN worked there
   throughout. No live capture of the `COMM,SIOC` write was needed after all;
   the machine had been writing the bit correctly all along. Both
   `nd120_nexys4ddr_top.v` and `IO_REG_41.v` now carry the measurement and a
   warning not to drop the inversions again without a fresh measurement that
   contradicts MiSTer's.

4. **QSPI burn - see `HANDOFF-nexys-01SEP.md`:** the "cannot set write
   enable bit" failure did NOT recur; `restore_qspi.tcl` erased, programmed
   and verified with the full part name `s25fl128sxxxxxx0-spi-x1_x2_x4`.
   The wildcard `s25fl128*` was the whole problem (it picks the S25FL128L).
5. **Insert key - CONFIRMED 01-SEP-2026 evening on build 24:** pressing
   Insert in PED toggled the status line from "Expand" to blank, which is
   the INNS/EXPS mode change. Up, Down and Right arrows confirmed working
   on the same session; Left still sends 0x66 (keyboard fault, item 2).

## Known process problem this session (for whoever reads this next)

Another concurrent Claude session was actively editing the SAME shared
working tree (`E:\Dev\Repos\Ronny\nd-120`) throughout. At one point their
`git commit` swept up this session's staged files into their own commit
(`f6e2982`, "banner: stamp the git hash...") because we share one git index -
content was verified intact afterward, but the commit message and authorship
don't describe these keyboard/TDV changes at all. A separate `restore_qspi.tcl`
process (also not this session) was found actively erasing/reprogramming the
board's physical QSPI flash mid-session. **If multiple sessions are working
this repo at once, do not assume a clean git index or an idle board** - check
`git status` and running `vivado.exe`/JTAG processes (with real command-line
verification, never kill-by-name) before any commit or hardware operation.
