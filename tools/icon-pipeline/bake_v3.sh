#!/bin/bash
# Bake all 12 widget animations from meteocons v3 FILL Lottie -> animated WebP.
# Pipeline: pad comp -> render_frames.py (full-colour PNGs, proportional fps select)
# -> magick assemble animated WebP (centre-crop zoom, transparent). WebP avoids
# GIF's 256-colour dithering ("boil" in motion) and is ~half the size.
V=3.0.0-next.10
FPS=25            # playback frame rate (20 and 30 fall on even integer steps of the
                 # 60 fps source; 25 needs proportional frame selection — see below)
PY=/tmp/v3venv/bin/python
CONV=/tmp/v3venv/bin/lottie_convert.py
OUT=/tmp/v3anim
mkdir -p "$OUT" /tmp/v3lottie

# our animated filename : meteocons v3 icon name
map="
clear:clear-day
clear-night:clear-night
partly-cloudy-day:partly-cloudy-day
partly-cloudy-night:partly-cloudy-night
clouds:overcast
overcast-night:overcast-night
rain-day:partly-cloudy-day-rain
rain-night:partly-cloudy-night-rain
snow-day:partly-cloudy-day-snow
snow-night:partly-cloudy-night-snow
sleet-day:partly-cloudy-day-sleet
sleet-night:partly-cloudy-night-sleet
thunderstorms:thunderstorms-day
overcast-snow:overcast-snow
"
# NOTE: fog (fog-day.webp / fog-night.webp) is NOT baked here — Meteocons' Lottie fog
# hides the sun/moon behind dense haze. It's custom-built from the FILL SVG by
# animate_fog.py, reproducing Meteocons' SMIL (day: rays rotate; night: moon rocks;
# both: haze lines drift). Run: animate_fog.py <fill-stripped.svg> fog-day|fog-night <out> 150

for pair in $map; do
  ours=${pair%%:*}; theirs=${pair##*:}
  # NOTE: animations use the FILL (gradient) Lottie, not flat. The flat icons'
  # solid single-colour back-cloud gets dropped by Qt's GIF decoder (QMovie/
  # AnimatedImage) — the gradient back-cloud's multi-colour fill survives. The
  # static SVGs stay flat (they render fine through QtSvg). See DEVELOPMENT.md.
  json=/tmp/v3lottie/$theirs.json
  curl -sL -o "$json" "https://cdn.meteocons.com/$V/lottie/fill/$theirs.json"
  fr=$($PY -c "import json;print(json.load(open('$json'))['fr'])")
  op=$($PY -c "import json;print(int(json.load(open('$json'))['op']))")
  # Meteocons content (back-clouds) overhangs the 128 comp; enlarge the comp so the
  # renderer does not clip it. Uniform pad keeps the set consistently sized.
  $PY "$(dirname "$0")/pad_lottie.py" "$json" "$OUT/pad_$ours.json" 14 >/dev/null 2>&1
  # Render FULL-COLOUR frames straight from the Lottie (NO 256-colour GIF
  # intermediate → no dithering/"boil" in motion, smooth gradients). render_frames.py
  # scales to 232px (= 160·1.45; the zoom is the native-res crop below, never a raster
  # upscale) and picks N frames PROPORTIONALLY across the loop for arbitrary fps:
  #   N = loop_seconds × FPS = (op/fr)·FPS ;  delay = 100/FPS cs.
  # 25 fps over the 6 s loop = 150 frames @ delay 4cs (20/30 land on even integer
  # steps; 25 needs proportional selection — a fine size/smoothness midpoint).
  target=$($PY -c "print(round($op/$fr*$FPS))")
  delay=$($PY -c "print(max(2,round(100/$FPS)))")
  rm -rf "$OUT/fr_$ours"; mkdir -p "$OUT/fr_$ours"
  # no-crop icons render straight at 160 (full glyph, no zoom); others at 232 then
  # centre-crop to 160 for the 1.45× zoom.
  if [[ "$no_crop" == *" $ours "* ]]; then rw=160; else rw=232; fi
  $PY "$(dirname "$0")/render_frames.py" "$OUT/pad_$ours.json" "$OUT/fr_$ours" $rw "$target" >/dev/null 2>&1
  # Assemble an animated WebP: full colour + alpha, ~half the GIF size, and Qt's
  # AnimatedImage plays it (the pack shipped a .webp originally). Centre-CROP 232→160
  # for the 1.45× zoom (no upscale; Meteocons art fills only ~51% of its box, so this
  # makes it fill the box like the old pack). Keep transparency (-background none),
  # lossy q82 for smooth gradients. Content max ~142px, inside 160 → no clipping.
  # no-crop icons are already 160 → -extent is a harmless no-op for them.
  magick -delay $delay -loop 0 "$OUT/fr_$ours"/f_*.png \
    -background none -gravity center -extent 160x160 -quality 82 "$OUT/$ours.webp" 2>/dev/null
  rm -rf "$OUT/fr_$ours" "$OUT/pad_$ours.json"
  printf "%-22s <- %-26s %8s B  %3s frames  delay=%scs\n" \
    "$ours.webp" "$theirs" "$(wc -c < "$OUT/$ours.webp")" \
    "$(magick identify "$OUT/$ours.webp" | wc -l)" "$delay"
done
echo "ALL DONE — total:"
du -sh "$OUT"
