/*
 * Full (popup) representation — header, daily tabs, and a continuous
 * scrollable/draggable hourly timeline with day-break dividers. Scrolling the
 * timeline highlights the matching day tab; clicking a tab scrolls to that day.
 * Copyright 2026  bvlthvzvr — SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: full

    property var weatherRoot
    property int selectedDay: 0
    // hour whose card the pointer is over, so the header's instantaneous metrics
    // (cloud, humidity, UV, feels, wind) track it like the graph scrubs — null when
    // not hovering, so they fall back to the current reading. Day-based metrics
    // (precip/snow totals, sun) keep following selectedDay regardless.
    property var hoveredHourSample: null

    // Uniform padding around the whole popup
    readonly property int pad: Math.round(Kirigami.Units.gridUnit * 0.85)

    // Shared top margin for the two top-aligned header blocks (metrics and
    // condition/location) so the condition's top always lines up with the first
    // metric line ("Feels like"), independent of the condition font size.
    readonly property int headerBlockTop: Math.round(Kirigami.Units.gridUnit * 0.95)

    // A bigger font has more empty space above its caps (internal leading), so a
    // top-aligned 26px condition would sit ~5px lower than the 13px metric line.
    // Lift it by an amount proportional to the font-size gap so the VISIBLE tops
    // align at any condition font size.
    readonly property int condTopFix: Math.round(
        ((weatherRoot ? weatherRoot.conditionFontSize : 26)
         - (weatherRoot ? weatherRoot.headerInfoFontSize : 13)) * 0.55)

    // Hourly timeline geometry (used for both layout and scroll math)
    // Card width FLEXES to the visible strip: a whole number of cards fills the
    // width exactly, so the last card is never chopped off — whatever width the box
    // ends up (on the desktop it's dictated by the graph layout's size). Falls back
    // to the base width before the strip has a width. ponytail: targets hour cards;
    // a day-break divider in view leaves a small remainder, but the common
    // resting view (today, no midnight in frame) fills cleanly.
    readonly property int hourCardBaseW: Math.round(Kirigami.Units.gridUnit * 5.9)
    readonly property int hourCardW: {
        var avail = hourlyFlick.width;
        if (avail <= 0) return hourCardBaseW;
        var n = Math.max(1, Math.round(avail / (hourCardBaseW + hourGap)));   // whole cards that fit
        return Math.max(Math.round(hourCardBaseW * 0.8),
                        Math.floor((avail - (n - 1) * hourGap) / n));          // fill the width exactly
    }
    readonly property int hourCardH: (weatherRoot ? weatherRoot.hourlyIconSize : 32)
                                     + Math.round(Kirigami.Units.gridUnit * 8)
    readonly property int dayBreakW: Math.round(Kirigami.Units.gridUnit * 2.2)
    readonly property int hourGap:   Kirigami.Units.smallSpacing * 2
    // Fixed height for a per-hour readout row. Each card always reserves this
    // height per configured metric (even when a given hour has no value, e.g.
    // snow on a dry hour), so the centered time/icon/temp cluster sits at the
    // same Y on every card instead of drifting between 1- and 2-readout hours.
    // Must clear the TALLEST content — the wind glyph at 1.6× the readout font.
    // Its line box runs taller than its em, so + smallSpacing of headroom keeps
    // it fully inside the row (else it overflows downward and crowds line 2).
    readonly property int hourMetricRowH: Math.max(
        Kirigami.Units.iconSizes.small,
        Math.round((weatherRoot ? weatherRoot.hourlyCardFontSize : 11) * 1.6)
            + Kirigami.Units.smallSpacing)

    // ── "Corner split" precip gradient for hourly cards (precip-corner-split.js) ──
    // Rain blooms from the BOTTOM-LEFT corner in blue; snow blooms from the
    // TOP-RIGHT corner in white. Each corner grows + brightens with its share of
    // the precip chance, so a wintry-mix hour shows a diagonal of both, an all-rain
    // hour is just blue, an all-snow hour just white. Dry/low hours stay clean.
    readonly property var  rainBlue:      [66, 165, 245]    // #42a5f5 rain hue
    readonly property var  snowWhite:     [234, 242, 255]   // snow
    readonly property real rainTideFloor: weatherRoot ? weatherRoot.precipDisplayFloor : 15   // shared floor: % at/under which a card stays clean (no wash, no readout)
    function rainTideT(pct) {                // overall intensity 0..1 (0 at floor, 1 at 100%)
        if (isNaN(pct)) return 0;
        var t = (pct - rainTideFloor) / (100 - rainTideFloor);
        return t < 0 ? 0 : (t > 1 ? 1 : t);
    }
    // Fraction of the precip falling as snow (0 = all rain → blue corner, 1 = all
    // snow → white corner). Gate on the SAME icon the card shows (precipAwareCode)
    // so a snow glyph ALWAYS gets a white corner — even a flurry that accumulates to
    // ~0. Then grade the split by air temp: a clearly-cold hour reads pure white,
    // while a near-freezing snow hour keeps a blue corner too (the wintry-mix
    // diagonal). Rain-coded hours stay all blue.
    function snowFraction(code, precip, precipAmt, snowCm, temp) {
        var ic = weatherRoot ? weatherRoot.precipAwareCode(code, precip, precipAmt, snowCm, temp) : code;
        // Sleet (56/57/66/67) is a rain/snow MIX — give it a half-and-half wash so
        // the corner shows both colours, matching the sleet glyph (the marginal-band
        // hours land here; pure blue read as plain rain under a "light snow" label).
        if (ic === 56 || ic === 57 || ic === 66 || ic === 67) return 0.5;
        if (!((ic >= 71 && ic <= 77) || ic === 85 || ic === 86)) return 0;   // icon says rain → all blue
        if (isNaN(temp)) return 1;
        var f = weatherRoot && weatherRoot.units === "fahrenheit";
        var tAllSnow = f ? 31 : -0.5, tAllRain = f ? 37 : 3;
        var frac = (tAllRain - temp) / (tAllRain - tAllSnow);
        frac = frac < 0 ? 0 : (frac > 1 ? 1 : frac);
        return Math.max(0.45, frac);         // snow per icon → keep a visible blue hint when marginal
    }
    function tideRgbaStr(c, a) { return "rgba(" + c[0] + "," + c[1] + "," + c[2] + "," + a.toFixed(3) + ")"; }

    // true while the hourly strip is in motion (drag/flick or wheel/tab animation);
    // hourly card animations pause during this for smooth scrolling
    readonly property bool scrolling: hourlyFlick.moving || scrollAnim.running

    // Animated hero source for the current condition ("" → use static icon).
    // Suppressed when forecast animation is set to None (fullHeaderAnim false).
    // Always resolve the WebP so the hero shows the SAME artwork whether animation is on
    // or off (frozen frame 0 when off — see `playing` below). Static SVG only for
    // conditions heroAnim has no WebP for. Keeps the hero consistent with the cards.
    readonly property string _heroAnim: (weatherRoot)
        ? weatherRoot.heroAnim(weatherRoot.weatherCode, weatherRoot.isDay, weatherRoot.cloudCover) : ""

    // bumping this re-deals the hourly cards (entrance animation). Fires on
    // creation (layout switch recreates the view) and on every popup open.
    property int dealRun: 0
    Component.onCompleted: dealRun++
    Connections {
        target: full.weatherRoot
        function onExpandedChanged() {
            if (full.weatherRoot.expanded) {
                scrollAnim.stop();
                hourlyFlick.contentX = 0;   // always reopen on today's tab
                full.dealRun++;
            }
        }
    }

    // Weather Icons font for the hourly wind-direction arrow glyphs
    FontLoader {
        id: wiFont
        source: Qt.resolvedUrl("../fonts/weathericons-regular-webfont.ttf")
    }

    // toolbar buttons floated at the very top-right corner (out of the header
    // flow, so they don't push the condition/location down)
    WeatherToolbar {
        pad: full.pad
        switchTooltip: i18n("Switch to graph layout")
        root: weatherRoot
    }

    implicitWidth:  content.implicitWidth  + pad * 2
    implicitHeight: content.implicitHeight + pad + Math.round(pad * 0.4)
    Layout.minimumWidth: Kirigami.Units.gridUnit * 32 + pad * 2

    // Continuous hourly model — rebuilds after each fetch and when the day count
    // changes (those properties are read here to register the dependency).
    readonly property var timeline: {
        if (!weatherRoot) return [];
        var _dep1 = weatherRoot.allHourly;
        var _dep2 = weatherRoot.dailyDays;
        return weatherRoot.timeline();
    }

    // x offset to open a day at its configured start hour (detailDayStartHour:
    // 6 = 6AM, skipping the overnight cards; 0 = midnight) — except "today"
    // (index 0), which opens at its first available card, i.e. the current hour.
    function dayCardX(dayIdx) {
        if (!weatherRoot || dayIdx < 0 || dayIdx >= weatherRoot.dailyData.length) return 0;
        var date = weatherRoot.dailyData[dayIdx].date;
        var pos = 0, firstPos = -1;
        for (var i = 0; i < timeline.length; ++i) {
            var e = timeline[i];
            if (!e.dayBreak && e.date === date) {
                if (firstPos < 0) firstPos = pos;
                if (dayIdx !== 0 && new Date(e.time).getHours() >= weatherRoot.detailDayStartHour) return pos;
            }
            pos += (e.dayBreak ? dayBreakW : hourCardW) + hourGap;
        }
        return firstPos < 0 ? 0 : firstPos;
    }

    // which day index sits at the left edge for a given scroll offset
    function leadingDay(contentX) {
        if (!weatherRoot) return 0;
        var pos = 0;
        for (var i = 0; i < timeline.length; ++i) {
            var e = timeline[i];
            var w = e.dayBreak ? dayBreakW : hourCardW;
            if (contentX < pos + w)
                return weatherRoot.dayIndexForDate(e.date);
            pos += w + hourGap;
        }
        return 0;
    }

    // clicking a day tab animates the timeline to that day's first card
    function scrollToDay(dayIdx) {
        var target = Math.min(dayCardX(dayIdx),
                              Math.max(0, hourlyFlick.contentWidth - hourlyFlick.width));
        scrollAnim.stop();
        scrollAnim.from = hourlyFlick.contentX;
        scrollAnim.to = target;
        scrollAnim.start();
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: full.pad
        anchors.rightMargin: full.pad
        anchors.bottomMargin: full.pad
        anchors.topMargin: Math.round(full.pad * 0.4)
        spacing: Kirigami.Units.smallSpacing

        // ── Header ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: -Math.round(Kirigami.Units.gridUnit * 0.35)   // lift the whole header up slightly
            spacing: Kirigami.Units.largeSpacing

            Item {
                // hero size, shrunk for the visually-heavy clear-night moon
                readonly property int heroSz: Math.round((weatherRoot ? weatherRoot.heroIconSize : 96)
                    * (weatherRoot ? weatherRoot.heroScale(weatherRoot.weatherCode, weatherRoot.isDay) : 1))
                Layout.preferredWidth:  heroSz
                Layout.preferredHeight: heroSz
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: -Math.round(Kirigami.Units.gridUnit * 0.6)   // shift the whole left cluster (icon+temp+metrics) left
                Layout.topMargin: -Math.round(Kirigami.Units.gridUnit * 0.45)   // lift icon up a bit more

                // static basmilius icon when the condition has no animation — zoomed
                // to match the animated icons' baked-in 1.45× crop (see staticIconZoom)
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(parent.width * (weatherRoot ? weatherRoot.staticIconZoom(weatherRoot.weatherCode, weatherRoot.isDay) : 1))
                    height: width
                    roundToIconSize: false   // honor the exact zoom; don't snap to 32/48
                    visible: full._heroAnim.length === 0
                    source: weatherRoot ? weatherRoot.conditionIcon(weatherRoot.weatherCode, weatherRoot.isDay, weatherRoot.cloudCover)
                                        : "weather-none-available"
                }
                // animated hero (GIF/WebP) otherwise
                AnimatedImage {
                    anchors.fill: parent
                    visible: full._heroAnim.length > 0
                    source: full._heroAnim
                    // animate only when forecast animation is on; otherwise hold frame 0
                    playing: visible && weatherRoot && weatherRoot.fullHeaderAnim
                    cache: false
                    smooth: true
                    mipmap: true
                    fillMode: Image.PreserveAspectFit
                }
            }
            Label {
                text: weatherRoot ? weatherRoot.temperatureText : "—"
                color: Kirigami.Theme.textColor
                font.pixelSize: weatherRoot ? weatherRoot.tempFontSize : 54
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
                Layout.topMargin: -Math.round(Kirigami.Units.gridUnit * 0.7)   // lift temp up a bit more
            }
            ColumnLayout {
                spacing: 0
                // TOP-aligned (shared headerBlockTop) so the condition/location
                // block can lock its top to "Feels like" at any font size — keep
                // this topMargin identical to the condition block's below.
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: full.headerBlockTop
                Layout.leftMargin: -Math.round(Kirigami.Units.gridUnit * 0.3)   // and slightly left
                // user-selected header metrics (up to 4); the "!" alert indicator
                // sits next to the first line (feels like by default)
                Repeater {
                    model: weatherRoot ? weatherRoot.headerMetrics : []
                    delegate: RowLayout {
                        id: metricRow
                        required property int index
                        required property var modelData
                        // pass the focused day so day-based metrics (sun, precip/snow totals)
                        // follow the timeline. For the hour: the hovered card while the pointer
                        // is over the strip, else the CURRENT hour's sample — so when nothing's
                        // hovered the instantaneous metrics read "now" the same way the cards do
                        // (the current-hour forecast), not the slightly-different live block.
                        readonly property string metric: weatherRoot ? weatherRoot.metricText(modelData, full.selectedDay, full.hoveredHourSample || weatherRoot.currentHourSample) : ""
                        // keep the FIRST row visible for the alert "!" even when its
                        // metric text is empty (e.g. metric set to "none", or a precip
                        // metric that's blank on a dry day) — an invisible parent would
                        // hide the AlertIndicator child along with the row.
                        visible: metric.length > 0
                                 || (index === 0 && weatherRoot && weatherRoot.showAlerts
                                     && weatherRoot.topAlert !== null)
                        spacing: Kirigami.Units.smallSpacing
                        Label {
                            textFormat: Text.StyledText
                            font.bold: true
                            font.pixelSize: weatherRoot ? weatherRoot.headerInfoFontSize : 13
                            text: metricRow.metric
                        }
                        AlertIndicator {
                            weatherRoot: full.weatherRoot
                            visible: metricRow.index === 0 && weatherRoot
                                     && weatherRoot.showAlerts && weatherRoot.topAlert !== null
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
            Item { Layout.fillWidth: true }
            ColumnLayout {
                // TOP-aligned with the SAME margin as the metrics block, so the
                // condition's top always lines up with "Feels like" — when the
                // font grows the block extends downward, top stays locked.
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: full.headerBlockTop - full.condTopFix
                Layout.rightMargin: -Math.round(Kirigami.Units.gridUnit * 0.5)   // nudge condition/location right
                spacing: Kirigami.Units.smallSpacing

                Label {
                    Layout.alignment: Qt.AlignRight
                    horizontalAlignment: Text.AlignRight
                    text: weatherRoot ? weatherRoot.conditionText(weatherRoot.weatherCode, weatherRoot.isDay) : ""
                    font.bold: true
                    font.pixelSize: weatherRoot ? weatherRoot.conditionFontSize : 26
                }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    Layout.topMargin: -Math.round(Kirigami.Units.gridUnit * 0.35)   // pull location up closer to condition
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        source: "mark-location"
                        roundToIconSize: false   // render at the exact size, not snapped to 16/22/32
                        // scale the pin with the condition/location font so they stay balanced
                        Layout.preferredWidth:  Math.round((weatherRoot ? weatherRoot.conditionFontSize : 26) * 1.17)
                        Layout.preferredHeight: Math.round((weatherRoot ? weatherRoot.conditionFontSize : 26) * 1.17)
                    }
                    Label {
                        text: weatherRoot ? weatherRoot.locationShortName : ""
                        font.bold: true
                        font.pixelSize: weatherRoot ? weatherRoot.conditionFontSize : 26
                    }
                }
            }
        }

        // ── Daily tabs (count limited by the dailyDays setting) ───────────
        // wrapped in a plain Item so the sliding highlight can live OUTSIDE the
        // RowLayout — a RowLayout manages every child item, so a highlight
        // inside it would be grabbed as a layout cell and lose its x/width
        Item {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            implicitHeight: dayTabsRow.implicitHeight

            // single selection highlight that SLIDES between tabs (drawn under
            // the RowLayout; same coordinate space since the row fills this Item)
            Rectangle {
                readonly property Item sel: dayTabsRep.count > full.selectedDay
                                            ? dayTabsRep.itemAt(full.selectedDay) : null
                visible: sel !== null
                x: sel ? sel.x : 0
                y: sel ? sel.y : 0
                width: sel ? sel.width : 0
                height: sel ? sel.height : 0
                radius: 8
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                               Kirigami.Theme.textColor.b, 0.10)
                Behavior on x     { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
            }

            RowLayout {
            id: dayTabsRow
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                id: dayTabsRep
                model: weatherRoot ? weatherRoot.dailyData.slice(0, weatherRoot.dailyDays) : []
                delegate: Rectangle {
                    id: dayTab
                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: dayCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                    radius: 8
                    readonly property bool selected: index === full.selectedDay
                    // selection is drawn by the sliding highlight; tabs only
                    // paint their hover state
                    color: tabHover.hovered ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                  Kirigami.Theme.textColor.b, 0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: 200 } }

                    HoverHandler { id: tabHover }
                    TapHandler { onTapped: full.scrollToDay(dayTab.index) }

                    ColumnLayout {
                        id: dayCol
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: weatherRoot ? weatherRoot.dayName(dayTab.index) : ""
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                            font.bold: dayTab.selected
                        }
                        Item {
                            id: dayIcon
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth:  weatherRoot ? weatherRoot.dailyIconSize : 24
                            Layout.preferredHeight: weatherRoot ? weatherRoot.dailyIconSize : 24

                            // Always resolve the WebP so the static (anim-off) tab matches the animated
                            // one and the hourly cards — frozen frame 0 when off (playing gated below).
                            // Daily tabs always use the day variant. Falls back to SVG only when "".
                            readonly property string animSrc: (weatherRoot && dayTab.modelData)
                                ? weatherRoot.heroAnim(dayTab.modelData.code, 1) : ""
                            // per-condition fine-tune (sunny trimmed); daily is always day variant
                            readonly property real iScale: weatherRoot ? weatherRoot.iconScale(dayTab.modelData.code, 1) : 1

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: Math.round(parent.width * (weatherRoot ? weatherRoot.staticIconZoom(dayTab.modelData.code, 1) : 1))
                                height: width
                                roundToIconSize: false   // honor the exact zoom; don't snap to 32/48
                                visible: dayIcon.animSrc.length === 0
                                source: weatherRoot ? weatherRoot.conditionIcon(dayTab.modelData.code, 1)
                                                    : "weather-none-available"
                            }
                            AnimatedImage {
                                anchors.centerIn: parent
                                width: Math.round(parent.width * dayIcon.iScale)
                                height: width
                                visible: dayIcon.animSrc.length > 0
                                source: dayIcon.animSrc
                                // animate only when daily-icon animation is on; else hold frame 0
                                playing: visible && weatherRoot && weatherRoot.animatedDailyIcons
                                cache: false
                                smooth: true
                                mipmap: true
                                fillMode: Image.PreserveAspectFit
                            }
                        }
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            textFormat: Text.StyledText
                            text: weatherRoot
                                ? "<b><font color=\"#42a5f5\">" + weatherRoot.tempStr(dayTab.modelData.lo) + "</font> | "
                                  + "<font color=\"#ff6e40\">" + weatherRoot.tempStr(dayTab.modelData.hi) + "</font></b>" : ""
                        }
                    }
                }
            }
            }
        }

        // ── Continuous hourly timeline (scroll + drag) ────────────────────
        Flickable {
            id: hourlyFlick
            Layout.fillWidth: true
            Layout.preferredHeight: full.hourCardH + Kirigami.Units.smallSpacing * 2
            Layout.topMargin: Math.round(Kirigami.Units.largeSpacing * 1.6)   // gap between tabs and hourly
            Layout.leftMargin: Kirigami.Units.largeSpacing                     // inset from the day tabs
            Layout.rightMargin: Kirigami.Units.largeSpacing
            contentWidth: hourlyRow.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            // Whenever the pointer isn't over the hourly strip at all, drop the hovered
            // hour so the header readouts fall back to the current ("now") reading. The
            // per-card HoverHandlers pick the hour while inside; this is the robust catch-all
            // for leaving the section (a fast exit can skip a card's own hovered=false, and
            // a stale identity-guard miss would otherwise leave the header stuck on an hour).
            HoverHandler { onHoveredChanged: if (!hovered) full.hoveredHourSample = null }

            // track scroll direction so cards deal in from the side they enter
            property real _prevContentX: 0
            property int scrollDir: 1   // 1 = entering from right, -1 = from left
            onContentXChanged: {
                scrollDir = contentX >= _prevContentX ? 1 : -1;
                _prevContentX = contentX;
                full.selectedDay = full.leadingDay(contentX);
            }

            // vertical mouse wheel (or touchpad) scrolls the strip horizontally,
            // animated through the same scrollAnim used by tab clicks. One notch
            // (120) moves ~1.4 card pitches; touchpad pixel deltas move 1:1.
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (wheel) => {
                    var maxX = Math.max(0, hourlyFlick.contentWidth - hourlyFlick.width);
                    var ad = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                    var pd = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.pixelDelta.x;
                    // accumulate onto the in-flight target so rapid notches stack smoothly
                    var base = scrollAnim.running ? scrollAnim.to : hourlyFlick.contentX;
                    var targetX = (pd !== 0)
                        ? base - pd
                        : base - (ad / 120) * (full.hourCardW + full.hourGap) * 1.4;
                    targetX = Math.max(0, Math.min(maxX, targetX));
                    scrollAnim.stop();
                    scrollAnim.from = hourlyFlick.contentX;
                    scrollAnim.to = targetX;
                    scrollAnim.start();
                }
            }

            NumberAnimation {
                id: scrollAnim
                target: hourlyFlick
                property: "contentX"
                duration: 140
                easing.type: Easing.OutCubic
            }

            Row {
                id: hourlyRow
                spacing: full.hourGap

                Repeater {
                    model: full.timeline
                    delegate: Loader {
                        id: cardLoader
                        required property int index
                        required property var modelData
                        sourceComponent: modelData.dayBreak ? dayBreakCard : hourCard

                        // "Deal The Cards" entrance: slide in from the right + fade,
                        // 75 ms stagger per card. Resting state is visible — the
                        // card is only hidden when a deal is triggered, so cards
                        // created later (data refresh) just show normally.
                        transform: [
                            Translate { id: dealTr },
                            Scale {
                                id: dealScale
                                origin.x: cardLoader.width / 2
                                origin.y: cardLoader.height / 2
                                yScale: xScale
                            }
                        ]
                        SequentialAnimation {
                            id: dealAnim
                            // cap the stagger at ~the visible strip so offscreen
                            // cards don't lag seconds behind
                            PauseAnimation { duration: Math.min(cardLoader.index, 10) * 75 }
                            ParallelAnimation {
                                NumberAnimation {
                                    target: cardLoader; property: "opacity"
                                    from: 0; to: 1; duration: 550
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: [0.2, 0.7, 0.25, 1, 1, 1]
                                }
                                NumberAnimation {
                                    target: dealTr; property: "x"
                                    from: 60; to: 0; duration: 550
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: [0.2, 0.7, 0.25, 1, 1, 1]
                                }
                                NumberAnimation {
                                    target: dealScale; property: "xScale"
                                    from: 0.75; to: 1; duration: 550
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: [0.2, 0.7, 0.25, 1, 1, 1]
                                }
                            }
                        }
                        function deal() {
                            opacity = 0;
                            dealTr.x = 60;
                            dealScale.xScale = 0.75;
                            dealAnim.restart();
                        }
                        Connections {
                            target: full
                            function onDealRunChanged() { cardLoader.deal(); }
                        }

                        // Re-deal each card as it scrolls/drags into view — same
                        // slide+fade as the entrance, dealt from the side it enters.
                        // Gated on full.scrolling so it never fights the entrance
                        // (which runs with no scroll in progress).
                        readonly property bool inView:
                            (x + width) > hourlyFlick.contentX
                            && x < (hourlyFlick.contentX + hourlyFlick.width)
                        onInViewChanged: if (inView && full.scrolling)
                                             slideIn(hourlyFlick.scrollDir < 0 ? -130 : 130)
                        ParallelAnimation {
                            id: slideInAnim
                            NumberAnimation {
                                target: cardLoader; property: "opacity"; to: 1; duration: 650
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.2, 0.7, 0.25, 1, 1, 1]
                            }
                            NumberAnimation {
                                target: dealTr; property: "x"; to: 0; duration: 650
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.2, 0.7, 0.25, 1, 1, 1]
                            }
                            NumberAnimation {
                                target: dealScale; property: "xScale"; to: 1; duration: 650
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.2, 0.7, 0.25, 1, 1, 1]
                            }
                        }
                        function slideIn(fromX) {
                            opacity = 0;
                            dealTr.x = fromX;
                            dealScale.xScale = 0.75;
                            slideInAnim.restart();
                        }

                        Component {
                            id: dayBreakCard
                            Item {
                                width: full.dayBreakW
                                height: full.hourCardH
                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.bold: true
                                    opacity: 0.8
                                }
                            }
                        }

                        Component {
                            id: hourCard
                            Rectangle {
                                id: card
                                width: full.hourCardW
                                height: full.hourCardH
                                radius: 8
                                // the hour this card shows, aliased so the inner metric
                                // Repeater (whose own modelData is a metric id) can reach it
                                readonly property var hourData: modelData

                                // hovering a card feeds its hour to the header metrics; the
                                // identity guard means sliding A→B doesn't let A's exit wipe
                                // B's freshly-set value (whichever order the events fire).
                                HoverHandler {
                                    onHoveredChanged: {
                                        if (hovered) full.hoveredHourSample = card.hourData;
                                        else if (full.hoveredHourSample === card.hourData) full.hoveredHourSample = null;
                                    }
                                }

                                // is this card within the visible strip? (parent is the
                                // Loader, whose x is its position in the flickable content)
                                readonly property bool inView:
                                    (parent.x + width) > hourlyFlick.contentX
                                    && parent.x < (hourlyFlick.contentX + hourlyFlick.width)
                                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                               Kirigami.Theme.textColor.b, 0.06)
                                border.width: 1
                                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                                      Kirigami.Theme.textColor.b, 0.11)

                                // "Corner split" precip wash: rain blooms blue from the
                                // bottom-left, snow white from the top-right, each sized
                                // and brightened by its share of the chance (so a wintry
                                // mix shows both). Behind the content, clipped to the
                                // rounded card; blank for dry hours. See precip-corner-split.js.
                                Canvas {
                                    id: tide
                                    anchors.fill: parent
                                    readonly property real precip:  isNaN(modelData.precip) ? 0 : modelData.precip
                                    readonly property real snowFrac: full.snowFraction(modelData.code, modelData.precip, modelData.precipAmt, modelData.snow, modelData.temp)
                                    onPrecipChanged:   requestPaint()
                                    onSnowFracChanged: requestPaint()
                                    onWidthChanged:    requestPaint()
                                    onHeightChanged:   requestPaint()
                                    Component.onCompleted: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d"); ctx.reset();
                                        var w = width, h = height;
                                        var t = full.rainTideT(precip);
                                        if (t <= 0 || w <= 0 || h <= 0) return;
                                        // clip to the card's rounded rect so the blooms
                                        // don't square off the corners
                                        var r = card.radius;
                                        ctx.beginPath();
                                        ctx.moveTo(r, 0);
                                        ctx.arcTo(w, 0, w, h, r);
                                        ctx.arcTo(w, h, 0, h, r);
                                        ctx.arcTo(0, h, 0, 0, r);
                                        ctx.arcTo(0, 0, w, 0, r);
                                        ctx.closePath();
                                        ctx.clip();
                                        var diag = Math.max(w, h);
                                        var snowT = t * tide.snowFrac;          // top-right, white
                                        var rainT = t * (1 - tide.snowFrac);    // bottom-left, blue
                                        if (snowT > 0) {
                                            var sR = (0.5 + snowT * 0.6) * diag;
                                            var g = ctx.createRadialGradient(w, 0, 0, w, 0, sR);
                                            g.addColorStop(0,   full.tideRgbaStr(full.snowWhite, 0.20 + 0.40 * snowT));
                                            g.addColorStop(0.7, full.tideRgbaStr(full.snowWhite, 0));
                                            g.addColorStop(1,   full.tideRgbaStr(full.snowWhite, 0));
                                            ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);
                                        }
                                        if (rainT > 0) {
                                            var rR = (0.5 + rainT * 0.6) * diag;
                                            var g2 = ctx.createRadialGradient(0, h, 0, 0, h, rR);
                                            g2.addColorStop(0,   full.tideRgbaStr(full.rainBlue, 0.18 + 0.40 * rainT));
                                            g2.addColorStop(0.7, full.tideRgbaStr(full.rainBlue, 0));
                                            g2.addColorStop(1,   full.tideRgbaStr(full.rainBlue, 0));
                                            ctx.fillStyle = g2; ctx.fillRect(0, 0, w, h);
                                        }
                                    }
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: Kirigami.Units.smallSpacing * 2
                                    Label {
                                        Layout.alignment: Qt.AlignHCenter
                                        font.pixelSize: Math.round((weatherRoot ? weatherRoot.hourlyCardFontSize : 11) * 1.1)
                                        font.bold: true
                                        text: weatherRoot ? weatherRoot.formatHour(modelData.time) : ""
                                    }
                                    Item {
                                        id: hrIcon
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth:  weatherRoot ? weatherRoot.hourlyIconSize : 32
                                        Layout.preferredHeight: weatherRoot ? weatherRoot.hourlyIconSize : 32

                                        // probability-aware code: a likely-rain hour shows rain even if the code reads cloudy
                                        readonly property int iconCode: weatherRoot ? weatherRoot.precipAwareCode(modelData.code, modelData.precip, modelData.precipAmt, modelData.snow, modelData.temp) : modelData.code
                                        // Always resolve the WebP so the static (anim-off) icon is the
                                        // SAME artwork as the animated one — just frozen (playing gated
                                        // below on animatedHourlyIcons). Falls back to the static SVG only
                                        // for conditions heroAnim has no WebP for (returns "").
                                        readonly property string animSrc: (weatherRoot && modelData)
                                            ? weatherRoot.heroAnim(hrIcon.iconCode, modelData.day, modelData.cloud) : ""
                                        // per-condition fine-tune (sunny trimmed)
                                        readonly property real iScale: weatherRoot ? weatherRoot.iconScale(hrIcon.iconCode, modelData.day) : 1

                                        Kirigami.Icon {
                                            anchors.centerIn: parent
                                            width: Math.round(parent.width * (weatherRoot ? weatherRoot.staticIconZoom(hrIcon.iconCode, modelData.day) : 1))
                                            height: width
                                            roundToIconSize: false   // honor the exact zoom; don't snap to 32/48
                                            visible: hrIcon.animSrc.length === 0
                                            source: weatherRoot ? weatherRoot.conditionIcon(hrIcon.iconCode, modelData.day, modelData.cloud)
                                                                : "weather-none-available"
                                        }
                                        AnimatedImage {
                                            anchors.centerIn: parent
                                            width: Math.round(parent.width * hrIcon.iScale)
                                            height: width
                                            visible: hrIcon.animSrc.length > 0
                                            source: hrIcon.animSrc
                                            // animate only when the option is on; otherwise hold frame 0
                                            // (a static poster matching the animated art). Decode only
                                            // on-screen cards, and freeze while scrolling.
                                            playing: weatherRoot && weatherRoot.animatedHourlyIcons && visible && card.inView && !full.scrolling
                                            cache: false
                                            smooth: true
                                            mipmap: true
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }
                                    Label {
                                        Layout.alignment: Qt.AlignHCenter
                                        font.bold: true
                                        font.pixelSize: weatherRoot ? weatherRoot.hourlyTempFontSize : 13
                                        text: weatherRoot ? weatherRoot.tempStr(modelData.temp) : ""
                                    }
                                    // two configurable readouts (Appearance → Detailed →
                                    // Hourly cards). Each slot resolves its primary metric
                                    // against this card's hour (card.hourData), falling back
                                    // to the slot's fallback metric when the primary is empty
                                    // (e.g. dry hour for snow → precip chance). `effId` is the
                                    // metric that actually produced the value, so the icon and
                                    // wind glyph follow the fallback when it kicks in.
                                    Repeater {
                                        model: weatherRoot ? weatherRoot.hourlyMetrics : []
                                        delegate: RowLayout {
                                            id: hMetricRow
                                            required property int index
                                            required property var modelData   // a readout slot { id, fallback }
                                            readonly property var m: card.hourData
                                            readonly property var ro: weatherRoot ? weatherRoot.hourlyReadout(modelData, m) : ({ id: "", val: "" })
                                            readonly property string effId: ro.id
                                            readonly property string val: ro.val
                                            Layout.alignment: Qt.AlignHCenter
                                            // Put the extra gap BELOW line 1 (above line 2) rather
                                            // than above line 1: nudges the first readout up toward
                                            // the temp and widens the gap to the second readout. Total
                                            // column height is unchanged, so the centered cluster holds.
                                            Layout.topMargin: index === 0 ? 0 : Kirigami.Units.smallSpacing
                                            // Always reserve the row's height (even when this hour has
                                            // no value for the metric) so the centered cluster above
                                            // doesn't shift; the contents simply hide when val is empty.
                                            Layout.preferredHeight: full.hourMetricRowH
                                            spacing: 2
                                            Text {   // leading metric glyph from the BUNDLED weather-
                                                     // icons font (wiFont) — identical for every user,
                                                     // unlike a system-theme icon. Wind has none here
                                                     // (its direction arrow trails the label instead).
                                                readonly property string glyph: weatherRoot ? weatherRoot.hourlyMetricGlyph(hMetricRow.effId) : ""
                                                visible: hMetricRow.val.length > 0 && glyph.length > 0
                                                text: glyph
                                                color: Kirigami.Theme.textColor
                                                opacity: 0.75
                                                font.family: wiFont.status === FontLoader.Ready ? wiFont.font.family : ""
                                                font.pixelSize: Math.round((weatherRoot ? weatherRoot.hourlyCardFontSize : 11)
                                                    * (weatherRoot ? weatherRoot.hourlyMetricGlyphScale(hMetricRow.effId) : 1.5))
                                            }
                                            Label {
                                                font.pixelSize: weatherRoot ? weatherRoot.hourlyCardFontSize : 11
                                                opacity: 0.9
                                                text: hMetricRow.val
                                                // default theme text (white) — card readouts aren't colour-coded
                                            }
                                            Text {   // wind direction glyph (wind / wind+gust metrics)
                                                visible: hMetricRow.val.length > 0 && (hMetricRow.effId === "wind" || hMetricRow.effId === "windGust") && hMetricRow.m && !isNaN(hMetricRow.m.windDir)
                                                text: weatherRoot ? weatherRoot.windDirectionGlyph(hMetricRow.m.windDir) : ""
                                                color: Kirigami.Theme.textColor
                                                font.family: wiFont.status === FontLoader.Ready ? wiFont.font.family : ""
                                                font.pixelSize: Math.round((weatherRoot ? weatherRoot.hourlyCardFontSize : 11) * 1.6)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
