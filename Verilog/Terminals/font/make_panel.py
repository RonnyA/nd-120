#!/usr/bin/env python3
"""Generate rtl/term_panel_rom.v - the STATIC text of the ND-120 operator panel.

The panel is 80 columns x 5 rows of the same 8x16 font the console uses, which
is not a coincidence: 80 columns of 8 pixels is 640, and 640 is exactly the
width of the console's own character grid. Drawing the panel with the console's
character generator instead of a bespoke renderer is what makes it cheap.

WHAT IS IN HERE AND WHAT IS NOT. This file holds only the parts that never
change: the silkscreen labels, the octal ACTIVE LEVEL ruler, the captions. Every
cell that shows a VALUE is left as 0x00, and term_panel.v fills those in from
the machine's signals. So the layout is editable here, in one place, without
touching RTL - and there is no second copy of the geometry to drift.

Layout follows the photographed folio panel
(Pictures/ronny/20230618_193546.jpg) and the octal ruler close-up
(active-levels.png):

  row 0   UTILIZATION   CACHE HIT RATE   PROTECT RING  INTERRUPT  PAGING
  row 1   [bargraph]    [bargraph]            [n]         ON/OFF   ON/OFF
  row 2   UP:hh:mm:ss              [16 level cells, 2 columns each]
  row 3                            [octal ruler, alternating triplets]
  row 4                                 CURRENT LEVEL

Run:  python3 font/make_panel.py
from Verilog/Terminals/. Re-run and commit the result after editing LAYOUT.
"""

import os

COLS = 80
ROWS = 5

# Column origins. Kept as named constants because term_panel.v needs the same
# numbers - they are printed into the generated file as localparams so the RTL
# cannot disagree with the ROM.
COL_UTIL_LABEL   = 1
COL_UTIL_BAR     = 1
UTIL_BAR_W       = 11

COL_HIT_LABEL    = 14
COL_HIT_BAR      = 14
HIT_BAR_W        = 10

COL_RING_LABEL   = 30
COL_RING_VALUE   = 35

COL_INT_LABEL    = 43
COL_INT_VALUE    = 43

COL_PAGE_LABEL   = 53
COL_PAGE_VALUE   = 53

COL_UPTIME_LABEL = 1          # "UP:"
COL_UPTIME_VALUE = 4          # hh:mm:ss, 8 cells

COL_LEVELS       = 24         # 16 cells, 2 columns each -> 24..55
LEVEL_CELL_W     = 2

COL_LEGEND       = 62         # RUNNING / OPCOM, driven by the RUN line

DYNAMIC = 0x00                # "term_panel.v fills this cell in"


def blank_grid():
    return [[0x20] * COLS for _ in range(ROWS)]


def put(grid, row, col, text):
    for i, ch in enumerate(text):
        if col + i < COLS:
            grid[row][col + i] = ord(ch)


def put_dynamic(grid, row, col, count):
    for i in range(count):
        if col + i < COLS:
            grid[row][col + i] = DYNAMIC


def build():
    g = blank_grid()

    # --- row 0: the silkscreen labels, exactly as printed on the fascia -----
    put(g, 0, COL_UTIL_LABEL, "UTILIZATION")
    put(g, 0, COL_HIT_LABEL,  "CACHE HIT RATE")
    put(g, 0, COL_RING_LABEL, "PROTECT RING")
    put(g, 0, COL_INT_LABEL,  "INTERRUPT")
    put(g, 0, COL_PAGE_LABEL, "PAGING")

    # --- row 1: the values under them --------------------------------------
    put_dynamic(g, 1, COL_UTIL_BAR, UTIL_BAR_W)
    put_dynamic(g, 1, COL_HIT_BAR,  HIT_BAR_W)
    put_dynamic(g, 1, COL_RING_VALUE, 1)
    put_dynamic(g, 1, COL_INT_VALUE, 3)     # "ON " or "OFF"
    put_dynamic(g, 1, COL_PAGE_VALUE, 3)

    # --- row 2: uptime, and the level cells ---------------------------------
    #
    # UP: not DAY:/TIME:. The real panel's clock is a battery-backed MM58274 on
    # standby power; we have no panel processor and no calendar, so this counts
    # from reset and says so. Labelling uptime as a date would be a lie that
    # looks exactly like the truth.
    put(g, 2, COL_UPTIME_LABEL, "UP:")
    put_dynamic(g, 2, COL_UPTIME_VALUE, 8)          # hh:mm:ss
    put_dynamic(g, 2, COL_LEVELS, 16 * LEVEL_CELL_W)

    # --- row 3: the octal ruler ---------------------------------------------
    #
    # Level 15 down to 0, right to left, two columns each - matching the
    # photograph. The alternating triplets {14,13,12} {8,7,6} {2,1,0} are
    # REVERSED OUT on the real fascia (dark digits on a light block); term_panel
    # renders that by inverting those cells, so the ROM just holds the digits.
    for lvl in range(16):
        col = COL_LEVELS + (15 - lvl) * LEVEL_CELL_W
        put(g, 3, col, "%2d" % lvl)

    # --- row 4: the caption --------------------------------------------------
    #
    # ACTIVE LEVEL, matching the real fascia - Ronny checked his own panel,
    # 28-AUG-2026, and that is what is silkscreened on it.
    #
    # Worth knowing what we can and cannot put under it: the real display lights
    # every level that is active at once, fed from the microprogram in PANC
    # packets. All the RTL exposes is PIL, the level running now, so one cell
    # lights rather than several. The level shown IS active - the display is
    # incomplete, not wrong - and the afterglow keeps brief visits readable.
    caption = "ACTIVE LEVEL"
    centre = COL_LEVELS + (16 * LEVEL_CELL_W - len(caption)) // 2
    put(g, 4, centre, caption)

    # --- the RUN legend, right-hand side ------------------------------------
    put_dynamic(g, 1, COL_LEGEND, 7)     # "RUNNING" or blank
    put_dynamic(g, 2, COL_LEGEND, 7)     # "OPCOM  " or blank

    return g


