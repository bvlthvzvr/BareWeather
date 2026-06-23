/*
 * Flat popup-header ToolButton that shows a single themed dot instead of an icon.
 * The 3 header controls (switch layout / pin / refresh) in both FullView and
 * SimpleView share the same size + flat + dot look — that lives here; each call
 * site keeps its own onClicked / onToggled / checkable / enabled / ToolTip wiring.
 * Inherits ToolButton, so all those properties work unchanged.
 * Copyright 2026  bvlthvzvr — SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

ToolButton {
    id: dot
    width: Math.round(Kirigami.Units.gridUnit * 0.9); height: width
    flat: true
    // dot replaces the icon; hover/checked/pressed feedback still comes from the
    // flat ToolButton background. Dim when disabled (e.g. refresh while loading).
    contentItem: Item {
        Rectangle {
            anchors.centerIn: parent
            width: Math.round(Kirigami.Units.gridUnit * 0.32); height: width
            radius: width / 2
            color: Kirigami.Theme.textColor
            opacity: dot.enabled ? 1 : 0.4
        }
    }
}
