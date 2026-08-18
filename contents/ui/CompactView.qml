/*
 * Compact (panel/tray) representation — white icon + temperature.
 * Copyright 2026  bvlthvzvr — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: compact

    property var weatherRoot

    readonly property int iconPercent: weatherRoot ? weatherRoot.panelIconPercent : 130
    readonly property int fontPercent: weatherRoot ? weatherRoot.panelFontPercent : 48
    // Detailed layout only: condition word and second line, each its own % of height.
    readonly property int _condPx: Math.round(compact.height
        * (weatherRoot ? weatherRoot.panelConditionPercent : 40) / 100)
    readonly property int _line2Px: Math.round(compact.height
        * (weatherRoot ? weatherRoot.panelSecondLinePercent : 37) / 100)

    // The bundled Basmilius sun glyph fills its box more than the other condition
    // icons (same "over-full artwork" issue main.qml's heroScale/iconScale correct
    // for elsewhere), so it reads oversized in the panel at the same box size next
    // to e.g. clouds. Scale it down a touch; every other condition, and every other
    // icon pack, is untouched.
    function panelIconScale() {
        if (!weatherRoot || weatherRoot.iconPackId !== "basmilius") return 1.0;
        var code = weatherRoot.heroCode, day = weatherRoot.heroDay;
        if ((code === 0 || code === 1) && day !== 0) return 0.85;   // clear sky / sunny (day)
        return 1.0;
    }

    // White icon by default; colored variant when the panelColorIcon setting is on.
    function panelIconSource() {
        if (!weatherRoot) return "";
        if (!weatherRoot.hasLocation) return "mark-location";   // no location set → pin, not fake weather
        var code = weatherRoot.heroCode, day = weatherRoot.heroDay;
        // panel-only: show the moon-behind-cloud icon for overcast night (the
        // popup keeps its own overcast-night artwork).
        var override = (code === 3 && day === 0) ? "wi-night-alt-partly-cloudy" : undefined;
        return weatherRoot.panelColorIcon
            ? weatherRoot.conditionIcon(code, day, weatherRoot.heroCloud, override)
            : weatherRoot.conditionIconWhite(code, day, weatherRoot.heroCloud, override);
    }

    // Force the panel to allocate exactly the content width + side padding, so
    // the temperature is never clipped and the widget never overlaps neighbours.
    // Asymmetric: the white-moon SVG already carries internal left padding, so
    // keep the outer-left gap small and put the breathing room on the right.
    readonly property int _leftPad:  0
    readonly property int _rightPad: 0
    readonly property int _w: row.implicitWidth + _leftPad + _rightPad
    Layout.minimumWidth:   _w
    Layout.preferredWidth: _w
    Layout.maximumWidth:   _w

    MouseArea {
        anchors.fill: parent
        onClicked: if (weatherRoot) weatherRoot.expanded = !weatherRoot.expanded
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: compact._leftPad
        spacing: 0

        // Bundled white SVG packs render flat via a plain Image (no icon-engine
        // recolouring); theme packs need Kirigami.Icon to resolve "weather-*"
        // names, so the two swap by visibility (Row skips the hidden one).
        Image {
            id: icon
            visible: weatherRoot && weatherRoot.hasLocation && !weatherRoot.iconPackIsTheme
            anchors.verticalCenter: parent.verticalCenter
            height: Math.round(compact.height * compact.iconPercent / 100 * compact.panelIconScale())
            width: height
            sourceSize.width: width
            sourceSize.height: height
            fillMode: Image.PreserveAspectFit
            smooth: true
            source: visible && weatherRoot ? compact.panelIconSource() : ""
        }
        Kirigami.Icon {
            id: themeIcon
            // theme renderer also carries the "mark-location" pin when unset
            visible: weatherRoot && (!weatherRoot.hasLocation || weatherRoot.iconPackIsTheme)
            anchors.verticalCenter: parent.verticalCenter
            height: Math.round(compact.height * compact.iconPercent / 100)
            width: height
            source: visible && weatherRoot ? compact.panelIconSource() : ""
        }
        Text {
            id: temp
            anchors.verticalCenter: parent.verticalCenter
            visible: weatherRoot && !weatherRoot.panelDetailed && text.length > 0 && weatherRoot.hasLocation
            text: weatherRoot ? weatherRoot.temperatureText : "—"
            color: Kirigami.Theme.textColor
            font.pixelSize: Math.round(compact.height * compact.fontPercent / 100)
        }

        // Detailed layout: big bold "96°" on the left, with a smaller muted
        // stack ("H 99°" over "L 74°", or the precip line) to its right.
        Row {
            id: detailedCol
            anchors.verticalCenter: parent.verticalCenter
            visible: weatherRoot && weatherRoot.panelDetailed && weatherRoot.hasLocation
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: weatherRoot ? weatherRoot.temperatureText : "—"
                color: Kirigami.Theme.textColor
                font.pixelSize: Math.round(compact.height * 0.68)
            }
            // Right stack: bold condition word always on top; the second line
            // switches between "low / high" and precip via the panelSecondLine setting.
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -3
                Text {
                    text: weatherRoot ? weatherRoot.conditionText(weatherRoot.heroCode, weatherRoot.heroDay) : ""
                    color: Kirigami.Theme.textColor
                    font.bold: true
                    font.pixelSize: compact._condPx
                }
                // Second line, option A: low / high temperature. With the colored
                // panel icon on, tint L blue and H warm (matching FullView's temps).
                Text {
                    visible: weatherRoot && weatherRoot.panelSecondLine === 0
                    textFormat: Text.StyledText
                    text: {
                        if (!weatherRoot || isNaN(weatherRoot.lowTemp) || isNaN(weatherRoot.highTemp))
                            return "";
                        var L = Math.round(weatherRoot.lowTemp), H = Math.round(weatherRoot.highTemp);
                        return weatherRoot.panelColorIcon
                            ? "<font color='" + weatherRoot.precipColor + "'>L</font>" + L + "&nbsp;&nbsp;&nbsp;"
                              + "<font color='#ff6e40'>H</font>" + H
                            : "L" + L + "&nbsp;&nbsp;&nbsp;H" + H;
                    }
                    color: Kirigami.Theme.textColor
                    opacity: 0.7
                    font.bold: true
                    font.pixelSize: compact._line2Px
                }
                // Second line, option B: "chance / amount" for today. With the colored
                // panel icon on, tint both numbers blue but leave the "/" theme-colored.
                Text {
                    visible: weatherRoot && weatherRoot.panelSecondLine === 1
                             && !isNaN(weatherRoot.precipChanceToday)
                    textFormat: Text.StyledText
                    text: {
                        if (!weatherRoot) return "";
                        var c = Math.round(weatherRoot.precipChanceToday) + "%";
                        var a = weatherRoot.precipUnitStr(weatherRoot.precipSumToday, false);
                        return weatherRoot.panelColorIcon
                            ? "<font color='" + weatherRoot.precipColor + "'>" + c + "</font> / "
                              + "<font color='" + weatherRoot.precipColor + "'>" + a + "</font>"
                            : c + " / " + a;
                    }
                    color: Kirigami.Theme.textColor
                    opacity: 0.7
                    font.bold: true
                    font.pixelSize: compact._line2Px
                }
                // Second line, option C: wind + gust → "34 G12 mph".
                Text {
                    visible: weatherRoot && weatherRoot.panelSecondLine === 2
                             && !isNaN(weatherRoot.windSpeed)
                    text: weatherRoot
                        ? Math.round(weatherRoot.windSpeed)
                          + (isNaN(weatherRoot.windGust) ? "" : " G" + Math.round(weatherRoot.windGust))
                          + " " + weatherRoot.windUnitLabel
                        : ""
                    color: Kirigami.Theme.textColor
                    opacity: 0.7
                    font.bold: true
                    font.pixelSize: compact._line2Px
                }
            }
        }
    }

    // No stale marker in the panel: the panel is glanced at, not read, and a dot there
    // says something is wrong without saying what. The "Updated Xh ago" line in both
    // popup layouts carries it instead (weatherRoot.weatherStale / staleAgeStr).
}
