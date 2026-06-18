# Animated hero assets

These animated **WebP** files are baked from **Meteocons by Bas Milius** (MIT) —
the **Lottie**, **fill (gradient)** style, v3.0.0-next.10, fetched from
`https://cdn.meteocons.com/{version}/lottie/fill/{icon}.json`.
See `../basmilius/LICENSE` and `../basmilius/ATTRIBUTION.md`.

The animations use the **fill/gradient** Lottie even though the static icons
(`../basmilius/`) are **flat** — the gradient reads richer in motion, and it sized
the same. (For users with animations on, the popup hero/cards show these; the flat
statics only appear with animations off, and the panel icon is a flat silhouette.)

## Why WebP (not GIF)
Qt's `AnimatedImage` can't play Lottie/SMIL, so each Lottie is baked to a raster
animation. **WebP, not GIF**, because:
- **8-bit alpha → smooth silhouette.** GIF has only 1-bit transparency, so icon
  edges are hard/jagged and *shimmer* as they animate — very visible at the big
  hero size. WebP's full alpha gives clean anti-aliased edges.
- **Full colour → no dithering.** GIF's 256-colour palette dithers gradients,
  which "boils" in motion. WebP keeps the smooth gradients.
- **Smaller** (~2.8 MB total vs ~3.6 MB for the equivalent GIFs).

## Pipeline (see `../../../tools/icon-pipeline/bake_v3.sh`)
`render_frames.py` (python-lottie `export_png`) renders **full-colour** PNG frames
straight from the padded Lottie at **232 px** (no 256-colour GIF intermediate),
selecting frames **proportionally** for the target fps. `magick` then centre-crops
to **160 px** (a 1.45× zoom at native res — Meteocons art only fills ~51% of its
box, so this fills it like the old pack without upscaling) and assembles an animated
WebP (`-background none` for transparency, lossy q82). Output: **160 px, 150 frames,
25 fps** (delay 4cs), seamless 6 s loop. ~2.8 MB total.

## widget filename → Meteocons v3 Lottie

| file | meteocons v3 |
|---|---|
| clear.webp | clear-day |
| starry-night.webp | **pre-v3 legacy asset** (moon + 3 stars) — Meteocons v3 has no `starry-night`, so clear night keeps the old animation; restored by preference over the plainer v3 moon. 360 px / 60 frames (the rest of the set is 160 px / 150). |
| partly-cloudy-day.webp | partly-cloudy-day |
| partly-cloudy-night.webp | partly-cloudy-night |
| clouds.webp | overcast (plain, no sun) |
| overcast-night.webp | overcast-night |
| rain-day.webp | partly-cloudy-day-rain |
| rain-night.webp | partly-cloudy-night-rain |
| snow-day.webp | partly-cloudy-day-snow |
| snow-night.webp | partly-cloudy-night-snow |
| sleet-day.webp | partly-cloudy-day-sleet (freezing drizzle/rain — WMO 56/57/66/67) |
| sleet-night.webp | partly-cloudy-night-sleet |
| fog-day.webp | fog-day (WMO 45/48) — **custom-built**, not from the Lottie. Meteocons' Lottie fog hides the sun behind dense haze, so we render the **fill SVG** per frame via `tools/icon-pipeline/animate_fog.py`, reproducing its SMIL: sun rays rotate 360°/loop, the two haze lines drift. Keeps the full gradient sun visible. |
| fog-night.webp | fog-night — same, with the moon rocking ±6° instead of rotating rays. |
| thunderstorms.webp | thunderstorms-day (used for day & night) |
| overcast-snow.webp | overcast-snow (daytime overcast snow; night keeps snow-night) |
