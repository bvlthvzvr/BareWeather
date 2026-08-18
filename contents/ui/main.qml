/*
 * Weather — a simple weather widget for KDE Plasma 6
 * Copyright 2026  bvlthvzvr
 * SPDX-License-Identifier: MIT
 *
 * Original work. Weather data from Open-Meteo (https://open-meteo.com),
 * a free, no-key public API.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property bool keepOpen: Plasmoid.configuration.keepOpen || false
    function setKeepOpen(v) { Plasmoid.configuration.keepOpen = v; }
    function toggleLayout() { Plasmoid.configuration.simpleLayout = !simpleLayout; }
    hideOnWindowDeactivate: !keepOpen

    // Transparent on the desktop by default — the widget paints its own content
    // and looks better floating frameless over the wallpaper. ConfigurableBackground
    // keeps the "Show background" toggle in settings, so the standard applet frame
    // is one click away for anyone who wants it. No-op on the panel.
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    // On the desktop (not the panel) the full rep is embedded directly — its size
    // is the applet box, not a popup window. The popup machinery below no-ops here.
    readonly property bool planar: Plasmoid.formFactor === PlasmaCore.Types.Planar

    // ── Live weather state ────────────────────────────────────────────────
    property real temperature: NaN
    property int  weatherCode: -1
    property real cloudCover: NaN     // %, drives the overcast-snow icon
    property bool loading: false

    readonly property string locationName: Plasmoid.configuration.locationName || "—"
    // just the city/region for the header — drop the ", Region, Country" that
    // geocoding tacks on (the saved-locations list shows that part by the coords)
    readonly property string locationShortName: {
        var c = locationName.indexOf(",");
        return c >= 0 ? locationName.substring(0, c).trim() : locationName;
    }
    // false until the user sets a location (any method); gates fetching and drives
    // the "no location" empty state. Out of the box there is no default city.
    readonly property bool   hasLocation:  Plasmoid.configuration.locationConfigured
    readonly property string units: Plasmoid.configuration.temperatureUnit || "celsius"
    readonly property int    dailyDays:      Plasmoid.configuration.dailyDays      || 5
    readonly property int    simpleDailyDays: Plasmoid.configuration.simpleDailyDays || 5
    readonly property bool   simpleHourly:    Plasmoid.configuration.simpleHourly    || false
    readonly property int    refreshMinutes: Plasmoid.configuration.refreshInterval || 15
    readonly property int    heroIconSize:   Plasmoid.configuration.heroIconSize   || 88
    readonly property int    tempFontSize:   Plasmoid.configuration.tempFontSize   || 88
    readonly property int    dailyIconSize:  Plasmoid.configuration.dailyIconSize  || 36
    readonly property int    hourlyIconSize:     Plasmoid.configuration.hourlyIconSize     || 38
    readonly property int    hourlyInfoFontSize: Plasmoid.configuration.hourlyInfoFontSize || 11
    // Detailed hourly-card element font (time + per-hour readouts/glyphs); SimpleView
    // keeps hourlyInfoFontSize, so this control only affects the Detailed cards.
    readonly property int    hourlyCardFontSize:  Plasmoid.configuration.hourlyCardFontSize  || 13
    readonly property int    hourlyTempFontSize: Plasmoid.configuration.hourlyTempFontSize || 15
    // hour a non-today day opens at in the Detailed timeline (6 = 6 AM, 0 = midnight).
    // Read directly — NOT `|| 6` — since 0 (midnight) is a valid value `||` would clobber.
    readonly property int    detailDayStartHour:  Plasmoid.configuration.detailDayStartHour
    readonly property int    conditionFontSize:   Plasmoid.configuration.conditionFontSize   || 28
    readonly property bool   animatedDailyIcons:  Plasmoid.configuration.animatedDailyIcons  ?? true
    readonly property bool   animatedHourlyIcons: Plasmoid.configuration.animatedHourlyIcons ?? true
    readonly property bool   simpleLayout:         Plasmoid.configuration.simpleLayout         || false
    readonly property int    simpleHourlyIconSize: Plasmoid.configuration.simpleHourlyIconSize || 34
    readonly property bool   simpleAnimatedIcons:  Plasmoid.configuration.simpleAnimatedIcons  || false
    readonly property bool   simpleHeaderAnim:     Plasmoid.configuration.simpleHeaderAnim     ?? true
    // regular-layout header (hero) icon animates unless forecast animation is None
    readonly property bool   fullHeaderAnim:       animatedDailyIcons || animatedHourlyIcons
    readonly property int    simpleHeroIconSize:   Plasmoid.configuration.simpleHeroIconSize   || 86
    readonly property int    simpleTempFontSize:   Plasmoid.configuration.simpleTempFontSize   || 86
    readonly property int    graphColorMode:       Plasmoid.configuration.graphColorMode       ?? 2
    readonly property int    panelIconPercent:   Plasmoid.configuration.panelIconPercent   || 130
    readonly property int    panelFontPercent:   Plasmoid.configuration.panelFontPercent   || 48
    readonly property bool   panelColorIcon:     Plasmoid.configuration.panelColorIcon === true
    readonly property bool   panelDetailed:      Plasmoid.configuration.panelDetailed === true
    readonly property int    panelSecondLine:    Plasmoid.configuration.panelSecondLine ?? 0
    // Detailed-panel font sizes, % of panel height: the bold condition word and
    // the second line chosen by panelSecondLine.
    readonly property int    panelConditionPercent:  Plasmoid.configuration.panelConditionPercent  || 40
    readonly property int    panelSecondLinePercent: Plasmoid.configuration.panelSecondLinePercent || 37

    // Wind speed unit. "auto" follows the temperature unit (mph with °F, kmh
    // with °C) — what the widget always did; "kmh"/"mph"/"ms" pin it instead.
    // windUnitApi goes straight into the Open-Meteo query, windUnitLabel is
    // what the UI prints.
    readonly property string windUnit:    Plasmoid.configuration.windUnit || "auto"
    readonly property string windUnitApi: (windUnit !== "auto") ? windUnit
                                        : (units === "fahrenheit" ? "mph" : "kmh")
    readonly property string windUnitLabel: (windUnitApi === "mph") ? "mph"
                                          : (windUnitApi === "ms")  ? "m/s" : "kmh"

    property real apparentTemp: NaN
    property real humidity:     NaN
    property real uvIndex:      NaN
    property real precipRate:   NaN   // current precipitation, mm/h
    property real windSpeed:    NaN   // current wind speed (unit = windUnitApi)
    property real windGust:     NaN   // current wind gust (same unit as windSpeed)
    property real precipSumToday: NaN // today's total precipitation, mm
    property real precipChanceToday: NaN // today's max chance of precipitation, %
    property real snowSumToday:   NaN // today's total snowfall, cm
    property real highTemp:     NaN
    property real lowTemp:      NaN

    // ── Stale-data signal ─────────────────────────────────────────────────
    // fetchWeather keeps the last-good values on failure (so a blip doesn't blank
    // the widget), but that means an outage shows hours-old weather as if current —
    // a fast storm over a frozen "sunny" reads as WRONG, not stale. Track the last
    // success time and flag data that has aged past the threshold; the panel shows a
    // small dot so "can't refresh" is visible instead of silently misleading.
    property double lastGoodFetch: 0        // wall-clock ms of last success (0 = none yet)
    property double _nowMs: 0               // ticked each minute by staleClock
    // Floor 30 min, but scale with the refresh interval so a long-refresh user isn't
    // flagged mid-cycle — ~2 missed fetches before we call it stale.
    readonly property int staleThresholdMs: Math.max(30, refreshMinutes * 2) * 60000
    // Only once we HAVE data that has since gone stale — never on first load
    // (weatherCode < 0) or before the clock's first tick.
    readonly property bool weatherStale: weatherCode >= 0 && lastGoodFetch > 0
                                         && _nowMs - lastGoodFetch > staleThresholdMs
    // "Updated Xh ago" for the full/simple header stale marker (panel uses a dot —
    // no room for text). Empty until we've had a successful fetch.
    function staleAgeText() {
        if (lastGoodFetch <= 0) return "";
        var mins = Math.floor((_nowMs - lastGoodFetch) / 60000);
        if (mins < 60) return i18n("Updated %1m ago", mins);
        var hrs = Math.floor(mins / 60);
        if (hrs < 24) return i18n("Updated %1h ago", hrs);
        return i18n("Updated %1d ago", Math.floor(hrs / 24));
    }

    // ── Severe-weather alerts (KDE FOSS Public Alert Server, worldwide) ────
    readonly property bool showAlerts: Plasmoid.configuration.showAlerts
    property var weatherAlerts: []    // [{ event, severity, headline, ends, expires, description, instruction }]
    property int _alertGen: 0         // bumped per fetch; stale responses are dropped
    function alertRank(sev) {
        return sev === "Extreme" ? 4 : sev === "Severe" ? 3
             : sev === "Moderate" ? 2 : sev === "Minor" ? 1 : 0;
    }
    // minimum severity to show (user-set in General settings): 1 Minor, 2 Moderate,
    // 3 Severe, 4 Extreme. Default 2 = Moderate+ (Minor/Unknown filtered). Applied
    // at DISPLAY time (see displayAlerts) so changing it re-filters instantly.
    readonly property int minAlertRank: Plasmoid.configuration.minAlertSeverity || 2
    function alertColor(sev) {
        return sev === "Extreme" ? "#d32f2f" : sev === "Severe" ? "#e53935"
             : sev === "Moderate" ? "#fb8c00" : "#fbc02d";   // Minor / Unknown → amber
    }
    // alerts at or above the user's minimum severity — the filtered view that
    // drives the banner + tooltip. weatherAlerts holds the FULL fetched set, so
    // changing minAlertRank re-filters live without waiting for the next fetch.
    readonly property var displayAlerts: weatherAlerts.filter(function (a) {
        if (alertRank(a.severity) < minAlertRank) return false;
        // Drop alerts already past their CAP <expires> so a stale record from the
        // beta server (or one that lapses between the 15-min fetches) doesn't linger.
        // Filter on the REAL expires only (not the onset fallback `ends` uses), and
        // keep alerts with no/unparseable expiry — absent expiry means "still active".
        if (a.expires) {
            var exp = new Date(a.expires).getTime();
            if (!isNaN(exp) && exp < Date.now()) return false;
        }
        return true;
    })
    // drives the header banner
    readonly property var topAlert: {
        if (!displayAlerts.length) return null;
        var best = displayAlerts[0];
        for (var i = 1; i < displayAlerts.length; ++i)
            if (alertRank(displayAlerts[i].severity) > alertRank(best.severity)) best = displayAlerts[i];
        return best;
    }
    // short text: "Heat Advisory until Fri 8:00 PM"
    function alertText(a) {
        if (!a) return "";
        var t = a.event;
        if (a.ends) {
            var d = new Date(a.ends);
            if (!isNaN(d.getTime())) t += " " + i18n("until %1", d.toLocaleString(Qt.locale(), use24Hour ? "ddd H:mm" : "ddd h:mm AP"));
        }
        return t;
    }
    // NWS descriptions are hard-wrapped at ~65 cols; every wrap is a \n. Join those
    // continuation lines back into flowing text (the Label wraps it), but keep "*"/"-"
    // bullet lines on their own line. Other agencies' single-line text passes through.
    function _flowAlert(t) {
        var out = "", lines = t.replace(/\r/g, "").split("\n");
        for (var i = 0; i < lines.length; ++i) {
            var ln = lines[i].trim();
            if (!ln) continue;
            out += (out ? (/^[*\-]/.test(ln) ? "\n" : " ") : "") + ln;
        }
        return out;
    }
    // full alert text for the hover tooltip: top alert's headline + description +
    // instruction, then every other active alert as a one-liner. No caps — the
    // point-in-polygon filter keeps the set small (only alerts covering us).
    function alertDetail() {
        if (!displayAlerts.length) return "";
        var top = topAlert;
        var s = top.headline;
        if (top.description) s += "\n\n" + _flowAlert(top.description);
        if (top.instruction) s += "\n\n" + _flowAlert(top.instruction);
        if (displayAlerts.length > 1) {
            s += "\n\n" + i18n("Also active:");
            for (var i = 0; i < displayAlerts.length; ++i)
                if (displayAlerts[i] !== top) s += "\n• " + alertText(displayAlerts[i]);
        }
        return s;
    }

    // header info lines: up to 4 user-selected metrics shown next to the temp.
    // Each layout has its own list + font — `headerMetrics`/`headerInfoFontSize`
    // for Detailed (FullView), the `simple*` pair for Simple (SimpleView).
    readonly property int headerInfoFontSize:       Plasmoid.configuration.headerInfoFontSize       || 12
    readonly property int simpleHeaderInfoFontSize: Plasmoid.configuration.simpleHeaderInfoFontSize || 12
    // Simple-layout graph hour-axis label font (the "6 PM 7 PM …" row)
    readonly property int simpleHourFontSize: Plasmoid.configuration.simpleHourFontSize || 13
    readonly property bool use24Hour: Plasmoid.configuration.use24Hour
    // Simple-layout graph per-point temperature label font (the "41° 40° …");
    // decoupled from the Detailed cards' hourlyTempFontSize.
    readonly property int simpleGraphTempFontSize: Plasmoid.configuration.simpleGraphTempFontSize || 16
    readonly property var headerMetrics: [
        Plasmoid.configuration.headerMetric1 || "feelsLike",
        Plasmoid.configuration.headerMetric2 || "humidity",
        Plasmoid.configuration.headerMetric3 || "uv",
        Plasmoid.configuration.headerMetric4 || "none"
    ]
    readonly property var simpleHeaderMetrics: [
        Plasmoid.configuration.simpleHeaderMetric1 || "feelsLike",
        Plasmoid.configuration.simpleHeaderMetric2 || "humidity",
        Plasmoid.configuration.simpleHeaderMetric3 || "uv",
        Plasmoid.configuration.simpleHeaderMetric4 || "none"
    ]
    // The two configurable readouts at the bottom of each Detailed hourly card.
    // Each slot has a primary metric id and a chain of fallbacks, tried in order
    // when the primary has no value for an hour (e.g. snow → precip chance → wind
    // on a dry hour). See hourlyReadout().
    readonly property var hourlyMetrics: [
        { id: Plasmoid.configuration.hourlyMetric1 || "wind",
          fallbacks: [ Plasmoid.configuration.hourlyMetric1Fallback  || "none",
                       Plasmoid.configuration.hourlyMetric1Fallback2 || "none" ] },
        { id: Plasmoid.configuration.hourlyMetric2 || "precip",
          fallbacks: [ Plasmoid.configuration.hourlyMetric2Fallback  || "none",
                       Plasmoid.configuration.hourlyMetric2Fallback2 || "none" ] }
    ]
    // Resolve a readout slot for hour `m` to { id, val }: the primary's value, or
    // the first fallback in the chain that has one. `id` is whichever metric
    // actually produced the text (so the card picks the right icon/glyph); `val`
    // is "" when nothing in the chain has anything to show.
    function hourlyReadout(slot, m) {
        var ids = [slot.id].concat(slot.fallbacks || []);
        for (var i = 0; i < ids.length; ++i) {
            if (!ids[i] || ids[i] === "none") continue;
            var v = hourlyMetricValue(ids[i], m);
            if (v.length > 0) return { id: ids[i], val: v };
        }
        return { id: slot.id, val: "" };
    }
    // Per-hour card metric (id) → display value for the hour sample `m`. Returns
    // "" to hide the row. Mirrors the header metric ids but reads PER-HOUR fields.
    function hourlyMetricValue(id, m) {
        if (!m) return "";
        switch (id) {
        case "wind":      return isNaN(m.wind) ? "" : windLabel(m.wind);
        // "Wind + gust" → compact "5G10" (sustained-Gust, whole numbers, no unit — cards
        // are tight, and the trailing direction arrow marks it as wind). Falls back to the
        // plain speed when no gust rounds higher than sustained (a steady-wind hour).
        case "windGust":  return isNaN(m.wind) ? "" :
                              ((!isNaN(m.gust) && Math.round(m.gust) > Math.round(m.wind))
                                  ? (Math.round(m.wind) + "G" + Math.round(m.gust))
                                  : ("" + Math.round(m.wind)));
        // At/under precipDisplayFloor counts as nothing-to-show on dry-coded hours
        // so a fallback can take over. But on actual precip-coded hours (WMO 51+)
        // always show the chance — suppressing it while the card shows a rain icon
        // is more confusing than a low number.
        case "precip": {
            if (isNaN(m.precip)) return "";
            var isPrecipCode = (m.code >= 51 && m.code <= 82) || m.code >= 95;
            return (m.precip <= precipDisplayFloor && !isPrecipCode) ? "" : (Math.round(m.precip) + "%");
        }
        case "precipAmt":
            // precipAmtStr renders every real amount as a number (traces at extra
            // precision). A true-zero hour has no number to show, so it blanks and the
            // slot's fallback (if any) takes over.
            return precipAmtStr(m.precipAmt);
        case "snow": {
            var s = snowfallStr(m.snow, true);
            if (s.length > 0) return s;
            // Snow-coded hour but sub-0.1 cm: the card shows a snow ICON (gated on
            // precipAwareCode), so the readout must say snow too — else it blanks
            // and the fallback paints a raindrop over a snowing hour. "light" is
            // the honest floor (same wording snowfallStr uses for tiny amounts).
            var c = precipAwareCode(m.code, m.precip, m.precipAmt, m.snow, m.temp);
            if ((c >= 71 && c <= 77) || c === 85 || c === 86) return i18n("light");
            return "";
        }
        case "humidity":  return isNaN(m.humidity) ? "" : (Math.round(m.humidity) + "%");
        case "uv":        return isNaN(m.uv) ? "" : ("UV " + Math.round(m.uv));
        case "feelsLike": return isNaN(m.feels) ? "" : tempStr(m.feels);
        case "cloud":     return (isNaN(m.cloud) || m.cloud < 10) ? "" : (Math.round(m.cloud) + "%");
        }
        return "";   // "none" / unknown
    }
    // Leading glyph (a char in the BUNDLED weather-icons font, wiFont) for a
    // readout metric — so the icon is identical for every user regardless of
    // their system icon theme (named theme icons like weather-showers-symbolic
    // render differently per theme, or not at all). "" = no glyph: wind has its
    // own trailing direction arrow; "none"/unknown get nothing. Codepoints are
    // PUA, verified against the bundled .ttf cmap.
    function hourlyMetricGlyph(id) {
        switch (id) {
        case "cloud":     return "\uf041";   // wi-cloud (U+F041) — escape form, not the literal PUA char the others use
        case "precip":    return "";   // wi-umbrella (U+F084) — precip *chance* (vs wi-raindrop below = precip amount)
        case "precipAmt": return "";   // wi-raindrop
        case "snow":      return "";   // wi-snowflake-cold
        case "humidity":  return "";   // wi-humidity
        case "uv":        return "";   // wi-day-sunny
        case "feelsLike": return "";   // wi-thermometer
        }
        return "";
    }
    // Per-glyph size multiplier (× the readout font) for the leading glyph. The
    // sun / thermometer / humidity glyphs render visually larger than the rain &
    // snow ones at the same pixel size, so they're nudged down slightly to look
    // balanced against the text. Rain/snow (and anything else) use the base 1.5×.
    function hourlyMetricGlyphScale(id) {
        switch (id) {
        case "uv":
        case "humidity":
        case "feelsLike":
        case "precip":    return 1.25;   // wi-umbrella reads a touch large at base — nudge down to match sun/humidity
        }
        return 1.5;
    }
    // per-hour precipitation amount → "1.2 mm" / "0.05 in" (imperial follows °F).
    // A real-but-sub-display amount (would round to "0.00 in" / "0.0 mm" at the normal
    // precision) is shown at EXTRA precision instead, so a trace reads as a real small
    // number (e.g. "0.004 in") rather than a meaningless zero. Only a TRUE zero
    // (mm <= 0) — or a value that rounds away even at the extra precision — blanks.
    // Every non-empty return is a positive number, so callers gate visibility on `!== ""`.
    function precipAmtStr(mm) {
        if (isNaN(mm) || mm <= 0) return "";
        if (units === "fahrenheit") {
            var inch = mm / 25.4;
            if (inch >= 0.005) return inch.toFixed(2) + " in";   // normal: 2 dp
            var i3 = inch.toFixed(3);                            // trace: 3 dp so it isn't "0.00 in"
            return i3 === "0.000" ? "" : i3 + " in";             // rounds away even at 3 dp → blank
        }
        if (mm >= 0.05) return mm.toFixed(1) + " mm";            // normal: 1 dp
        var m2 = mm.toFixed(2);                                  // trace: 2 dp
        return m2 === "0.00" ? "" : m2 + " mm";                  // rounds away even at 2 dp → blank
    }
    // header precipitation amount (mm) → display string in the active unit; imperial
    // (°F) → inches (2 dp), else mm (1 dp). `perHour` adds "/h" for a rate. Unlike
    // precipAmtStr (card readouts, which blank a 0), this keeps 0 visible so the
    // header reads "0 in" / "0 mm" rather than going empty.
    function precipUnitStr(mm, perHour) {
        if (isNaN(mm)) return "";
        var imperial = (units === "fahrenheit");
        var v = imperial ? (mm / 25.4) : mm;
        var num = imperial ? v.toFixed(2) : ("" + (Math.round(v * 10) / 10));
        return num + (imperial ? " in" : " mm") + (perHour ? "/h" : "");
    }
    // Snowfall (cm) → an HONEST, coarse label. Snow depth is a ballpark: it's
    // derived from water with a FIXED snow:liquid ratio while real ratios swing
    // 5:1–20:1 (see DEVELOPMENT), so a tenths digit is fake precision. Three
    // tiers: ~0 → "0", a real-but-tiny amount → "light", else round to the
    // nearest half-unit. Imperial follows the °F unit (½-inch buckets: "½ in").
    function snowfallStr(cm, blankZero) {
        if (isNaN(cm)) return "";
        var imperial = (units === "fahrenheit");
        var unit = imperial ? " in" : " cm";
        // Below the "is it snowing" floor (0.1 cm — same gate SimpleView uses to
        // decide which columns get a snow label) there's effectively no snow. The
        // header shows "0"; the graph passes blankZero=true so a column morphing
        // through ~0 as it fades out blanks instead of flashing "0 in".
        if (cm < 0.1) return blankZero ? "" : ("0" + unit);
        var v = imperial ? (cm / 2.54) : cm;          // value in display units
        if (v < 0.25) return i18n("light");           // real but too little to quantify honestly
        var r = Math.round(v * 2) / 2;                // nearest 0.5
        if (imperial) {                               // ½-inch buckets: "½ in", "1½ in"
            var whole = Math.floor(r);
            var half  = (r - whole) >= 0.5;
            return (whole > 0 ? whole : "") + (half ? "½" : "") + unit;
        }
        return (r % 1 === 0 ? r.toFixed(0) : r.toFixed(1)) + unit;  // metric: "1 cm", "1.5 cm"
    }
    // rich-text "Label: value" for a metric id (or "" when unavailable / none).
    // dayIdx (optional) selects the day for the daily-total metrics (snowSum /
    // precipSum) so a scrolling view shows the day in focus. hourSample (optional)
    // is the focused hour's data, letting an instantaneous metric (humidity) sync
    // to the scrolled hour; without it, it falls back to current conditions.
    // Defaults to today / now.
    function metricText(id, dayIdx, hourSample) {
        var day = (dayIdx !== undefined && dayIdx >= 0 && dayIdx < dailyData.length) ? dailyData[dayIdx] : null;
        // word for the daily-total labels: "today" for day 0 / unset, else the
        // focused day's name (so a scrolled view reads e.g. "Snowfall Sun: …")
        var whenWord = (dayIdx !== undefined && dayIdx > 0) ? dayName(dayIdx) : i18n("Today");
        if (id === "feelsLike") {
            var ft = (hourSample && !isNaN(hourSample.feels)) ? hourSample.feels : apparentTemp;
            return isNaN(ft) ? "" : i18n("Feels like: %1",
                "<font color=\"" + feelsColor(ft) + "\">" + tempStr(ft) + "</font>");
        }
        if (id === "humidity") {
            var hum = (hourSample && !isNaN(hourSample.humidity)) ? hourSample.humidity : humidity;
            return isNaN(hum) ? "" : i18n("Humidity: %1",
                "<font color=\"" + humidityColor(hum) + "\">" + Math.round(hum) + "%</font>");
        }
        if (id === "uv") {
            var uv = (hourSample && !isNaN(hourSample.uv)) ? hourSample.uv : uvIndex;
            return isNaN(uv) ? "" : i18n("UV Index: %1",
                "<font color=\"" + uvColor(uv) + "\">" + uvIndexText(uv) + "</font>");
        }
        if (id === "precipRate") {
            var pr = (hourSample && !isNaN(hourSample.precipAmt)) ? hourSample.precipAmt : precipRate;
            return isNaN(pr) ? "" : i18n("Precipitation: %1",
                "<font color=\"" + precipColor + "\">" + precipUnitStr(pr, true) + "</font>");
        }
        if (id === "precipSum") {
            var ps = day ? day.precipSum : precipSumToday;
            return isNaN(ps) ? "" : i18n("Precip. %1: %2", whenWord,
                "<font color=\"" + precipColor + "\">" + precipUnitStr(ps, false) + "</font>");
        }
        if (id === "wind") {
            var ws = (hourSample && !isNaN(hourSample.wind)) ? hourSample.wind : windSpeed;
            if (isNaN(ws)) return "";
            // show the gust whenever it rounds higher than the sustained wind — the SAME
            // rule as the hourly cards, so header and cards never disagree (no "5G10" on a
            // card while the header hides it). Skips a redundant "5 G5" on calm hours.
            var gs = (hourSample && !isNaN(hourSample.gust)) ? hourSample.gust : windGust;
            var windBody = (!isNaN(gs) && Math.round(gs) > Math.round(ws))
                ? (Math.round(ws) + " G" + Math.round(gs) + " " + windUnitLabel)
                : windLabel(ws);
            return i18n("Wind: %1", "<b>" + windBody + "</b>");
        }
        if (id === "cloud") {
            var cc = (hourSample && !isNaN(hourSample.cloud)) ? hourSample.cloud : cloudCover;
            return isNaN(cc) ? "" : i18n("Cloud cover: %1", "<b>" + Math.round(cc) + "%</b>");
        }
        if (id === "snowSum") {
            var ss = day ? day.snowSum : snowSumToday;
            return isNaN(ss) ? "" : i18n("Snowfall %1: %2", whenWord,
                "<font color=\"" + precipColor + "\">" + snowfallStr(ss) + "</font>");
        }
        // Combined sunrise/sunset — Detailed-layout header only (not offered in
        // Simple). One compact line "↑ 5:23a  ↓ 8:23p"; falls back to today
        // (dailyData[0]) when no day is focused. The old "sunrise"/"sunset" ids are
        // kept as aliases so a previously-saved value still renders.
        if (id === "sun" || id === "sunrise" || id === "sunset") {
            var d0 = day ? day : (dailyData.length ? dailyData[0] : null);
            if (!d0 || !d0.sunrise || !d0.sunset) return "";
            var rise = _sunClock(d0.sunrise), set = _sunClock(d0.sunset);
            if (!rise || !set) return "";
            var up = "<font color=\"" + sunColor + "\">↑</font>";
            var dn = "<font color=\"" + sunColor + "\">↓</font>";
            return up + " " + rise + "&#160;&#160;" + dn + " " + set;
        }
        return "";
    }
    readonly property string precipColor: "#42a5f5"
    readonly property string sunColor:    "#ffb74d"
    property int  isDay:        1
    property var  dailyData:    []   // [{ date, code, hi, lo }] — up to 7 days
    property var  allHourly:    []   // [{ time, date, temp, code, day, precip }] — all hours

    readonly property string temperatureText: tempStr(temperature)

    function tempStr(t) { return isNaN(t) ? "—" : (Math.round(t) + "°"); }

    // ISO local time string → "9PM" (12h) or "19:00" (24h)
    function formatHour(iso) { return new Date(iso).toLocaleTimeString(Qt.locale(), use24Hour ? "H:mm" : "hAP"); }
    // compact clock for the combined sun line: "5:23a" / "8:23p" (12h) or "5:23" / "20:23" (24h)
    function _sunClock(iso) {
        var d = new Date(iso);
        if (isNaN(d.getTime())) return "";
        if (use24Hour) return d.toLocaleTimeString(Qt.locale(), "H:mm");
        return d.toLocaleTimeString(Qt.locale(), "h:mm AP").replace(/\s*AM/, "a").replace(/\s*PM/, "p");
    }

    // Wind speed → "6.0 mph" / "12.3 kmh" / "3.4 m/s" (see windUnit).
    function windLabel(speed) {
        if (isNaN(speed)) return "";
        return (Math.round(speed * 10) / 10) + " " + windUnitLabel;
    }

    // Wind-direction arrow as a Weather Icons font glyph (the glyph already
    // points the right way for each of the 16 compass sectors — no rotation).
    function windDirectionGlyph(deg) {
        if (isNaN(deg)) return "";   // wi-wind fallback
        var glyphs = ["", "", "", "", "", "", "", "",
                      "", "", "", "", "", "", "", ""];
        return glyphs[Math.floor(((deg + 11.25) % 360) / 22.5) % 16];
    }

    // Day label for a daily index: index 0 is "Today" — Open-Meteo returns
    // days in the LOCATION's timezone, so day 0 is the location's current day (which
    // may differ from the viewer's calendar day if the location is in another tz).
    // "Today" stays in the fixed first slot; the midnight refresh re-rolls the array
    // so a new day simply becomes day 0. Other days show the short weekday (Mon…).
    // Pass absolute=true to get the weekday for day 0 too (graph-layout pills).
    function dayName(idx, absolute) {
        if (idx < 0 || idx >= dailyData.length) return idx === 0 ? i18n("Today") : "";
        if (idx === 0 && !absolute) return i18n("Today");
        return new Date(dailyData[idx].date + "T12:00").toLocaleDateString(Qt.locale(), "ddd");
    }
    function dayIndexForDate(date) {
        for (var i = 0; i < dailyData.length; ++i)
            if (dailyData[i].date === date) return i;
        return 0;
    }

    // utc offset (seconds) of the WEATHER LOCATION, from Open-Meteo's response. Lets
    // "now" be evaluated in the location's wall clock, so the day/hour logic lines up
    // with the forecast (which is in the location's tz) even when the viewer sits in
    // a different timezone.
    property real utcOffsetSeconds: NaN
    // "Now" in the location's wall clock, in the SAME frame as new Date(h.time):
    // Open-Meteo times are location-local naive strings, which new Date() would parse
    // in the VIEWER's tz. Shifting by (locationOffset + viewerOffset) re-aligns them.
    // No-op when the location's tz equals the viewer's (the common case).
    function locNow() {
        if (isNaN(utcOffsetSeconds)) return new Date();
        return new Date(Date.now() + utcOffsetSeconds * 1000 + new Date().getTimezoneOffset() * 60000);
    }

    // Continuous hourly timeline from now forward, with a day-break marker
    // ({ dayBreak: true, date, label }) inserted whenever the date rolls over.
    function timeline() {
        var out = [];
        var now = locNow();
        var lastDate = "";
        var n = Math.min(dailyDays, dailyData.length);
        var cutoff = n > 0 ? dailyData[n - 1].date : "";   // last day to include
        for (var i = 0; i < allHourly.length; ++i) {
            var h = allHourly[i];
            if (cutoff !== "" && h.date > cutoff) break;    // dates sort lexically
            if (new Date(h.time).getTime() + 3600000 < now.getTime()) continue;
            if (lastDate !== "" && h.date !== lastDate)
                out.push({ dayBreak: true, date: h.date,
                           label: new Date(h.date + "T12:00").toLocaleDateString(Qt.locale(), "ddd") });
            lastDate = h.date;
            out.push(h);
        }
        return out;
    }

    // The hourly sample for the hour containing "now" (location tz) — the first hour
    // timeline() keeps. Lets the Detailed header fall back to the CURRENT HOUR's forecast
    // (so it matches the hourly cards) instead of the live `current` block when nothing's hovered.
    readonly property var currentHourSample: {
        if (!allHourly || !allHourly.length) return null;
        var hnow = locNow().getTime();
        for (var ci = 0; ci < allHourly.length; ++ci)
            if (new Date(allHourly[ci].time).getTime() + 3600000 >= hnow) return allHourly[ci];
        return null;
    }

    // Current-condition icon inputs for the header hero. Open-Meteo's live
    // `current.weather_code` is a nowcast that can read "overcast" while the current
    // HOUR's forecast (and so the first hourly card) already shows rain — they
    // disagree hour-marginally. Drive the hero off the current-hour sample through
    // precipAwareCode, exactly like the cards, so the header glyph can never
    // contradict the first card. The header metric row already falls back to
    // currentHourSample; this puts the icon on the same source. Falls back to the
    // live `current` block before the hourly array exists.
    readonly property int heroCode: currentHourSample
        ? precipAwareCode(currentHourSample.code, currentHourSample.precip,
                          currentHourSample.precipAmt, currentHourSample.snow, currentHourSample.temp)
        : weatherCode
    readonly property int  heroDay:   currentHourSample ? currentHourSample.day   : isDay
    readonly property real heroCloud: currentHourSample ? currentHourSample.cloud : cloudCover

    // All hourly entries across the configured days, sampled every `step` hours
    // (00:00, 02:00, …) — the continuous data for the simple-layout graph.
    // `days` overrides the day span (defaults to dailyDays).
    function allSamples(step, days) {
        var out = [];
        var now = locNow();
        var span = (days !== undefined && days > 0) ? days : dailyDays;
        var n = Math.min(span, dailyData.length);
        var cutoff = n > 0 ? dailyData[n - 1].date : "";   // last day to include
        for (var i = 0; i < allHourly.length; ++i) {
            var h = allHourly[i];
            if (cutoff !== "" && h.date > cutoff) break;    // dates sort lexically
            // drop hours already past, so the Today graph begins near the
            // current time instead of midnight (future days stay full)
            if (new Date(h.time).getTime() + 3600000 < now.getTime()) continue;
            if (new Date(h.time).getHours() % step !== 0) continue;
            // a precip spike in a skipped hour would vanish between samples
            // (e.g. 21% at 5 PM with step 2) — carry the max of the hours
            // this sample covers instead of the point value
            var s = Object.assign({}, h);
            for (var j = i + 1; j < Math.min(i + step, allHourly.length); ++j) {
                var p = allHourly[j].precip;
                if (!isNaN(p) && (isNaN(s.precip) || p > s.precip)) s.precip = p;
            }
            out.push(s);
        }
        return out;
    }

    // Privacy: weather/alerts are computed on multi-km grids, so we only ever
    // send ~1 km-precise coordinates to the network (2 decimals). The full
    // precision stays in the config for saved locations.
    readonly property int coordPrecision: 2
    function coarseCoord(v) {
        var p = Math.pow(10, coordPrecision);
        return Math.round(v * p) / p;
    }

    // ── Data fetch (Open-Meteo current weather) ───────────────────────────
    function fetchWeather() {
        if (!root.hasLocation) { root.loading = false; return; }
        var lat = Plasmoid.configuration.latitude;
        var lon = Plasmoid.configuration.longitude;
        if (lat === undefined || lon === undefined || isNaN(lat) || isNaN(lon))
            return;
        loading = true;
        var url = "https://api.open-meteo.com/v1/forecast"
                + "?latitude=" + coarseCoord(lat)
                + "&longitude=" + coarseCoord(lon)
                + "&current=temperature_2m,weather_code,apparent_temperature,relative_humidity_2m,is_day,uv_index,precipitation,wind_speed_10m,wind_gusts_10m,cloud_cover"
                + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,snowfall_sum,sunrise,sunset"
                + "&hourly=temperature_2m,apparent_temperature,weather_code,is_day,relative_humidity_2m,uv_index,precipitation_probability,precipitation,snowfall,wind_speed_10m,wind_direction_10m,wind_gusts_10m,cloud_cover"
                + "&forecast_days=7"
                + "&timezone=auto"
                + "&wind_speed_unit=" + windUnitApi
                + "&temperature_unit=" + (units === "fahrenheit" ? "fahrenheit" : "celsius");
        // Abandon any still-in-flight request first. At boot the free-running
        // boot probe (below) re-fires on its OWN schedule whether or not the
        // previous attempt's callbacks ever returned, so without this an attempt
        // hung on a half-up route would leak one socket per probe tick.
        if (root._wxhr) { try { root._wxhr.abort(); } catch (e) {} }
        var xhr = new XMLHttpRequest();
        root._wxhr = xhr;
        // Belt-and-suspenders fast-fail. At login the interface can be up while
        // the route isn't ready (e.g. a VPN tunnel mid-handshake): the connect
        // then HANGS instead of returning HTTP 0. We set a timeout, but a connect
        // stuck in the SYN/black-hole phase doesn't reliably honour xhr.timeout —
        // so the real safety net is the boot probe, which retries on its own
        // timer regardless of whether this request ever calls back.
        var done = false;
        function failWeather(why) {
            if (done) return;
            done = true;
            root.loading = false;
            loadingWatchdog.stop();
            console.log("Weather:", why);   // probe re-fires on its own timer
        }
        xhr.timeout = 8000;
        xhr.ontimeout = function () { failWeather("timeout"); };
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || done) return;
            if (xhr.status !== 200) {
                failWeather("HTTP " + xhr.status);   // network likely not up yet (boot)
                return;
            }
            done = true;
            root.loading = false;
            loadingWatchdog.stop();
            root._probeUntilOk = false;   // a resume-armed retry has landed
            try {
                var data = JSON.parse(xhr.responseText);
                root.utcOffsetSeconds = (data.utc_offset_seconds !== undefined) ? data.utc_offset_seconds : NaN;
                var c = data.current;
                root.temperature  = c.temperature_2m;
                root.weatherCode  = c.weather_code;
                root.apparentTemp = c.apparent_temperature;
                root.humidity     = c.relative_humidity_2m;
                root.isDay        = c.is_day;
                root.uvIndex      = c.uv_index;
                root.precipRate   = (c.precipitation !== undefined) ? c.precipitation : NaN;
                root.windSpeed    = (c.wind_speed_10m !== undefined) ? c.wind_speed_10m : NaN;
                root.windGust     = (c.wind_gusts_10m !== undefined) ? c.wind_gusts_10m : NaN;
                root.cloudCover   = (c.cloud_cover !== undefined) ? c.cloud_cover : NaN;
                if (data.daily && data.daily.time) {
                    var dd = data.daily;
                    var darr = [];
                    for (var di = 0; di < dd.time.length; ++di)
                        darr.push({
                            date: dd.time[di],
                            code: dd.weather_code[di],
                            hi:   dd.temperature_2m_max[di],
                            lo:   dd.temperature_2m_min[di],
                            snowSum:   (dd.snowfall_sum && di < dd.snowfall_sum.length) ? dd.snowfall_sum[di] : NaN,
                            precipSum: (dd.precipitation_sum && di < dd.precipitation_sum.length) ? dd.precipitation_sum[di] : NaN,
                            // local-time ISO strings ("2026-06-16T06:18") — timezone=auto
                            sunrise:   (dd.sunrise && di < dd.sunrise.length) ? dd.sunrise[di] : "",
                            sunset:    (dd.sunset  && di < dd.sunset.length)  ? dd.sunset[di]  : ""
                        });
                    root.dailyData = darr;
                    root.highTemp = dd.temperature_2m_max[0];
                    root.lowTemp  = dd.temperature_2m_min[0];
                    root.precipSumToday = (dd.precipitation_sum && dd.precipitation_sum.length)
                                          ? dd.precipitation_sum[0] : NaN;
                    root.precipChanceToday = (dd.precipitation_probability_max && dd.precipitation_probability_max.length)
                                          ? dd.precipitation_probability_max[0] : NaN;
                    root.snowSumToday = (dd.snowfall_sum && dd.snowfall_sum.length)
                                        ? dd.snowfall_sum[0] : NaN;
                }
                if (data.hourly && data.hourly.time) {
                    var hh = data.hourly;
                    var harr = [];
                    for (var hi = 0; hi < hh.time.length; ++hi)
                        harr.push({
                            time:    hh.time[hi],
                            date:    hh.time[hi].substring(0, 10),
                            temp:    hh.temperature_2m[hi],
                            feels:   hh.apparent_temperature ? hh.apparent_temperature[hi] : NaN,
                            code:    hh.weather_code[hi],
                            day:     hh.is_day[hi],
                            humidity: hh.relative_humidity_2m ? hh.relative_humidity_2m[hi] : NaN,
                            uv:       hh.uv_index ? hh.uv_index[hi] : NaN,
                            precip:  hh.precipitation_probability ? hh.precipitation_probability[hi] : NaN,
                            precipAmt: hh.precipitation ? hh.precipitation[hi] : NaN,   // mm this hour
                            snow:    hh.snowfall ? hh.snowfall[hi] : NaN,   // cm in that hour
                            cloud:   hh.cloud_cover ? hh.cloud_cover[hi] : NaN,   // % cover, for overcast-snow icon
                            wind:    hh.wind_speed_10m ? hh.wind_speed_10m[hi] : NaN,
                            gust:    hh.wind_gusts_10m ? hh.wind_gusts_10m[hi] : NaN,
                            windDir: hh.wind_direction_10m ? hh.wind_direction_10m[hi] : 0
                        });
                    root.allHourly = harr;
                }
                root.lastGoodFetch = Date.now();   // stamp success → clears the stale marker
                // good data — weatherCode is now ≥ 0, so the boot probe stops
            } catch (e) {
                console.log("Weather: parse error", e);   // probe keeps retrying while weatherCode < 0
            }
        };
        xhr.open("GET", url);
        xhr.send();
        loadingWatchdog.restart();   // see the watchdog — this request may never call back
    }

    // ── Severe-weather alerts (KDE FOSS Public Alert Server) ──────────────
    // Global, FOSS, privacy-focused (alerts.kde.org). Two steps: query a
    // deliberately COARSE bounding box (alertBoxDeg) so the server learns only a
    // rough region — not the point — then pull each matching CAP 1.2 alert.
    // Anything but a clean result → no banner.
    readonly property real alertBoxDeg: 0.3   // ±deg box (~±33 km) around the location
    function fetchAlerts() {
        if (!showAlerts || !hasLocation) { weatherAlerts = []; return; }
        var lat = Plasmoid.configuration.latitude;
        var lon = Plasmoid.configuration.longitude;
        if (lat === undefined || lon === undefined || isNaN(lat) || isNaN(lon)) return;
        // round to ~1 km BEFORE building the box: the box edges are symmetric, so
        // its centre = the coordinate we send. Coarsening here keeps that centre
        // ~1 km-precise, matching the weather request (raw lat/lon would let the
        // server recover the exact point from (min+max)/2).
        lat = coarseCoord(lat);
        lon = coarseCoord(lon);
        var gen = ++root._alertGen;   // this fetch's id; a newer one supersedes it
        var d = alertBoxDeg;
        var url = "https://alerts.kde.org/alert/area"
                + "?min_lat=" + Math.max(-90,  lat - d).toFixed(3)
                + "&max_lat=" + Math.min(90,   lat + d).toFixed(3)
                + "&min_lon=" + Math.max(-180, lon - d).toFixed(3)
                + "&max_lon=" + Math.min(180,  lon + d).toFixed(3);
        var xhr = new XMLHttpRequest();
        xhr.timeout = 8000;   // don't hang on a half-up route at boot (see fetchWeather)
        xhr.ontimeout = function () { if (gen === root._alertGen) root.weatherAlerts = []; };
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (gen !== root._alertGen) return;   // a later fetch already started → drop this
            if (xhr.status !== 200) { root.weatherAlerts = []; return; }
            var ids;
            try { ids = JSON.parse(xhr.responseText) || []; }
            catch (e) { root.weatherAlerts = []; return; }
            if (!ids.length) { root.weatherAlerts = []; return; }
            root._fetchAlertDetails(ids.slice(0, 12), gen);   // cap to keep it polite
        };
        xhr.open("GET", url);
        xhr.send();
    }
    // pull each CAP alert by id, parse, and publish once the whole batch is in
    function _fetchAlertDetails(ids, gen) {
        var results = [], pending = ids.length;
        for (var k = 0; k < ids.length; ++k) {
            var x = new XMLHttpRequest();
            // a hung detail would never decrement `pending`, so results never
            // publish — time it out and count it as a skipped (failed) detail.
            var settle = (function (xhr) {
                var fin = false;
                return function (use) {
                    if (fin || gen !== root._alertGen) return;   // superseded/done → drop
                    fin = true;
                    if (use && xhr.status === 200) {
                        var a = root._parseCapAlert(xhr.responseText);
                        // store the FULL set; the minimum-severity filter is applied at
                        // display time (displayAlerts) so the level can change live
                        if (a) results.push(a);
                    }
                    if (--pending === 0 && gen === root._alertGen) root.weatherAlerts = results;
                };
            })(x);
            x.timeout = 8000;
            x.ontimeout = (function (fn) { return function () { fn(false); }; })(settle);
            x.onreadystatechange = (function (xhr, fn) { return function () {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                fn(true);
            }; })(x, settle);
            // no trailing slash: /alert/{id} 301-redirects to the raw CAP file
            // (QML XHR follows the same-origin redirect automatically)
            x.open("GET", "https://alerts.kde.org/alert/" + encodeURIComponent(ids[k]));
            x.send();
        }
    }
    // CAP 1.2 XML → our alert object. CAP carries one <info> per language; pick
    // the UI language, else English, else the first. (Lightweight regex parse —
    // CAP's structure is regular and QML's XML DOM is awkward with namespaces.)
    function _xmlUnescape(s) {
        return s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
                .replace(/&#39;/g, "'").replace(/&apos;/g, "'").replace(/&amp;/g, "&");
    }
    function _capTag(s, tag) {
        var m = s.match(new RegExp("<" + tag + "\\b[^>]*>([\\s\\S]*?)<\\/" + tag + ">"));
        return m ? root._xmlUnescape(m[1].trim()) : "";
    }
    // ray-cast point-in-polygon. polyStr is a CAP <polygon> ("lat,lon lat,lon …").
    // Runs locally on our exact config coords — nothing is sent.
    function _pointInRing(lon, lat, polyStr) {
        var pts = polyStr.replace(/<\/?polygon>/g, "").trim().split(/\s+/);
        var c = false, n = pts.length;
        for (var i = 0, j = n - 1; i < n; j = i++) {
            var pi = pts[i].split(","), pj = pts[j].split(",");   // CAP order = lat,lon
            var yi = +pi[0], xi = +pi[1], yj = +pj[0], xj = +pj[1];
            if (((yi > lat) !== (yj > lat)) && (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi)) c = !c;
        }
        return c;
    }
    function _parseCapAlert(xml) {
        var infos = xml.match(/<info\b[\s\S]*?<\/info>/g);
        if (!infos || !infos.length) return null;
        var want = Qt.locale().name.substring(0, 2).toLowerCase();
        var chosen = null, english = null;
        for (var i = 0; i < infos.length; ++i) {
            var lang = (root._capTag(infos[i], "language") || "").substring(0, 2).toLowerCase();
            if (lang === want) { chosen = infos[i]; break; }
            if (lang === "en" && !english) english = infos[i];
        }
        var blk = chosen || english || infos[0];
        // Local point-in-polygon filter: if the block carries polygon geometry, drop
        // the alert unless our EXACT point is inside one. Kills neighbour-area false
        // positives (a watch clipping the coarse query box). Geocode-only blocks have
        // no polygon to test → fall through and stay (box behaviour, can't do better).
        var polys = blk.match(/<polygon>[\s\S]*?<\/polygon>/g);
        if (polys && polys.length) {
            var plat = Plasmoid.configuration.latitude;
            var plon = Plasmoid.configuration.longitude;
            var inAny = false;
            for (var p = 0; p < polys.length; ++p)
                if (root._pointInRing(plon, plat, polys[p])) { inAny = true; break; }
            if (!inAny) return null;
        }
        var ev = root._capTag(blk, "event");
        return {
            event:       ev,
            severity:    root._capTag(blk, "severity") || "Unknown",
            headline:    root._capTag(blk, "headline") || ev,
            ends:        root._capTag(blk, "expires") || root._capTag(blk, "onset") || "",
            expires:     root._capTag(blk, "expires") || "",   // real CAP <expires>, for the expiry filter (ends may fall back to onset)
            description: root._capTag(blk, "description") || "",
            instruction: root._capTag(blk, "instruction") || ""
        };
    }

    // ── WMO weather code → human text ─────────────────────────────────────
    function conditionText(code, day) {
        if (code === 0 || code === 1)      return (day === 0) ? i18n("Clear night") : i18n("Clear sky");
        if (code === 2)                    return i18n("Partly cloudy");
        if (code === 3)                    return i18n("Overcast");
        if (code === 45 || code === 48)    return i18n("Fog");
        if (code === 56 || code === 57 || code === 66 || code === 67) return i18n("Freezing rain");
        if (code >= 51 && code <= 67)      return i18n("Rain");
        if (code >= 71 && code <= 77)      return i18n("Snow");
        if (code >= 80 && code <= 82)      return i18n("Showers");
        if (code === 85 || code === 86)    return i18n("Snow showers");
        if (code >= 95)                    return i18n("Thunderstorm");
        return "—";
    }

    // ── Icon packs (registry) ─────────────────────────────────────────────
    // Each entry says how to turn a WMO code into an icon source:
    //   dir/whiteDir/ext → bundled SVG pack using the wi-* stem names below
    //   theme:true       → freedesktop "weather-*" names from the user's icon
    //                      theme (no bundled files; follows the desktop theme)
    // Adding a pack = one entry here (+ its files under contents/icons/<name>/).
    readonly property var iconPacks: ({
        "basmilius": { dir: "../icons/basmilius/32/", whiteDir: "../icons/basmilius-white/32/",
                       ext: ".svg", animated: true },
        "system":    { theme: true, animated: false },
        "custom":    { custom: true, ext: ".svg", animated: false }
    })
    readonly property string iconPackId: iconPacks[Plasmoid.configuration.iconPack]
                                         ? Plasmoid.configuration.iconPack : "basmilius"
    readonly property var _pack: iconPacks[iconPackId]
    // true when the active pack uses theme names (needs Kirigami.Icon, not Image)
    readonly property bool iconPackIsTheme: _pack.theme === true

    // Probability-aware icon code: when an hour's chance of precipitation is high
    // (≥ rainIconThreshold) but its weather_code is only clear/cloudy, show a rain
    // icon. Open-Meteo's deterministic code can read "cloudy" through a likely-rain
    // stretch (it even alternates drizzle/overcast hour-to-hour) while the chance
    // stays high — the chance is the steadier signal, so the icon follows it.
    readonly property int  rainIconThreshold: 60     // chance% — NWS "likely" line
    readonly property real rainAmountThreshold: 0.1  // mm — any predicted precip counts
    // chance% at/under which a card shows NO precip — both the blue rain wash
    // (FullView's rainTideFloor reads this) and the per-hour precip% readout. One
    // source so the tint and the number can never disagree about "is it raining".
    // 20 = NWS "Slight Chance" line (its first firm precip wording); pairs with
    // rainIconThreshold's 60 = NWS "Likely". See DEVELOPMENT for the PoP table.
    readonly property real precipDisplayFloor: 20
    readonly property real snowIconThreshold: 0.1    // cm/hr — at/above this it's snowing; show snow even over a RAIN code (marginal-temp mismatch)
    // cloud% at/above which DAYTIME snow drops the sun-and-cloud glyph for the
    // sun-free "overcast snow" icon — 85 = the METAR/WMO "overcast" (8/8) cutoff.
    readonly property real overcastCloudCover: 85
    // True only for daytime snow under (near-)full overcast — both the static
    // stem (→ wi-overcast-snow) and heroAnim (→ "" so it falls back to that
    // static icon, since there is no overcast-snow GIF) gate on this one predicate
    // so the animated and static paths can never disagree. Night snow is untouched.
    function isOvercastDaySnow(code, day, cloudCover) {
        return day !== 0
            && ((code >= 71 && code <= 77) || code === 85 || code === 86)
            && !isNaN(cloudCover) && cloudCover >= overcastCloudCover;
    }
    function precipAwareCode(code, precip, precipAmt, snow, temp) {
        var snowing = !isNaN(snow) && snow >= snowIconThreshold;
        var freezing = (units === "fahrenheit") ? 32 : 0;
        // Does this hour show precip at all? Either a precip weather_code, OR a
        // clear/cloudy code that a high chance / real amount upgrades to precip
        // (same test the chance-upgrade rule below uses). Both the sub-freezing
        // and mix-band rules need to fire on EITHER, else a cloudy-but-likely hour
        // slips past them and gets rain-upgraded.
        var precipCode = (code >= 51 && code <= 67) || (code >= 71 && code <= 86);
        var chanceUp   = code <= 3 && ((!isNaN(precip) && precip >= rainIconThreshold)
                                    || (!isNaN(precipAmt) && precipAmt >= rainAmountThreshold));
        var hasPrecip  = precipCode || chanceUp;
        // Sub-freezing air can't produce liquid rain/drizzle, yet Open-Meteo can
        // return a plain rain code (or a likely-rain cloudy code) at e.g. -6 °C.
        // Force snow. SKIP explicit freezing-rain codes (56/57/66/67) — legit
        // supercooled liquid, stays sleet.
        var freezingRain = (code === 56 || code === 57 || code === 66 || code === 67);
        if (!isNaN(temp) && temp <= freezing && hasPrecip && !freezingRain)
            return 71;                                // → snow icon (71–77 all map to snow)
        // Just above freezing (~33–39 °F / 0–4 °C), a RAIN code is the dubious one:
        // liquid rain at near-freezing amid cold air is really wintry MIX (verified
        // across GFS/ECMWF/ICON/wttr/met.no — they split, two independents said
        // sleet). So a rain/drizzle/shower hour (or a cloudy hour chance-upgraded to
        // rain) in that band → sleet (66 → wi-sleet). A SNOW code here is left ALONE
        // — it's a confident snow forecast, so consistent snow runs at 35–38 °F stay
        // snow instead of being blanket-converted to sleet. See DEVELOPMENT.
        var mixCeil = (units === "fahrenheit") ? 39 : 4;
        var rainType = (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || chanceUp;
        if (!isNaN(temp) && temp > freezing && temp <= mixCeil && rainType)
            return 66;                                // → sleet icon (56/57/66/67 all map to sleet)
        // Near freezing, Open-Meteo can return a RAIN weather_code while still
        // forecasting snowfall (cm). The amount is the honest signal, so trust it
        // over a rain/drizzle/showers code and show snow — keeping the icon in
        // step with the snow band tint, the snow labels, and the daily total.
        if (snowing && ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)))
            return 71;
        // only override a clear/cloudy code; a high CHANCE or a non-trivial
        // predicted AMOUNT both mean "show precip" (the amount catches hours where
        // Open-Meteo predicts real precip but leaves the chance/code understated).
        if (code <= 3 && ((!isNaN(precip) && precip >= rainIconThreshold)
                       || (!isNaN(precipAmt) && precipAmt >= rainAmountThreshold)))
            // if that precip is falling as snow, show snow — not rain
            return snowing ? 71 : 61;
        return code;
    }

    // ── WMO weather code → basmilius condition stem (night-aware) ─────────
    // cloudCover (optional %) lets daytime snow swap the sun-and-cloud glyph for
    // the sun-free overcast-snow icon when the sky is (near-)fully overcast.
    function conditionStem(code, day, cloudCover) {
        var night = (day === 0);
        if (code === 0 || code === 1)      return night ? "wi-night-clear" : "wi-day-sunny";
        if (code === 2)                    return night ? "wi-night-alt-partly-cloudy" : "wi-day-cloudy";
        if (code === 3)                    return night ? "wi-night-cloudy" : "wi-cloudy";
        if (code === 45 || code === 48)    return night ? "wi-night-fog" : "wi-day-fog";
        // Daytime precip uses SUN-FREE stems (wi-rain/snow/sleet/thunderstorm, derived
        // by stripping the sun from the basmilius wi-day-* glyphs) so the panel/static
        // icon matches the sunless animated WebP heroes — and so a 100%-overcast rain
        // hour doesn't show a sun. Night keeps wi-night-alt-* (moon matches the night WebP).
        // freezing drizzle/rain (56/57/66/67) — the sleet glyph (rain + snowflakes)
        if (code === 56 || code === 57 || code === 66 || code === 67)
            return night ? "wi-night-alt-sleet" : "wi-sleet";
        if (code >= 51 && code <= 67)      return night ? "wi-night-alt-rain" : "wi-rain";
        if (code >= 80 && code <= 82)      return night ? "wi-night-alt-rain" : "wi-rain";
        // overcast daytime snow drops the sun
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return night ? "wi-night-alt-snow"
                         : (isOvercastDaySnow(code, day, cloudCover) ? "wi-overcast-snow" : "wi-snow");
        if (code >= 95)                    return night ? "wi-night-alt-thunderstorm" : "wi-thunderstorm";
        return "wi-cloudy";
    }
    // ── WMO weather code → freedesktop "weather-*" name (System theme pack) ─
    function conditionStemFreedesktop(code, day) {
        var night = (day === 0);
        if (code === 0 || code === 1)   return night ? "weather-clear-night" : "weather-clear";
        if (code === 2)                 return night ? "weather-few-clouds-night" : "weather-few-clouds";
        if (code === 3)                 return "weather-many-clouds";
        if (code === 45 || code === 48) return "weather-fog";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "weather-snow";
        if (code >= 95)                 return "weather-storm";
        // Breeze extension (not in the freedesktop standard set); sparse themes
        // without it fall back to their generic icon — acceptable for the rarer code.
        if (code === 56 || code === 57 || code === 66 || code === 67) return "weather-freezing-rain";
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return "weather-showers";
        return "weather-many-clouds";
    }
    // cloudCover (optional %) → daytime overcast snow gets the sun-free glyph.
    // stemOverride (optional) forces a specific wi-* stem for the bundled/custom
    // packs (e.g. the panel substituting its own overcast-night artwork); theme
    // packs ignore both since they use freedesktop names.
    function conditionIcon(code, day, cloudCover, stemOverride) {
        if (code < 0) return "weather-none-available";
        if (_pack.theme) return conditionStemFreedesktop(code, day);
        var stem = stemOverride || conditionStem(code, day, cloudCover);
        if (_pack.custom && Plasmoid.configuration.customIconDir)
            return Plasmoid.configuration.customIconDir + "/" + stem + _pack.ext;
        // bundled pack (or custom with no folder chosen → fall back to basmilius)
        var dir = _pack.dir || iconPacks.basmilius.dir;
        return Qt.resolvedUrl(dir) + stem + (_pack.ext || ".svg");
    }
    // White (monochrome) variant — used for the panel/tray icon.
    function conditionIconWhite(code, day, cloudCover, stemOverride) {
        if (code < 0) return "weather-none-available";
        if (_pack.theme) return conditionStemFreedesktop(code, day);
        var stem = stemOverride || conditionStem(code, day, cloudCover);
        if (_pack.custom && Plasmoid.configuration.customIconDir)
            return Plasmoid.configuration.customIconDir + "/" + stem + _pack.ext;
        var dir = _pack.whiteDir || iconPacks.basmilius.whiteDir;
        return Qt.resolvedUrl(dir) + stem + (_pack.ext || ".svg");
    }

    // Sunrise/sunset glyphs for the SimpleView temperature curve are DECORATION,
    // not condition icons, so they always come from the bundled Basmilius colour
    // pack regardless of the active icon pack: the System theme has no
    // sunrise/sunset glyph (conditionIcon would yield a plain sun) and a Custom
    // folder may not include wi-sunrise/wi-sunset at all.
    function sunEventIcon(rise) {
        return Qt.resolvedUrl(iconPacks.basmilius.dir) + (rise ? "wi-sunrise" : "wi-sunset") + ".svg";
    }

    // The clear-night moon artwork (wi-night-clear) packs more visual mass into its
    // box than other condition icons, so it reads oversized at the same pixel size.
    // Scale the HERO down for that condition only (both layouts multiply their hero
    // size by this); everything else stays 1.0.
    function heroScale(code, day) {
        // Other packs (system theme, custom folder) have their own proportions, so
        // render them at the plain configured size rather than leaking these factors.
        if (iconPackId !== "basmilius") return 1.0;
        var night = (day === 0);
        if (night && (code === 0 || code === 1)) return 0.90;   // tame the heavy clear-night moon
        return 1.10;                                            // all other conditions a touch larger
    }

    // Static-icon zoom to match the ANIMATED icons' framing. The Meteocons v3 art
    // fills only ~half its 128 box, so the baked WebPs are centre-cropped 232→160
    // (=1.45×) to fill the icon box. The static SVGs keep the full, mostly-empty
    // box, so with animations OFF they render ~45 % smaller than the GIFs. Apply the
    // same 1.45× crop to the static icons (centre + scale, transparent margins
    // overflow harmlessly) so toggling animations doesn't change the apparent size.
    // Basmilius-only: theme/custom packs fill their own boxes, so they stay 1.0.
    // Per-condition because the glyphs fill their box by very different amounts: the
    // clear-DAY sun already fills ~75 % (rays spread wide), so the full 1.45× makes it
    // overflow and read large — it needs much less zoom than the ~50 %-fill moon.
    function staticIconZoom(code, day) {
        if (iconPackId !== "basmilius") return 1.0;
        if (day !== 0 && (code === 0 || code === 1)) return 1.20;   // sunny: lands at ~0.90 of the box
        if (code === 45 || code === 48) return (232 / 160) * 1.15;  // fog: a touch larger (sun/moon cut at the fog bank reads small)
        return 232 / 160;                                           // others: ~1.45× to fill the empty box
    }

    // ANIMATED-path scale (independent of staticIconZoom). The WebPs fill their frame
    // differently than the SVGs — the baked sun fills ~90 %, vs the SVG sun's ~75 %.
    // So the two paths need DIFFERENT factors to land the sun at the same displayed
    // size (~0.90 of the box): static gets 1.20 above, animated gets 1.0 here. Tune
    // the animated sun here, the static sun in staticIconZoom — they no longer share.
    // Per-condition zoom so each animated WebP's artwork fills the box to ~the sun's
    // extent. The art frames its subjects at different sizes: sun/moon nearly fill the
    // 160px frame (~0.90/0.86), while clouds & precip sit smaller (~0.75–0.79) and fog
    // smallest (~0.72). Factors measured from each frame-0 opaque bbox (sun = reference).
    function iconScale(code, day) {
        if (iconPackId !== "basmilius") return 1.0;
        if (code === 0 || code === 1)   return 1.0;    // sun/moon: already ~fill the frame (reference)
        if (code === 45 || code === 48) return 1.25;   // fog: sits smallest in its frame
        if (code === 3)                 return 1.15;   // overcast cloud: wide but a touch smaller
        return 1.20;                                   // partly-cloudy / rain / snow / sleet / thunder (~0.75 fill)
    }

    // Animated hero (WebP baked from Meteocons) for the header, or "" when the
    // condition has no animation (falls back to the static icon).
    readonly property string _animDir: Qt.resolvedUrl("../icons/animated/")
    function heroAnim(code, day, cloudCover) {
        if (code < 0 || !_pack.animated) return "";
        // Daytime overcast snow → its own no-sun animation (matches the static
        // wi-overcast-snow icon; both gate on isOvercastDaySnow so they agree).
        if (isOvercastDaySnow(code, day, cloudCover)) return _animDir + "overcast-snow.webp";
        var night = (day === 0);
        if (code === 0 || code === 1)   return _animDir + (night ? "starry-night.webp" : "clear.webp");
        if (code === 2)                 return _animDir + (night ? "partly-cloudy-night.webp" : "partly-cloudy-day.webp");
        if (code === 3)                 return _animDir + (night ? "overcast-night.webp" : "clouds.webp");
        if (code === 45 || code === 48) return _animDir + (night ? "fog-night.webp" : "fog-day.webp");   // sun/moon + drifting haze, rays rotating (custom-built from the fill SVG via tools/icon-pipeline/animate_fog.py). Meteocons' Lottie fog hides the sun behind dense haze, so we reproduce its SMIL ourselves.
        if (code >= 95)                 return _animDir + "thunderstorms.webp";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
                                        return _animDir + (night ? "snow-night.webp" : "snow-day.webp");
        if (code === 56 || code === 57 || code === 66 || code === 67)
                                        return _animDir + (night ? "sleet-night.webp" : "sleet-day.webp");
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
                                        return _animDir + (night ? "rain-night.webp" : "rain-day.webp");
        return "";
    }

    // ── UV index → text with WHO category ─────────────────────────────────
    function uvIndexText(uv) {
        if (isNaN(uv)) return "—";
        var v = Math.round(uv * 10) / 10;
        if (v <= 2)  return v + " (" + i18n("Low") + ")";
        if (v <= 5)  return v + " (" + i18n("Moderate") + ")";
        if (v <= 7)  return v + " (" + i18n("High") + ")";
        if (v <= 10) return v + " (" + i18n("Very High") + ")";
        return v + " (" + i18n("Extreme") + ")";
    }

    // ── Value colors ──────────────────────────────────────────────────────
    // Feels-like: warm when apparent sits in the top half of today's range,
    // blue below — ratio-based, so it works in °C or °F without a fixed window.
    function feelsColor(val) {
        var ft = (val === undefined) ? apparentTemp : val;
        if (isNaN(ft) || isNaN(highTemp) || isNaN(lowTemp) || highTemp === lowTemp)
            return Kirigami.Theme.textColor;
        var t = (ft - lowTemp) / (highTemp - lowTemp);
        return t >= 0.5 ? "#ff6e40" : "#42a5f5";
    }
    // Humidity: a "moisture" scale — dry amber → comfortable teal → muggy blue.
    function humidityColor(val) {
        var h = (val === undefined) ? humidity : val;
        if (isNaN(h)) return Kirigami.Theme.textColor;
        if (h < 30)  return "#d4a85f";
        if (h <= 60) return "#4db6ac";
        return "#1e88e5";
    }
    // UV: official WHO exposure-category colors.
    function uvColor(val) {
        var uv = (val === undefined) ? uvIndex : val;
        if (isNaN(uv)) return Kirigami.Theme.textColor;
        if (uv <= 2)  return "#43a047";
        if (uv <= 5)  return "#eab308";
        if (uv <= 7)  return "#fb8c00";
        if (uv <= 10) return "#e53935";
        return "#8e24aa";
    }

    // Location auto-detection is on-demand only — the config page's "Detect now"
    // button (Mullvad, no-logging). No startup detection: boot uses the stored
    // coordinates, so the widget never pings a geolocation service unprompted.
    Component.onCompleted: {
        fetchWeather();
        fetchAlerts();
    }

    Timer {
        interval: Math.max(1, root.refreshMinutes) * 60 * 1000
        running: true
        repeat: true
        onTriggered: { root.fetchWeather(); root.fetchAlerts(); }
    }

    // Staleness clock: 60s granularity is plenty for a 30-min threshold.
    // It doubles as the resume-from-suspend detector. Qt timers run on the
    // MONOTONIC clock, which is frozen while the machine sleeps, so the periodic
    // refresh above wakes up still believing it has most of its interval left —
    // after an 8-hour suspend the widget shows last night's weather until the
    // remainder plays out (or the user refreshes by hand). Date.now() is the wall
    // clock and DOES jump, so a gap far larger than our interval means we were
    // asleep (or the clock was stepped): refetch immediately.
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = Date.now();
            if (root._nowMs > 0 && now - root._nowMs > 150000) {   // 2+ missed ticks
                // arm the free-running retry too: right after resume the route is
                // usually still coming up, so this first attempt often black-holes
                root._bootProbes = 0;
                root._probeUntilOk = true;
                root.fetchWeather();
                root.fetchAlerts();
            }
            root._nowMs = now;
        }
    }

    // Day-boundary refresh: re-fetch just after local midnight so the daily array
    // rolls over (Open-Meteo returns days from the current local day). Without it,
    // "Today" keeps pointing at yesterday until the next periodic refresh — up to
    // refreshInterval minutes. One-shot, rescheduled for the next midnight each time.
    function _msToNextDay() {
        // Roll over at the LOCATION's midnight (locNow), matching the timezone-aware
        // "today"/timeline — not the viewer's. locNow() advances 1:1 with real time
        // (just shifted to the location's wall clock), so the field-difference below
        // is the real elapsed ms to the location's next midnight. Falls back to the
        // viewer's clock when the location offset is unknown, so it's correct either way.
        var now = locNow();
        var next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 20);
        return Math.max(1000, next.getTime() - now.getTime());
    }
    Timer {
        id: dayRollover
        interval: root._msToNextDay()
        running: true
        repeat: false
        onTriggered: {
            root.fetchWeather(); root.fetchAlerts();
            interval = root._msToNextDay();   // reschedule for the following midnight
            restart();
        }
    }

    // Boot resilience. At login the network is often not up when the first fetch
    // fires, so the widget would sit in the "?" state until the next periodic
    // refresh (refreshMinutes — up to 15 min). We retry until the first success,
    // but the retry MUST be driven by a free-running timer, NOT chained off the
    // request's error/timeout callback: a connect black-holed by a half-up route
    // (VPN tunnel mid-handshake) can hang without ever calling back — QML's
    // xhr.timeout doesn't reliably abort a connect stuck in that phase — and a
    // chain kicked only from that dead callback then stalls for the whole ~minute
    // until the OS connect timeout. This timer doesn't wait on the dead socket:
    // each tick aborts the prior attempt (see fetchWeather) and fires a fresh one,
    // so we load within one interval of the route coming up. It stops the instant
    // we have data (weatherCode ≥ 0) and after ~3 min hands off to periodic refresh.
    property var _wxhr: null         // current in-flight weather request (abortable)
    property int _bootProbes: 0
    // Armed by the resume-from-suspend detector. Waking up is the boot case all over
    // again — the wifi is still reassociating, so the refetch hits the same half-up
    // route — except we already HAVE (stale) data, so `weatherCode < 0` is false and
    // the probe below would never run. Without it the widget sat on pre-sleep weather
    // until the next periodic refresh, up to 15 min later.
    property bool _probeUntilOk: false
    Timer {
        id: bootProbe
        interval: 10000              // worst-case wait after the route is up
        repeat: true
        running: (root.weatherCode < 0 || root._probeUntilOk) && _bootProbes < 18   // ~3 min, then leave it to periodic refresh
        onTriggered: { _bootProbes++; root.fetchWeather(); root.fetchAlerts(); }
    }
    // `loading` greys out the Refresh button, so anything that can leave it stuck true
    // takes the button with it — permanently, since the user's own escape hatch is the
    // button. A connect black-holed by a half-up route (see fetchWeather) hangs without
    // ever calling back, and xhr.timeout doesn't reliably fire in that phase, so this
    // clears the flag a beat after xhr.timeout should have. The request itself is left
    // alone; the next fetch aborts it.
    Timer {
        id: loadingWatchdog
        interval: 12000              // > xhr.timeout (8 s): only catches the never-called-back case
        onTriggered: root.loading = false
    }

    Connections {
        target: Plasmoid.configuration
        function onLatitudeChanged()        { root.fetchWeather(); root.weatherAlerts = []; alertsDebounce.restart(); }
        function onLongitudeChanged()       { root.fetchWeather(); root.weatherAlerts = []; alertsDebounce.restart(); }
        function onTemperatureUnitChanged() { root.fetchWeather(); }
        function onWindUnitChanged()        { root.fetchWeather(); }
        function onShowAlertsChanged()      { root.fetchAlerts(); }
        // On first-time setup, lat/lon and locationConfigured commit together on
        // Apply in an unspecified order — fetch on the flag too so weather always
        // loads even if the coordinates happened to write first (while gated off).
        function onLocationConfiguredChanged() { root.fetchWeather(); root.fetchAlerts(); }
        // Auto-fit the Simple popup to the day tabs when the count changes. A new
        // day count is an explicit re-fit gesture, so it clears any manual-resize
        // latch (re-enabling auto-fit). A closed popup re-fits on its next open.
        function onSimpleDailyDaysChanged() {
            Plasmoid.configuration.simplePopupManual = false;
            if (root.expanded) fullRep.armFit();
        }
    }
    // A location switch updates latitude AND longitude as two separate writes;
    // debounce so alerts are fetched once with the FINAL point, not on the first
    // half-changed (stale-longitude) write — which would land on the wrong place.
    Timer {
        id: alertsDebounce
        interval: 400
        onTriggered: root.fetchAlerts()
    }

    compactRepresentation: CompactView { weatherRoot: root }

    // Full popup: switch between the detailed (card) view and the simple (graph)
    // view per the simpleLayout setting. The wrapper forwards the inner view's
    // implicit/minimum sizing so the popup sizes correctly for either layout.
    fullRepresentation: Item {
        id: fullRep
        readonly property var view: !root.hasLocation ? null
                                  : (root.simpleLayout ? simpleLoader.item : detailLoader.item)
        // Pin the WIDTH to the saved size once set. We drive the popup window
        // directly (below), but Plasma still follows this implicit size — and the
        // metric readouts change the view's implicit WIDTH on every scroll/pan, so
        // Plasma kept resizing the popup back to fit (the "resets when I scroll"
        // bug). A stable implicit width = saved width stops it. HEIGHT is NOT pinned:
        // it's stable during scroll (single-line readouts), and pinning it to savedH
        // fed capture → implicitHeight → resize → capture into a runaway vertical
        // grow. First run (unpinned width) tracks the view so the popup opens at its
        // natural size, then self-pins on first capture.
        implicitWidth:  savedW > 0 ? savedW : (view ? view.implicitWidth : Kirigami.Units.gridUnit * 32)
        implicitHeight: view ? view.implicitHeight : Kirigami.Units.gridUnit * 20
        // On the panel the popup keeps its own sizing. On the DESKTOP a widget has ONE
        // stored geometry that Plasma only ever grows (never shrinks) — per-layout or
        // auto-shrink sizing is impossible. We pin the minimum to the content size so
        // the box is always big enough for the active layout (no graph/pills spilling
        // past the edge, toolbar stays in the corner); the box settles at the largest
        // layout's size and both layouts share it. Size is driven by content
        // (Appearance settings). Panel popup keeps its own implicit sizing.
        readonly property real _deskW: view ? view.implicitWidth  : Kirigami.Units.gridUnit * 32
        readonly property real _deskH: view ? view.implicitHeight : Kirigami.Units.gridUnit * 20
        Layout.minimumWidth:  root.planar ? _deskW : (view ? view.Layout.minimumWidth  : 0)
        Layout.minimumHeight: root.planar ? _deskH : (view ? view.Layout.minimumHeight : 0)
        Layout.preferredWidth:  root.planar ? _deskW : implicitWidth
        Layout.preferredHeight: root.planar ? _deskH : implicitHeight

        // On the desktop the widget floats frameless over the wallpaper, so its text
        // can wash out on bright/busy backgrounds. Drop a soft shadow behind the whole
        // view (text + icons) for contrast. Desktop only — the panel popup has its own
        // background. ponytail: one layer effect instead of a shadow on every label;
        // the layer re-rasterises with the hero animation, fine for one desktop widget.
        layer.enabled: root.planar
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.9)
            shadowBlur: 0.55
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
        }

        // ── Per-layout remembered popup size ──────────────────────────────
        // Plasma's AppletPopup owns the window size: it keeps ONE shared
        // popupWidth/popupHeight (saved on close, restored once on creation)
        // and ignores our Layout hints once a size is set. To give each
        // layout its own size we drive the popup window directly — restore
        // the active layout's saved size on open and on layout switch, and
        // capture user drags back into that layout's keys. We store the
        // CONTENT size (this Item's width/height); the window chrome delta is
        // measured live and re-added when applying, so 0 means "use the view's
        // implicit size" (first run).
        readonly property int savedW: root.simpleLayout ? Plasmoid.configuration.simplePopupWidth
                                                        : Plasmoid.configuration.detailPopupWidth
        readonly property int savedH: root.simpleLayout ? Plasmoid.configuration.simplePopupHeight
                                                        : Plasmoid.configuration.detailPopupHeight
        property bool _applying: false

        // On the desktop (Planar form factor) the full rep is embedded directly
        // in the containment view — its Window IS the desktop, not a popup. The
        // size-driving below would then resize the desktop window itself, which
        // a user reads as "it resizes the wallpaper" / "zooms in on layout switch"
        // (KDE Neon / Plasma 6.7 bug report). Return null off-panel so every
        // driver here no-ops; the embedded widget just sizes from its Layout hints.
        function _win() {
            if (Plasmoid.formFactor === PlasmaCore.Types.Planar) return null;
            return fullRep.Window.window;
        }

        function applySize() {
            var win = _win();
            if (!win || fullRep.width <= 0) return;
            var chromeW = win.width  - fullRep.width;
            var chromeH = win.height - fullRep.height;
            var w = (savedW > 0 ? savedW : Math.round(implicitWidth))  + chromeW;
            var h = (savedH > 0 ? savedH : Math.round(implicitHeight)) + chromeH;
            _applying = true;
            win.width  = w;
            win.height = h;
            Qt.callLater(function () { fullRep._applying = false; });
        }

        function captureSize() {
            if (_applying || fullRep.width <= 0 || fullRep.height <= 0) return;
            if (root.planar) return;   // desktop auto-fits to content; nothing to capture
            if (root.simpleLayout) {
                Plasmoid.configuration.simplePopupWidth  = Math.round(fullRep.width);
                Plasmoid.configuration.simplePopupHeight = Math.round(fullRep.height);
            } else {
                Plasmoid.configuration.detailPopupWidth  = Math.round(fullRep.width);
                Plasmoid.configuration.detailPopupHeight = Math.round(fullRep.height);
            }
        }

        // User drags resize this Item; debounce, then store under the active
        // layout. Skipped while we're applying a size ourselves. Stamp the time of
        // a real (non-self) size change so _reflow can tell a drag from a content
        // reflow and not fight an in-progress resize.
        property double _lastDragMs: 0
        // A non-self WIDTH change is a user drag → latch "manual" so auto-fit-to-tabs
        // stops overriding their chosen width (Simple layout only; cleared on a day-
        // count change). Height drags don't disable width auto-fit.
        onWidthChanged:  {
            if (!_applying) {
                _lastDragMs = Date.now();
                if (root.simpleLayout) Plasmoid.configuration.simplePopupManual = true;
            }
            captureTimer.restart();
        }
        onHeightChanged: { if (!_applying) _lastDragMs = Date.now(); captureTimer.restart(); }
        Timer { id: captureTimer; interval: 250; onTriggered: fullRep.captureSize() }

        // A font/metric change alters the view's implicit (and minimum) size, so
        // Plasma would resize the popup to fit and the capture above would overwrite
        // the user's saved drag. On such a reflow, re-assert the PINNED dimension(s)
        // and drop the pending capture. Two musts, learned the hard way:
        //  • Only PINNED dims — re-applying an UNPINNED dim snaps it to the implicit
        //    size, which the live readouts nudge on every scroll → window jitter.
        //  • Skip if a real resize just happened (_lastDragMs): a drag's size change
        //    fires FIRST, so a drag-induced reflow must not fight the drag. A font
        //    change has no preceding size change, so it still re-asserts.
        // While a fit is "armed" (just opened / switched to Simple / changed the day
        // count), the view is still laying out its tabs — its implicit width keeps
        // changing for a few frames. Re-run the fit on each of those changes so we
        // measure the SETTLED width, not a half-laid-out one (the fresh-widget "didn't
        // auto-fit on first open" bug). Outside the armed window this does nothing, so
        // scroll-time readout nudges never trigger a resize. fitToTabs disarms once the
        // width converges.
        property double _fitArmedUntil: 0
        function armFit() {
            if (!root.simpleLayout) return;
            _fitArmedUntil = Date.now() + 1200;
            fitTimer.restart();
        }
        onImplicitWidthChanged:  {
            _reflow();
            if (root.simpleLayout && !Plasmoid.configuration.simplePopupManual
                && Date.now() < _fitArmedUntil) fitTimer.restart();
        }
        onImplicitHeightChanged: _reflow()
        function _reflow() {
            if (savedW <= 0 && savedH <= 0) return;      // nothing pinned → let implicit drive
            if (Date.now() - _lastDragMs < 200) return;  // a resize is in progress → don't fight it
            var win = _win();
            if (!win || fullRep.width <= 0) return;
            captureTimer.stop();
            _applying = true;
            var chromeW = win.width  - fullRep.width;
            var chromeH = win.height - fullRep.height;
            if (savedW > 0) win.width  = savedW + chromeW;
            if (savedH > 0) win.height = savedH + chromeH;
            Qt.callLater(function () { fullRep._applying = false; });
        }

        // Auto-fit the Simple popup to the day tabs — for ANY day count, growing OR
        // shrinking to an exact fit (the pills live in the header row, so the count
        // drives the view's implicit width; SimpleView floors it at gridUnit*34 so
        // few days don't shrink it absurdly). Runs only on the discrete count-change
        // events (popup open + a simpleDailyDays change) — never on scroll, where the
        // live metric readouts also nudge the implicit width. A manual width resize
        // latches simplePopupManual, which suppresses this so the user's size sticks.
        // The timer lets the new pills lay out before we measure.
        function fitToTabs() {
            if (!root.simpleLayout || !view) return;
            if (Plasmoid.configuration.simplePopupManual) return;   // manual size wins
            var win = _win();
            if (!win || fullRep.width <= 0) return;
            // implicitWidth is an EXACT fit — SimpleView's header runs edge-to-edge
            // with negative margins, so it leaves no slack and a wide readout (e.g.
            // "UV index … Very High") spills the last day tab past the right edge.
            // Add headroom so the header spacer keeps breathing room and a changing
            // readout is absorbed there instead of clipping the tabs.
            var need = Math.round(view.implicitWidth) + Kirigami.Units.gridUnit * 2;
            if (Math.abs(fullRep.width - need) < 2) { _fitArmedUntil = 0; return; }  // converged → disarm
            Plasmoid.configuration.simplePopupWidth = need;    // persist the fitted width…
            Qt.callLater(applySize);                           // …and apply it now
        }
        Timer { id: fitTimer; interval: 60; onTriggered: fullRep.fitToTabs() }

        // Apply the saved size on open and on layout switch. ⚠️ NOT on savedW/H
        // change — capture writes those on every drag, and re-applying then both
        // fought the drag and yanked the unpinned dimension to its implicit size.
        Component.onCompleted: { Qt.callLater(applySize); armFit(); }

        // Resizing the popup BEFORE the newly-shown view paints stretches the stale
        // buffer for a frame, so on a switch we resize a couple frames later — the
        // warm view is already up at the old size, correct content and all.
        Timer { id: resizeAfterPaint; interval: 48; onTriggered: fullRep.applySize() }

        Connections {
            target: root
            function onExpandedChanged()    { if (root.expanded) { Qt.callLater(fullRep.applySize); fullRep.armFit(); } }
            // Both views stay warm (loaders below), so a switch just flips which is
            // visible — no rebuild, no blank frame. Resize after the shown view paints.
            function onSimpleLayoutChanged() { resizeAfterPaint.restart(); fullRep.armFit(); }
        }

        // Keep BOTH layouts instantiated once a location is set, toggling visibility
        // instead of swapping a single Loader's sourceComponent. Destroying + recreating
        // the view on every switch left an empty frame (the "flash"); a warm view paints
        // the instant it's shown. active:false until hasLocation keeps the lazy-until-
        // located behaviour and lets the empty-state notice below stand in.
        Loader {
            id: detailLoader
            anchors.fill: parent
            active: root.hasLocation
            visible: !root.simpleLayout
            sourceComponent: detailComp
        }
        Loader {
            id: simpleLoader
            anchors.fill: parent
            active: root.hasLocation
            visible: root.simpleLayout
            sourceComponent: simpleComp
        }
        Component { id: detailComp; FullView   { weatherRoot: root } }
        Component { id: simpleComp; SimpleView { weatherRoot: root } }

        // Out of the box there is no default city, so this stands in for the weather
        // view (null above). hasLocation flips in configLocation's _setLocation and
        // the manual lat/lon fields.
        Kirigami.InlineMessage {
            id: locationHint
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Kirigami.Units.largeSpacing
            z: 100
            visible: !root.hasLocation
            type: Kirigami.MessageType.Information
            text: i18n("No location set. Open settings to choose where to show the weather.")
            actions: [
                Kirigami.Action {
                    text: i18n("Open settings")
                    icon.name: "configure"
                    onTriggered: Plasmoid.internalAction("configure").trigger()
                }
            ]
        }
    }
}
