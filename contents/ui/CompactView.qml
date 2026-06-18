/*
 * Compact (panel/tray) representation — white icon + temperature.
 * Copyright 2026  bvlthvzvr — SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: compact

    property var weatherRoot

    readonly property int iconPercent: weatherRoot ? weatherRoot.panelIconPercent : 130
    readonly property int fontPercent: weatherRoot ? weatherRoot.panelFontPercent : 48

    // White icon by default; colored variant when the panelColorIcon setting is on.
    function panelIconSource() {
        if (!weatherRoot) return "";
        if (!weatherRoot.hasLocation) return "mark-location";   // no location set → pin, not fake weather
        var code = weatherRoot.weatherCode, day = weatherRoot.isDay;
        // panel-only: show the moon-behind-cloud icon for overcast night (the
        // popup keeps its own overcast-night artwork).
        var override = (code === 3 && day === 0) ? "wi-night-alt-partly-cloudy" : undefined;
        return weatherRoot.panelColorIcon
            ? weatherRoot.conditionIcon(code, day, weatherRoot.cloudCover, override)
            : weatherRoot.conditionIconWhite(code, day, weatherRoot.cloudCover, override);
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
        spacing: 2

        // Bundled white SVG packs render flat via a plain Image (no icon-engine
        // recolouring); theme packs need Kirigami.Icon to resolve "weather-*"
        // names, so the two swap by visibility (Row skips the hidden one).
        Image {
            id: icon
            visible: weatherRoot && weatherRoot.hasLocation && !weatherRoot.iconPackIsTheme
            anchors.verticalCenter: parent.verticalCenter
            height: Math.round(compact.height * compact.iconPercent / 100)
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
            text: weatherRoot ? weatherRoot.temperatureText : "—"
            color: Kirigami.Theme.textColor
            font.pixelSize: Math.round(compact.height * compact.fontPercent / 100)
            visible: text.length > 0 && weatherRoot && weatherRoot.hasLocation
        }
    }
}
