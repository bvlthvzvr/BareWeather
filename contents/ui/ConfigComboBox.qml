/*
 * Config ComboBox preset shared by the settings pages. Two defaults every config
 * combo wants, set here instead of repeated on each one:
 *   - wheelEnabled: false — scroll-over never changes the value.
 *   - popup.width — qqc2-desktop-style sizes the popup to the (narrow) FIELD
 *     width, so long options elide in the list. We widen it to the longest
 *     option, estimated from one calibrated average character width: pure
 *     arithmetic, no per-item measuring loop. (An earlier shared-TextMetrics
 *     loop crashed plasmashell; a per-combo TextMetrics assigned to a property
 *     couldn't see `model`. The popup.width binding runs in THIS combo's scope,
 *     so `model`/`textRole` resolve here.)
 * Inherits ComboBox, so `model`, `textRole`, `currentIndex`, `onActivated`, etc.
 * (and any cfg_* binding) work unchanged; each call site keeps its own value
 * wiring and just drops the two repeated lines.
 * Copyright 2026  bvlthvzvr — SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

ComboBox {
    wheelEnabled: false
    // guard `model` so a combo without one falls back to its natural width
    popup.width: (model && model.length)
        ? longestText(model, textRole).length * charPx + Kirigami.Units.gridUnit * 3
        : implicitWidth

    readonly property real charPx: charMetrics.width / charMetrics.text.length
    function longestText(items, role) {
        var s = "";
        for (var i = 0; i < items.length; ++i) {
            var t = "" + (role ? items[i][role] : items[i]);
            if (t.length > s.length) s = t;
        }
        return s;
    }
    TextMetrics { id: charMetrics; text: "Temperature & precipitation" }
}
