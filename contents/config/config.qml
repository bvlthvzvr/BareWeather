/*
 * Config categories.
 * Copyright 2026  bvlthvzvr — SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Location")
        icon: "mark-location"
        source: "configLocation.qml"
    }
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "configAppearance.qml"
    }
}
