#!/usr/bin/env python3
"""Markdown dead-link checker - a test-suite gate.

Resolves every RELATIVE link target in every git-tracked *.md file and
reports the ones that point at nothing. Motivation (28-AUG-2026): the
README linked DEVELOPMENT.md/HARDWARE.md at the repo root for five months
while the files sat under tmp/ - a session then "proved" they never
existed and the false fact survived two compactions. A path mismatch
caught at commit time costs seconds; discovered later it costs campaigns.

Checked:  [text](relative/path), [text](relative/path#anchor)
Ignored:  http(s)/mailto links, pure #anchors, links inside fenced code
          blocks, image data URIs, <autolinks>.
Verdict:  TB_RESULT: PASS / a per-file list and TB_RESULT: FAIL n dead links
Exit:     0 on pass, 1 otherwise.
"""
import os, re, subprocess, sys
from urllib.parse import unquote

ROOT = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                      capture_output=True, text=True).stdout.strip()
files = subprocess.run(["git", "ls-files", "*.md"], cwd=ROOT,
                       capture_output=True, text=True).stdout.splitlines()

LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
dead = []
for rel in files:
    path = os.path.join(ROOT, rel)
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError as e:
        dead.append((rel, "(unreadable: %s)" % e)); continue
    # strip fenced code blocks so shell/verilog examples are not parsed
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    base = os.path.dirname(path)
    for m in LINK.finditer(text):
        tgt = m.group(1)
        if tgt.startswith(("http://", "https://", "mailto:", "#", "data:")):
            continue
        tgt = unquote(tgt.split("#", 1)[0])
        if not tgt:
            continue
        cand = os.path.normpath(os.path.join(base, tgt))
        if not os.path.exists(cand):
            dead.append((rel, m.group(1)))

if dead:
    for rel, tgt in dead:
        print("dead link: %s -> %s" % (rel, tgt))
    print("TB_RESULT: FAIL %d dead links" % len(dead))
    sys.exit(1)
print("TB_RESULT: PASS (%d markdown files, all relative links resolve)" % len(files))
