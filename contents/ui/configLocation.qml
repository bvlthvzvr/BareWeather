/*
 * Location settings — on-demand IP auto-detect (Mullvad), place-name search +
 * manual entry (Open-Meteo geocoding), and saved locations. No map picker /
 * QtLocation: it would fetch OSM map tiles, leaking your area of interest to the
 * tile server — the name search and auto-detect cover the use case privately.
 * Copyright 2026  bvlthvzvr — SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ScrollView {
    id: page

    // plain property (not aliased to the name field) so the Manual fields can be
    // left blank on open without wiping the stored location name
    property string cfg_locationName
    property double cfg_latitude
    property double cfg_longitude
    property string cfg_savedLocations
    // latches true the first time a location is set (any method); drives the
    // first-run "set your location" hint in the popup (see main.qml)
    property bool   cfg_locationConfigured
    // temperature unit + whether it's been decided — so first-time setup can pick
    // °F/°C from the location's country without overriding a deliberate choice
    property string cfg_temperatureUnit
    property bool   cfg_unitConfigured

    // shared width of the Manual input fields (name / lat / lon) and the action row,
    // so the fields are comfortably long and the Save button can centre under them.
    readonly property real manualFieldW: Kirigami.Units.gridUnit * 16

    contentWidth: availableWidth

    Component.onCompleted: _rebuildSaved()

    // ── helpers ───────────────────────────────────────────────────────────
    // set the staged location; field text is written explicitly because user
    // edits break the declarative text bindings
    function _setLocation(name, lat, lon) {
        cfg_latitude = Math.round(lat * 1e6) / 1e6;
        cfg_longitude = Math.round(lon * 1e6) / 1e6;
        latField.text = String(cfg_latitude);
        lonField.text = String(cfg_longitude);
        if (name && name.length > 0) { nameField.text = name; cfg_locationName = name; }
        cfg_locationConfigured = true;   // dismisses the first-run hint
    }

    // First-time-setup convenience: the handful of Fahrenheit countries (US +
    // territories and a few others) → °F, everywhere else → °C, based on the
    // location the user picks. Runs only until the unit is decided
    // (cfg_unitConfigured) — a manual choice in General, or the first auto-pick,
    // locks it, so changing location later never flips the unit. Accepts an ISO-2
    // code OR a country name, since auto-detect and geocoding report it differently.
    readonly property var _fahrenheitPlaces: ({
        "US": 1, "USA": 1, "UNITED STATES": 1, "UNITED STATES OF AMERICA": 1,
        "BS": 1, "BZ": 1, "KY": 1, "LR": 1, "PW": 1, "FM": 1, "MH": 1,
        "PR": 1, "GU": 1, "VI": 1, "AS": 1, "MP": 1
    })
    // Call BEFORE _setLocation (which flips locationConfigured): only the very first
    // location set, with the unit not yet decided, auto-picks — so an already-set-up
    // widget that changes location is never flipped.
    function _autoUnitFor(country) {
        if (cfg_unitConfigured || cfg_locationConfigured || !country) return;
        cfg_temperatureUnit = _fahrenheitPlaces[("" + country).trim().toUpperCase()]
                            ? "fahrenheit" : "celsius";
        cfg_unitConfigured = true;
    }

    // Geocoding is Open-Meteo only (forward search below) — no reverse lookup,
    // so naming from raw coordinates is not auto-filled.

    // an Open-Meteo geocoding result → "name, admin1, ABBREV-country"
    function _formatGeoName(r) {
        var ccMap = { "US": "USA", "GB": "UK", "AE": "UAE" };
        var cc = (r.country_code || "").toUpperCase();
        var country = ccMap[cc] || cc || r.country || "";
        var parts = [];
        if (r.name) parts.push(r.name);
        if (r.admin1 && r.admin1 !== r.name) parts.push(r.admin1);
        var name = parts.join(", ");
        if (country) name = name.length ? name + ", " + country : country;
        return name;
    }

    // Forward geocode: a place name → coordinates via Open-Meteo's geocoding API
    // (same provider as the weather, no extra third party). Open-Meteo matches the
    // place NAME only, so "Coney Island, NY" finds nothing — we try progressively
    // shorter queries (dropping the trailing qualifier) until one matches, then
    // use the dropped qualifier to FILTER the matches (so "Paris, Texas" lands on
    // Paris TX). One result fills directly; several open a pick-list.
    property bool searchBusy: false
    property string searchStatus: ""
    property var searchResults: []
    // bumped on each new search so a slow earlier response can't overwrite the
    // results of a later keystroke (live type-ahead fires many overlapping requests)
    property int _searchGen: 0
    // US state abbreviations → full name, so a qualifier like "ny" can filter
    // (Open-Meteo's admin1 is the full state name, which "ny" wouldn't match)
    readonly property var _usStates: ({
        "al": "alabama", "ak": "alaska", "az": "arizona", "ar": "arkansas", "ca": "california",
        "co": "colorado", "ct": "connecticut", "de": "delaware", "fl": "florida", "ga": "georgia",
        "hi": "hawaii", "id": "idaho", "il": "illinois", "in": "indiana", "ia": "iowa",
        "ks": "kansas", "ky": "kentucky", "la": "louisiana", "me": "maine", "md": "maryland",
        "ma": "massachusetts", "mi": "michigan", "mn": "minnesota", "ms": "mississippi",
        "mo": "missouri", "mt": "montana", "ne": "nebraska", "nv": "nevada", "nh": "new hampshire",
        "nj": "new jersey", "nm": "new mexico", "ny": "new york", "nc": "north carolina",
        "nd": "north dakota", "oh": "ohio", "ok": "oklahoma", "or": "oregon", "pa": "pennsylvania",
        "ri": "rhode island", "sc": "south carolina", "sd": "south dakota", "tn": "tennessee",
        "tx": "texas", "ut": "utah", "vt": "vermont", "va": "virginia", "wa": "washington",
        "wv": "west virginia", "wi": "wisconsin", "wy": "wyoming", "dc": "district of columbia",
        "pr": "puerto rico"
    })
    // `live` = typed-ahead search (debounced, never auto-commits, always shows the
    // dropdown); explicit (Enter / search button) is `live === false` and still
    // auto-fills when a single place matches.
    function _searchByName(q, live) {
        var gen = ++_searchGen;               // newest search wins (see _searchGen)
        if (!q || q.trim().length === 0) { searchResults = []; resultsPopup.close(); return; }
        searchBusy = true;
        if (!live) searchStatus = i18n("Searching…");   // live uses the dropdown as feedback, no status spam
        var orig = q.trim();
        var base = orig.split(",")[0].trim();   // drop anything after a comma first
        var words = base.split(/\s+/);
        var cands = [orig];                      // try the full input, then shrink
        for (var k = words.length; k >= 1; --k) {
            var c = words.slice(0, k).join(" ");
            if (cands.indexOf(c) < 0) cands.push(c);
        }
        _searchTry(cands, 0, orig, live, gen);
    }
    function _searchTry(cands, idx, orig, live, gen) {
        if (gen !== _searchGen) return;          // a newer keystroke superseded this search
        if (idx >= cands.length) {
            searchBusy = false; searchResults = []; resultsPopup.close();
            if (!live) searchStatus = i18n("No match for “%1”. Try just the place name.", orig);
            return;
        }
        var qq = cands[idx];
        var req = new XMLHttpRequest();
        req.open("GET", "https://geocoding-api.open-meteo.com/v1/search"
                 + "?count=10&format=json&language=en&name=" + encodeURIComponent(qq));
        req.onreadystatechange = function () {
            if (req.readyState !== XMLHttpRequest.DONE) return;
            if (gen !== page._searchGen) return;   // stale response — a later search is in flight
            var out = [];
            if (req.status === 200) {
                try {
                    var res = JSON.parse(req.responseText).results || [];
                    for (var i = 0; i < res.length; ++i) {
                        var r = res[i];
                        var lat = parseFloat(r.latitude), lon = parseFloat(r.longitude);
                        if (isNaN(lat) || isNaN(lon)) continue;
                        out.push({ name: page._formatGeoName(r) || r.name || qq, lat: lat, lon: lon,
                                   cc: (r.country_code || "").toUpperCase(),   // for first-setup unit auto-pick
                                   hay: ((r.admin1 || "") + " " + (r.admin2 || "") + " " + (r.admin3 || "")
                                         + " " + (r.country || "") + " " + (r.country_code || "")).toLowerCase() });
                    }
                } catch (e) {}
            }
            if (out.length === 0) { page._searchTry(cands, idx + 1, orig, live, gen); return; }   // try a shorter query
            // filter by the dropped qualifier, if any (e.g. "Texas" in "Paris, Texas")
            var qual = orig.toLowerCase().indexOf(qq.toLowerCase()) === 0
                     ? orig.substring(qq.length).replace(/^[\s,]+/, "").trim().toLowerCase() : "";
            if (qual.length > 0) {
                var needle = page._usStates[qual] || qual;   // expand "ny" → "new york"
                var f = out.filter(function (o) { return o.hay.indexOf(needle) >= 0; });
                if (f.length > 0) out = f;
            }
            page.searchBusy = false;
            page.searchResults = out;
            // live never auto-commits (the user is still typing); explicit search with a
            // single hit fills it straight in, otherwise both show the dropdown to pick from
            if (!live && out.length === 1) { resultsPopup.close(); page._pickResult(out[0]); }
            else {
                if (!live) page.searchStatus = i18n("%1 matches — pick one:", out.length);
                resultsPopup.open();
            }
        };
        req.send();
    }
    function _pickResult(r) {
        _searchGen++;                         // cancel any in-flight live search
        searchResults = [];
        resultsPopup.close();
        searchDebounce.stop();
        _autoUnitFor(r.cc);                   // first-setup: °F/°C from the result's country (before _setLocation)
        _setLocation(r.name, r.lat, r.lon);
        searchStatus = i18n("Set to: %1", r.name);
    }

    // debounce: live search fires a short beat after the last keystroke, not on
    // every letter, so a quick typist makes one request instead of a dozen
    Timer {
        id: searchDebounce
        interval: 350
        onTriggered: page._searchByName(nameField.text, true)
    }

    // The name field is deliberately narrow, but results carry the full
    // "City, State, Country" — so size the dropdown to the LONGEST result (measured
    // here) instead of cropping it. Clamped to the field width (floor) and a sane
    // max (so a very long line can't run off the dialog) where the Popup uses it.
    property real _resultsWidth: 0
    TextMetrics { id: _resultMetrics }
    onSearchResultsChanged: {
        var w = 0;
        for (var i = 0; i < searchResults.length; ++i) {
            _resultMetrics.text = searchResults[i].name;
            if (_resultMetrics.width > w) w = _resultMetrics.width;
        }
        _resultsWidth = w;
    }

    // type-ahead dropdown. A Popup (not a Menu) so it does NOT steal focus — the
    // user keeps typing in the field while the suggestions update beneath it.
    Popup {
        id: resultsPopup
        parent: nameField
        y: nameField.height
        x: 0
        // fit the longest result (+ delegate padding & scrollbar), but never narrower
        // than the field nor wide enough to spill off the dialog
        width: Math.min(Math.max(nameField.width,
                                 page._resultsWidth + Kirigami.Units.largeSpacing * 4),
                        Kirigami.Units.gridUnit * 24)
        padding: 1
        // keep focus in the text field; close on Esc or a click truly outside the
        // field (clicking the field itself keeps it open so typing continues)
        focus: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        contentItem: ListView {
            implicitHeight: Math.min(contentHeight, nameField.height * 6)
            model: page.searchResults
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            delegate: ItemDelegate {
                width: ListView.view.width
                text: modelData.name
                onClicked: page._pickResult(modelData)
            }
        }
    }

    // ── IP-based auto-detection (Mullvad only — no-logging, no key/account) ──
    property bool detectBusy: false
    property string detectStatus: ""

    function detectNow() {
        detectBusy = true;
        detectStatus = i18n("Detecting location…");
        var req = new XMLHttpRequest();
        req.open("GET", "https://am.i.mullvad.net/json");
        req.onreadystatechange = function () {
            if (req.readyState !== XMLHttpRequest.DONE) return;
            page.detectBusy = false;
            if (req.status === 200) {
                try {
                    var d = JSON.parse(req.responseText);
                    var lat = parseFloat(d.latitude), lon = parseFloat(d.longitude);
                    if (!isNaN(lat) && !isNaN(lon)) {
                        var name = d.city && d.city.length ? d.city : "";
                        page._autoUnitFor(d.country_code || d.country);   // first-setup: °F/°C from country (before _setLocation)
                        page._setLocation(name, lat, lon);
                        page.detectStatus = i18n("Detected: %1°, %2°", lat.toFixed(3), lon.toFixed(3));
                        return;
                    }
                } catch (e) {}
            }
            page.detectStatus = i18n("Could not detect location. Enter it manually below.");
        };
        req.send();
    }

    // ── saved locations (cfg_savedLocations JSON ↔ ListModel mirror) ──────
    ListModel { id: savedModel }

    function _parseSaved() {
        try {
            var locs = JSON.parse(cfg_savedLocations || "[]");
            return Array.isArray(locs) ? locs : [];
        } catch (e) { return []; }
    }
    function _rebuildSaved() {
        savedModel.clear();
        var locs = _parseSaved();
        for (var i = 0; i < locs.length; ++i)
            savedModel.append({ name: locs[i].name || "",
                                lat: Number(locs[i].lat) || 0,
                                lon: Number(locs[i].lon) || 0,
                                starred: !!locs[i].starred });
    }
    onCfg_savedLocationsChanged: _rebuildSaved()

    property string savedHint: ""
    function saveCurrent() {
        var locs = _parseSaved();
        for (var i = 0; i < locs.length; ++i) {
            if (Math.abs(locs[i].lat - cfg_latitude) < 0.01
                && Math.abs(locs[i].lon - cfg_longitude) < 0.01) {
                savedHint = i18n("This location is already saved.");
                return;
            }
        }
        locs.push({ name: cfg_locationName, lat: cfg_latitude, lon: cfg_longitude });
        cfg_savedLocations = JSON.stringify(locs);
        savedHint = "";
    }
    function useSaved(idx) {
        var locs = _parseSaved();
        if (idx < 0 || idx >= locs.length) return;
        _setLocation(locs[idx].name, locs[idx].lat, locs[idx].lon);
    }
    function removeSaved(idx) {
        var locs = _parseSaved();
        if (idx < 0 || idx >= locs.length) return;
        locs.splice(idx, 1);
        cfg_savedLocations = JSON.stringify(locs);
        savedHint = "";
    }
    // up to 3 favorites; favorites are kept grouped at the top of the list
    readonly property int maxFavorites: 3
    function toggleFavorite(idx) {
        var locs = _parseSaved();
        if (idx < 0 || idx >= locs.length) return;
        if (locs[idx].starred) {
            delete locs[idx].starred;
        } else {
            var count = 0;
            for (var i = 0; i < locs.length; ++i) if (locs[i].starred) count++;
            if (count >= maxFavorites) {
                savedHint = i18n("You can have up to %1 favorites.", maxFavorites);
                return;
            }
            locs[idx].starred = true;
        }
        // re-group: favorites first (stable), the rest below
        var fav = [], rest = [];
        for (var j = 0; j < locs.length; ++j) (locs[j].starred ? fav : rest).push(locs[j]);
        cfg_savedLocations = JSON.stringify(fav.concat(rest));
        savedHint = "";
    }
    function editSaved(idx, name, lat, lon) {
        var locs = _parseSaved();
        if (idx < 0 || idx >= locs.length) return;
        var wasActive = Math.abs(locs[idx].lat - cfg_latitude) < 0.01
                     && Math.abs(locs[idx].lon - cfg_longitude) < 0.01;
        locs[idx].name = name;
        locs[idx].lat = lat;
        locs[idx].lon = lon;
        cfg_savedLocations = JSON.stringify(locs);
        // editing the entry that is currently active also updates the staged location
        if (wasActive) _setLocation(name, lat, lon);
    }

    // ── edit dialog for a saved entry (rename / adjust coordinates) ───────
    property int _editIndex: -1
    Kirigami.Dialog {
        id: editDialog
        title: i18n("Edit location")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        padding: Kirigami.Units.largeSpacing
        preferredWidth: Kirigami.Units.gridUnit * 22
        onAccepted: {
            var lat = parseFloat(editLat.text), lon = parseFloat(editLon.text);
            if (isNaN(lat) || isNaN(lon) || editName.text.trim().length === 0) return;
            page.editSaved(page._editIndex, editName.text.trim(), lat, lon);
        }
        Kirigami.FormLayout {
            TextField {
                id: editName
                Kirigami.FormData.label: i18n("Name:")
            }
            TextField {
                id: editLat
                Kirigami.FormData.label: i18n("Latitude:")
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator { bottom: -90; top: 90; decimals: 6 }
            }
            TextField {
                id: editLon
                Kirigami.FormData.label: i18n("Longitude:")
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator { bottom: -180; top: 180; decimals: 6 }
            }
        }
    }
    function openEditDialog(idx) {
        var locs = _parseSaved();
        if (idx < 0 || idx >= locs.length) return;
        _editIndex = idx;
        editName.text = locs[idx].name || "";
        editLat.text = String(locs[idx].lat);
        editLon.text = String(locs[idx].lon);
        editDialog.open();
    }

    // ── UI ────────────────────────────────────────────────────────────────
    ColumnLayout {
        width: page.availableWidth
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true

            Kirigami.Separator {
                Kirigami.FormData.label: i18n("Automatic")
                Kirigami.FormData.isSection: true
            }
            RowLayout {
                Kirigami.FormData.label: i18n("Auto-detect:")
                Button {
                    text: i18n("Detect now")
                    icon.name: "find-location"
                    enabled: !page.detectBusy
                    onClicked: page.detectNow()
                }
                // bare info icon (no button background) — matches the Manual
                // section's info icon; hover shows how auto-detect works
                Kirigami.Icon {
                    source: "documentinfo"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                    opacity: detectInfoHover.hovered ? 1.0 : 0.65
                    HoverHandler { id: detectInfoHover; cursorShape: Qt.PointingHandCursor }
                    ToolTip.visible: detectInfoHover.hovered
                    ToolTip.text: i18n("Auto-detect estimates your location from your public IP address via Mullvad's geolocation endpoint (am.i.mullvad.net — a privacy focused, no-logging service). Your IP is sent to Mullvad to do this, but won't be stored or profiled. It's approximate, city-level, not precise location.")
                }
                BusyIndicator {
                    visible: page.detectBusy
                    running: visible
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                }
                Label {
                    text: page.detectStatus
                    visible: page.detectStatus.length > 0
                    opacity: 0.8
                }
            }

            Kirigami.Separator {
                Kirigami.FormData.label: i18n("Manual")
                Kirigami.FormData.isSection: true
            }
            TextField {
                id: nameField
                Kirigami.FormData.label: i18n("Location name:")
                // fixed manualFieldW wide so name / lat / lon all share one length
                // (the Save button centres under them — see actionRow). maximumWidth
                // caps it so the larger rightPadding can't push the field's implicit
                // width past that edge.
                Layout.fillWidth: false
                Layout.preferredWidth: page.manualFieldW
                Layout.maximumWidth: page.manualFieldW
                placeholderText: ""
                // live type-ahead: stage the name AND kick the debounced search so the
                // suggestion dropdown updates as you type (≥2 chars); clearing it closes
                // the dropdown. Enter / the search button still force an immediate lookup.
                onTextEdited: {
                    page.cfg_locationName = text;
                    if (text.trim().length >= 2) searchDebounce.restart();
                    else { searchDebounce.stop(); page.searchResults = []; resultsPopup.close(); }
                }
                // keep typed text from sliding under the inline search + info icons
                rightPadding: searchBtn.width + infoBtn.width + Kirigami.Units.smallSpacing * 4
                // type a place name and search (Enter) → fills the coordinates
                // below; Enter is swallowed so it doesn't close the config dialog
                Keys.onReturnPressed: function (e) { page._searchByName(text, false); e.accepted = true; }
                Keys.onEnterPressed:  function (e) { page._searchByName(text, false); e.accepted = true; }
                // plain icon (no button background) that triggers the search,
                // sitting just left of the info icon
                Kirigami.Icon {
                    id: searchBtn
                    anchors.right: infoBtn.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: Kirigami.Units.smallSpacing
                    width: Kirigami.Units.iconSizes.small
                    height: width
                    source: "search"
                    enabled: !page.searchBusy && nameField.text.trim().length > 0
                    opacity: enabled ? (searchHov.hovered ? 1.0 : 0.65) : 0.35
                    HoverHandler { id: searchHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { enabled: searchBtn.enabled; onTapped: page._searchByName(nameField.text, false) }
                }
                // info icon at the right edge — hover for how the name lookup works
                Kirigami.Icon {
                    id: infoBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: Kirigami.Units.smallSpacing
                    width: Kirigami.Units.iconSizes.small
                    height: width
                    source: "documentinfo"
                    opacity: infoHov.hovered ? 1.0 : 0.65
                    HoverHandler { id: infoHov; cursorShape: Qt.PointingHandCursor }
                    ToolTip.visible: infoHov.hovered
                    ToolTip.text: i18n("Type a place name (city, town, postal) to find the coordinates.  The name is looked up via OpenMeteo's geocoding service, which fills in the latitude and longitude below.")
                }
            }
            Label {
                Kirigami.FormData.label: ""
                visible: page.searchStatus.length > 0
                Layout.fillWidth: false
                Layout.preferredWidth: page.manualFieldW
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: page.searchStatus
            }
            TextField {
                id: latField
                Kirigami.FormData.label: i18n("Latitude:")
                // manualFieldW wide, matching the name & longitude fields
                Layout.fillWidth: false
                Layout.preferredWidth: page.manualFieldW
                Layout.maximumWidth: page.manualFieldW
                // left blank on open (Manual is for entering a NEW location); the
                // location in use is shown by the highlight in Saved locations
                placeholderText: ""
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator { bottom: -90; top: 90; decimals: 6 }
                onTextEdited: { page.cfg_latitude = parseFloat(text) || 0; page.cfg_locationConfigured = true; }
                // swallow Enter so it doesn't trigger the config dialog's default
                // button (which would close it)
                Keys.onReturnPressed: function (e) { e.accepted = true; }
                Keys.onEnterPressed:  function (e) { e.accepted = true; }
            }
            TextField {
                id: lonField
                Kirigami.FormData.label: i18n("Longitude:")
                Layout.fillWidth: false
                Layout.preferredWidth: page.manualFieldW
                Layout.maximumWidth: page.manualFieldW
                placeholderText: ""
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator { bottom: -180; top: 180; decimals: 6 }
                onTextEdited: { page.cfg_longitude = parseFloat(text) || 0; page.cfg_locationConfigured = true; }
                Keys.onReturnPressed: function (e) { e.accepted = true; }
                Keys.onEnterPressed:  function (e) { e.accepted = true; }
            }
            RowLayout {
                id: actionRow
                Kirigami.FormData.label: ""
                Layout.topMargin: Kirigami.Units.gridUnit * 1.5
                // as wide as the input fields, so the fill spacers centre the button under them
                Layout.preferredWidth: page.manualFieldW
                Layout.maximumWidth: page.manualFieldW
                Item { Layout.fillWidth: true }
                Button {
                    text: i18n("Save current location")
                    icon.name: "bookmark-new"
                    // the in-use location (cfg_*), not the blank-on-open field
                    enabled: page.cfg_locationName.length > 0
                    onClicked: page.saveCurrent()
                }
                Item { Layout.fillWidth: true }
            }
            Label {
                Kirigami.FormData.label: ""
                text: page.savedHint
                visible: page.savedHint.length > 0
                opacity: 0.8
            }

            Kirigami.Separator {
                Kirigami.FormData.label: i18n("Saved locations")
                Kirigami.FormData.isSection: true
            }
        }

        // saved entries (Repeater, not ListView — the page already scrolls)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            Label {
                visible: savedModel.count === 0
                text: i18n("No saved locations yet.")
                opacity: 0.6
            }

            Repeater {
                model: savedModel
                delegate: Rectangle {
                    id: savedRow
                    required property int index
                    required property string name
                    required property real lat
                    required property real lon
                    required property bool starred
                    readonly property bool isActive:
                        Math.abs(lat - page.cfg_latitude) < 0.01
                        && Math.abs(lon - page.cfg_longitude) < 0.01
                    // split the geocoded "City, Region, Country" → bold city name,
                    // with the region/country shown beside the coordinates instead
                    readonly property string baseName: {
                        var c = name.indexOf(",");
                        return c >= 0 ? name.substring(0, c).trim() : name;
                    }
                    readonly property string qualifier: {
                        var c = name.indexOf(",");
                        return c >= 0 ? name.substring(c + 1).trim() : "";
                    }

                    Layout.fillWidth: true
                    implicitHeight: rowLay.implicitHeight + Kirigami.Units.smallSpacing * 2
                    radius: 6
                    color: isActive
                        ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g,
                                  Kirigami.Theme.highlightColor.b, 0.15)
                        : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                  Kirigami.Theme.textColor.b, rowHover.hovered ? 0.10 : 0.05)
                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        id: rowLay
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Kirigami.Units.largeSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.largeSpacing

                        // single (symbolic) source so the size stays constant when
                        // active; coloured gold when this location is a favorite
                        Kirigami.Icon {
                            source: "mark-location-symbolic"
                            color: savedRow.starred ? "#f0b429" : Kirigami.Theme.textColor
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }
                        ColumnLayout {
                            spacing: 0
                            Label { text: savedRow.baseName; font.bold: true }
                            Label {
                                text: savedRow.lat.toFixed(3) + "°, " + savedRow.lon.toFixed(3) + "°"
                                      + (savedRow.qualifier ? "   ·   " + savedRow.qualifier : "")
                                opacity: 0.6
                                font: Kirigami.Theme.smallFont
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Label {
                            text: i18n("Active")
                            visible: savedRow.isActive
                            opacity: 0.7
                            font: Kirigami.Theme.smallFont
                        }
                        ToolButton {
                            icon.name: savedRow.starred ? "starred-symbolic" : "non-starred-symbolic"
                            onClicked: page.toggleFavorite(savedRow.index)
                            ToolTip.visible: hovered
                            ToolTip.text: savedRow.starred ? i18n("Remove favorite") : i18n("Set as favorite")
                        }
                        ToolButton {
                            icon.name: "document-edit"
                            onClicked: page.openEditDialog(savedRow.index)
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Edit name or coordinates")
                        }
                        ToolButton {
                            icon.name: "edit-delete"
                            onClicked: page.removeSaved(savedRow.index)
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Remove")
                        }
                    }

                    // double-click anywhere on the row switches to it (same as "Use").
                    // The buttons above grab their own clicks, so this only fires on
                    // the row body, and never on the already-active row.
                    TapHandler {
                        enabled: !savedRow.isActive
                        onDoubleTapped: page.useSaved(savedRow.index)
                    }
                    HoverHandler { id: rowHover }
                }
            }
        }
    }
}
