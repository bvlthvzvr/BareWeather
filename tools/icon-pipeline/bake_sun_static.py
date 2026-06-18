#!/usr/bin/env python3
# Bake the horizon occlusion into the meteocons sunrise/sunset STATIC icons.
# QtSvg renders neither <mask> nor <clipPath>, and it DROPS masked groups entirely
# (the sun vanishes — verified with qtsvg_render.py), so the meteocons "rising/
# setting sun behind the horizon" can't survive as-is. We clip the sun CORE to the
# horizon mask region with QPainterPath and emit the result as a plain filled path;
# the rays are kept verbatim (QtSvg handles their arcs) minus the three that sit
# below the horizon, and the horizon stroke is kept as drawn. Output is a clean,
# QtSvg-renderable flat SVG that reproduces the meteocons look.
#
#   python3 bake_sun_static.py sunrise out.svg
#   python3 bake_sun_static.py sunset  out.svg
import sys
from PyQt6.QtGui import QPainterPath
from PyQt6.QtCore import QRectF

which, out = sys.argv[1], sys.argv[2]

def serialize(p):
    d, i, n = [], 0, p.elementCount()
    while i < n:
        e = p.elementAt(i)
        if e.isMoveTo():
            d.append("M%.3f %.3f" % (e.x, e.y)); i += 1
        elif e.isLineTo():
            d.append("L%.3f %.3f" % (e.x, e.y)); i += 1
        elif e.isCurveTo():
            c2 = p.elementAt(i + 1); ep = p.elementAt(i + 2)
            d.append("C%.3f %.3f %.3f %.3f %.3f %.3f" % (e.x, e.y, c2.x, c2.y, ep.x, ep.y))
            i += 3
        else:
            i += 1
    return " ".join(d) + " Z"

# the 5 rays that sit above the horizon (up, NE, E, W, NW); the SE/S/SW rays are
# below the cut and dropped — identical set for both rise and set.
RAYS = ('M61 37a3 3 0 1 1 6 0v14a3 3 0 0 1-6 0z'
        'M93.699 48.059a3 3 0 1 1 4.242 4.243l-9.9 9.899a3 3 0 1 1-4.242-4.243z'
        'M109 79a3 3 0 1 1 0 6H95a3 3 0 1 1 0-6z'
        'M33 79a3 3 0 1 1 0 6H19a3 3 0 0 1 0-6z'
        'M44.201 57.958a3 3 0 1 1-4.243 4.243l-9.9-9.9a3 3 0 1 1 4.243-4.242z')

# Horizon strokes and clip polygons transcribed from the meteocons masks. The clip
# is the visible region ABOVE the horizon; the tiny 3–6px corner arcs are squared to
# straight segments (negligible at icon scale, and the horizon stroke covers them).
if which == "sunrise":
    horizon = ('<path stroke="#ffffff" stroke-linecap="round" stroke-width="4" '
               'd="M37 92h16.746a6 6 0 0 0 3.95-1.484l4.329-3.787a3 3 0 0 1 3.95 0'
               'l4.328 3.787A6 6 0 0 0 74.254 92H91"/>')
    clip_pts = [(0, 0), (128, 0), (128, 86), (75.05, 86),
                (67.75, 81), (60.25, 81), (52.95, 86), (0, 86)]   # notch UP at centre
else:  # sunset
    horizon = ('<path stroke="#ffffff" stroke-linecap="round" stroke-width="4" '
               'd="M37 91.986h16.746a6 6 0 0 1 3.95 1.485l4.329 3.787a3 3 0 0 0 3.95 0'
               'l4.328-3.787a6 6 0 0 1 3.951-1.485H91"/>')
    clip_pts = [(0, 0), (128, 0), (128, 86), (73.22, 86),
                (69.3, 87.45), (64, 92), (58.69, 87.45), (54.78, 86), (0, 86)]  # dip DOWN

clip = QPainterPath()
clip.moveTo(*clip_pts[0])
for pt in clip_pts[1:]:
    clip.lineTo(*pt)
clip.closeSubpath()

core = QPainterPath()
core.addEllipse(QRectF(64 - 19.5, 82 - 19.5, 39, 39))
core = core.intersected(clip)

gid = which + "__g"
svg = ('<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 128 128">'
       + horizon
       + '<path fill="url(#%s)" d="%s"/>' % (gid, serialize(core))
       + '<path fill="#f8af18" d="%s"/>' % RAYS
       + '<defs><linearGradient id="%s" x1="64" x2="64" y1="62" y2="102" '
         'gradientUnits="userSpaceOnUse">'
         '<stop stop-color="#fbbf24"/><stop offset="1" stop-color="#f8af18"/>'
         '</linearGradient></defs>' % gid
       + '</svg>')
open(out, "w").write(svg)
print("wrote", out)
