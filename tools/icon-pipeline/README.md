# Icon pipeline — Meteocons v3 → this widget's pack

Reproducible steps to (re)generate the bundled icon pack from Meteocons.
**No build step ships with the plasmoid** — this is a one-off authoring tool.

## Why each step exists
- **The widget renders static SVGs through QtSvg** (`Kirigami.Icon`), which
  **ignores `<mask>`**. Meteocons hides the sun/moon/back-cloud behind the front
  cloud with masks, so a raw copy renders with **suns/moons missing** and fog as
  bare lines. `strip_masks.py` removes the masks (the opaque cloud on top already
  occludes what the mask hid → same picture, QtSvg-safe).
- **`AnimatedImage` can't play Lottie/SMIL** → animations are baked to GIF.
- The panel/tray uses a **white silhouette** → `flatten_white.py`.

## Prerequisites
```fish
python3 -m venv /tmp/v3venv
/tmp/v3venv/bin/pip install lottie==0.7.1 cairosvg setuptools pillow
# system: imagemagick (magick), librsvg (rsvg-convert), and PyQt6 for verification
```
⚠️ **Version pins matter — the recipe is fragile across lottie releases + new Python:**
- **`lottie==0.7.1`** — the two pipeline scripts need APIs from *different* eras:
  `render_frames.py` imports `lottie.exporters.cairo.export_png` (**removed in 0.7.2**)
  and `pad_lottie.py` calls `anim.to_precomp()` (**absent in ≤0.6.x**). 0.7.1 is the
  only version with both. If a frame render emits 0 frames or `pad_lottie` throws
  `AttributeError: to_precomp`, you're on the wrong version.
- **`cairosvg`** is what actually rasterizes — python-lottie's PNG path is gated on
  `lottie.exporters.cairo.has_cairo`, which is **only true when `cairosvg` imports**.
  `pycairo` alone does **not** satisfy it (`export_png` won't even import).
- **`setuptools`** — Python 3.12+ removed `distutils`, which older `lottie` imports
  (`ModuleNotFoundError: No module named 'distutils'`); setuptools restores it.

### Adjusting raindrop / streak length (sleet, rain)
Each precip streak is a 2-vertex vertical line in the Lottie (`"v": [[x,88],[x,91]]`
= length 3) and in the static SVG (`d="M52 88v3"`). To lengthen, extend the bottom
point downward — keep the top at y=88 so it still hangs from the cloud. Sleet drops
were taken to **11** (`v11`) so sleet reads distinctly from snow (flakes, no streak).
Edit BOTH the baked webp (re-run the Lottie through `bake_v3.sh`) AND the static SVGs
(`wi-*-sleet.svg`, both packs, all sizes) or the two will disagree when animation is off.

## Steps
1. **Static color** — fetch flat `svg-static`, strip masks, drop into
   `contents/icons/basmilius/{16,22,24,32}/wi-<stem>.svg` (one SVG copied to all
   four sizes; SVGs are scalable, the dirs just satisfy Plasma's size lookup).
   ```fish
   python3 strip_masks.py in.svg out.svg
   ```
2. **Static white** — `python3 flatten_white.py color.svg white.svg` →
   `contents/icons/basmilius-white/...`.
3. **Animations** — `bash bake_v3.sh` (fetches flat Lottie, renders, decimates to
   ~90 frames, optimizes) → `contents/icons/animated/*.gif`.
4. **VERIFY with the real renderer**, not rsvg/magick (they support masks; QtSvg
   does not, so they lie):
   ```fish
   QT_QPA_PLATFORM=offscreen python3 qtsvg_render.py out.svg check.png 96   # static
   QT_QPA_PLATFORM=offscreen python3 qmovie_render.py out.gif check.png 30  # animated, frame 30
   ```
   `qtsvg_render.py` uses PyQt6's `QSvgRenderer` (= the widget's QtSvg);
   `qmovie_render.py` uses `QMovie` (= what `AnimatedImage` uses). `magick` lies for
   both: it supports SVG masks and composites optimized GIF frames that Qt does not.

## Stem ↔ Meteocons name maps
See `contents/icons/basmilius/ATTRIBUTION.md` (static) and
`contents/icons/animated/ATTRIBUTION.md` (animated).
