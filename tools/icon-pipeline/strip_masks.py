#!/usr/bin/env python3
# QtSvg (the widget's renderer) ignores <mask>, dropping every masked element
# (suns, moons, back-clouds). In meteocons the mask only carves out where the
# OPAQUE cloud is then drawn on top, so removing masks reproduces the same picture
# while staying QtSvg-compatible. Strips: mask="url()" attrs + <mask> defs.
import sys, xml.etree.ElementTree as ET

SVG = "{http://www.w3.org/2000/svg}"
ET.register_namespace("", "http://www.w3.org/2000/svg")
tree = ET.parse(sys.argv[1])

def clean(parent):
    for ch in list(parent):
        if ch.tag == SVG + "mask":
            parent.remove(ch)
            continue
        if "mask" in ch.attrib:
            del ch.attrib["mask"]
        clean(ch)

clean(tree.getroot())
tree.write(sys.argv[2])
