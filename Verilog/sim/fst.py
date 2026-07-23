#!/usr/bin/env python3
"""
fst.py — drop-in FST reader for ND-120 analysis scripts.

Usage in any script:
    from fst import open_wave
    with open_wave(path) as f:
        for line in f:
            ...

If path ends with .fst, pipes through fst2vcd transparently.
If path ends with .vcd, opens directly (backwards compat).
"""

import io
import subprocess
import sys


def open_wave(path, buffering=8*1024*1024):
    """
    Return a text-mode file-like object for a VCD or FST waveform file.
    FST files are converted on-the-fly via fst2vcd (part of gtkwave).
    """
    if path.endswith(".fst"):
        proc = subprocess.Popen(
            ["fst2vcd", path],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        return io.TextIOWrapper(
            io.BufferedReader(proc.stdout, buffer_size=buffering),
            encoding="ascii",
            errors="replace",
        )
    else:
        return open(path, "r", buffering=buffering)
