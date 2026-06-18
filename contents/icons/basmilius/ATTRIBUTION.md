# Basmilius Weather Icons

The icons in this folder are derived from **Meteocons by Bas Milius**
(https://github.com/basmilius/meteocons, https://meteocons.com), licensed under
the MIT License (see `LICENSE` in this folder).

- Source: Meteocons **v3.0.0-next.10**, **flat** style, fetched from the CDN
  (`https://cdn.meteocons.com/{version}/svg-static/flat/{icon}.svg`).
- The folder name (`basmilius`) and the `wi-*.svg` stem names are this widget's
  own convention, kept stable so the QML needs no change across icon updates.

## Processing (see `../../../tools/icon-pipeline/`)
1. **Mask-strip** (`strip_masks.py`): the v3 SVGs hide the sun/moon/back-cloud
   behind the front cloud with `<mask>`. **QtSvg — the widget's renderer — does
   not support `<mask>` and drops the masked elements entirely** (suns/moons
   vanish, fog becomes bare lines). The mask only carves out where the OPAQUE
   front cloud is drawn on top anyway, so stripping the masks reproduces the same
   picture while rendering correctly in QtSvg.
2. **White-flatten** (`flatten_white.py`, `../basmilius-white/`): forces every
   visible fill/stroke to white (skipping mask/defs/clipPath internals) for the
   panel/tray monochrome icon.
3. **Horizon-bake** (`bake_sun_static.py`, the `sunrise`/`sunset` stems only):
   those two are the **fill** (coloured) style, and their sun is clipped at the
   horizon with a `<mask>` — which QtSvg drops entirely (the sun vanishes), while
   stripping the mask leaves a FULL sun (the rise/set look lost). So the sun core
   is clipped to the horizon region with `QPainterPath.intersected()` (as the fog
   statics are), the below-horizon rays dropped, and the horizon stroke recoloured
   white. Output is flat, QtSvg-safe geometry.

The animated hero **WebP** files in `../animated/` are baked from the Meteocons
**Lottie** (fill/gradient) exports — see `../animated/ATTRIBUTION.md`.

## Icon stem → Meteocons v3 source

| widget stem | meteocons v3 | notes |
|---|---|---|
| day-sunny | clear-day | |
| night-clear | clear-night | |
| day-cloudy | partly-cloudy-day | |
| night-alt-partly-cloudy | partly-cloudy-night | |
| cloudy | **overcast** | plain (no sun) — WMO 3 is "overcast" |
| night-cloudy | overcast-night | |
| day-fog | fog-day | |
| night-fog | fog-night | |
| day-rain | partly-cloudy-day-rain | |
| night-alt-rain | partly-cloudy-night-rain | |
| day-snow | partly-cloudy-day-snow | |
| night-alt-snow | partly-cloudy-night-snow | |
| day-thunderstorm | thunderstorms-day | |
| night-alt-thunderstorm | thunderstorms-night | |
| overcast-snow | overcast-snow | sun-free; daytime overcast snow |
| sunrise | sunrise (**fill** style) | horizon occlusion baked (`bake_sun_static.py`); SimpleView sun-event marker |
| sunset | sunset (**fill** style) | horizon occlusion baked (`bake_sun_static.py`); SimpleView sun-event marker |
