#!/usr/bin/env python3
# Bake the fog-bank occlusion into the STATIC fog SVGs. QtSvg renders neither <mask>
# nor <clipPath>, so we clip the sun/moon geometry to y<75 with QPainterPath and emit
# the resulting outline as a plain filled path (+ the haze lines on top). Output is a
# clean QtSvg-renderable flat SVG matching the animated fog (sun/moon behind the fog).
import sys, math
from PyQt6.QtGui import QPainterPath, QTransform
from PyQt6.QtCore import QRectF

MASK_Y = 75.0
MOON_SCALE = 1.2               # the crescent has no rays, so cut at the fog bank it reads
                               # small vs the day sun — enlarge it about its centre (64,62)
which = sys.argv[1]            # "day" or "night"
out = sys.argv[2]

def serialize(p):
    d = []
    i = 0
    n = p.elementCount()
    while i < n:
        e = p.elementAt(i)
        if e.isMoveTo():
            d.append("M%.3f %.3f" % (e.x, e.y)); i += 1
        elif e.isLineTo():
            d.append("L%.3f %.3f" % (e.x, e.y)); i += 1
        elif e.isCurveTo():
            c1 = e; c2 = p.elementAt(i+1); ep = p.elementAt(i+2)
            d.append("C%.3f %.3f %.3f %.3f %.3f %.3f" % (c1.x, c1.y, c2.x, c2.y, ep.x, ep.y))
            i += 3
        else:
            i += 1
    return " ".join(d) + " Z"

clip = QPainterPath(); clip.addRect(QRectF(0, 0, 128, MASK_Y))
LINES = ('<g><path stroke="#e2e8f0" stroke-linecap="round" stroke-miterlimit="10" stroke-width="3" d="M40 81h48"/>'
         '<path stroke="#e2e8f0" stroke-linecap="round" stroke-miterlimit="10" stroke-width="3" d="M40 89h48"/></g>')

if which == "day":
    core = QPainterPath(); core.addEllipse(QRectF(64-13, 72-13, 26, 26))
    core = core.intersected(clip)
    # rays: keep only those that sit above the fog bank (up, NE, E, W, NW); drop SE,S,SW
    rays = ('M62 42a2 2 0 1 1 4 0v9.333a2 2 0 1 1-4 0z'                       # up
            'M83.799 49.373a2 2 0 1 1 2.828 2.828l-6.6 6.6a2 2 0 0 1-2.828-2.829z'  # NE
            'M94 70a2 2 0 1 1 0 4h-9.333a2 2 0 1 1 0-4z'                      # E
            'M43.333 70a2 2 0 1 1 0 4H34a2 2 0 1 1 0-4z'                      # W
            'M50.8 55.972a2 2 0 0 1-2.828 2.829l-6.6-6.6a2 2 0 1 1 2.829-2.828z')   # NW
    body = ('<path fill="#f8af18" d="%s"/><path fill="#f8af18" d="%s"/>'
            % (serialize(core), rays))
else:
    m = QPainterPath()
    m.moveTo(61.912, 40)
    m.cubicTo(50.715, 41.208, 42, 50.562, 42, 61.93)
    m.cubicTo(42, 74.118, 52.015, 84, 64.368, 84)
    m.cubicTo(74.782, 84, 83.507, 76.97, 86, 67.465)
    m.cubicTo(71.137, 69.059, 58.039, 54.757, 61.912, 40)
    m.closeSubpath()
    t = QTransform(); t.translate(64, 62); t.scale(MOON_SCALE, MOON_SCALE); t.translate(-64, -62)
    m = t.map(m)               # enlarge the moon about its centre, then cut at the fog bank
    m = m.intersected(clip)
    body = '<path fill="#72b9d5" d="%s"/>' % serialize(m)

svg = ('<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 128 128">'
       + body + LINES + '</svg>')
open(out, "w").write(svg)
print("wrote", out)
