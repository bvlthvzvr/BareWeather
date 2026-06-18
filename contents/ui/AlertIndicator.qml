/*
 * Severe-weather alert indicator — a small severity-coloured warning mark shown
 * beside the header metrics when the alert feed has an active alert. Hover shows
 * the full alert headline + description.
 * Copyright 2026  bvlthvzvr — SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Kirigami.Icon {
    id: indicator

    property var weatherRoot
    readonly property var alert: weatherRoot ? weatherRoot.topAlert : null

    visible: weatherRoot && weatherRoot.showAlerts && alert !== null
    source: "dialog-warning"
    color: alert ? weatherRoot.alertColor(alert.severity) : "transparent"
    implicitWidth: Kirigami.Units.iconSizes.small
    implicitHeight: Kirigami.Units.iconSizes.small

    HoverHandler { id: hov }

    // Hovering the icon OR the tooltip keeps it up (so a tooltip that lands over
    // the small icon doesn't steal the hover and flicker). Visibility is driven
    // imperatively with two timers: a short SHOW delay, and a small HIDE grace so
    // the instant with neither hovered — crossing the gap from the icon onto the
    // tooltip — doesn't blink it off.
    readonly property bool _wantTip: (hov.hovered || tipHov.hovered) && indicator.alert !== null
    on_WantTipChanged: {
        if (_wantTip) { hideTimer.stop(); showTimer.restart(); }
        else          { showTimer.stop(); hideTimer.restart(); }
    }
    Timer { id: showTimer; interval: 150; onTriggered: tip.visible = true }
    Timer { id: hideTimer; interval: 130; onTriggered: tip.visible = false }

    ToolTip {
        id: tip
        parent: indicator
        delay: 0   // timing is handled by the timers above
        // The popup sizes itself to the content's IMPLICIT width, so capping the
        // Label's width does nothing — cap the wrapper's implicitWidth instead,
        // then the Label wraps within it.
        contentItem: Item {
            implicitWidth: Math.min(tipLabel.implicitWidth, Kirigami.Units.gridUnit * 19)
            implicitHeight: tipLabel.implicitHeight
            HoverHandler { id: tipHov }
            Label {
                id: tipLabel
                width: parent.width
                text: weatherRoot ? weatherRoot.alertDetail() : ""
                color: tip.palette.toolTipText
                wrapMode: Text.WordWrap
            }
        }
    }
}
