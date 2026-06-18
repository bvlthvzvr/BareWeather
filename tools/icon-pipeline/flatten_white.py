#!/usr/bin/env python3
# Turn a v3 flat color SVG into an all-white silhouette for the panel/tray icon,
# WITHOUT touching mask/clipPath/defs internals (those drive the geometry; recoloring
# them would break the masking). Only visible fills/strokes are forced to white.
import sys, re, xml.etree.ElementTree as ET

SVG = "{http://www.w3.org/2000/svg}"
ET.register_namespace("", "http://www.w3.org/2000/svg")
SKIP = {SVG + "mask", SVG + "defs", SVG + "clipPath", SVG + "filter", SVG + "pattern"}

tree = ET.parse(sys.argv[1])

def walk(el, in_defs):
    for ch in el:
        is_def = in_defs or (ch.tag in SKIP)
        if not is_def:
            for attr in ("fill", "stroke"):
                v = ch.get(attr)
                if v and v != "none" and not v.startswith("url"):
                    ch.set(attr, "#ffffff")
            st = ch.get("style")
            if st:
                st = re.sub(r"(fill|stroke):\s*#[0-9a-fA-F]+", r"\1:#ffffff", st)
                ch.set("style", st)
        walk(ch, is_def)

walk(tree.getroot(), False)
tree.write(sys.argv[2])
