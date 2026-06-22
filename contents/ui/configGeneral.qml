/*
 * General settings — units and refresh.
 * (Location → configLocation.qml; forecast days, graph detail and the per-layout
 *  header-info pickers → configAppearance.qml, inside the layout tabs.)
 * Copyright 2026  bvlthvzvr — SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    // cfg_* properties are auto-bound to the config keys by Plasma.
    property string cfg_temperatureUnit
    property bool   cfg_unitConfigured        // set once the unit is chosen (here or auto-picked)
    property alias  cfg_refreshInterval: refreshSpin.value
    property alias  cfg_showAlerts: alertsCheck.checked
    property int    cfg_minAlertSeverity

    // breathing room so the settings don't sit flush against the top
    Item { implicitHeight: Kirigami.Units.gridUnit }

    ConfigSpinBox {
        id: refreshSpin
        Kirigami.FormData.label: i18n("Refresh interval (minutes):")
        from: 1
        to: 180
        stepSize: 5
    }
    RowLayout {
        Kirigami.FormData.label: i18n("Weather alerts:")
        CheckBox {
            id: alertsCheck
            text: i18n("Show severe-weather alerts")
        }
        Kirigami.Icon {
            source: "dialog-information"
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
            opacity: alertInfoHov.hovered ? 1.0 : 0.7
            HoverHandler { id: alertInfoHov }
            ToolTip.visible: alertInfoHov.hovered
            ToolTip.text: i18n("Weather alerts come from the KDE Public Alert Server, not from government servers directly. Agencies like the NWS publish their official warnings as open CAP feeds. KDE's open-source server continuously aggregates hundreds of those feeds worldwide into one place, and the widget just asks for it. So you get the official alerts without contacting or revealing yourself to every agency that issues them.")
        }
    }
    ConfigComboBox {
        id: alertLevelCombo
        Kirigami.FormData.label: i18n("Show alerts at or above:")
        enabled: alertsCheck.checked   // only meaningful when alerts are on
        textRole: "text"
        // CAP severity ranks (see alertRank in main.qml): the floor for display
        model: [
            { text: i18n("Minor"),    value: 1 },
            { text: i18n("Moderate"), value: 2 },
            { text: i18n("Severe"),   value: 3 },
            { text: i18n("Extreme"),  value: 4 }
        ]
        Component.onCompleted: {
            for (var i = 0; i < model.length; ++i)
                if (model[i].value === page.cfg_minAlertSeverity) { currentIndex = i; break; }
        }
        onActivated: page.cfg_minAlertSeverity = model[currentIndex].value
    }
    ConfigComboBox {
        id: unitCombo
        Kirigami.FormData.label: i18n("Temperature unit:")
        textRole: "text"
        model: [
            { text: i18n("Celsius (°C)"),    value: "celsius"    },
            { text: i18n("Fahrenheit (°F)"), value: "fahrenheit" }
        ]
        Component.onCompleted: {
            for (var i = 0; i < model.length; ++i)
                if (model[i].value === page.cfg_temperatureUnit) { currentIndex = i; break; }
        }
        onActivated: { page.cfg_temperatureUnit = model[currentIndex].value; page.cfg_unitConfigured = true; }
    }
}
