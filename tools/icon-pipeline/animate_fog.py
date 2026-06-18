#!/usr/bin/env python3
# Custom fog animation reproducing Meteocons' own SMIL (which QtSvg can't play) AND
# its mask (which QtSvg can't render): the sun/moon sits behind a fog bank — a mask
# rect hides everything below y=75, so the lower rays/limb are occluded by the fog.
#   fog-day  : sun RAYS rotate 360°/loop (lower rays vanish into the fog), haze drifts
#   fog-night: MOON rocks ±6° (lower limb behind fog),                     haze drifts
# We render the mask-stripped FILL SVG in two layers per frame: the sun/moon CLIPPED
# to y<75 (reproduces the mask), then the haze lines on top. Transparent bg; magick
# then centre-crops 232→160 (1.45×) to match the rest of the set. See ATTRIBUTION.
import sys, os, math, re
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PyQt6.QtGui import QGuiApplication, QImage, QPainter
from PyQt6.QtCore import QByteArray, Qt, QRectF
from PyQt6.QtSvg import QSvgRenderer

app = QGuiApplication(sys.argv)
src, prefix, outdir, N = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
RENDER = 232
SCALE = RENDER / 128.0
MASK_Y = 75.0                       # Meteocons fog mask: hide everything below y=75
raw = re.sub(r"<animateTransform[^>]*/>", "", open(src).read())   # drop SMIL; we drive it
# sun/moon-only SVG (drop the Precipitation group — drawn separately, unclipped)
sun_base = re.sub(r'<g id="%s__Precipitation">.*?</g>' % re.escape(prefix), "", raw, flags=re.S)
os.makedirs(outdir, exist_ok=True)

def drift(u):                      # 0→3→0, ease-in-out, period 1 (≈ Meteocons line SMIL)
    return 1.5 * (1 - math.cos(2 * math.pi * (u % 1.0)))

def inject(s, idstr, xform):
    return s.replace('id="%s"' % idstr, 'id="%s" transform="%s"' % (idstr, xform))

def lines_svg(dx2, dx1):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" fill="none">'
            '<path stroke="#e2e8f0" stroke-linecap="round" stroke-width="3" transform="translate(%.3f,0)" d="M40 81h48"/>'
            '<path stroke="#e2e8f0" stroke-linecap="round" stroke-width="3" transform="translate(%.3f,0)" d="M40 89h48"/>'
            '</svg>') % (dx2, dx1)

for k in range(N):
    f = k / N
    s = sun_base
    if prefix == "fog-day":
        s = inject(s, "%s__Rays" % prefix, "rotate(%.3f 64 72)" % (360.0 * f))
    else:
        # rock ±6° AND enlarge the moon 1.2× about its centre (matches bake_fog_static.py;
        # the rayless crescent reads small cut at the fog bank)
        s = inject(s, "%s__Moon" % prefix,
                   "rotate(%.3f 63.9 62) translate(64 62) scale(1.2) translate(-64 -62)" % (6.0 * math.sin(2 * math.pi * 2 * f)))
    img = QImage(RENDER, RENDER, QImage.Format.Format_ARGB32)
    img.fill(Qt.GlobalColor.transparent)
    p = QPainter(img)
    # layer 1: sun/moon, clipped to y<75 (the fog-bank mask)
    p.save()
    p.setClipRect(QRectF(0, 0, RENDER, MASK_Y * SCALE))
    QSvgRenderer(QByteArray(s.encode())).render(p)
    p.restore()
    # layer 2: haze lines on top, unclipped
    QSvgRenderer(QByteArray(lines_svg(drift(2 * f), drift(2 * f + 0.5)).encode())).render(p)
    p.end()
    img.save("%s/f_%04d.png" % (outdir, k))
print("rendered", N, prefix)
