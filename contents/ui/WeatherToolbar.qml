/*
 * The three header toolbar buttons (switch layout / pin / refresh) shared by
 * FullView and SimpleView. Floated at the top-right corner of each view.
 * Copyright 2026  bvlthvzvr — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Row {
    property real pad: 0
    property string switchTooltip: ""
    property var root: null   // weatherRoot reference

    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: -Math.round(pad * 0.35)
    anchors.rightMargin: Math.round(pad * 0.35)
    spacing: 0
    z: 10

    DotButton {
        onClicked: if (root) root.toggleLayout()
        ToolTip.visible: hovered
        ToolTip.text: switchTooltip
    }
    DotButton {
        // pinning is meaningless on the desktop (the widget is always shown) — only
        // the panel popup can be dismissed, so show the pin there only
        visible: !(root && root.planar)
        checkable: true
        Component.onCompleted: checked = (root ? root.keepOpen : false)
        onToggled: if (root) root.setKeepOpen(checked)
        ToolTip.visible: hovered
        ToolTip.text: checked ? i18n("Unpin window") : i18n("Keep window open")
    }
    DotButton {
        enabled: root && !root.loading
        onClicked: if (root) root.fetchWeather()
        ToolTip.visible: hovered
        ToolTip.text: i18n("Refresh")
    }
}
