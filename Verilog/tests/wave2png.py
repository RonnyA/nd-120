#!/usr/bin/env python3
"""
wave2png.py - render a testbench VCD into a committable PNG timing diagram.

WHY THIS EXISTS
    A Verilog testbench cannot write an image; it can only write a VCD
    ($dumpfile/$dumpvars). 61 of the 210 testbenches in this tree already do.
    This turns that VCD into a picture, so a testbench can auto-document what
    it actually exercised and the PNG can be committed next to the testbench.

WHAT IT IS NOT
    It is NOT the pass/fail record. The authoritative verdict stays the
    "TB_RESULT: PASS" line the runner greps for (tests/run_all_tests.sh).
    A PNG in git cannot be diffed meaningfully - it is documentation for a
    human, not evidence for the suite.

WHEN A PICTURE HELPS, AND WHEN IT DOES NOT
    Good:  testbenches where TIMING IS THE CONTRACT - transparency across a
           latch enable, a protocol replay with a fixed deadline, a
           clock-domain handshake. A reader sees the contract at a glance.
    Poor:  exhaustive sweeps. Shared/support/sim/TTL_74245_tb.v walks 262,144
           input combinations; a waveform of that is noise. For those, a
           truth table or a pass matrix says more - use --table.

DEPENDENCIES
    python3 + vcdvcd + Pillow. All three are already present in this
    environment; nothing needs installing and nothing is fetched.

USAGE
    wave2png.py IN.vcd OUT.png [options]

      --signals A,B,C   only these (substring match, in this order)
      --max-signals N   cap rows when no --signals given (default 16)
      --start T         start time (VCD time units)
      --end T           end time
      --title TEXT      title line drawn at the top
      --note TEXT       footer line - put the TB_RESULT verdict here
      --table           render a value table instead of a waveform
      --width N         pixel width of the wave area (default 1100)

EXAMPLE
    iverilog -g2005 -o x_tb x_tb.v ../x.v && vvp x_tb          # writes x.vcd
    python3 tests/wave2png.py x.vcd docs/waves/x.png \\
        --signals clk,ENABLE,D,Q --title "X: transparency" \\
        --note "TB_RESULT: PASS (583 checks)"

Last reviewed: 20-AUG-2026
Ronny Hansen
"""
import argparse
import os
import sys

try:
    from vcdvcd import VCDVCD
except ImportError:
    sys.exit("wave2png: needs 'vcdvcd' (python3 -m pip install vcdvcd)")
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("wave2png: needs Pillow (python3 -m pip install pillow)")

# --- palette: dark, high contrast, readable when embedded in a README -------
BG        = (24, 26, 32)
GRID      = (52, 56, 68)
GRID_MAJ  = (78, 84, 100)
LABEL     = (208, 214, 226)
TITLE     = (255, 255, 255)
NOTE_OK   = (126, 214, 146)
NOTE_BAD  = (240, 122, 122)
WAVE      = (122, 198, 255)   # 1-bit signals
BUSCOL    = (198, 168, 255)   # multi-bit buses
BUSFILL   = (58, 48, 84)
XCOL      = (240, 122, 122)   # x / z

ROW_H     = 34
WAVE_H    = 18
LABEL_W   = 190
PAD       = 16
TOP_PAD   = 54


def _font(size):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()


def load(vcd_path, want, max_signals):
    """Return [(display_name, width, [(time, value), ...]), ...]."""
    vcd = VCDVCD(vcd_path, store_tvs=True)
    names = list(vcd.references_to_ids.keys())

    if want:
        chosen = []
        for w in want:
            hit = [n for n in names if w.lower() in n.lower()]
            # prefer an exact leaf-name match when there is one
            exact = [n for n in hit if n.split(".")[-1].split("[")[0].lower() == w.lower()]
            for n in (exact or hit):
                if n not in chosen:
                    chosen.append(n)
    else:
        chosen = names[:max_signals]

    out = []
    for n in chosen:
        sig = vcd[n]
        tv = list(sig.tv)
        if not tv:
            continue
        width = getattr(sig, "size", None)
        try:
            width = int(width)
        except (TypeError, ValueError):
            width = len(str(tv[0][1])) if not str(tv[0][1]).isdigit() else 1
        leaf = n.split(".")[-1]
        out.append((leaf, width, tv))
    return out


def value_at(tv, t):
    v = None
    for tt, vv in tv:
        if tt <= t:
            v = vv
        else:
            break
    return v


def fmt(v, width):
    if v is None:
        return "?"
    s = str(v)
    if any(c in s for c in "xzXZ"):
        return s if len(s) <= 8 else "x"
    if width and width > 1:
        try:
            return f"{int(s, 2):X}"
        except ValueError:
            return s
    return s


