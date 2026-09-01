#!/usr/bin/env python3
"""Convert the repo's WCS microcode images to Quartus MIF files.

Full path: Verilog/fpga/mister/tools/wcs_hex_to_mif.py

WHY THIS EXISTS (31-AUG-2026, MiSTer build 2)
---------------------------------------------
Code/Microcode/wcs/wcs_*.hex are $readmemh images: one hex nibble per line,
4096 lines = one 4Kx4 IDT6168A_20 WCS chip. Vivado (Nexys) and Gowin (Tang)
read them directly through the `initial $readmemh(INIT_FILE, ...)` preload
inside IDT6168A_20.v, which is how SKIP_WCS_LOAD bakes microcode into the
bitstream on those boards.

Quartus cannot use that path here: its RAM inference refused the plain
Verilog WCS array, so this board instantiates altsyncram explicitly, and
altsyncram takes its contents from an `init_file` parameter that accepts a
.mif (or Intel HEX) - NOT a $readmemh nibble list. So the same images get
converted to MIF, once, at build time.

Output name is "<input>.mif" (e.g. wcs_16C.hex.mif) on purpose: the Verilog
side derives it as {INIT_FILE, ".mif"} from the INIT_FILE parameter that
CPU_CS_WCS_21_22.v already passes, so no shared file needed changing to add
a second per-chip parameter.
"""

import sys
import pathlib

WIDTH = 4       # bits per word - IDT6168A_20 is 4 bits wide
DEPTH = 4096    # words per chip


def convert(src: pathlib.Path, dst: pathlib.Path) -> int:
    words = []
    for lineno, raw in enumerate(src.read_text().splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("//"):
            continue
        # Tolerate an inline comment after the value, same as $readmemh does.
        token = line.split("//")[0].strip()
        if not token:
            continue
        try:
            value = int(token, 16)
        except ValueError:
            raise SystemExit(f"{src}:{lineno}: not a hex value: {raw!r}")
        if not 0 <= value < (1 << WIDTH):
            raise SystemExit(f"{src}:{lineno}: value {value:#x} does not fit {WIDTH} bits")
        words.append(value)

    if len(words) != DEPTH:
        raise SystemExit(f"{src}: expected {DEPTH} words, found {len(words)}")

    out = [
        f"-- Generated from {src.name} by wcs_hex_to_mif.py - do not edit.",
        f"DEPTH = {DEPTH};",
        f"WIDTH = {WIDTH};",
        "ADDRESS_RADIX = HEX;",
        "DATA_RADIX = HEX;",
        "CONTENT",
        "BEGIN",
    ]
    out += [f"    {addr:X} : {value:X};" for addr, value in enumerate(words)]
    out.append("END;")
    dst.write_text("\n".join(out) + "\n")
    return len(words)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: wcs_hex_to_mif.py <src-dir-with-wcs_*.hex> <dst-dir>")

    src_dir = pathlib.Path(sys.argv[1])
    dst_dir = pathlib.Path(sys.argv[2])
    dst_dir.mkdir(parents=True, exist_ok=True)

    # wcs_image.hex is the whole-store image, not a per-chip one - the 32
    # per-chip files are what the IDT6168A_20 instances name.
    sources = sorted(p for p in src_dir.glob("wcs_*.hex") if p.name != "wcs_image.hex")
    if len(sources) != 32:
        raise SystemExit(f"expected 32 per-chip WCS images in {src_dir}, found {len(sources)}")

    for src in sources:
        convert(src, dst_dir / (src.name + ".mif"))

    print(f"WCS preload: {len(sources)} images converted to MIF in {dst_dir}")


if __name__ == "__main__":
    main()
