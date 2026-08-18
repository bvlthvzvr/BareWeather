/*
 * Severe-weather alert indicator — a small severity-coloured warning mark shown
 * beside the header metrics when the alert feed has an active alert. Hover shows
 * the full alert headline + description.
 * Copyright 2026  bvlthvzvr — SPDX-License-Identifier: GPL-2.0-or-later
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
        // The popup sizes itself to the content's IMPLICIT size, so cap the wrapper:
        // width caps the wrap, height caps the box — a long alert scrolls inside the
        // ScrollView (wheel works because the pointer is over the hovered tooltip)
        // instead of running off-screen.
        contentItem: Item {
            implicitWidth: Math.min(tipLabel.implicitWidth, Kirigami.Units.gridUnit * 19)
            implicitHeight: Math.min(tipLabel.implicitHeight, Kirigami.Units.gridUnit * 22)
            HoverHandler { id: tipHov }
            ScrollView {
                id: tipScroll
                anchors.fill: parent
                contentWidth: availableWidth   // vertical scroll only
                Label {
                    id: tipLabel
                    width: tipScroll.availableWidth
                    text: weatherRoot ? weatherRoot.alertDetail() : ""
                    color: tip.palette.toolTipText
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