def render_wave(sigs, args, tmin, tmax):
    w = args.width + LABEL_W + PAD * 2
    h = TOP_PAD + len(sigs) * ROW_H + 46
    img = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(img)
    f_lbl = _font(12)
    f_ttl = _font(15)
    f_val = _font(10)

    span = max(1, tmax - tmin)
    x0 = LABEL_W + PAD
    x1 = x0 + args.width

    def X(t):
        return x0 + int((t - tmin) / span * args.width)

    if args.title:
        d.text((PAD, 12), args.title, font=f_ttl, fill=TITLE)
    d.text((PAD, 32), f"{os.path.basename(args.vcd)}   t={tmin}..{tmax}",
           font=f_val, fill=(140, 148, 164))

    # vertical grid, 10 divisions
    for i in range(11):
        gx = x0 + int(i / 10 * args.width)
        d.line([(gx, TOP_PAD - 6), (gx, h - 46)],
               fill=GRID_MAJ if i % 5 == 0 else GRID)
        d.text((gx + 2, h - 44), str(tmin + int(i / 10 * span)),
               font=f_val, fill=(120, 128, 144))

    for row, (name, width, tv) in enumerate(sigs):
        y = TOP_PAD + row * ROW_H
        ymid = y + ROW_H // 2
        yhi = ymid - WAVE_H // 2
        ylo = ymid + WAVE_H // 2

        d.text((PAD, ymid - 7), name[:26], font=f_lbl, fill=LABEL)
        d.line([(x0, ymid), (x1, ymid)], fill=GRID)

        # edges inside the window, plus the value entering it
        pts = [(tmin, value_at(tv, tmin))]
        pts += [(t, v) for (t, v) in tv if tmin < t <= tmax]
        pts.append((tmax, pts[-1][1]))

        multi = width and width > 1
        for i in range(len(pts) - 1):
            t, v = pts[i]
            tn = pts[i + 1][0]
            xa, xb = X(t), X(tn)
            if xb <= xa:
                continue
            s = str(v)
            bad = any(c in s for c in "xzXZ")

            if multi:
                col = XCOL if bad else BUSCOL
                # bus shape: hexagon body
                d.polygon([(xa, ymid), (xa + 3, yhi), (xb - 3, yhi),
                           (xb, ymid), (xb - 3, ylo), (xa + 3, ylo)],
                          fill=BUSFILL, outline=col)
                label = fmt(v, width)
                if xb - xa > 8 * len(label):
                    d.text((xa + (xb - xa - 6 * len(label)) // 2, ymid - 6),
                           label, font=f_val, fill=col)
            else:
                if bad:
                    d.rectangle([xa, yhi, xb, ylo], outline=XCOL)
                    continue
                yy = yhi if s == "1" else ylo
                d.line([(xa, yy), (xb, yy)], fill=WAVE, width=2)
                if i > 0:  # transition edge
                    prev = str(pts[i - 1][1])
                    if prev in ("0", "1") and prev != s:
                        d.line([(xa, yhi), (xa, ylo)], fill=WAVE, width=2)

    if args.note:
        col = NOTE_BAD if "FAIL" in args.note.upper() else NOTE_OK
        d.text((PAD, h - 26), args.note, font=f_lbl, fill=col)
    return img


def render_table(sigs, args, tmin, tmax):
    """Value table at every transition - the right picture for sweeps."""
    times = sorted({t for _, _, tv in sigs for (t, _) in tv
                    if tmin <= t <= tmax})[: args.max_rows]
    f_lbl = _font(12)
    f_ttl = _font(15)
    colw = 104
    w = 110 + colw * len(sigs) + PAD * 2
    h = TOP_PAD + (len(times) + 1) * 22 + 46
    img = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(img)

    if args.title:
        d.text((PAD, 12), args.title, font=f_ttl, fill=TITLE)
    d.text((PAD, 32), f"{os.path.basename(args.vcd)}  {len(times)} sample(s)",
           font=_font(10), fill=(140, 148, 164))

    for c, (name, _, _) in enumerate(sigs):
        d.text((110 + c * colw, TOP_PAD), name[:14], font=f_lbl, fill=TITLE)
    d.text((PAD, TOP_PAD), "time", font=f_lbl, fill=TITLE)
    d.line([(PAD, TOP_PAD + 18), (w - PAD, TOP_PAD + 18)], fill=GRID_MAJ)

    for r, t in enumerate(times):
        y = TOP_PAD + 22 + r * 22
        d.text((PAD, y), str(t), font=f_lbl, fill=(150, 158, 174))
        for c, (_, width, tv) in enumerate(sigs):
            v = fmt(value_at(tv, t), width)
            col = XCOL if "x" in v.lower() else LABEL
            d.text((110 + c * colw, y), v, font=f_lbl, fill=col)
        d.line([(PAD, y + 19), (w - PAD, y + 19)], fill=GRID)

    if args.note:
        col = NOTE_BAD if "FAIL" in args.note.upper() else NOTE_OK
        d.text((PAD, h - 26), args.note, font=f_lbl, fill=col)
    return img


def main():
    ap = argparse.ArgumentParser(description="VCD -> PNG timing diagram")
    ap.add_argument("vcd")
    ap.add_argument("png")
    ap.add_argument("--signals")
    ap.add_argument("--max-signals", type=int, default=16)
    ap.add_argument("--max-rows", type=int, default=40)
    ap.add_argument("--start", type=int)
    ap.add_argument("--end", type=int)
    ap.add_argument("--title", default="")
    ap.add_argument("--note", default="")
    ap.add_argument("--table", action="store_true")
    ap.add_argument("--width", type=int, default=1100)
    args = ap.parse_args()

    want = [s.strip() for s in args.signals.split(",")] if args.signals else None
    sigs = load(args.vcd, want, args.max_signals)
    if not sigs:
        sys.exit("wave2png: no matching signals in " + args.vcd)

    all_t = [t for _, _, tv in sigs for (t, _) in tv]
    tmin = args.start if args.start is not None else min(all_t)
    tmax = args.end if args.end is not None else max(all_t)
    if tmax <= tmin:
        tmax = tmin + 1

    img = (render_table if args.table else render_wave)(sigs, args, tmin, tmax)
    os.makedirs(os.path.dirname(os.path.abspath(args.png)), exist_ok=True)
    img.save(args.png)
    print(f"wave2png: {args.png}  ({len(sigs)} signals, t={tmin}..{tmax})")


if __name__ == "__main__":
    main()
