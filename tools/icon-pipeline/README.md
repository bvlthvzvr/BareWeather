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
/tmp/v3venv/bin/pip install lottie cairosvg pillow   # GIF export needs cairosvg
# system: imagemagick (magick), librsvg (rsvg-convert), and PyQt6 for verification
```

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
