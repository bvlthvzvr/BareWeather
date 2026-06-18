#!/usr/bin/env python3
# Meteocons Lottie content (back-clouds) extends past the 128 comp bound, so
# python-lottie clips it. Enlarge the comp by `pad` on every side and shift the
# content (wrapped via to_precomp) to keep it centered, so nothing is clipped.
import sys, json
from lottie.objects import Animation

inp, outp = sys.argv[1], sys.argv[2]
pad = int(sys.argv[3]) if len(sys.argv) > 3 else 22

anim = Animation.load(json.load(open(inp)))
anim.to_precomp()                      # wrap all content in layers[0]
anim.width += 2 * pad
anim.height += 2 * pad
pos = anim.layers[0].transform.position
if getattr(pos, "animated", False) and pos.keyframes:
    for kf in pos.keyframes:
        for v in (kf.start, kf.end):
            if v is not None:
                v[0] += pad; v[1] += pad
else:
    pos.value[0] += pad; pos.value[1] += pad
json.dump(anim.to_dict(), open(outp, "w"))
print("padded %s -> comp %dx%d" % (inp.split("/")[-1], anim.width, anim.height))
