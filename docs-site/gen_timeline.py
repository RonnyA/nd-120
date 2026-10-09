#!/usr/bin/env python3
"""Draw the milestone timeline shown at the top of HISTORY.md.

Edit MILESTONES below, then run:  python3 docs-site/gen_timeline.py
Writes HISTORY-timeline.svg in the repository root.
"""
import os

# (date, line 1, line 2, year)
MILESTONES = [
    ("MAR 2023", "Design documents", "received", "2023"),
    ("DEC 2023", "Drawn in Logisim,", "Verilog generated", "2023"),
    ("APR 2024", "Whole board compiles", "in Verilator", "2024"),
    ("DEC 2024", "Microcode runs,", "OPCOM answers", "2024"),
    ("MAR 2025", "ND bus devices", "from C++", "2025"),
    ("NOV 2025", "First FPGA", "synthesis (Basys3)", "2025"),
    ("JUL 2026", "First CPU boot", "on FPGA silicon", "2026"),
    ("AUG 2026", "SINTRAN III boots", "Tang + Nexys", "2026"),
    ("SEP 2026", "SINTRAN III on MiSTer", "MEGA65 cores built", "2026"),
]

# (fill, stroke) per year, from the WCAG 2.1 AA palette; repeats if more years are added
PALETTE = [
    ("#E3F2FD", "#0D47A1"),  # blue
    ("#E0F7FA", "#00838F"),  # teal
    ("#F3E5F5", "#7B1FA2"),  # purple
    ("#E8F5E9", "#2E7D32"),  # green
    ("#FFF3E0", "#E65100"),  # orange
    ("#E0F2F1", "#00695C"),  # dark teal
]

TITLE = "ND-120 recreation, 2023-2026"
X0, DX = 110, 132      # first milestone x, spacing
AXIS_Y = 220
BOX_W, BOX_H = 156, 64
TEXT = "#1A1A1A"


def build():
    years = []
    for m in MILESTONES:
        if m[3] not in years:
            years.append(m[3])
    width = X0 * 2 + DX * (len(MILESTONES) - 1)
    height = 440
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
        f'font-family="Segoe UI, Helvetica, Arial, sans-serif">',
        f'<rect width="{width}" height="{height}" fill="#FFFFFF"/>',
        f'<text x="40" y="44" font-size="22" font-weight="700" fill="{TEXT}">{TITLE}</text>',
    ]

    # one coloured axis segment and one label per year
    for yi, year in enumerate(years):
        stroke = PALETTE[yi % len(PALETTE)][1]
        xs = [X0 + i * DX for i, m in enumerate(MILESTONES) if m[3] == year]
        a, b = xs[0] - 50, xs[-1] + 50
        out.append(f'<rect x="{a}" y="{AXIS_Y - 7}" width="{b - a}" height="14" rx="7" fill="{stroke}"/>')
        out.append(f'<text x="{(xs[0] + xs[-1]) / 2}" y="{height - 24}" font-size="16" '
                   f'font-weight="700" fill="{stroke}" text-anchor="middle">{year}</text>')

    # milestones alternate above and below the axis
    for i, (date, line1, line2, year) in enumerate(MILESTONES):
        fill, stroke = PALETTE[years.index(year) % len(PALETTE)]
        x = X0 + i * DX
        up = i % 2 == 0
        cy = AXIS_Y - 95 if up else AXIS_Y + 95
        stem_end = cy + 30 if up else cy - 30
        out.append(f'<line x1="{x}" y1="{AXIS_Y}" x2="{x}" y2="{stem_end}" stroke="{stroke}" stroke-width="2"/>')
        out.append(f'<circle cx="{x}" cy="{AXIS_Y}" r="9" fill="#FFFFFF" stroke="{stroke}" stroke-width="3"/>')
        out.append(f'<rect x="{x - BOX_W / 2}" y="{cy - BOX_H / 2}" width="{BOX_W}" height="{BOX_H}" '
                   f'rx="10" fill="{fill}" stroke="{stroke}" stroke-width="2"/>')
        out.append(f'<text x="{x}" y="{cy - 12}" font-size="12" font-weight="700" fill="{stroke}" '
                   f'text-anchor="middle" letter-spacing="1">{date}</text>')
        out.append(f'<text x="{x}" y="{cy + 6}" font-size="13" fill="{TEXT}" text-anchor="middle">{line1}</text>')
        out.append(f'<text x="{x}" y="{cy + 22}" font-size="13" fill="{TEXT}" text-anchor="middle">{line2}</text>')

    out.append('</svg>')
    return "\n".join(out) + "\n"


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    path = os.path.join(root, "HISTORY-timeline.svg")
    with open(path, "w", newline="\n") as f:
        f.write(build())
    print("wrote", os.path.relpath(path, root))


if __name__ == "__main__":
    main()
