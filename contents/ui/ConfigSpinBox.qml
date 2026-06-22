/*
 * Config SpinBox preset: scroll-over never changes the value. Every config
 * SpinBox wants this, so it's defaulted here instead of repeated on each one.
 * Inherits SpinBox, so `value`, `from`, `to`, `stepSize` (and the cfg_* aliases
 * that bind to `value`) all work unchanged.
 * Copyright 2026  bvlthvzvr — SPDX-License-Identifier: MIT
 */
import QtQuick.Controls

SpinBox {
    wheelEnabled: false
}
