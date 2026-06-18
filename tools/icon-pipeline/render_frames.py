#!/usr/bin/env python3
# Render full-colour PNG frames from a (padded) Lottie — bypasses lottie_convert's
# 256-colour GIF intermediate, so an animated WebP made from these keeps smooth
# gradients (no dithering). Proportional frame selection for arbitrary fps.
import sys, json, os
from lottie.objects import Animation
from lottie.exporters.cairo import export_png

inp, outdir, width, n = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
anim = Animation.load(json.load(open(inp)))
anim.scale(width, width)            # scale content+comp so frames render at `width` px
op = int(anim.out_point)            # last frame index (loop point)
os.makedirs(outdir, exist_ok=True)
for k in range(n):
    fr = int(k * op / n)            # proportional selection across the loop
    export_png(anim, os.path.join(outdir, "f_%04d.png" % k), frame=fr)
print("rendered %d frames at %dpx (op=%d)" % (n, width, op))
