/*
 * Simple (graph) representation — a compact header plus a graph over ONE
 * continuous forward timeline (from now): a smooth temperature curve with an
 * area fill, a precipitation-chance band, per-point value labels, hour icons and
 * a time axis. A sliding window (`hourPos`) pans the icons/time/markers while the
 * curve RESHAPES in fixed columns; the timeline flows across midnight with
 * correctly-dated new-day markers. Detail level (`simpleHourly`) only sets the
 * timeline density (hourly / every-2h) and window width. Free drag/scroll slides;
 * tapping a day pill cross-fades the curve to that day (`dayMorphT`). Ported from
 * the MorphCurve design (quadratic ease-in-out tween).
 * Copyright 2026  bvlthvzvr — SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: simple

    property var weatherRoot

    // animated hero for the current condition (or "" → static fallback icon).
    // Gated by the simple-layout header-animation toggle.
    readonly property string heroAnimSrc: (weatherRoot && weatherRoot.simpleHeaderAnim)
        ? weatherRoot.heroAnim(weatherRoot.weatherCode, weatherRoot.isDay, weatherRoot.cloudCover) : ""

    // `hourPos` is the left-edge position (in sample-index units) of the sliding
    // window over the continuous timeline; the columns stay fixed and the curve
    // RESHAPES in place as the window slides — see loSamples/hiSamples below.
    property real hourPos: 0
    // A day-pill click morphs the curve IN PLACE from the current shape to the
    // target day's shape (dayMorphT 0→1, columns held fixed) while the window
    // scrolls there. 1 = settled → curve follows the window.
    property real dayMorphT: 1
    property var morphFromT: []
    property var morphFromP: []
    property var morphFromS: []
    property var morphFromA: []
    property var morphToT: []
    property var morphToP: []
    property var morphToS: []
    property var morphToA: []
    property bool dragging: false
    readonly property int selectedDay: {
        if (!weatherRoot || !weatherRoot.dailyData || !samples.length) return 0;
        // the day at the START of the window (where you actually are) — using the
        // window centre rounds onto tomorrow once the 13h window crosses midnight,
        // so at 5 PM today it would wrongly highlight tomorrow's tab
        var c = Math.max(0, Math.min(samples.length - 1, Math.round(hourPos)));
        var date = samples[c].date;
        for (var d = 0; d < dayCount; ++d)
            if (weatherRoot.dailyData[d] && weatherRoot.dailyData[d].date === date) return d;
        return 0;
    }
    // The focused hour's sample (the one at the START of the window — where you
    // actually are). Drives instantaneous header metrics (humidity) so they sync
    // to the scrolled hour, the way the daily-total metrics sync to selectedDay.
    readonly property var focusedSample: {
        if (!samples.length) return null;
        var c = Math.max(0, Math.min(samples.length - 1, Math.round(hourPos)));
        return samples[c];
    }

    readonly property int pad: Math.round(Kirigami.Units.gridUnit * 0.85)
    readonly property string precipColor: "#42a5f5"
    readonly property string snowLabelColor: "#d8ecff"   // pale icy blue for snow cm labels
    readonly property string sunGold: "#ffa840"          // warm amber of the sunset glyph + its time label
    readonly property string sunRiseColor: "#f8c01c"     // sunrise gold, nudged slightly toward yellow from the glyph's #f8af18 — sunrise time label + bloom share it

    // ── Sun bloom: a soft radial glow that rises off the temp line where it
    // crosses a sunrise or sunset, clipped to the area ABOVE the curve so it
    // never spills below. Two-tone — sunrise is the gold of its icon (#f8af18,
    // #fbbf24 hot core), sunset orange.
    // Ported from a Claude-design SVG (radialGradient + clip + blurred streak)
    // to Canvas 2D: the radial is an ellipse via ctx.scale, the streak is a
    // stack of wide low-alpha strokes (Canvas has no feGaussianBlur). Colours
    // are RGB triples; alphas come from the *Alpha tunables below so "soft" can
    // be dialled in one place. core = on the line, mid = the body, streak = the
    // glow laid along the line itself.
    readonly property var sunGlow: ({
        "rise": { core: [252, 208,  46], mid: [248, 192,  28], streak: [248, 192,  28] },
        "set":  { core: [255, 205, 120], mid: [255, 145,  62], streak: [255, 154,  68] }
    })
    readonly property real sunGlowCoreA:   0.62   // brightest (on the line) — softened from the design's .97
    readonly property real sunGlowFeather: 3.5    // radial falloff exponent: alpha = coreA·exp(−feather·r²). Higher = softer, more feathered rim; lower = a fuller, more defined glow
    readonly property real sunGlowStreakA: 0.45   // peak alpha of the line streak
    readonly property real sunGlowHalfCols: 1.4   // horizontal radius of the radial bloom, in curve columns (feathering keeps a soft edge instead of wedging on a slope)
    readonly property real sunGlowRiseIcons: 1.2  // vertical reach upward, in sun-glyph heights (≤1 keeps the glow no taller than the icon)
    readonly property real sunStreakHalfCols: 2.2 // half-width of the warm streak ALONG the line, in columns — carries most of the bloom's width (always hugs the curve, never wedges)

    // ── Temperature → colour gradient: cold blue → cool teal → mild green →
    // warm amber → hot orange-red. The line and band are tinted per hour by how
    // hot it is.
    readonly property var tempRamp: [
        [0.0,  [86, 148, 213]],   // cold blue
        [0.35, [104, 188, 191]],  // cool teal
        [0.55, [134, 192, 143]],  // mild green
        [0.78, [232, 176, 74]],   // warm amber
        [1.0,  [226, 104, 63]]    // hot orange-red
    ]
    readonly property real bandAlpha: 0.38   // opacity of the gradient band fill

    // graph colouring toggle (config graphColorMode): 0 = both, 1 = temp only,
    // 2 = precip only, 3 = none. When a series is "off" it falls back to a flat
    // neutral (theme-grey) instead of its colour.
    readonly property int  colorMode:   weatherRoot ? weatherRoot.graphColorMode : 0
    readonly property bool colorTemp:   colorMode === 0 || colorMode === 1
    readonly property bool colorPrecip: colorMode === 0 || colorMode === 2

    // ── Graph data & geometry ─────────────────────────────────────────────
    // "Graph detail" setting. Both modes use the per-day morph; the difference is
    // curve density per day tile — every-2h thins to 12 points, hourly keeps all
    // 24 (with the time axis / icons thinned to every 2nd point).
    readonly property bool hourlyDetail: weatherRoot ? weatherRoot.simpleHourly : false
    // The graph is ONE continuous forward timeline (from now) for both detail
    // levels — so it flows across midnight: after tonight's 10 PM comes 12 AM with
    // a correctly-dated "new day" marker, no seam, no overlap, no missing hours.
    // The detail level only changes timeline DENSITY + window width.
    // Hourly = every hour. Every-2h = even-hour points only, folding the skipped
    // odd hour's MAX precip into each 2h cell so an odd-hour spike isn't lost.
    // Rough "how wet is this condition" rank for a WMO code, so a 2h cell can show
    // the wetter of its two hours' ICONS (rain often lands on the odd hour we skip,
    // which otherwise leaves a high chance next to a dry cloud icon).
    function precipRank(c) {
        if (c >= 95) return 5;                                        // thunderstorm
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return 4;   // snow
        if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82)) return 3;   // rain/drizzle
        if (c === 45 || c === 48) return 2;                           // fog
        if (c === 2 || c === 3) return 1;                             // cloudy
        return 0;                                                     // clear
    }
    readonly property var samples: {
        if (!weatherRoot) return [];
        var _a = weatherRoot.allHourly;
        var _d = weatherRoot.dailyData;
        var _n = weatherRoot.simpleDailyDays;
        var src = weatherRoot.allSamples(1, weatherRoot.simpleDailyDays);
        if (hourlyDetail) return src;
        // Every-2h: step by 2 FROM NOW (src[0]) so the CURRENT hour is always the
        // leading point — the old even-clock-hour filter dropped "now" whenever it fell
        // on an odd hour (and lost that hour's precip spike, since folding only looked
        // forward from even hours). Spacing stays a uniform 2 h — the sun-event x-mapping
        // and the markers rely on uniform spacing; new-day markers key on a date change
        // between samples (isDayStart), not an exact hour-0 sample. Fold the skipped
        // in-between hour's MAX precip chance / amount / snow (and its wetter code) into
        // the kept point so a spike between 2-hourly samples isn't lost.
        var out = [];
        for (var i = 0; i < src.length; i += 2) {
            var s = Object.assign({}, src[i]);
            var mid = (i + 1 < src.length) ? src[i + 1] : null;
            if (mid) {
                if (!isNaN(mid.precip)    && (isNaN(s.precip)    || mid.precip    > s.precip))    s.precip    = mid.precip;
                if (!isNaN(mid.precipAmt) && (isNaN(s.precipAmt) || mid.precipAmt > s.precipAmt)) s.precipAmt = mid.precipAmt;
                if (!isNaN(mid.snow)      && (isNaN(s.snow)      || mid.snow      > s.snow))      s.snow      = mid.snow;
                if (precipRank(mid.code) > precipRank(s.code)) s.code = mid.code;
            }
            out.push(s);
        }
        return out;
    }
    readonly property int dayCount: weatherRoot ? weatherRoot.simpleDailyDays : 0

    // Sliding window width: hourly = 13 consecutive hours; every-2h = 12 even-hour
    // points (≈ a day on screen).
    readonly property int pointsVisible: hourlyDetail ? 13 : 12
    readonly property int maxHourPos: Math.max(0, (samples ? samples.length : 0) - pointsVisible)
    function windowAt(w) {
        var o = [], n = samples.length;
        for (var i = 0; i < pointsVisible; ++i) {
            var idx = w + i;
            if (idx >= 0 && idx < n) o.push(samples[idx]);
        }
        return o;
    }
    // Sliding filmstrip (icons / time / markers PAN with the scroll, unlike the
    // curve which reshapes in fixed columns). A small FIXED pool of delegates
    // recycles: delegate `index` shows global sample `windowBase + index - 1`
    // (one off-left for buffer), positioned continuously by hourX(g). `windowBase`
    // is the INTEGER hour, so a delegate's *content* only changes once per hour
    // while its *x* slides every frame — smooth, and never rebuilt.
    readonly property int  windowBase: Math.floor(hourPos)
    readonly property int  poolSize:   pointsVisible + 3
    function hourX(g) { return (g - hourPos + 0.5) * (plotW / pointsVisible); }
    // a sample STARTS a new day when its date differs from the previous sample's.
    // Works for both hourly (midnight IS a sample) and every-2h (when "now" is odd, no
    // sample lands exactly on hour 0, so an hour-0 test would MISS the rollover and the
    // new-day divider would vanish). g <= 0 is the leading edge, never a day-start.
    function isDayStart(g) {
        return g > 0 && g < samples.length && samples[g].date !== samples[g - 1].date;
    }
    // is any new-day boundary in the visible window? — lets the marker canvas skip
    // its per-frame repaint while no new-day line is on screen
    readonly property bool windowHasMidnight: {
        var base = windowBase;
        for (var k = -1; k < poolSize; ++k)
            if (isDayStart(base + k)) return true;
        return false;
    }

    // the two window frames the position sits between + the blend. Keyed on the
    // INTEGER hour so they only re-allocate when the window actually shifts (once
    // per hour), not every drag frame — only the scalar curFrac changes per frame,
    // which is what drives the smooth in-column reshape.
    readonly property int  hourFloor: Math.floor(hourPos)
    readonly property int  hourCeil:  Math.ceil(hourPos)
    readonly property real curFrac:   hourPos - hourFloor
    readonly property var  loSamples: windowAt(hourFloor)
    readonly property var  hiSamples: windowAt(hourCeil)

    // interpolate two equal-length column arrays (drives the day-tab morph)
    function lerpArr(a, b, t) {
        var o = [], n = Math.max(a.length, b.length);
        for (var i = 0; i < n; ++i) {
            var av = i < a.length ? a[i] : 0, bv = i < b.length ? b[i] : av;
            o.push(av + (bv - av) * t);
        }
        return o;
    }

    // Curve values: the sliding-window reshape between loSamples/hiSamples (above).
    readonly property var curTemps: {
        // a day-tab click morphs the held from→to columns in place
        if (dayMorphT < 1) return lerpArr(morphFromT, morphToT, dayMorphT);
        var a = loSamples, b = hiSamples, f = curFrac, out = [];
        var n = Math.max(a.length, b.length);
        for (var i = 0; i < n; ++i) {
            var av = i < a.length ? a[i].temp : (i < b.length ? b[i].temp : 0);
            var bv = i < b.length ? b[i].temp : av;
            out.push(av + (bv - av) * f);
        }
        return out;
    }
    readonly property var curPrecip: {
        if (dayMorphT < 1) return lerpArr(morphFromP, morphToP, dayMorphT);
        var a = loSamples, b = hiSamples, f = curFrac, out = [];
        var n = Math.max(a.length, b.length);
        for (var i = 0; i < n; ++i) {
            var av = i < a.length && !isNaN(a[i].precip) ? a[i].precip : 0;
            var bv = i < b.length && !isNaN(b[i].precip) ? b[i].precip : 0;
            out.push(av + (bv - av) * f);
        }
        return out;
    }
    // Per-point "snowiness" 0..1 (blended through the morph) graded by the
    // forecast snowfall AMOUNT, so the precip band tints toward white in
    // proportion to how heavy the snow is (not a binary rain/snow flag).
    // The band is the dominant element on screen, so ANY real snow must read
    // clearly white — not just a blizzard. snowiness() rises fast from the first
    // flake (≈70% white by snowWhiteCm) and saturates by ~4×, so light all-day
    // snow no longer looks like rain-blue; heaviness still modulates within white.
    readonly property real snowWhiteCm: 0.5   // cm/hr that already reads ~70% white
    function snowiness(cm) {
        if (!(cm > 0)) return 0;
        return Math.min(1, 1 - Math.exp(-cm / (snowWhiteCm * 0.83)));
    }
    function snowCm(s) { return (s && !isNaN(s.snow)) ? Math.max(0, s.snow) : 0; }
    // curSnow carries the raw cm/hour per column (blended through the morph): the
    // band tint derives its 0..1 "snowiness" from it, and the snow labels read it.
    readonly property var curSnow: {
        if (dayMorphT < 1) return lerpArr(morphFromS, morphToS, dayMorphT);
        var a = loSamples, b = hiSamples, f = curFrac, out = [];
        var n = Math.max(a.length, b.length);
        for (var i = 0; i < n; ++i) {
            var av = i < a.length ? snowCm(a[i]) : 0;
            var bv = i < b.length ? snowCm(b[i]) : 0;
            out.push(av + (bv - av) * f);
        }
        return out;
    }
    function precipMm(s) { return (s && !isNaN(s.precipAmt)) ? Math.max(0, s.precipAmt) : 0; }
    // curPrecipAmt carries the raw mm/hour per column (blended through the morph),
    // so the amount readout above each chance label morphs in place like the others.
    readonly property var curPrecipAmt: {
        if (dayMorphT < 1) return lerpArr(morphFromA, morphToA, dayMorphT);
        var a = loSamples, b = hiSamples, f = curFrac, out = [];
        var n = Math.max(a.length, b.length);
        for (var i = 0; i < n; ++i) {
            var av = i < a.length ? precipMm(a[i]) : 0;
            var bv = i < b.length ? precipMm(b[i]) : 0;
            out.push(av + (bv - av) * f);
        }
        return out;
    }
    // ── Delayed value-label morph (temp numbers) ──────────────────────────
    // On a flick / wheel-notch the temp VALUE labels trail the curve: the number is
    // held for lblMorphDelay ms, then ticks to the new value, finishing a beat after
    // the curve settles. The label POSITION still rides the LIVE curve (curTempY), so
    // labels never detach — only the shown number lags. Inline (not a helper fn) so the
    // binding captures lblMorphT / lblMorphActive as dependencies (see the Repeater-
    // model gotcha: deps read only inside a called fn aren't tracked).
    property real lblMorphT: 1
    readonly property bool lblMorphActive: lblMorphAnim.running
    readonly property var lblTemps: {
        if (lblMorphActive) return lerpArr(morphFromT, morphToT, lblMorphT);
        return curTemps;
    }
    readonly property int lblMorphDelay: 220   // numbers hold this long before ticking
    property int lblMorphDur: 600              // then morph over this (set per gesture)
    // sunrise + sunset instants across the forecast days: {ms, rise}. Drives both
    // the warm bloom the temp line picks up at a crossing AND the glyph pinned above
    // it. Local-time ISO strings parse the same way the sample times do
    // (timezone=auto), so they share an x-axis.
    readonly property var sunMarkerModel: {
        var out = [], dd = weatherRoot ? weatherRoot.dailyData : null;
        if (!dd) return out;
        for (var i = 0; i < dd.length; ++i) {
            if (dd[i].sunrise) out.push({ ms: new Date(dd[i].sunrise).getTime(), rise: true });
            if (dd[i].sunset)  out.push({ ms: new Date(dd[i].sunset).getTime(),  rise: false });
        }
        return out;
    }
    // curve-space x for a time instant, matching sunBloomPeaks's mapping so a glyph
    // sits exactly over the bloom: fractional sample index gFrac=(t−s0)/step, then
    // column (gFrac − hourPos) → screen x. NaN until the sample grid exists.
    // sample-grid origin + step (ms), cached per data load — xAtTime / sunMarkerLift /
    // sunBloomPeaks read these instead of re-parsing two Date strings on every call
    // (each runs per sun marker per frame during a drag). Spacing is uniform (1 h / 2 h).
    readonly property real sampleT0Ms:   (samples && samples.length)     ? new Date(samples[0].time).getTime() : NaN
    readonly property real sampleStepMs: (samples && samples.length > 1)
        ? (new Date(samples[1].time).getTime() - sampleT0Ms) : NaN
    function xAtTime(ms) {
        if (isNaN(sampleT0Ms) || isNaN(sampleStepMs) || sampleStepMs <= 0 || nPts < 1) return NaN;
        return ((ms - sampleT0Ms) / sampleStepMs - hourPos + 0.5) * (plotW / nPts);
    }
    // compact 12h sun-event time, matching the AM/PM hour axis: "6:18a" / "7:48p"
    function sunTimeLabel(ms) {
        var d = new Date(ms), h = d.getHours(), m = d.getMinutes();
        var h12 = h % 12; if (h12 === 0) h12 = 12;
        return h12 + ":" + (m < 10 ? "0" + m : m) + (h < 12 ? "a" : "p");
    }
    // Extra height to lift a sun marker so it clears the per-hour precip/snow/amount
    // readouts that sit above the temp number — a sun glyph straddles up to a couple
    // of columns, so a readout there would otherwise jumble with its time. Returns
    // the tallest readout (in lines) among the marker's neighbouring columns, ×0,
    // so dry columns keep the marker tight to the temp number.
    function sunMarkerLift(px) {
        // off-plot markers aren't drawn, so their lift is irrelevant — skip the work
        // (the 3-column scan + per-column precipAmtStr) for markers outside the plot.
        if (nPts < 1 || isNaN(px) || px < 0 || px > plotW) return 0;
        var col = Math.round(px / (plotW / nPts) - 0.5), maxLines = 0;
        for (var c = col - 1; c <= col + 1; ++c) {
            if (c < 0 || c >= nPts) continue;
            var pv = c < curPrecip.length    ? curPrecip[c]    : 0;
            var sv = c < curSnow.length      ? curSnow[c]      : 0;
            var av = c < curPrecipAmt.length ? curPrecipAmt[c] : 0;
            var lines = 0;
            if (pv >= pctLabelMin) lines++;                                          // % line
            if (sv >= 0.1) lines++;                                                  // snow line
            else if (weatherRoot && av > 0 && parseFloat(weatherRoot.precipAmtStr(av)) > 0) lines++;  // amount line
            if (lines > maxLines) maxLines = lines;
        }
        return maxLines > 0 ? maxLines * Math.round(graphReadoutFontSize * 1.4) + Kirigami.Units.smallSpacing : 0;
    }
    readonly property int nPts: curTemps.length

    readonly property real plotW:      Math.max(1, graphArea.width)
    readonly property real inset:      Kirigami.Units.gridUnit * 0.7   // edge breathing room
    // plotH grows with topReserve so the temp curve keeps the same pixel
    // amplitude (range = 0.68·plotH − topReserve) — the extra room is purely
    // headroom for the new-day marker above a peak, the curve is not flattened.
    readonly property real plotH:      Kirigami.Units.gridUnit * 14.0
    readonly property real topReserve: Kirigami.Units.gridUnit * 4.1   // room for temp labels + the new-day marker above the peak
    readonly property real precipBandH: plotH * 0.13                   // bottom margin the temp curve keeps clear (smaller → taller, more dramatic temp curve)
    readonly property real precipMaxFrac: 0.70                         // precip fill rises to this fraction of plotH at 100% chance — high chances overlap the temp curve, low ones stay a sliver near the floor
    readonly property real markerGap:   Kirigami.Units.gridUnit * 1.9  // gap between a new-day marker and the temp curve/label
    readonly property real iconRowH: (weatherRoot ? weatherRoot.simpleHourlyIconSize : 24)
                                     + Kirigami.Units.smallSpacing * 2
    // grows with the configurable hour-axis font so a larger size never clips
    readonly property real timeRowH: Math.max(Math.round(Kirigami.Units.gridUnit * 1.2),
                                              Math.round((weatherRoot ? weatherRoot.simpleHourFontSize : 11) * 1.5))
    // font for the per-hour readout labels on the graph (precip % + snow amount)
    readonly property int graphReadoutFontSize: 13
    // how long a precip/snow readout takes to fade as it crosses its visibility
    // threshold while scrolling. Asymmetric: a quick fade IN, a slower lingering fade
    // OUT. Each Behavior picks via its own on-flag — at fade start the flag already
    // holds the target state (on → in, off → out).
    readonly property int  readoutFadeDur:    80    // fade IN
    readonly property int  readoutFadeOutDur: 500   // fade OUT

    // y-scale tracks the interpolated values, so the vertical range eases too. One
    // pass over curTemps per frame (it re-allocates each frame) yields BOTH bounds;
    // tmin/tmax read the cached pair instead of walking the array twice.
    readonly property var tRange: {
        var a = curTemps; if (!a.length) return [0, 1];
        var lo = 1e9, hi = -1e9;
        for (var i = 0; i < a.length; ++i) { var v = a[i]; if (v < lo) lo = v; if (v > hi) hi = v; }
        return [lo, hi];
    }
    readonly property real tmin: tRange[0]
    readonly property real tmax: tRange[1]

    // x for point `i` when a day fills the width as `count` equal cells, the
    // point centered in its cell. Cell-centering makes consecutive days in the
    // sliding filmstrip tile seamlessly (uniform spacing across day seams).
    function xAtFor(i, count) { return count > 0 ? (i + 0.5) * (plotW / count) : 0; }
    // curve column x: the curve is `nPts` columns wide (24 hourly / 12 every-2h).
    function xAt(i) { return xAtFor(i, nPts); }
    // entrance reveal factor: 0 = curves flat on the baseline, 1 = full shape.
    // Baked into the y-mappings so the canvas, value labels and new-day markers
    // all rise from the ground together.
    property real reveal: 1
    function tempY(t) {
        var hi = topReserve, lo = plotH - precipBandH;
        var y = (tmax === tmin) ? (hi + lo) / 2
                                : hi + (tmax - t) / (tmax - tmin) * (lo - hi);
        return plotH + (y - plotH) * reveal;
    }
    // height tracks the ABSOLUTE chance (0-100), not the window max, so a high
    // chance genuinely rises into the temp zone (overlap) while a dry window stays
    // a low sliver. Capped at precipMaxFrac of plotH at 100%.
    function precipY(p) {
        var frac = Math.max(0, Math.min(1, (isNaN(p) ? 0 : p) / 100));
        return plotH - frac * precipMaxFrac * plotH * reveal;
    }
    function curTempY(i)   { return tempY(curTemps[i]); }
    function curPrecipY(i) { return precipY(curPrecip[i]); }
    // y of the UPPER silhouette (temp or precip, whichever is higher) at an
    // arbitrary plot x (linear between points) — lets the new-day marker ride
    // just above whatever peaks there, dodging both a high temp curve and a tall
    // precip wash as they morph/slide during a scroll.
    function silY(i) { return Math.min(curTempY(i), curPrecipY(i)); }
    // linear-interpolate a per-column curve y at an arbitrary plot x. kind:
    // 0 = temp curve, 1 = precip curve, else = upper silhouette (min of the two).
    // Lets the sliding filmstrip overlays (new-day marker, precip/snow readouts)
    // ride whatever the morphing curve is doing at their panned x.
    function colYAtX(px, kind) {
        var n = nPts;
        if (n === 0) return topReserve;
        function yAt(i) { return kind === 0 ? curTempY(i) : kind === 1 ? curPrecipY(i) : silY(i); }
        if (px <= xAt(0))     return yAt(0);
        if (px >= xAt(n - 1)) return yAt(n - 1);
        for (var i = 0; i < n - 1; ++i) {
            var x0 = xAt(i), x1 = xAt(i + 1);
            if (px >= x0 && px <= x1) {
                var f = (px - x0) / Math.max(1e-6, x1 - x0);
                return yAt(i) + (yAt(i + 1) - yAt(i)) * f;
            }
        }
        return yAt(n - 1);
    }
    function curveYAtX(px) { return colYAtX(px, 2); }
    // A precip-% readout shows on any column whose chance is at least this. It's a
    // STABLE threshold, not a moving-peak test: a column keeps its label while rain
    // is present there and the value just MORPHS as you scroll (like the temp
    // numbers), instead of blinking as a peak slides across fixed columns. Snow
    // labels use a fixed cm floor (0.1) the same way.
    //
    // pctLabelHide is the HYSTERESIS release point: a shown label only hides once the
    // morphing value falls below it (not back at pctLabelMin). Without this gap, two
    // adjacent hours whose chances bracket 30 (e.g. 39% and 16%) blank the label as
    // the interpolated value passes ~27% mid-scroll; the band keeps it visible across
    // the seam and only clears it where the column is genuinely dry.
    readonly property int pctLabelMin:  30
    readonly property int pctLabelHide: 20

    readonly property bool scrolling: posAnim.running || flickAnim.running || dragging

    // Fixed [min,max] across all configured days so a given temperature maps to
    // the same colour on every tab (honest colours, not per-day relative).
    readonly property var tempDomain: {
        var a = samples, lo = 1e9, hi = -1e9;
        for (var i = 0; i < a.length; ++i) {
            var t = a[i].temp;
            if (t < lo) lo = t;
            if (t > hi) hi = t;
        }
        return lo <= hi ? [lo, hi] : [0, 1];
    }
    function tempNorm(t) {
        var d = tempDomain, span = Math.max(1, d[1] - d[0]);
        return (t - d[0]) / span;
    }
    // normalized temp (0..1) → "rgba(...)" via the ramp
    function rampColor(t, alpha) {
        var ramp = tempRamp, x = Math.max(0, Math.min(1, t));
        var lo = ramp[0], hi = ramp[ramp.length - 1];
        for (var i = 0; i < ramp.length - 1; ++i) {
            if (x >= ramp[i][0] && x <= ramp[i + 1][0]) { lo = ramp[i]; hi = ramp[i + 1]; break; }
        }
        var f = (x - lo[0]) / Math.max(1e-6, hi[0] - lo[0]);
        var r = Math.round(lo[1][0] + (hi[1][0] - lo[1][0]) * f);
        var g = Math.round(lo[1][1] + (hi[1][1] - lo[1][1]) * f);
        var b = Math.round(lo[1][2] + (hi[1][2] - lo[1][2]) * f);
        return "rgba(" + r + "," + g + "," + b + "," + alpha + ")";
    }

    function rgbaArr(c, a) { return "rgba(" + c[0] + "," + c[1] + "," + c[2] + "," + a.toFixed(3) + ")"; }

    // Sun events currently on (or just off) screen, as {off, rise}. `off` is the
    // fractional curve-column offset (0 = leftmost column, 1 = rightmost): a sun
    // instant maps to fractional sample index gFrac = (t − s0)/step, and column i
    // tracks global index (hourPos + i), so off = (gFrac − hourPos)/(nPts−1).
    // `step` is read from the data (1h or 2h modes). Margin = the bloom half-width
    // so a glow whose centre is just off-screen still bleeds in. Drives drawSunBloom.
    function sunBloomPeaks() {
        var evs = sunMarkerModel;
        if (!evs.length || nPts < 2 || !samples || samples.length < 2) return [];
        var s0 = sampleT0Ms, step = sampleStepMs;
        if (isNaN(s0) || isNaN(step) || step <= 0) return [];
        var denom = nPts - 1, hw = sunGlowHalfCols / denom, out = [];
        for (var i = 0; i < evs.length; ++i) {
            var off = ((evs[i].ms - s0) / step - hourPos) / denom;
            if (off > -hw && off < 1 + hw) out.push({ off: off, rise: evs[i].rise });
        }
        return out;
    }

    // Paint the radial sun bloom + line streak for every on-screen sun event.
    // Drawn straight onto the chart canvas (after the fills, before the crisp temp
    // line) so the line sits on top of its own glow. xs/ty are the live (morphing)
    // curve columns; gx0/gx1 the horizontal span shared with the gradients. Each
    // event: a tall radial ellipse (core on the line, fading up, clipped above the
    // curve) plus a soft horizontal streak laid along the line itself.
    function drawSunBloom(ctx, xs, ty, gx0, gx1, w) {
        var peaks = sunBloomPeaks();
        if (!peaks.length) return;
        var n = xs.length, spanX = gx1 - gx0;
        if (n < 2 || spanX <= 0) return;
        var denom = nPts - 1;
        var colW = spanX / denom;                 // px per curve column
        var rx = sunGlowHalfCols * colW;          // horizontal radius
        // upward reach measured in sun-glyph heights, so the glow never overshoots
        // the icon pinned above the line (icon = hourlyInfoFontSize * 3.1, see marker delegate).
        var iconSz = weatherRoot ? weatherRoot.hourlyInfoFontSize * 3.1 : 34;
        var ry = iconSz * sunGlowRiseIcons;       // upward reach
        if (rx <= 0 || ry <= 0) return;

        // clip to the area ABOVE the temp curve (the whole trick from the design):
        // trace the curve, then close up-and-over the top so the glow can't spill below.
        ctx.save();
        ctx.beginPath();
        ctx.moveTo(0, ty[0]);
        ctx.lineTo(xs[0], ty[0]);
        smooth(ctx, xs, ty);
        ctx.lineTo(w, ty[n - 1]);
        ctx.lineTo(w, 0);
        ctx.lineTo(0, 0);
        ctx.closePath();
        ctx.clip();

        for (var p = 0; p < peaks.length; ++p) {
            var off = peaks[p].off;
            var cx = gx0 + off * spanX;
            // line y at the (fractional) event column, so the core sits on the curve
            var colF = Math.max(0, Math.min(denom, off * denom));
            var i0 = Math.min(n - 2, Math.floor(colF)), fr = colF - i0;
            var cy = ty[i0] + (ty[i0 + 1] - ty[i0]) * fr;
            var pal = peaks[p].rise ? sunGlow.rise : sunGlow.set;
            // local slope of the curve at the event: the chord between the bracketing
            // columns. The bloom is rotated by this so its wide axis lies ALONG the
            // line and the rise is perpendicular to it — on a steep section it follows
            // the curve instead of floating as a flat horizontal lens.
            var slopeAngle = Math.atan2(ty[i0 + 1] - ty[i0], xs[i0 + 1] - xs[i0]);

            // radial ellipse: a circle in a rotated, y-scaled frame → a feathered lens
            // that hugs the line at its local angle. Gaussian falloff (many stops) so the
            // rim dissolves smoothly; colour eases core→mid across the inner third;
            // alpha follows coreA·exp(−feather·r²), the last stop forced transparent.
            ctx.save();
            ctx.translate(cx, cy);
            ctx.rotate(slopeAngle);
            ctx.scale(1, ry / rx);
            var g = ctx.createRadialGradient(0, 0, 0, 0, 0, rx);
            var GSTOPS = 8;
            for (var gs = 0; gs <= GSTOPS; ++gs) {
                var gt = gs / GSTOPS;
                var cmix = Math.min(1, gt / 0.33);
                var gcol = [Math.round(pal.core[0] + (pal.mid[0] - pal.core[0]) * cmix),
                            Math.round(pal.core[1] + (pal.mid[1] - pal.core[1]) * cmix),
                            Math.round(pal.core[2] + (pal.mid[2] - pal.core[2]) * cmix)];
                var ga = gs === GSTOPS ? 0 : sunGlowCoreA * Math.exp(-sunGlowFeather * gt * gt);
                g.addColorStop(gt, rgbaArr(gcol, ga));
            }
            ctx.fillStyle = g;
            ctx.beginPath();
            ctx.arc(0, 0, rx, 0, 2 * Math.PI);
            ctx.fill();
            ctx.restore();
        }
        ctx.restore();   // drop the above-line clip

        // soft glowing streak along the line at each event: a horizontal gradient
        // that's transparent except a bump of `streak` colour around each peak,
        // stroked wide+faint then narrow+brighter to fake a blurred glow (Canvas
        // has no feGaussianBlur). Drawn unclipped — it rides the line, not above it.
        var denom2 = nPts - 1, shw = sunStreakHalfCols / denom2;
        var sg = ctx.createLinearGradient(gx0, 0, gx1, 0);
        sg.addColorStop(0, rgbaArr(peaks[0].rise ? sunGlow.rise.streak : sunGlow.set.streak, 0));
        for (var q = 0; q < peaks.length; ++q) {
            var e = peaks[q].off, sc = peaks[q].rise ? sunGlow.rise.streak : sunGlow.set.streak;
            // feathered bell ALONG the line: gaussian alpha across ±shw (same exp(−feather·u²)
            // profile as the radial) so the warm width fades smoothly instead of as a hard
            // triangle. Stops outside [0,1] (event scrolled near/off the edge) are dropped —
            // an out-of-range addColorStop throws and aborts the whole paint; the 0/1 anchor
            // stops still fade it cleanly.
            var SSTOPS = 6;
            for (var ss = -SSTOPS; ss <= SSTOPS; ++ss) {
                var su = ss / SSTOPS;                          // −1..1 across the streak
                var so = e + su * shw;
                if (so <= 0 || so >= 1) continue;
                var sa = Math.abs(ss) === SSTOPS ? 0
                       : sunGlowStreakA * Math.exp(-sunGlowFeather * su * su);
                sg.addColorStop(so, rgbaArr(sc, sa));
            }
        }
        sg.addColorStop(1, rgbaArr(peaks[peaks.length - 1].rise ? sunGlow.rise.streak : sunGlow.set.streak, 0));
        ctx.save();
        ctx.lineCap = "round";
        ctx.strokeStyle = sg;
        var passes = [[16, 0.32], [8, 0.62], [3.5, 1.0]];   // [width, alpha-scale]: wide+faint halo → mid → tight core, faking a blurred glow
        for (var s = 0; s < passes.length; ++s) {
            ctx.globalAlpha = passes[s][1];
            ctx.lineWidth = passes[s][0];
            ctx.beginPath();
            ctx.moveTo(0, ty[0]);
            ctx.lineTo(xs[0], ty[0]);
            smooth(ctx, xs, ty);
            ctx.lineTo(w, ty[n - 1]);
            ctx.stroke();
        }
        ctx.restore();
    }

    // Precip colour is CONSISTENT — a fixed rain-blue independent of the chance
    // (the chance is conveyed by the fill HEIGHT, not its colour). Snowiness is
    // the only thing that shifts it: rain-blue → white in proportion to amount.
    readonly property var snowRGB:   [245, 250, 255]  // bright snow white
    readonly property var precipRGB: [66, 165, 245]   // rain blue (#42a5f5)
    readonly property real precipBandA: 0.30          // consistent fill opacity
    readonly property real precipLineA: 0.95          // consistent stroke opacity
    readonly property real precipFadeFloor: 0.18      // band alpha kept at the floor; the fill is dense at its top edge and fades down to this (vertical wash)
    readonly property real precipFadeExp:   1.4       // >1 = fade harder toward the floor while the top edge keeps full opacity
    // colour for one column: fixed blue, only snow shifts it toward white.
    function precipColorAt(snow, chance, isLine) {
        var s = Math.max(0, Math.min(1, snow));
        var r = Math.round(precipRGB[0] + (snowRGB[0] - precipRGB[0]) * s);
        var g = Math.round(precipRGB[1] + (snowRGB[1] - precipRGB[1]) * s);
        var b = Math.round(precipRGB[2] + (snowRGB[2] - precipRGB[2]) * s);
        var a = (isLine ? precipLineA : precipBandA);
        a = a + (1 - a) * s * 0.32;                   // snow reads a bit more opaque than rain
        return "rgba(" + r + "," + g + "," + b + "," + a.toFixed(3) + ")";
    }

    // canvas-side helpers
    function rgba(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255)
             + "," + Math.round(c.b * 255) + "," + a + ")";
    }
    function smooth(ctx, xs, ys) {   // Catmull-Rom → bezier
        for (var i = 0; i < xs.length - 1; ++i) {
            var x0 = i > 0 ? xs[i - 1] : xs[i], y0 = i > 0 ? ys[i - 1] : ys[i];
            var x1 = xs[i], y1 = ys[i], x2 = xs[i + 1], y2 = ys[i + 1];
            var x3 = i + 2 < xs.length ? xs[i + 2] : x2, y3 = i + 2 < xs.length ? ys[i + 2] : y2;
            ctx.bezierCurveTo(x1 + (x2 - x0) / 6, y1 + (y2 - y0) / 6,
                              x2 - (x3 - x1) / 6, y2 - (y3 - y1) / 6, x2, y2);
        }
    }

    function clampPos(p) { return Math.max(0, Math.min(dayCount - 1, p)); }

    // entrance animation: the curves rise from the baseline into shape (no
    // day-scrolling). Plays when the view is created (layout switch recreates
    // it via the Loader) and again every time the popup is opened (the view
    // survives a close, so watch `expanded`).
    NumberAnimation {
        id: revealAnim
        target: simple
        property: "reveal"
        from: 0
        to: 1
        duration: 700
        easing.type: Easing.OutCubic
    }
    function entranceReveal() {
        posAnim.stop(); flickAnim.stop();
        hourPos = 0;   // always reopen on today
        revealAnim.restart();
    }
    Component.onCompleted: entranceReveal()
    Connections {
        target: simple.weatherRoot
        function onExpandedChanged() {
            if (simple.weatherRoot.expanded) simple.entranceReveal();
        }
    }

    implicitWidth:  Math.max(Kirigami.Units.gridUnit * 34, content.implicitWidth + pad * 2)
    implicitHeight: content.implicitHeight + pad + Math.round(pad * 1.0)
    Layout.minimumWidth: Kirigami.Units.gridUnit * 30 + pad * 2

    // animations drive the window position (hourPos)
    NumberAnimation {
        id: posAnim
        target: simple
        property: "hourPos"
        duration: 600
        easing.type: Easing.InOutQuad
    }
    NumberAnimation {
        id: flickAnim
        target: simple
        property: "hourPos"
        easing.type: Easing.OutCubic
    }
    // Paired with flickAnim for the FLING MORPH: cross-fades the curve (dayMorphT 0→1)
    // to the landing window while flickAnim pans the strip there. Given the SAME
    // per-fling duration as flickAnim so both finish together — dayMorphT hits 1 exactly
    // as hourPos reaches the target, so the cross-fade → windowAt() handoff doesn't snap.
    // Slow drag / touchpad stay 1:1 slides (they don't touch this); only a flick morphs.
    NumberAnimation {
        id: flickMorphAnim
        target: simple
        property: "dayMorphT"
        easing.type: Easing.OutQuart   // match morphAnim so readout digits settle in sync on a fling too
    }
    // Delayed VALUE-label morph: hold the numbers for lblMorphDelay, then tick them to
    // the new values over lblMorphDur (set per gesture ≥ the curve span, so when the
    // label morph ends curTemps is already at morphTo and the handoff doesn't jump).
    SequentialAnimation {
        id: lblMorphAnim
        PauseAnimation { duration: simple.lblMorphDelay }
        NumberAnimation { target: simple; property: "lblMorphT"; from: 0; to: 1
                          duration: simple.lblMorphDur; easing.type: Easing.OutCubic }
    }
    // The curve cross-fade outlasts the strip pan by this many ms, so the curve keeps
    // settling IN PLACE after the timeline has already reached the target — a slow,
    // decelerating finish (OutCubic). ⚠️ Must be ≥ 0: if the morph finished BEFORE the
    // pan, dayMorphT would hit 1 while hourPos≠target and snap curTemps from morphTo
    // back to windowAt(). Bump it for a longer lingering settle.
    readonly property int morphSettleTail: 450
    function clampHour(p) { return Math.max(0, Math.min(maxHourPos, p)); }
    function dayFirstSampleIndex(idx) {
        if (!weatherRoot || !weatherRoot.dailyData || !weatherRoot.dailyData[idx]) return 0;
        var date = weatherRoot.dailyData[idx].date;
        for (var i = 0; i < samples.length; ++i) if (samples[i].date === date) return i;
        return 0;
    }
    // day-tab click: the in-place curve morph (current → target day)
    NumberAnimation {
        id: morphAnim
        target: simple
        property: "dayMorphT"
        duration: 600   // overridden per tap in goToDay → pan + morphSettleTail (the settle tail)
        // Front-loaded (OutQuart) so most of each number's value travel happens
        // early and it settles into its final rounded digit sooner. With a
        // back-loaded/symmetric curve (e.g. InOutQuad) a big-delta readout keeps
        // ticking through digits deep into the slow tail while a small-delta one
        // settled long ago, so they read as out of sync — this compresses that
        // gap. Matches flickMorphAnim's decelerating feel.
        easing.type: Easing.OutQuart
    }
    // any free scroll (drag / wheel) abandons an in-flight curve morph (pill tap OR
    // fling) and its paired pan, returning the curve to following the window directly
    function cancelDayMorph() { morphAnim.stop(); flickMorphAnim.stop(); flickAnim.stop(); lblMorphAnim.stop(); simple.dayMorphT = 1; simple.lblMorphT = 1; }
    function flickTo(velocity) {                 // velocity in sample-index units/s
        var maxVh = 42, decelh = 60;
        var vh = Math.max(-maxVh, Math.min(maxVh, velocity));
        if (Math.abs(vh) < 1.5) return;
        var dh = (vh < 0 ? -1 : 1) * (vh * vh) / (2 * decelh);
        var th = clampHour(simple.hourPos + dh);
        if (Math.abs(th - simple.hourPos) < 0.5) return;
        // land on a WHOLE hour so the fling morph hands off seamlessly to windowAt()
        var targetW = Math.round(th);
        if (targetW === Math.round(simple.hourPos)) return;
        var dur = Math.min(1000, Math.max(180, Math.abs(vh) / decelh * 1000));
        // FLING MORPH: cross-fade the curve in place to the landing window while the
        // strip pans there. The curve morph runs LONGER than the pan (dur +
        // morphSettleTail) so it keeps settling after the strip has arrived; it must
        // not be SHORTER than the pan or the morphTo → windowAt() handoff would snap.
        _snapMorph(targetW);
        flickAnim.stop(); flickAnim.from = simple.hourPos; flickAnim.to = targetW;
        flickAnim.duration = dur; flickAnim.start();
        flickMorphAnim.stop(); flickMorphAnim.from = 0; flickMorphAnim.to = 1;
        flickMorphAnim.duration = dur + morphSettleTail; flickMorphAnim.start();
        simple.lblMorphT = 0; lblMorphAnim.stop();
        lblMorphDur = dur + morphSettleTail; lblMorphAnim.start();
    }
    // Snapshot the current curve columns as the morph SOURCE and the window at targetW
    // as the morph TARGET, then arm dayMorphT at 0. Shared by the day-pill morph
    // (goToDay) and the fling morph (flickTo). targetW must be a whole sample index so
    // the morph hands off cleanly to windowAt(targetW) when dayMorphT reaches 1.
    function _snapMorph(targetW) {
        var win = windowAt(targetW);
        morphFromT = curTemps.slice();
        morphFromP = curPrecip.slice();
        morphFromS = curSnow.slice();
        morphFromA = curPrecipAmt.slice();
        morphToT = win.map(function(s) { return s.temp; });
        morphToP = win.map(function(s) { return isNaN(s.precip) ? 0 : s.precip; });
        morphToS = win.map(function(s) { return simple.snowCm(s); });
        morphToA = win.map(function(s) { return simple.precipMm(s); });
        simple.dayMorphT = 0;
    }
    function goToDay(idx) {
        // Cancel any in-flight pan/morph (a fling, a wheel notch, or a prior tap):
        // morphAnim and flickMorphAnim BOTH drive dayMorphT, so a leftover flick
        // morph would fight this one. (The old version only stopped posAnim.)
        posAnim.stop(); flickAnim.stop(); morphAnim.stop(); flickMorphAnim.stop(); lblMorphAnim.stop();
        var targetW = Math.round(clampHour(dayFirstSampleIndex(clampPos(idx))));
        _snapMorph(targetW);
        // Pan the strip to the target day...
        posAnim.from = simple.hourPos; posAnim.to = targetW; posAnim.start();
        // ...while the curve cross-fade and the held-then-ticked value labels outlast
        // the pan by morphSettleTail — the SAME lingering settle as a wheel/fling
        // morph (notchMorph), so a pill tap finishes the way a scroll does instead of
        // stopping dead with the strip.
        morphAnim.from = 0; morphAnim.to = 1;
        morphAnim.duration = posAnim.duration + morphSettleTail; morphAnim.start();
        simple.lblMorphT = 0;
        lblMorphDur = posAnim.duration + morphSettleTail; lblMorphAnim.start();
    }
    // A mouse-wheel notch is a DISCRETE jump (fixed target), so like a flick it can
    // morph: cross-fade the curve in place to targetW while flickAnim pans the strip
    // there. Repeated notches (a fast scroll) chain via the in-flight flickAnim target.
    // Touchpad pixel-scroll stays a 1:1 slide — it's continuous, so it can't morph.
    function notchMorph(targetW) {
        morphAnim.stop(); posAnim.stop();
        _snapMorph(targetW);
        var dur = 350;
        flickAnim.stop(); flickAnim.from = simple.hourPos; flickAnim.to = targetW;
        flickAnim.duration = dur; flickAnim.start();
        flickMorphAnim.stop(); flickMorphAnim.from = 0; flickMorphAnim.to = 1;
        flickMorphAnim.duration = dur + morphSettleTail; flickMorphAnim.start();
        simple.lblMorphT = 0; lblMorphAnim.stop();
        lblMorphDur = dur + morphSettleTail; lblMorphAnim.start();
    }

    // toolbar buttons floated at the very top-right corner (mirrors FullView)
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -Math.round(simple.pad * 0.35)
        anchors.rightMargin: Math.round(simple.pad * 0.35)
        spacing: 0
        z: 10
        ToolButton {
            width: Math.round(Kirigami.Units.gridUnit * 0.9); height: width
            flat: true
            // switch to the detailed (regular) layout
            icon.name: "view-list-details"
            icon.width: Math.round(Kirigami.Units.gridUnit * 0.6)
            icon.height: Math.round(Kirigami.Units.gridUnit * 0.6)
            onClicked: if (weatherRoot) weatherRoot.toggleLayout()
            ToolTip.visible: hovered
            ToolTip.text: i18n("Switch to detailed layout")
        }
        ToolButton {
            width: Math.round(Kirigami.Units.gridUnit * 0.9); height: width
            flat: true
            checkable: true
            icon.name: "window-pin"
            icon.width: Math.round(Kirigami.Units.gridUnit * 0.6)
            icon.height: Math.round(Kirigami.Units.gridUnit * 0.6)
            Component.onCompleted: checked = (weatherRoot ? weatherRoot.keepOpen : false)
            onToggled: if (weatherRoot) weatherRoot.setKeepOpen(checked)
            ToolTip.visible: hovered
            ToolTip.text: checked ? i18n("Unpin window") : i18n("Keep window open")
        }
        ToolButton {
            width: Math.round(Kirigami.Units.gridUnit * 0.9); height: width
            flat: true
            icon.name: "view-refresh"
            icon.width: Math.round(Kirigami.Units.gridUnit * 0.6)
            icon.height: Math.round(Kirigami.Units.gridUnit * 0.6)
            enabled: weatherRoot && !weatherRoot.loading
            onClicked: if (weatherRoot) weatherRoot.fetchWeather()
            ToolTip.visible: hovered
            ToolTip.text: i18n("Refresh")
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: simple.pad
        anchors.rightMargin: simple.pad
        anchors.bottomMargin: simple.pad
        anchors.topMargin: Math.round(simple.pad * 1.0)
        spacing: Kirigami.Units.smallSpacing

        // ── Header ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            // pull the header block left, past the content padding, to trim the
            // extra space on the left of the icon
            Layout.leftMargin: -Math.round(simple.pad * 0.9)
            spacing: Kirigami.Units.largeSpacing

            // left block: icon + temperature, with "condition • location" below
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                // nudge the icon/temp/metrics block a touch right (the right-side
                // filler absorbs it, so the day pills stay put)
                Layout.leftMargin: Math.round(simple.pad * 0.4)
                spacing: 0

                RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    // current-condition icon to the left of the temperature
                    Item {
                        // hero size, shrunk for the visually-heavy clear-night moon
                        readonly property int sz: Math.round((weatherRoot ? weatherRoot.simpleHeroIconSize : 68)
                            * (weatherRoot ? weatherRoot.heroScale(weatherRoot.weatherCode, weatherRoot.isDay) : 1))
                        Layout.preferredWidth: sz
                        Layout.preferredHeight: sz
                        Layout.alignment: Qt.AlignVCenter
                        Layout.topMargin: -Math.round(Kirigami.Units.gridUnit * 1.1)

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Math.round(parent.width * (weatherRoot ? weatherRoot.staticIconZoom(weatherRoot.weatherCode, weatherRoot.isDay) : 1))
                            height: width
                            roundToIconSize: false   // honor the exact zoom; don't snap to 32/48
                            visible: simple.heroAnimSrc.length === 0
                            source: weatherRoot ? weatherRoot.conditionIcon(weatherRoot.weatherCode, weatherRoot.isDay, weatherRoot.cloudCover)
                                                : "weather-none-available"
                        }
                        AnimatedImage {
                            anchors.fill: parent
                            visible: simple.heroAnimSrc.length > 0
                            source: simple.heroAnimSrc
                            playing: visible
                            cache: false
                            smooth: true
                            mipmap: true
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignTop
                        // the big font has tall top leading — pull up so the
                        // digits sit level with the icon
                        Layout.topMargin: -Math.round((weatherRoot ? weatherRoot.simpleTempFontSize : 54) * 0.36)
                        text: weatherRoot ? weatherRoot.temperatureText : "—"
                        color: Kirigami.Theme.textColor
                        font.pixelSize: weatherRoot ? weatherRoot.simpleTempFontSize : 54
                        font.bold: true
                    }

                    // Metrics live INSIDE the icon+temp row so their x is governed
                    // by that (stable) row, not by the variable-width condition/
                    // location line below — otherwise a shorter location name
                    // shrinks the left block and the metrics slide left into the
                    // temperature (the post-location-change overlap bug).
                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: Math.round(Kirigami.Units.gridUnit * 0.05)
                        Layout.leftMargin: -Math.round(Kirigami.Units.largeSpacing * 0.5)
                        spacing: 0
                        // user-selected header metrics (up to 4) — Simple layout's own
                        // set; the "!" alert indicator sits next to the first line
                        Repeater {
                            model: weatherRoot ? weatherRoot.simpleHeaderMetrics : []
                            delegate: RowLayout {
                                id: simpMetricRow
                                required property int index
                                required property var modelData
                                readonly property string metric: weatherRoot ? weatherRoot.metricText(modelData, simple.selectedDay, simple.focusedSample) : ""
                                // keep the FIRST row visible for the alert "!" even when
                                // its metric text is empty (e.g. metric "none", or a blank
                                // precip metric) — an invisible parent would hide the
                                // AlertIndicator child along with the row.
                                visible: metric.length > 0
                                         || (index === 0 && weatherRoot && weatherRoot.showAlerts
                                             && weatherRoot.topAlert !== null)
                                spacing: Kirigami.Units.smallSpacing
                                Label {
                                    textFormat: Text.StyledText
                                    font.bold: true
                                    font.pixelSize: weatherRoot ? weatherRoot.simpleHeaderInfoFontSize : 13
                                    text: simpMetricRow.metric
                                }
                                AlertIndicator {
                                    weatherRoot: simple.weatherRoot
                                    visible: simpMetricRow.index === 0 && weatherRoot
                                             && weatherRoot.showAlerts && weatherRoot.topAlert !== null
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }
                    }
                }

            }

            Item { Layout.fillWidth: true }

            // Day pills — keep their own drop below the toolbar buttons (so the
            // temperature header can sit up top), nudged a touch past the right
            // edge so they tuck in under the buttons.
            Row {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: -Math.round(Kirigami.Units.gridUnit * 0.15)
                Layout.rightMargin: -Math.round(simple.pad * 0.9)
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: weatherRoot ? weatherRoot.dailyData.slice(0, weatherRoot.simpleDailyDays) : []
                    delegate: Rectangle {
                        id: pill
                        required property int index
                        readonly property bool selected: index === simple.selectedDay
                        width: pillLabel.implicitWidth + Math.round(Kirigami.Units.gridUnit * 1.1)
                        height: Math.round(Kirigami.Units.gridUnit * 1.7)
                        radius: height / 2
                        color: selected
                            ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                      Kirigami.Theme.textColor.b, 0.16)
                            : (pillHover.hovered ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                      Kirigami.Theme.textColor.b, 0.08) : "transparent")
                        Behavior on color { ColorAnimation { duration: 150 } }
                        HoverHandler { id: pillHover }
                        TapHandler { onTapped: simple.goToDay(pill.index) }
                        Label {
                            id: pillLabel
                            anchors.centerIn: parent
                            text: weatherRoot ? weatherRoot.dayName(pill.index) : ""
                            font.bold: pill.selected
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 2
                        }
                    }
                }
            }
        }

        // ── Graph: morphing curve + sliding icon/time filmstrip ────────────
        Item {
            id: graphArea
            Layout.fillWidth: true
            // pull the graph wider than the padded content column so it
            // stretches closer to the panel edges
            Layout.leftMargin: -simple.pad
            Layout.rightMargin: -simple.pad
            Layout.topMargin: -Math.round(Kirigami.Units.gridUnit * 0.6)   // lift the whole graph (curve + icon/time rows) up slightly
            Layout.preferredHeight: simple.plotH + simple.iconRowH + simple.timeRowH
                                    + Kirigami.Units.smallSpacing * 2
                                    + Kirigami.Units.gridUnit * 0.5
            clip: true

            // wheel scroll: touchpad pixels = 1:1 slide; mouse notch = discrete jump that morphs
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (wheel) => {
                    var pd = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x
                           : wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : 0;
                    if (pd !== 0) {
                        // touchpad: 1:1 pixels, position follows the gesture (slides);
                        // continuous, so it can't morph (same as a slow finger-drag)
                        simple.cancelDayMorph();
                        posAnim.stop();
                        var hourW = simple.plotW / simple.pointsVisible;
                        simple.hourPos = simple.clampHour(simple.hourPos - pd / hourW);
                    } else {
                        // mouse notch: a discrete jump → MORPH the curve in place to the
                        // target while the strip pans there (see notchMorph); chain from
                        // the in-flight flickAnim target so fast scrolling accumulates
                        var adh = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                        var baseh = flickAnim.running ? flickAnim.to : simple.hourPos;
                        var targetW = Math.round(simple.clampHour(baseh - (adh / 120) * 3));
                        if (targetW === Math.round(simple.hourPos) && !flickAnim.running) return;
                        simple.notchMorph(targetW);
                    }
                }
            }
            // free, pixel-sensitive horizontal drag with a momentum flick on release
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                property real startPos: 0
                property real startX: 0
                property real velocity: 0   // sample-index units / second, for the flick
                property real lastT: 0
                onPressed: (m) => {
                    posAnim.stop(); flickAnim.stop(); simple.cancelDayMorph();
                    startPos = simple.hourPos;
                    startX = m.x;
                    velocity = 0; lastT = Date.now();
                    simple.dragging = true;
                }
                onPositionChanged: (m) => {
                    if (!simple.dragging) return;
                    var now = Date.now(), dt = Math.max(1, now - lastT);
                    var hourW = simple.plotW / simple.pointsVisible;
                    var newH = simple.clampHour(startPos - (m.x - startX) / hourW);
                    velocity = 0.6 * velocity + 0.4 * ((newH - simple.hourPos) / dt * 1000);
                    simple.hourPos = newH;
                    lastT = now;
                }
                onReleased: () => { simple.dragging = false; simple.flickTo(velocity); }
                onCanceled: () => { simple.dragging = false; }
            }

            Column {
                id: gcol
                width: graphArea.width
                spacing: Kirigami.Units.smallSpacing

                // ── plot (morphing canvas + value labels, in place) ──
                Item {
                    id: plot
                    width: gcol.width
                    height: simple.plotH

                    Canvas {
                        id: chart
                        anchors.fill: parent
                        // GPU-render the curve (FBO) so a full-width repaint every
                        // drag frame doesn't rasterise on the CPU — the main
                        // hourly-scroll cost. Threaded keeps the paint off the GUI
                        // thread (noticeably smoother during a continuous drag than
                        // Cooperative); risk is a rare threaded-GL driver glitch,
                        // which surfaces visually, not as a crash.
                        renderTarget: Canvas.FramebufferObject
                        renderStrategy: Canvas.Threaded
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Connections {
                            target: simple
                            function onCurTempsChanged()  { chart.requestPaint(); }
                            function onCurPrecipChanged() { chart.requestPaint(); }
                            function onCurSnowChanged()   { chart.requestPaint(); }
                            function onColorModeChanged()  { chart.requestPaint(); }
                            function onRevealChanged()     { chart.requestPaint(); }
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var ct = simple.curTemps, cp = simple.curPrecip;
                            var n = ct.length;
                            if (n === 0) return;

                            var xs = [], ty = [], py = [];
                            for (var i = 0; i < n; ++i) {
                                xs.push(simple.xAt(i));
                                ty.push(simple.tempY(ct[i]));
                                py.push(simple.precipY(cp[i]));
                            }
                            var tCol = Kirigami.Theme.textColor;
                            // temperature fill + line: when colouring is on, a
                            // horizontal temp-colour gradient (cold blue → hot
                            // red), one stop per column, consistent across days
                            // via simple.tempDomain and lerping through the morph.
                            // When off, fall back to the flat neutral grey fade.
                            // horizontal gradient span (shared by temp + precip)
                            var gx0 = xs[0], gx1 = xs[n - 1];
                            if (gx1 <= gx0) gx1 = gx0 + 1;   // guard single point
                            var tBandStyle, tLineStyle;
                            if (simple.colorTemp) {
                                var bandGrad = ctx.createLinearGradient(gx0, 0, gx1, 0);
                                var lineGrad = ctx.createLinearGradient(gx0, 0, gx1, 0);
                                // sample the colour ramp at a fixed few stops (not
                                // one per column) — the gradient is smooth, so this
                                // looks identical but halves the per-frame work
                                var STOPS = Math.min(n, 7);
                                for (var k = 0; k < STOPS; ++k) {
                                    var off = STOPS === 1 ? 0 : k / (STOPS - 1);
                                    var tn = simple.tempNorm(ct[Math.round(off * (n - 1))]);
                                    bandGrad.addColorStop(off, simple.rampColor(tn, simple.bandAlpha));
                                    lineGrad.addColorStop(off, simple.rampColor(tn, 1));
                                }
                                tBandStyle = bandGrad;
                                tLineStyle = lineGrad;
                            } else {
                                var gray = ctx.createLinearGradient(0, simple.topReserve, 0, height);
                                gray.addColorStop(0, simple.rgba(tCol, 0.22));
                                gray.addColorStop(1, simple.rgba(tCol, 0.02));
                                tBandStyle = gray;
                                // flat neutral line — the sun warmth now comes from the
                                // separate radial bloom pass (drawSunBloom), not a recolor.
                                tLineStyle = simple.rgba(tCol, 0.85);
                            }

                            // Draw order matters here. The precip/snow band is
                            // painted FIRST so a vertical opacity fade can be masked
                            // onto it ALONE (destination-in) — dense at its top edge,
                            // melting toward the floor — without touching the temp
                            // fill. The temp area is then laid in BEHIND the faded
                            // band (destination-over), so the temp wash shows through
                            // the band's lower, fainter reaches.

                            // precip fill/line: a horizontal gradient that tints
                            // white where the forecast precipitation is snow
                            // (per-point curSnow), rain-blue otherwise. Falls back
                            // to flat neutral grey when precip colouring is off.
                            var cs = simple.curSnow;
                            var pBandStyle, pLineStyle;
                            if (simple.colorPrecip) {
                                var pBand = ctx.createLinearGradient(gx0, 0, gx1, 0);
                                var pLine = ctx.createLinearGradient(gx0, 0, gx1, 0);
                                // one stop per column so a sharp snow/rain change
                                // between hours stays crisp instead of averaged away.
                                for (var pk = 0; pk < n; ++pk) {
                                    var poff = n === 1 ? 0 : pk / (n - 1);
                                    var sv = pk < cs.length ? simple.snowiness(cs[pk]) : 0;
                                    var pv = pk < cp.length ? cp[pk] : 0;
                                    pBand.addColorStop(poff, simple.precipColorAt(sv, pv, false));
                                    pLine.addColorStop(poff, simple.precipColorAt(sv, pv, true));
                                }
                                pBandStyle = pBand;
                                pLineStyle = pLine;
                            } else {
                                pBandStyle = simple.rgba(tCol, 0.16);
                                pLineStyle = simple.rgba(tCol, 0.5);
                            }

                            // precipitation area (flat-extended to both edges)
                            ctx.beginPath();
                            ctx.moveTo(0, py[0]);
                            ctx.lineTo(xs[0], py[0]);
                            simple.smooth(ctx, xs, py);
                            ctx.lineTo(width, py[n - 1]);
                            ctx.lineTo(width, height);
                            ctx.lineTo(0, height);
                            ctx.closePath();
                            ctx.fillStyle = pBandStyle;
                            ctx.fill();

                            // vertical wash: multiply the band's alpha by a top→floor
                            // ramp so it's dense at its top edge (the crisp precip
                            // line) and fades to precipFadeFloor at the floor. The
                            // canvas holds nothing but the band yet, so destination-in
                            // fades ONLY the band. Anchored screen-space from the
                            // band's highest point down — same y reads the same alpha.
                            var pTopY = Math.min.apply(null, py);
                            if (pTopY < height - 0.5) {
                                var vFade = ctx.createLinearGradient(0, pTopY, 0, height);
                                // shape the falloff: full at the top edge, then drop
                                // away steeply (precipFadeExp) so the lower band thins
                                // out fast instead of staying opaque down to the floor.
                                var FADE_STOPS = 6;
                                for (var fi = 0; fi <= FADE_STOPS; ++fi) {
                                    var ft = fi / FADE_STOPS;
                                    var fa = simple.precipFadeFloor
                                           + (1 - simple.precipFadeFloor) * Math.pow(1 - ft, simple.precipFadeExp);
                                    vFade.addColorStop(ft, "rgba(0,0,0," + fa.toFixed(3) + ")");
                                }
                                ctx.globalCompositeOperation = "destination-in";
                                ctx.fillStyle = vFade;
                                ctx.fillRect(0, 0, width, height);
                                ctx.globalCompositeOperation = "source-over";
                            }

                            // temperature area (flat-extended to both edges), laid in
                            // BEHIND the faded band via destination-over so the temp
                            // wash shows through where the band has thinned out.
                            ctx.beginPath();
                            ctx.moveTo(0, ty[0]);
                            ctx.lineTo(xs[0], ty[0]);
                            simple.smooth(ctx, xs, ty);
                            ctx.lineTo(width, ty[n - 1]);
                            ctx.lineTo(width, height);
                            ctx.lineTo(0, height);
                            ctx.closePath();
                            ctx.globalCompositeOperation = "destination-over";
                            ctx.fillStyle = tBandStyle;
                            ctx.fill();
                            ctx.globalCompositeOperation = "source-over";

                            // precipitation line
                            ctx.beginPath();
                            ctx.moveTo(0, py[0]);
                            ctx.lineTo(xs[0], py[0]);
                            simple.smooth(ctx, xs, py);
                            ctx.lineTo(width, py[n - 1]);
                            ctx.lineWidth = 2;
                            ctx.strokeStyle = pLineStyle;
                            ctx.stroke();

                            // sun bloom: the warm radial glow + line streak at each
                            // sunrise/sunset, under the crisp line so the line tops its glow.
                            simple.drawSunBloom(ctx, xs, ty, gx0, gx1, width);

                            // temperature line — drawn LAST so the temp curve always
                            // stays on top of the precip wash, even at 100% precip.
                            ctx.beginPath();
                            ctx.moveTo(0, ty[0]);
                            ctx.lineTo(xs[0], ty[0]);
                            simple.smooth(ctx, xs, ty);
                            ctx.lineTo(width, ty[n - 1]);
                            ctx.lineWidth = simple.colorTemp ? 2.2 : 2;
                            ctx.strokeStyle = tLineStyle;
                            ctx.stroke();
                        }
                    }

                    // temperature value labels — ride the morphing curve. In hourly
                    // mode the curve has 24 points, so label every 2nd to avoid crowding.
                    Repeater {
                        model: simple.nPts
                        delegate: Label {
                            required property int index
                            x: simple.xAt(index) - width / 2
                            y: simple.curTempY(index) - height - Kirigami.Units.smallSpacing
                            text: weatherRoot ? weatherRoot.tempStr(simple.lblTemps[index]) : ""
                            font.bold: true
                            font.pixelSize: weatherRoot ? weatherRoot.simpleGraphTempFontSize : 13
                            color: Kirigami.Theme.textColor
                        }
                    }
                    // precip-% + snow readouts at FIXED curve columns, like the temp
                    // value labels above: each rides curPrecipY/curTempY and its VALUE
                    // MORPHS live as you scroll/day-morph (curPrecip/curSnow interpolate),
                    // so the number animates in place. Visibility is a STABLE threshold
                    // (chance ≥ pctLabelMin / snow ≥ 0.1 cm), not a moving-peak test —
                    // a column keeps its label while precip/snow is present there and
                    // only fades at the edges of a wet/snowy stretch, instead of blinking
                    // as a peak slides across columns. Top→bottom: snow, rain
                    // amount, chance (snow and rain amount are mutually exclusive).
                    Repeater {
                        model: simple.nPts
                        delegate: Column {
                            id: roGroup
                            required property int  index
                            readonly property real pVal: index < simple.curPrecip.length ? simple.curPrecip[index] : 0
                            readonly property real sVal: index < simple.curSnow.length   ? simple.curSnow[index]   : 0
                            // Precip % shows on EVERY hour above the threshold, including
                            // repeated flat runs (a steady 90% stretch is labelled every
                            // hour, not just at its start). It ALSO shows whenever this
                            // hour has an amount label (amtOn) — even below the threshold —
                            // so a shown amount always carries its chance alongside it.
                            // Snow shows on EVERY snowy hour too — a repeated amount
                            // is fresh accumulation (½in + ½in = 1in), not a repeat.
                            readonly property string sText:  (weatherRoot && sVal >= 0.1) ? weatherRoot.snowfallStr(sVal, true) : ""
                            // Sticky (hysteresis) visibility: on at pctLabelMin, off only
                            // once below pctLabelHide; amtOn forces it on. The initializer
                            // sets the resting state, then onPVal/onAmtOn drive it
                            // imperatively as the value morphs — so a column straddling the
                            // 30% line between two hours keeps its label across the seam
                            // instead of blanking at the ~27% midpoint. See pctLabelHide.
                            property bool pctOn: pVal >= simple.pctLabelMin || amtOn
                            function _refreshPctOn() {
                                pctOn = amtOn || pVal >= simple.pctLabelMin
                                              || (pctOn && pVal >= simple.pctLabelHide);
                            }
                            onPValChanged:  _refreshPctOn()
                            onAmtOnChanged: _refreshPctOn()
                            readonly property bool   snowOn: sText.length > 0
                            // Liquid precip AMOUNT, shown on every wet hour like snow
                            // (each hour's rain is fresh, not a repeat). Gated on the
                            // FORMATTED value so a trace that rounds to "0.00 in" is
                            // hidden, and suppressed while it's snowing — the snow row
                            // above already carries that hour's accumulation.
                            readonly property real   aVal:   index < simple.curPrecipAmt.length ? simple.curPrecipAmt[index] : 0
                            readonly property string aText:  weatherRoot ? weatherRoot.precipAmtStr(aVal) : ""
                            readonly property bool   amtOn:  !snowOn && aText.length > 0 && parseFloat(aText) > 0
                            // each readout fades itself (below) so a value crossing its
                            // threshold while scrolling animates in/out instead of popping.
                            // BUT sText/aText blank EXACTLY when snowOn/amtOn flip false,
                            // so the fade-OUT would have an empty string to fade (= an
                            // instant vanish, not a fade). Latch the last non-empty text in
                            // sShown/aShown so the label keeps something visible while it
                            // fades out, then catches the new value on the way back in. (The
                            // chance label needs no latch — its "NN%" text is always set.)
                            property string sShown: ""
                            property string aShown: ""
                            onSTextChanged: if (sText.length > 0) sShown = sText
                            onATextChanged: if (aText.length > 0) aShown = aText
                            spacing: 1
                            x: Math.max(0, simple.xAt(index) - width / 2)
                            y: {
                                var pTop = simple.curPrecipY(index);
                                var tTop = simple.curTempY(index);
                                var tempLabelH = (weatherRoot ? weatherRoot.simpleGraphTempFontSize : 13) * 1.4;
                                var tempLabelTop = tTop - tempLabelH - Kirigami.Units.smallSpacing;
                                var gap = 3;
                                // group bottom must clear the temp label AND sit a
                                // comfortable distance above the precip curve.
                                var bottom = Math.min(tempLabelTop - gap, pTop - 14);
                                return Math.max(0, bottom - height);
                            }
                            // Snow + rain-amount share ONE fixed-height slot above the
                            // chance. They're mutually exclusive, so one cross-fades into
                            // the other IN PLACE; and because the slot's height is FIXED
                            // (never collapses), toggling either never reflows the group —
                            // it's a pure opacity fade, no vertical "slide". An empty slot
                            // is just transparent space over the graph (invisible), and the
                            // group is at most 2 lines (slot + chance), same as before.
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.max(snowLbl.implicitWidth, amtLbl.implicitWidth)
                                height: Math.round(simple.graphReadoutFontSize * 1.4)
                                Label {
                                    id: snowLbl
                                    anchors.centerIn: parent
                                    opacity: roGroup.snowOn ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: roGroup.snowOn ? simple.readoutFadeDur : simple.readoutFadeOutDur; easing.type: Easing.InOutQuad } }
                                    text: roGroup.sShown
                                    color: simple.snowLabelColor
                                    font.bold: true
                                    font.pixelSize: simple.graphReadoutFontSize
                                }
                                // amount is a finer, lighter detail so the % stays prominent
                                Label {
                                    id: amtLbl
                                    anchors.centerIn: parent
                                    opacity: roGroup.amtOn ? 0.9 : 0   // 0.9 = its lighter "detail" base
                                    Behavior on opacity { NumberAnimation { duration: roGroup.amtOn ? simple.readoutFadeDur : simple.readoutFadeOutDur; easing.type: Easing.InOutQuad } }
                                    text: roGroup.aShown
                                    color: simple.colorPrecip ? simple.precipColor : Kirigami.Theme.textColor
                                    font.pixelSize: Math.round(simple.graphReadoutFontSize * 0.85)
                                }
                            }
                            Label {
                                opacity: roGroup.pctOn ? 1 : 0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: roGroup.pctOn ? simple.readoutFadeDur : simple.readoutFadeOutDur; easing.type: Easing.InOutQuad } }
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Math.round(roGroup.pVal) + "%"
                                color: simple.colorPrecip ? simple.precipColor : Kirigami.Theme.textColor
                                font.bold: true
                                font.pixelSize: simple.graphReadoutFontSize
                            }
                        }
                    }
                    // New-day markers: a dashed line + moon + date at any fixed
                    // column whose hour is 00:00 (it snaps column to column as you
                    // scroll, in keeping with the reshape-in-place columns).
                    Canvas {
                        id: hrMarkerCanvas
                        anchors.fill: parent
                        Connections {
                            target: simple
                            // only track the curve per-frame while a midnight line is
                            // actually on screen; repaint once on enter/leave to clear
                            function onCurTempsChanged() { if (simple.windowHasMidnight) hrMarkerCanvas.requestPaint(); }
                            function onCurPrecipChanged() { if (simple.windowHasMidnight) hrMarkerCanvas.requestPaint(); }
                            function onWindowHasMidnightChanged() { hrMarkerCanvas.requestPaint(); }
                            function onRevealChanged() { hrMarkerCanvas.requestPaint(); }
                        }
                        onPaint: {
                            var ctx = getContext("2d"); ctx.reset();
                            ctx.setLineDash([3, 4]); ctx.lineWidth = 1;
                            ctx.strokeStyle = simple.rgba(Kirigami.Theme.textColor, 0.45);
                            var tLabelH = (weatherRoot ? weatherRoot.simpleGraphTempFontSize : 13) * 1.4;
                            var rowH = weatherRoot ? Math.round(weatherRoot.hourlyInfoFontSize * 1.7) : 18;
                            var s = simple.samples, base = simple.windowBase;
                            for (var k = -1; k < simple.poolSize; ++k) {
                                var g = base + k;
                                if (g < 0 || g >= s.length) continue;
                                if (!simple.isDayStart(g)) continue;
                                var mx = simple.hourX(g);
                                if (mx < -10 || mx > width + 10) continue;
                                var top = Math.max(rowH, simple.curveYAtX(mx) - tLabelH - simple.markerGap);
                                ctx.beginPath(); ctx.moveTo(mx, top); ctx.lineTo(mx, height); ctx.stroke();
                            }
                        }
                    }
                    Repeater {
                        model: simple.poolSize
                        delegate: Row {
                            required property int index
                            readonly property int g: simple.windowBase + index - 1
                            readonly property var modelData: (g >= 0 && g < simple.samples.length) ? simple.samples[g] : null
                            readonly property real lineX: simple.hourX(g)
                            visible: modelData !== null && simple.isDayStart(g)
                                     && lineX > -width && lineX < plot.width + width
                            spacing: Kirigami.Units.smallSpacing
                            x: lineX - width / 2
                            y: {
                                var cy = simple.curveYAtX(lineX);
                                var tLabelH = (weatherRoot ? weatherRoot.simpleGraphTempFontSize : 13) * 1.4;
                                return Math.max(0, cy - tLabelH - height - simple.markerGap);
                            }
                            Kirigami.Icon {
                                // new-day marker icon — a touch larger than the row text
                                width: weatherRoot ? Math.round(weatherRoot.hourlyInfoFontSize * 2.45) : 27
                                height: width
                                roundToIconSize: false   // render at the exact size; don't snap to 22/32
                                anchors.verticalCenter: parent.verticalCenter
                                source: (weatherRoot && parent.modelData)
                                        ? weatherRoot.conditionIcon(parent.modelData.code, parent.modelData.day, parent.modelData.cloud)
                                        : "weather-clear-night"
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData ? new Date(parent.modelData.time).toLocaleDateString(Qt.locale(), "ddd, MMM d") : ""
                                font.bold: true
                                opacity: 0.8
                                font.pixelSize: weatherRoot ? weatherRoot.hourlyInfoFontSize + 1 : 12
                            }
                        }
                    }
                    // sunrise / sunset glyph + time, pinned above the temp label at the
                    // curve x where the line picks up its warm bloom (same xAtTime
                    // mapping, so glyph and bloom stay aligned through scroll/morph).
                    // High z keeps the whole marker ABOVE every other graph label
                    // (temp numbers, precip %/amount) when columns crowd together.
                    Repeater {
                        model: simple.sunMarkerModel
                        delegate: Column {
                            required property var modelData
                            readonly property real mx: simple.xAtTime(modelData.ms)
                            readonly property real sz: weatherRoot ? Math.round(weatherRoot.hourlyInfoFontSize * 3.1) : 34
                            z: 50
                            spacing: -Math.round(sz * 0.22)   // pull the time up under the icon's empty bottom margin
                            visible: !isNaN(mx) && mx > -sz && mx < plot.width + sz
                            x: mx - width / 2
                            // above the temp number when there's headroom; when the curve
                            // rides high (no room for the icon+time+readout stack) drop
                            // BELOW the line, where nothing else is drawn. Instead of
                            // SKIPPING between the two, animate the flip: belowF eases 0↔1
                            // and y lerps between the above/below anchors. Both anchors
                            // track the live curve, so only the FLIP animates — continuous
                            // curve-tracking stays lag-free (belowF holds at 0 or 1).
                            readonly property real markGap: Kirigami.Units.smallSpacing * 3
                            readonly property real cyV: simple.curveYAtX(mx)
                            readonly property real aboveY: cyV
                                - ((weatherRoot ? weatherRoot.simpleGraphTempFontSize : 13) * 1.4)
                                - height - markGap - simple.sunMarkerLift(mx)
                            readonly property real belowY: cyV + markGap
                            readonly property bool wantBelow: aboveY < 2
                            property real belowF: wantBelow ? 1 : 0
                            Behavior on belowF { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                            y: aboveY + (belowY - aboveY) * belowF
                            Kirigami.Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.sz; height: parent.sz
                                roundToIconSize: false   // exact size; don't snap to 22/32
                                // sunset glyph recoloured to match its time label (sunGold);
                                // the full-colour SVG needs isMask to accept a flat tint.
                                // sunrise keeps its natural artwork (isMask false → colour ignored).
                                isMask: !parent.modelData.rise
                                color: simple.sunGold
                                source: weatherRoot
                                        ? weatherRoot.sunEventIcon(parent.modelData.rise)
                                        : ""
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: weatherRoot ? simple.sunTimeLabel(parent.modelData.ms) : ""
                                // each time matches its own glyph: sunrise the icon's gold, sunset sunGold
                                color: parent.modelData.rise ? simple.sunRiseColor : simple.sunGold
                                font.bold: true
                                font.pixelSize: weatherRoot ? weatherRoot.hourlyInfoFontSize : 11
                            }
                        }
                    }
                }

                // small gap between the graph and the icon row (the icon + time
                // rows below sit just under the graph)
                Item { width: 1; height: Kirigami.Units.gridUnit * 0.1 }

                // ── hour icons ──
                Item {
                    width: gcol.width
                    height: simple.iconRowH
                    clip: true
                    // A sliding pool of icons — stable delegates that pan via
                    // hourX and recycle their hour once per window shift.
                    Repeater {
                        model: simple.poolSize
                        delegate: Item {
                            id: hrIconC
                            required property int index
                            readonly property int g: simple.windowBase + index - 1
                            readonly property var modelData: (g >= 0 && g < simple.samples.length) ? simple.samples[g] : null
                            readonly property real cx: simple.hourX(g)
                            visible: modelData !== null && cx > -width && cx < gcol.width + width
                            width: weatherRoot ? weatherRoot.simpleHourlyIconSize : 24
                            height: width
                            x: cx - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            // probability-aware code: a likely-rain hour shows rain even if the code reads cloudy
                            readonly property int iconCode: (weatherRoot && modelData)
                                ? weatherRoot.precipAwareCode(modelData.code, modelData.precip, modelData.precipAmt, modelData.snow) : 0
                            readonly property string animSrc: (weatherRoot && weatherRoot.simpleAnimatedIcons && modelData)
                                ? weatherRoot.heroAnim(hrIconC.iconCode, modelData.day, modelData.cloud) : ""
                            // per-condition fine-tune (sunny trimmed); guard null model
                            readonly property real iScale: (weatherRoot && hrIconC.modelData)
                                ? weatherRoot.iconScale(hrIconC.iconCode, hrIconC.modelData.day) : 1
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: Math.round(parent.width * (weatherRoot && hrIconC.modelData ? weatherRoot.staticIconZoom(hrIconC.iconCode, hrIconC.modelData.day) : 1))
                                height: width
                                roundToIconSize: false   // honor the exact zoom; don't snap to 32/48
                                visible: hrIconC.animSrc.length === 0
                                source: (weatherRoot && hrIconC.modelData)
                                        ? weatherRoot.conditionIcon(hrIconC.iconCode, hrIconC.modelData.day, hrIconC.modelData.cloud)
                                        : "weather-none-available"
                            }
                            AnimatedImage {
                                anchors.centerIn: parent
                                width: Math.round(parent.width * hrIconC.iScale)
                                height: width
                                visible: hrIconC.animSrc.length > 0
                                source: hrIconC.animSrc
                                playing: visible && !simple.scrolling
                                cache: false
                                smooth: true
                                mipmap: true
                                fillMode: Image.PreserveAspectFit
                            }
                        }
                    }
                }

                // ── time axis ──
                Item {
                    width: gcol.width
                    height: simple.timeRowH
                    clip: true
                    // A sliding pool of hour labels that pan with the scroll
                    Repeater {
                        model: simple.poolSize
                        delegate: Label {
                            required property int index
                            readonly property int g: simple.windowBase + index - 1
                            readonly property var modelData: (g >= 0 && g < simple.samples.length) ? simple.samples[g] : null
                            readonly property real cx: simple.hourX(g)
                            visible: modelData !== null && cx > -width && cx < gcol.width + width
                            x: cx - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData ? new Date(modelData.time).toLocaleTimeString(Qt.locale(), "h AP") : ""
                            font.pixelSize: weatherRoot ? weatherRoot.simpleHourFontSize : 11
                        }
                    }
                }
            }
        }
    }
}
