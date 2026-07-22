/*
 * Appearance settings — a shared icon-pack picker above per-layout tabs
 * (Detailed / Simple / Panel), each holding only that layout's own settings.
 * Copyright 2026  bvlthvzvr — SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

Item {
    id: page

    // cfg_* are auto-bound to the config keys by Plasma. ids live anywhere in
    // this file (file-wide scope), so the controls can sit inside the tabs while
    // their aliases stay here at the page root.

    // shared
    property string cfg_iconPack
    property string cfg_customIconDir
    // Detailed layout (forecast days moved here from the General page)
    property alias cfg_dailyDays:          dailyDaysSpin.value
    property alias cfg_heroIconSize:       heroSpin.value
    property alias cfg_tempFontSize:       tempSpin.value
    property alias cfg_dailyIconSize:      dailySpin.value
    property alias cfg_hourlyIconSize:     hourlySpin.value
    property alias cfg_hourlyTempFontSize: hourlyTempSpin.value
    property alias cfg_hourlyCardFontSize: hourlyCardSpin.value
    property alias cfg_conditionFontSize:  condFontSpin.value
    property bool  cfg_animatedDailyIcons
    property bool  cfg_animatedHourlyIcons
    property string cfg_headerMetric1
    property string cfg_headerMetric2
    property string cfg_headerMetric3
    property string cfg_headerMetric4
    property alias  cfg_headerInfoFontSize: detHeaderFontSpin.value
    // Simple layout (forecast days + graph detail moved here from General)
    property alias cfg_simpleDailyDays:        simpleDaysSpin.value
    property bool  cfg_simpleHourly
    property alias cfg_simpleHeroIconSize:     simpleHeroSpin.value
    property alias cfg_simpleTempFontSize:     simpleTempSpin.value
    property alias cfg_simpleHourlyIconSize:   simpleIconSpin.value
    property alias cfg_simpleHourFontSize:     simpleHourSpin.value
    property alias cfg_simpleGraphTempFontSize: simpleGraphTempSpin.value
    property bool  cfg_simpleAnimatedIcons
    property bool  cfg_simpleHeaderAnim
    property alias cfg_graphColorMode:         graphColorCombo.currentIndex
    property string cfg_simpleHeaderMetric1
    property string cfg_simpleHeaderMetric2
    property string cfg_simpleHeaderMetric3
    property string cfg_simpleHeaderMetric4
    property alias  cfg_simpleHeaderInfoFontSize: simpHeaderFontSpin.value
    property string cfg_hourlyMetric1
    property string cfg_hourlyMetric2
    property string cfg_hourlyMetric1Fallback
    property string cfg_hourlyMetric1Fallback2
    property string cfg_hourlyMetric2Fallback
    property string cfg_hourlyMetric2Fallback2
    property int    cfg_detailDayStartHour
    // Panel (compact view)
    property alias cfg_panelIconPercent:   panelIconSpin.value
    property alias cfg_panelFontPercent:   panelFontSpin.value
    property alias cfg_panelColorIcon:     panelColorCheck.checked
    property alias cfg_panelDetailed:      panelDetailedCheck.checked
    property alias cfg_panelSecondLine:    panelSecondLineCombo.currentIndex
    property alias cfg_panelConditionPercent:  panelConditionSpin.value
    property alias cfg_panelSecondLinePercent: panelSecondLineSpin.value

    // shared options for the header-metric dropdowns (id ↔ label)
    readonly property var metricOptions: [
        { text: i18n("None"),                    id: "none"       },
        { text: i18n("Feels like"),              id: "feelsLike"  },
        { text: i18n("Humidity"),                id: "humidity"   },
        { text: i18n("UV Index"),                id: "uv"         },
        { text: i18n("Precipitation rate"),      id: "precipRate" },
        { text: i18n("Precipitation sum"),       id: "precipSum"  },
        { text: i18n("Wind"),                    id: "wind"       },
        { text: i18n("Snowfall today"),          id: "snowSum"    },
        { text: i18n("Cloud cover"),             id: "cloud"      }
    ]
    function findMetricIndex(arr, id) {
        for (var i = 0; i < arr.length; ++i)
            if (arr[i].id === id) return i;
        return 0;
    }
    function metricIndexOf(id)        { return findMetricIndex(metricOptions,        id) }
    function detailMetricIndexOf(id)  { return findMetricIndex(detailMetricOptions,  id) }
    function hourlyMetricIndexOf(id)  { return findMetricIndex(hourlyMetricOptions,  id) }
    // Detailed layout additionally offers sunrise/sunset; the Simple header keeps the
    // base set, so these stay Detailed-only (its combos still use metricOptions).
    readonly property var detailMetricOptions: metricOptions.concat([
        { text: i18n("Sunrise / sunset"), id: "sun" }
    ])
    // Per-hour options for the Detailed hourly-card readouts (chance/amount are
    // per-hour, unlike the header's daily-total precip/snow sums).
    readonly property var hourlyMetricOptions: [
        { text: i18n("None"),          id: "none"      },
        { text: i18n("Wind"),          id: "wind"      },
        { text: i18n("Wind + gust"),   id: "windGust"  },
        { text: i18n("Precip chance"), id: "precip"    },
        { text: i18n("Precip amount"), id: "precipAmt" },
        { text: i18n("Snowfall"),      id: "snow"      },
        { text: i18n("Feels like"),    id: "feelsLike" },
        { text: i18n("Humidity"),      id: "humidity"  },
        { text: i18n("UV Index"),      id: "uv"        },
        { text: i18n("Cloud cover"),   id: "cloud"     }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Kirigami.Units.gridUnit   // don't sit flush against the top
        spacing: Kirigami.Units.largeSpacing

        // ── shared: the condition-icon pack applies to BOTH layouts, so it sits
        //    above the tabs rather than inside one of them ──
        Kirigami.FormLayout {
            Layout.fillWidth: true

            ConfigComboBox {
                id: iconPackCombo
                Kirigami.FormData.label: i18n("Icon pack:")
                textRole: "text"
                // each option stores its pack id (matches the registry in main.qml)
                model: [
                    { text: i18n("Basmilius (color)"), id: "basmilius" },
                    { text: i18n("System theme"),       id: "system"    },
                    { text: i18n("Custom folder…"),     id: "custom"    }
                ]
                Component.onCompleted: {
                    for (var i = 0; i < model.length; ++i)
                        if (model[i].id === page.cfg_iconPack) { currentIndex = i; break; }
                }
                onActivated: page.cfg_iconPack = model[currentIndex].id
            }
            RowLayout {
                Kirigami.FormData.label: i18n("Custom folder:")
                visible: page.cfg_iconPack === "custom"
                Button {
                    text: i18n("Choose…")
                    icon.name: "folder-open"
                    onClicked: iconFolderDialog.open()
                }
                Label {
                    Layout.fillWidth: true
                    // cap the layout contribution so a long path can't inflate the
                    // form width (elide trims rendering, not implicitWidth)
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                    elide: Text.ElideMiddle
                    opacity: 0.7
                    text: page.cfg_customIconDir
                          ? page.cfg_customIconDir.replace(/^file:\/\//, "")
                          : i18n("(none selected)")
                }
            }
            Label {
                visible: page.cfg_iconPack === "custom"
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: i18n("Folder with SVGs named like the bundled set (wi-day-sunny.svg, wi-night-clear.svg, …). Tip: copy contents/icons/basmilius/32/ as a starting point so every condition is covered, then edit.")
            }
        }

        FolderDialog {
            id: iconFolderDialog
            title: i18n("Choose icon folder")
            onAccepted: page.cfg_customIconDir = selectedFolder
        }

        TabBar {
            id: tabBar
            Layout.fillWidth: true
            TabButton { text: i18n("Cards") }
            TabButton { text: i18n("Graph") }
            TabButton { text: i18n("Panel") }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            // ── Detailed layout ──
            ScrollView {
                contentWidth: availableWidth
                RowLayout {
                    spacing: Kirigami.Units.gridUnit * 2
                    Kirigami.FormLayout {
                        Layout.alignment: Qt.AlignTop
                        ConfigSpinBox {
                            id: dailyDaysSpin
                            Kirigami.FormData.label: i18n("Forecast days:")
                            from: 1
                            to: 7
                        }
                        ConfigSpinBox {
                            id: heroSpin
                            Kirigami.FormData.label: i18n("Header icon size:")
                            from: 48
                            to: 200
                            stepSize: 4
                        }
                        ConfigSpinBox {
                            id: tempSpin
                            Kirigami.FormData.label: i18n("Temperature font:")
                            from: 24
                            to: 120
                            stepSize: 2
                        }
                        ConfigSpinBox {
                            id: condFontSpin
                            Kirigami.FormData.label: i18n("Condition & location font:")
                            from: 12
                            to: 64
                            stepSize: 1
                        }
                        ConfigSpinBox {
                            id: dailySpin
                            Kirigami.FormData.label: i18n("Daily tab icon size:")
                            from: 12
                            to: 64
                            stepSize: 2
                        }
                        ConfigSpinBox {
                            id: hourlySpin
                            Kirigami.FormData.label: i18n("Hourly icon size:")
                            from: 16
                            to: 80
                            stepSize: 2
                        }
                        ConfigSpinBox {
                            id: hourlyTempSpin
                            Kirigami.FormData.label: i18n("Hourly temperature font:")
                            from: 8
                            to: 40
                            stepSize: 1
                        }
                        ConfigSpinBox {
                            id: hourlyCardSpin
                            Kirigami.FormData.label: i18n("Hourly card font:")
                            from: 7
                            to: 32
                            stepSize: 1
                        }
                        ConfigComboBox {
                            id: dayStartCombo
                            Kirigami.FormData.label: i18n("Day starts at:")
                            textRole: "text"
                            // hour a non-today day opens at (detailDayStartHour): 6 AM skips
                            // the overnight cards, Midnight opens at 00:00
                            model: [
                                { text: i18n("6 AM"),     value: 6 },
                                { text: i18n("Midnight"), value: 0 }
                            ]
                            Component.onCompleted: {
                                for (var i = 0; i < model.length; ++i)
                                    if (model[i].value === page.cfg_detailDayStartHour) { currentIndex = i; break; }
                            }
                            onActivated: page.cfg_detailDayStartHour = model[currentIndex].value
                        }
                        ConfigComboBox {
                            id: forecastAnimCombo
                            Kirigami.FormData.label: i18n("Animation:")
                            textRole: "text"
                            // each option maps to the daily/hourly animation booleans
                            model: [
                                { text: i18n("None"),            d: false, h: false },
                                { text: i18n("Daily tab icons"), d: true,  h: false },
                                { text: i18n("Hourly icons"),    d: false, h: true  },
                                { text: i18n("Both"),            d: true,  h: true  }
                            ]
                            Component.onCompleted: {
                                var d = page.cfg_animatedDailyIcons, h = page.cfg_animatedHourlyIcons;
                                currentIndex = (d && h) ? 3 : (h ? 2 : (d ? 1 : 0));
                            }
                            onActivated: {
                                page.cfg_animatedDailyIcons  = model[currentIndex].d;
                                page.cfg_animatedHourlyIcons = model[currentIndex].h;
                            }
                        }

                    }
                    Kirigami.FormLayout {
                        Layout.alignment: Qt.AlignTop
                        Layout.leftMargin: Kirigami.Units.gridUnit * 4
                        Layout.topMargin: 0   // header has no intrinsic top padding now, so no negative pull needed (was clipping the title)
                        RowLayout {
                            // inline section header (see the matching note in the Hourly cards section)
                            Kirigami.FormData.isSection: true
                            Layout.fillWidth: true
                            Kirigami.Heading {
                                level: 5
                                text: i18n("Weather Elements (up to 4)")
                            }
                            Kirigami.Icon {
                                source: "documentinfo"
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: implicitWidth
                                opacity: headerInfoHover.hovered ? 1.0 : 0.65
                                HoverHandler { id: headerInfoHover; cursorShape: Qt.PointingHandCursor }
                                ToolTip.visible: headerInfoHover.hovered
                                ToolTip.text: i18n("The element header readouts follow whichever hour you hover.")
                            }
                            Item { Layout.fillWidth: true }
                        }
                        ConfigSpinBox {
                            id: detHeaderFontSpin
                            Kirigami.FormData.label: i18n("Font:")
                            from: 7
                            to: 32
                            stepSize: 1
                        }
                        ConfigComboBox {
                            id: detMetric1
                            Kirigami.FormData.label: i18n("Element 1:")
                            textRole: "text"
                            model: page.detailMetricOptions
                            Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_headerMetric1)
                            onActivated: page.cfg_headerMetric1 = page.detailMetricOptions[currentIndex].id
                        }
                        ConfigComboBox {
                            id: detMetric2
                            Kirigami.FormData.label: i18n("Element 2:")
                            textRole: "text"
                            model: page.detailMetricOptions
                            Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_headerMetric2)
                            onActivated: page.cfg_headerMetric2 = page.detailMetricOptions[currentIndex].id
                        }
                        ConfigComboBox {
                            id: detMetric3
                            Kirigami.FormData.label: i18n("Element 3:")
                            textRole: "text"
                            model: page.detailMetricOptions
                            Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_headerMetric3)
                            onActivated: page.cfg_headerMetric3 = page.detailMetricOptions[currentIndex].id
                        }
                        ConfigComboBox {
                            id: detMetric4
                            Kirigami.FormData.label: i18n("Element 4:")
                            textRole: "text"
                            model: page.detailMetricOptions
                            Component.onCompleted: currentIndex = page.detailMetricIndexOf(page.cfg_headerMetric4)
                            onActivated: page.cfg_headerMetric4 = page.detailMetricOptions[currentIndex].id
                        }
                        Button {
                            text: i18n("Reset to none")
                            icon.name: "edit-clear-all"
                            onClicked: {
                                page.cfg_headerMetric1 = "none"; detMetric1.currentIndex = 0;
                                page.cfg_headerMetric2 = "none"; detMetric2.currentIndex = 0;
                                page.cfg_headerMetric3 = "none"; detMetric3.currentIndex = 0;
                                page.cfg_headerMetric4 = "none"; detMetric4.currentIndex = 0;
                            }
                        }

                        Item { Layout.preferredHeight: Kirigami.Units.largeSpacing * 2 }
                        RowLayout {
                            Kirigami.FormData.isSection: true
                            Layout.fillWidth: true
                            Kirigami.Heading {
                                level: 5
                                text: i18n("Hourly cards (2 elements)")
                            }
                            Kirigami.Icon {
                                source: "documentinfo"
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: implicitWidth
                                opacity: hourlyInfoHover.hovered ? 1.0 : 0.65
                                HoverHandler { id: hourlyInfoHover; cursorShape: Qt.PointingHandCursor }
                                ToolTip.visible: hourlyInfoHover.hovered
                                ToolTip.text: i18n("Shows the main metric, or the fallback on hours the main one has nothing to show.")
                            }
                            Item { Layout.fillWidth: true }
                        }
                        ConfigComboBox {
                            id: hourMetric1
                            Kirigami.FormData.label: i18n("Element 1:")
                            textRole: "text"
                            model: page.hourlyMetricOptions
                            Component.onCompleted: currentIndex = page.hourlyMetricIndexOf(page.cfg_hourlyMetric1)
                            onActivated: page.cfg_hourlyMetric1 = page.hourlyMetricOptions[currentIndex].id
                        }
                        ConfigComboBox {
                            id: hourMetric1Fallback
                            Kirigami.FormData.label: i18n("Fallback:")
                            textRole: "text"
                            model: page.hourlyMetricOptions
                            Component.onCompleted: currentIndex = page.hourlyMetricIndexOf(page.cfg_hourlyMetric1Fallback)
                            onActivated: page.cfg_hourlyMetric1Fallback = page.hourlyMetricOptions[currentIndex].id
                        }
                        ConfigComboBox {
                            id: hourMetric1Fallback2
                            Kirigami.FormData.label: i18n("Fallback:")
                            textRole: "text"
                            model: page.hourlyMetricOptions
                            Component.onCompleted: currentIndex = page.hourlyMetricIndexOf(page.cfg_hourlyMetric1Fallback2)
                            onActivated: page.cfg_hourlyMetric1Fallback2 = page.hourlyMetricOptions[currentIndex].id
                        }
                        ConfigComboBox {
                            id: hourMetric2
                            Kirigami.FormData.label: i18n("Element 2:")
                            textRole: "text"
                            model: page.hourlyMetricOptions
                            Component.onCompleted: currentIndex = page.hourlyMetricIndexOf(page.cfg_hourlyMetric2)
                            onActivated: page.cfg_hourlyMetric2 = page.hourlyMetricOptions[currentIndex].id
                        }
                        ConfigComboBox {
                            id: hourMetric2Fallback
                            Kirigami.FormData.label: i18n("Fallback:")
                            textRole: "text"
                            model: page.hourlyMetricOptions
                            Component.onCompleted: currentIndex = page.hourlyMetricIndexOf(page.cfg_hourlyMetric2Fallback)
                            onActivated: page.cfg_hourlyMetric2Fallback = page.hourlyMetricOptions[currentIndex].id
                        }
                        ConfigComboBox {
                            id: hourMetric2Fallback2
                            Kirigami.FormData.label: i18n("Fallback:")
                            textRole: "text"
                            model: page.hourlyMetricOptions
                            Component.onCompleted: currentIndex = page.hourlyMetricIndexOf(page.cfg_hourlyMetric2Fallback2)
                            onActivated: page.cfg_hourlyMetric2Fallback2 = page.hourlyMetricOptions[currentIndex].id
                        }
                    }
                }
            }

            // ── Simple layout ──
            ScrollView {
                contentWidth: availableWidth
                RowLayout {
                    spacing: Kirigami.Units.gridUnit * 2
                    Kirigami.FormLayout {
                    Layout.alignment: Qt.AlignTop
                    ConfigSpinBox {
                        id: simpleDaysSpin
                        Kirigami.FormData.label: i18n("Forecast days:")
                        from: 1
                        to: 7
                    }
                    ConfigComboBox {
                        id: sampleStepCombo
                        Kirigami.FormData.label: i18n("Graph detail:")
                        textRole: "text"
                        // false = every 2 hours (12 pts/day), true = hourly (13)
                        model: [
                            { text: i18n("Every 2 hours"), value: false },
                            { text: i18n("Hourly"),        value: true  }
                        ]
                        Component.onCompleted: currentIndex = page.cfg_simpleHourly ? 1 : 0
                        onActivated: page.cfg_simpleHourly = model[currentIndex].value
                    }
                    ConfigSpinBox {
                        id: simpleHeroSpin
                        Kirigami.FormData.label: i18n("Header icon size:")
                        from: 32
                        to: 160
                        stepSize: 4
                    }
                    ConfigSpinBox {
                        id: simpleTempSpin
                        Kirigami.FormData.label: i18n("Temperature font:")
                        from: 24
                        to: 120
                        stepSize: 2
                    }
                    ConfigSpinBox {
                        id: simpleIconSpin
                        Kirigami.FormData.label: i18n("Hourly icon size:")
                        from: 12
                        to: 64
                        stepSize: 2
                    }
                    ConfigSpinBox {
                        id: simpleHourSpin
                        Kirigami.FormData.label: i18n("Hour font:")
                        from: 7
                        to: 32
                        stepSize: 1
                    }
                    ConfigSpinBox {
                        id: simpleGraphTempSpin
                        Kirigami.FormData.label: i18n("Graph temperature font:")
                        from: 8
                        to: 40
                        stepSize: 1
                    }
                    ConfigComboBox {
                        id: simpleAnimCombo
                        Kirigami.FormData.label: i18n("Animation:")
                        textRole: "text"
                        // each option maps to the hourly-icon / header-icon animation booleans
                        model: [
                            { text: i18n("None"),         hourly: false, header: false },
                            { text: i18n("Hourly icons"), hourly: true,  header: false },
                            { text: i18n("Header icon"),  hourly: false, header: true  },
                            { text: i18n("Both"),         hourly: true,  header: true  }
                        ]
                        Component.onCompleted: {
                            var ho = page.cfg_simpleAnimatedIcons, he = page.cfg_simpleHeaderAnim;
                            currentIndex = (ho && he) ? 3 : (he ? 2 : (ho ? 1 : 0));
                        }
                        onActivated: {
                            page.cfg_simpleAnimatedIcons = model[currentIndex].hourly;
                            page.cfg_simpleHeaderAnim    = model[currentIndex].header;
                        }
                    }
                    ConfigComboBox {
                        id: graphColorCombo
                        Kirigami.FormData.label: i18n("Graph Color:")
                        // index maps directly to graphColorMode (0..3)
                        model: [
                            i18n("Temperature & precipitation"),
                            i18n("Temperature only"),
                            i18n("Precipitation only"),
                            i18n("None")
                        ]
                    }

                    }
                    Kirigami.FormLayout {
                    Layout.alignment: Qt.AlignTop
                    Layout.leftMargin: Kirigami.Units.gridUnit * 1
                    RowLayout {
                        // inline section header (mirrors the Cards tab)
                        Kirigami.FormData.isSection: true
                        Layout.fillWidth: true
                        Kirigami.Heading {
                            level: 5
                            text: i18n("Weather Elements (up to 4)")
                        }
                        Item { Layout.fillWidth: true }
                    }
                    ConfigSpinBox {
                        id: simpHeaderFontSpin
                        Kirigami.FormData.label: i18n("Font:")
                        from: 7
                        to: 32
                        stepSize: 1
                    }
                    ConfigComboBox {
                        id: simpMetric1
                        Kirigami.FormData.label: i18n("Element 1:")
                        textRole: "text"
                        model: page.metricOptions
                        Component.onCompleted: currentIndex = page.metricIndexOf(page.cfg_simpleHeaderMetric1)
                        onActivated: page.cfg_simpleHeaderMetric1 = page.metricOptions[currentIndex].id
                    }
                    ConfigComboBox {
                        id: simpMetric2
                        Kirigami.FormData.label: i18n("Element 2:")
                        textRole: "text"
                        model: page.metricOptions
                        Component.onCompleted: currentIndex = page.metricIndexOf(page.cfg_simpleHeaderMetric2)
                        onActivated: page.cfg_simpleHeaderMetric2 = page.metricOptions[currentIndex].id
                    }
                    ConfigComboBox {
                        id: simpMetric3
                        Kirigami.FormData.label: i18n("Element 3:")
                        textRole: "text"
                        model: page.metricOptions
                        Component.onCompleted: currentIndex = page.metricIndexOf(page.cfg_simpleHeaderMetric3)
                        onActivated: page.cfg_simpleHeaderMetric3 = page.metricOptions[currentIndex].id
                    }
                    ConfigComboBox {
                        id: simpMetric4
                        Kirigami.FormData.label: i18n("Element 4:")
                        textRole: "text"
                        model: page.metricOptions
                        Component.onCompleted: currentIndex = page.metricIndexOf(page.cfg_simpleHeaderMetric4)
                        onActivated: page.cfg_simpleHeaderMetric4 = page.metricOptions[currentIndex].id
                    }
                    Button {
                        text: i18n("Reset to none")
                        icon.name: "edit-clear-all"
                        onClicked: {
                            page.cfg_simpleHeaderMetric1 = "none"; simpMetric1.currentIndex = 0;
                            page.cfg_simpleHeaderMetric2 = "none"; simpMetric2.currentIndex = 0;
                            page.cfg_simpleHeaderMetric3 = "none"; simpMetric3.currentIndex = 0;
                            page.cfg_simpleHeaderMetric4 = "none"; simpMetric4.currentIndex = 0;
                        }
                    }
                    }
                }
            }

            // ── Panel (compact view) ──
            ScrollView {
                contentWidth: availableWidth
                Kirigami.FormLayout {
                    ConfigSpinBox {
                        id: panelIconSpin
                        Kirigami.FormData.label: i18n("Panel icon size:")
                        from: 50
                        to: 200
                        stepSize: 5
                    }
                    ConfigSpinBox {
                        id: panelFontSpin
                        Kirigami.FormData.label: i18n("Panel temperature font:")
                        from: 20
                        to: 90
                        stepSize: 2
                    }
                    CheckBox {
                        id: panelColorCheck
                        Kirigami.FormData.label: i18n("Icon color:")
                        text: i18n("Use colored icon")
                    }
                    CheckBox {
                        id: panelDetailedCheck
                        Kirigami.FormData.label: i18n("Panel:")
                        text: i18n("Detailed View")
                    }
                    ConfigComboBox {
                        id: panelSecondLineCombo
                        enabled: panelDetailedCheck.checked
                        // index maps directly to panelSecondLine (0 = H/L, 1 = precip, 2 = wind)
                        model: [
                            i18n("High / low temperature"),
                            i18n("Precipitation (chance / amount)"),
                            i18n("Wind (speed / gust)")
                        ]
                    }
                    ConfigSpinBox {
                        id: panelConditionSpin
                        enabled: panelDetailedCheck.checked
                        Kirigami.FormData.label: i18n("Condition font:")
                        from: 15
                        to: 70
                        stepSize: 2
                    }
                    ConfigSpinBox {
                        id: panelSecondLineSpin
                        enabled: panelDetailedCheck.checked
                        Kirigami.FormData.label: i18n("Second line font:")
                        from: 15
                        to: 70
                        stepSize: 2
                    }
                }
            }
        }
    }
}