HEADER = '''//============================================================================
//! Static text of the ND-120 operator panel - GENERATED FILE, DO NOT EDIT.
//!
//! Regenerate with:  python3 font/make_panel.py   (from Verilog/Terminals/)
//! Edit the layout in that script, not here.
//!
//! Part of the board-independent terminal core (Verilog/Terminals/).
//!
//! Holds ONLY what never changes - the silkscreen labels, the octal ruler and
//! the caption. Every cell that shows a value reads 0x00 here, and term_panel.v
//! substitutes the live character. So the geometry exists once, and the RTL and
//! the ROM cannot disagree about where a field sits.
//!
//! Layout and legends are taken from the photographed folio panel, not from
//! memory: Pictures/ronny/20230618_193546.jpg for the fascia and LCD, and
//! active-levels.png for the octal ruler.
//============================================================================

`default_nettype none

module term_panel_rom (
    input  wire [8:0] addr,   //! row * 80 + column
    output reg  [7:0] data
);

  //! Column origins, exported so term_panel.v uses the SAME numbers the ROM
  //! was built with. Changing a column means re-running make_panel.py, which
  //! rewrites both halves together.
'''

FOOTER = '''      default: data = 8'h20;   // space
    endcase
  end

endmodule

`default_nettype wire
'''


def main():
    g = build()
    out = [HEADER]

    for name, value in [
        ("COL_UTIL_BAR", COL_UTIL_BAR), ("UTIL_BAR_W", UTIL_BAR_W),
        ("COL_HIT_BAR", COL_HIT_BAR), ("HIT_BAR_W", HIT_BAR_W),
        ("COL_RING_VALUE", COL_RING_VALUE),
        ("COL_INT_VALUE", COL_INT_VALUE), ("COL_PAGE_VALUE", COL_PAGE_VALUE),
        ("COL_UPTIME_VALUE", COL_UPTIME_VALUE),
        ("COL_LEVELS", COL_LEVELS), ("LEVEL_CELL_W", LEVEL_CELL_W),
        ("COL_LEGEND", COL_LEGEND),
        ("PANEL_COLS", COLS), ("PANEL_ROWS", ROWS),
    ]:
        out.append("  localparam integer %-18s = %d;\n" % (name, value))

    out.append("\n  always @(*) begin\n    case (addr)\n")
    for r in range(ROWS):
        for c in range(COLS):
            ch = g[r][c]
            if ch == 0x20:
                continue          # the default branch covers spaces
            addr = r * COLS + c
            if ch == DYNAMIC:
                note = "dynamic"
            elif 0x21 <= ch <= 0x7E:
                note = chr(ch)
            else:
                note = "0x%02X" % ch
            out.append("      9'd%-3d: data = 8'h%02X;  // r%d c%-2d %s\n"
                       % (addr, ch, r, c, note))
    out.append(FOOTER)

    path = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                         "..", "rtl", "term_panel_rom.v"))
    with open(path, "w", newline="\n") as f:
        f.write("".join(out))

    static = sum(1 for r in range(ROWS) for c in range(COLS)
                 if g[r][c] not in (0x20, DYNAMIC))
    dyn = sum(1 for r in range(ROWS) for c in range(COLS) if g[r][c] == DYNAMIC)
    print("wrote %s" % path)
    print("  %d x %d cells: %d static characters, %d dynamic"
          % (COLS, ROWS, static, dyn))


if __name__ == "__main__":
    main()
