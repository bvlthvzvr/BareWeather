#!/usr/bin/env python3
"""Build bare-weather.plasmoid — a clean, installable package.

A .plasmoid is just a zip of the widget package. We ship ONLY what the widget
needs at runtime — metadata.json, contents/, LICENSE — and leave out everything
else (git, dev tooling, translation sources, local notes, editor/QML caches).

Usage:  python3 tools/build-plasmoid.py
Output: ./bare-weather.plasmoid  (in the repo root)
"""

import os
import zipfile

# Run from the repo root regardless of where we're invoked from.
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(REPO)

OUT = "bare-weather.plasmoid"
INCLUDE = ["metadata.json", "LICENSE", "contents"]   # the only runtime essentials
SKIP_SUFFIX = (".qmlc", ".jsc", "~", ".swp", ".bak")  # editor / QML-cache cruft
SKIP_NAME = {".directory", ".DS_Store"}               # OS junk

if os.path.exists(OUT):
    os.remove(OUT)


def add(zf, path):
    if os.path.isdir(path):
        for root, _dirs, files in os.walk(path):
            for f in sorted(files):
                if f in SKIP_NAME or f.endswith(SKIP_SUFFIX):
                    continue
                full = os.path.join(root, f)
                zf.write(full, full)
    else:
        zf.write(path, path)


with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as zf:
    for p in INCLUDE:
        add(zf, p)

size = os.path.getsize(OUT)
count = len(zipfile.ZipFile(OUT).namelist())
print(f"Built {OUT}  ({count} files, {size/1024:.0f} KiB)")
