//@ pragma DataDir $BASE/radio-atlas-lite
import QtQuick
import Quickshell
import Quickshell.Io
import "RadioModel.js" as RadioModel

FloatingWindow {
    id: root
    visible: true
    implicitWidth: 1180
    implicitHeight: 740
    color: background

    // Standalone palette: no DMS/Omarchy imports required.
    property color background: "#0c1014"
    property color surface: "#12181e"
    property color surface2: "#192129"
    property color surfaceHover: "#222d37"
    property color foreground: "#edf1f5"
    property color dim: "#9aa6b2"
    property color faint: "#394550"
    property color accent: "#8ab4f8"
    property color danger: "#ff8a80"
    property color favoriteColor: "#ffd166"

    property var countries: []
    property var worldStations: []
    property var results: []
    property string mode: "world"
    property string activeCountryCode: ""
    property string activeCountryName: ""
    property int selectedIndex: -1
    property var selectedStation: null
    property var currentStation: null
    property var pendingStation: null
    property bool playerRunning: false
    property bool playerPaused: false
    property bool intentionalPlayerStop: false
    property bool fetching: false
    property string statusText: "Loading stations…"
    property string errorText: ""
    property bool mpvAvailable: true
    property int requestSerial: 0
    property bool closing: false

    readonly property var displayStations: mode === "favorites"
        ? state.favorites
        : (mode === "recent" ? state.recent : results)

    readonly property var currentGeoStations: RadioModel.mergeGeoStations(
        worldStations, displayStations, countries)

    function cleanText(value, limit) {
        return String(value || "").replace(/[\r\n\t]+/g, " ").trim().slice(0, limit || 200)
    }

    function normalizeStation(raw) {
        if (!raw || typeof raw !== "object") return null
        var uuid = cleanText(raw.stationuuid || raw.uuid, 64)
        var name = cleanText(raw.name || "Unknown station", 160)
        var url = cleanText(raw.url_resolved || raw.url, 2048)
        if (!uuid || !/^https?:\/\//i.test(url)) return null

        var latitude = raw.geo_lat !== undefined ? Number(raw.geo_lat) : Number(raw.latitude)
        var longitude = raw.geo_long !== undefined ? Number(raw.geo_long) : Number(raw.longitude)
        if (!isFinite(latitude) || latitude < -90 || latitude > 90) latitude = null
        if (!isFinite(longitude) || longitude < -180 || longitude > 180) longitude = null

        return {
            uuid: uuid,
            name: name,
            url: url,
            country: cleanText(raw.country, 100),
            countryCode: cleanText(raw.countrycode || raw.countryCode, 2).toUpperCase(),
            state: cleanText(raw.state, 100),
            language: cleanText(raw.language, 120),
            tags: cleanText(raw.tags, 500),
            codec: cleanText(raw.codec, 32),
            bitrate: Math.max(0, Number(raw.bitrate || 0) || 0),
            latitude: latitude,
            longitude: longitude
        }
    }

    function normalizeRows(rawRows, maxRows) {
        var input = Array.isArray(rawRows) ? rawRows : []
        var out = []
        var seen = ({})
        var limit = Math.max(1, Number(maxRows || 500))
        for (var i = 0; i < input.length && out.length < limit; i++) {
            var station = normalizeStation(input[i])
            if (!station || seen["$" + station.uuid]) continue
            seen["$" + station.uuid] = true
            out.push(station)
        }
        return out
    }

    function queryString(params) {
        var out = []
        for (var key in params) {
            if (params[key] === undefined || params[key] === null || params[key] === "") continue
            out.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(params[key])))
        }
        return out.join("&")
    }

    function apiGet(path, params, callback) {
        var serial = ++requestSerial
        fetching = true
        errorText = ""
        var url = "https://all.api.radio-browser.info" + path
        var query = queryString(params || ({}))
        if (query) url += "?" + query

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || serial !== root.requestSerial) return
            root.fetching = false
            if (xhr.status < 200 || xhr.status >= 300) {
                root.errorText = "Radio Browser unavailable (HTTP " + xhr.status + ")"
                callback(null)
                return
            }
            try {
                var payload = JSON.parse(xhr.responseText || "[]")
                callback(root.normalizeRows(payload, 500))
            } catch (error) {
                root.errorText = "Radio Browser returned invalid data"
                callback(null)
            }
        }
        xhr.onerror = function() {
            if (serial !== root.requestSerial) return
            root.fetching = false
            root.errorText = "Could not reach Radio Browser"
            callback(null)
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function setSelection(index) {
        var rows = displayStations
        if (!Array.isArray(rows) || rows.length === 0) {
            selectedIndex = -1
            selectedStation = null
            return
        }
        selectedIndex = Math.max(0, Math.min(rows.length - 1, Number(index)))
        selectedStation = rows[selectedIndex]
        if (stationList.count > 0) stationList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function setList(nextMode, rows) {
        mode = nextMode
        if (nextMode !== "favorites" && nextMode !== "recent") results = Array.isArray(rows) ? rows : []
        setSelection(displayStations.length ? 0 : -1)
    }

    function moveSelection(delta) {
        if (!displayStations.length) return
        var next = selectedIndex < 0 ? 0 : (selectedIndex + delta + displayStations.length) % displayStations.length
        setSelection(next)
    }

    function showWorld(refresh) {
        activeCountryCode = ""
        activeCountryName = ""
        errorText = ""
        setList("world", worldStations)
        searchInput.text = ""
        if (refresh !== false) fetchWorld()
    }

    function fetchWorld() {
        statusText = "Loading world stations…"
        apiGet("/json/stations/search", {
            has_geo_info: "true",
            hidebroken: "true",
            order: "clickcount",
            reverse: "true",
            limit: 500
        }, function(rows) {
            if (rows === null) return
            root.worldStations = RadioModel.mergeStations(root.worldStations, rows, 1500)
            root.setList("world", root.worldStations)
            root.statusText = root.worldStations.length + " stations loaded"
        })
    }

    function showFavorites() {
        ++requestSerial
        fetching = false
        errorText = ""
        mode = "favorites"
        searchInput.text = ""
        setSelection(state.favorites.length ? 0 : -1)
    }

    function showRecent() {
        ++requestSerial
        fetching = false
        errorText = ""
        mode = "recent"
        searchInput.text = ""
        setSelection(state.recent.length ? 0 : -1)
    }

    function previewSearch(text) {
        var query = cleanText(text, 128)
        if (!query) {
            setList("world", worldStations)
            return false
        }
        setList("search", RadioModel.searchStations(worldStations, query, 150))
        return true
    }

    function search(text) {
        var query = cleanText(text, 128)
        if (!query) {
            showWorld(false)
            return
        }
        previewSearch(query)
        statusText = "Searching…"
        apiGet("/json/stations/search", {
            name: query,
            hidebroken: "true",
            order: "clickcount",
            reverse: "true",
            limit: 120
        }, function(rows) {
            if (rows === null || root.mode !== "search") return
            var local = RadioModel.searchStations(root.worldStations, query, 150)
            root.setList("search", RadioModel.mergeStations(local, rows, 200))
            root.statusText = root.displayStations.length + " matches"
        })
    }

    function browseCountry(code, name) {
        var countryCode = cleanText(code, 2).toUpperCase()
        if (!/^[A-Z]{2}$/.test(countryCode)) return
        activeCountryCode = countryCode
        activeCountryName = cleanText(name || countryCode, 100)
        searchInput.text = activeCountryName
        var cached = RadioModel.stationsForCountry(worldStations, countryCode, 150)
        setList("country", cached)
        statusText = "Loading " + activeCountryName + "…"
        apiGet("/json/stations/bycountrycodeexact/" + encodeURIComponent(countryCode), {
            hidebroken: "true",
            order: "clickcount",
            reverse: "true",
            limit: 150
        }, function(rows) {
            if (rows === null || root.mode !== "country" || root.activeCountryCode !== countryCode) return
            root.worldStations = RadioModel.prioritizeStations(rows, root.worldStations, 1500)
            root.setList("country", rows)
            root.statusText = rows.length + " stations in " + root.activeCountryName
        })
    }

    function tuneRandom() {
        statusText = "Finding a random station…"
        setList("random", [])
        searchInput.text = ""
        apiGet("/json/stations/search", {
            hidebroken: "true",
            order: "random",
            limit: 40
        }, function(rows) {
            if (rows === null || root.mode !== "random") return
            var recentIds = ({})
            for (var i = 0; i < state.recent.length; i++) recentIds["$" + state.recent[i].uuid] = true
            var chosen = null
            for (var j = 0; j < rows.length; j++) {
                if (!recentIds["$" + rows[j].uuid]) { chosen = rows[j]; break }
            }
            if (!chosen && rows.length) chosen = rows[0]
            root.setList("random", rows)
            if (chosen) {
                root.setSelection(RadioModel.indexByUuid(rows, chosen.uuid))
                root.playSelected()
            }
        })
    }

    function safePlaybackUrl(url) {
        var value = String(url || "").trim()
        if (!/^https?:\/\//i.test(value) || /[\r\n]/.test(value)) return false
        // Cheap literal-host guard. This is NOT a full sandbox; see README.
        var lower = value.toLowerCase()
        if (/^https?:\/\/(localhost|127\.|0\.|10\.|192\.168\.|169\.254\.|\[?::1\]?)/.test(lower)) return false
        var m = lower.match(/^https?:\/\/(172\.([0-9]{1,3})\.)/)
        if (m && Number(m[2]) >= 16 && Number(m[2]) <= 31) return false
        return true
    }

    function recordPlayed(station) {
        if (!station || !station.uuid) return
        var rows = []
        for (var i = 0; i < state.recent.length; i++) {
            if (state.recent[i] && state.recent[i].uuid !== station.uuid) rows.push(state.recent[i])
        }
        rows.unshift(station)
        state.recent = rows.slice(0, 30)
    }

    function isFavorite(uuid) {
        return RadioModel.indexByUuid(state.favorites, uuid) >= 0
    }

    function toggleFavorite(station) {
        if (!station || !station.uuid) return
        var rows = []
        var existed = false
        for (var i = 0; i < state.favorites.length; i++) {
            if (state.favorites[i] && state.favorites[i].uuid === station.uuid) existed = true
            else rows.push(state.favorites[i])
        }
        if (!existed) rows.unshift(station)
        state.favorites = rows.slice(0, 300)
    }

    function startStation(station) {
        if (!station || !safePlaybackUrl(station.url)) {
            errorText = "Blocked an invalid/local stream URL"
            return
        }
        if (!mpvAvailable) {
            errorText = "mpv is not installed"
            return
        }
        pendingStation = station
        playerPaused = false
        errorText = ""
        if (player.running) {
            intentionalPlayerStop = true
            player.running = false
            return
        }
        startPendingStation()
    }

    function startPendingStation() {
        if (!pendingStation) return
        var station = pendingStation
        pendingStation = null
        currentStation = station
        selectedStation = station
        intentionalPlayerStop = false
        player.command = [
            "mpv",
            "--no-config",
            "--load-scripts=no",
            "--no-video",
            "--force-window=no",
            "--audio-display=no",
            "--really-quiet",
            "--cache=yes",
            "--cache-secs=10",
            "--network-timeout=20",
            "--load-unsafe-playlists=no",
            "--volume=" + state.volume,
            station.url
        ]
        player.running = true
        playerRunning = true
        playerPaused = false
        recordPlayed(station)
        statusText = "Playing " + station.name

        // Radio Browser click counter; no response data is used.
        try {
            var click = new XMLHttpRequest()
            click.open("GET", "https://all.api.radio-browser.info/json/url/" + encodeURIComponent(station.uuid))
            click.send()
        } catch (e) {}
    }

    function playSelected() {
        if (selectedStation) startStation(selectedStation)
    }

    function togglePlayback() {
        if (playerRunning && player.running) {
            intentionalPlayerStop = true
            playerPaused = true
            playerRunning = false
            player.running = false
            statusText = currentStation ? "Paused · " + currentStation.name : "Paused"
            return
        }
        if (currentStation) startStation(currentStation)
        else playSelected()
    }

    function stopPlayback() {
        pendingStation = null
        playerPaused = false
        playerRunning = false
        intentionalPlayerStop = true
        if (player.running) player.running = false
        currentStation = null
        statusText = "Stopped"
    }

    function playOffset(delta) {
        var rows = displayStations
        if (!rows.length) return
        var base = currentStation ? RadioModel.indexByUuid(rows, currentStation.uuid) : selectedIndex
        if (base < 0) base = 0
        setSelection((base + delta + rows.length) % rows.length)
        playSelected()
    }

    function changeVolume(delta) {
        state.volume = Math.max(0, Math.min(100, state.volume + delta))
        if (playerRunning && currentStation) volumeRestart.restart()
    }

    function activateMapStation(station) {
        var index = RadioModel.indexByUuid(displayStations, station.uuid)
        if (index < 0) {
            index = RadioModel.indexByUuid(worldStations, station.uuid)
            if (index < 0) return
            setList("world", worldStations)
        }
        setSelection(index)
        playSelected()
    }

    function closeApp() {
        closing = true
        pendingStation = null
        if (player.running) player.running = false
        visible = false
        Qt.quit()
    }

    FileView {
        id: countryFile
        path: Qt.resolvedUrl("assets/countries.json").toString().replace(/^file:\/\//, "")
        printErrors: true
        onLoaded: {
            try {
                var payload = JSON.parse(text())
                root.countries = Array.isArray(payload.features) ? payload.features : []
            } catch (error) {
                root.errorText = "Map data could not be loaded"
            }
        }
    }

    FileView {
        id: stateFile
        path: Quickshell.dataPath("state.json")
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: state
            property var favorites: []
            property var recent: []
            property int volume: 70
        }
    }

    Process {
        id: mpvCheck
        command: ["sh", "-c", "command -v mpv >/dev/null 2>&1"]
        running: true
        onExited: function(exitCode) {
            root.mpvAvailable = exitCode === 0
            if (!root.mpvAvailable) root.errorText = "mpv not found · install with: sudo dnf install mpv"
        }
    }

    Process {
        id: player
        command: []
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (text && !root.intentionalPlayerStop && !root.closing)
                    root.errorText = "Stream ended or mpv could not play it"
            }
        }
        onExited: function(exitCode) {
            var wasIntentional = root.intentionalPlayerStop
            root.intentionalPlayerStop = false
            root.playerRunning = false
            if (root.closing) return
            if (root.pendingStation) {
                Qt.callLater(root.startPendingStation)
                return
            }
            if (!wasIntentional && !root.playerPaused && root.currentStation) {
                root.statusText = "Stream ended · " + root.currentStation.name
                if (exitCode !== 0) root.errorText = "This station could not be played"
            }
        }
    }

    Timer {
        id: searchTimer
        interval: 350
        repeat: false
        onTriggered: root.search(searchInput.text)
    }

    Timer {
        id: volumeRestart
        interval: 250
        repeat: false
        onTriggered: {
            if (root.playerRunning && root.currentStation) root.startStation(root.currentStation)
        }
    }

    Component.onCompleted: fetchWorld()

    Connections {
        target: Quickshell
        function onLastWindowClosed() { Qt.quit() }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
            if (searchInput.activeFocus) {
                if (event.key === Qt.Key_Escape) {
                    searchInput.text = ""
                    root.showWorld(false)
                    keyCatcher.forceActiveFocus()
                    event.accepted = true
                }
                return
            }
            if (event.key === Qt.Key_Escape) {
                root.closeApp(); event.accepted = true
            } else if (event.key === Qt.Key_Slash) {
                searchInput.forceActiveFocus(); searchInput.selectAll(); event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                root.moveSelection(-1); event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                root.moveSelection(1); event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.playSelected(); event.accepted = true
            } else if (event.key === Qt.Key_Space) {
                root.togglePlayback(); event.accepted = true
            } else if (event.key === Qt.Key_R) {
                root.tuneRandom(); event.accepted = true
            } else if (event.key === Qt.Key_F && root.selectedStation) {
                root.toggleFavorite(root.selectedStation); event.accepted = true
            } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
                root.changeVolume(5); event.accepted = true
            } else if (event.key === Qt.Key_Minus) {
                root.changeVolume(-5); event.accepted = true
            }
        }
    }

    Rectangle {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 64
        color: root.surface

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: "RADIO ATLAS"
            color: root.foreground
            font.pixelSize: 19
            font.bold: true
            font.letterSpacing: 1.5
        }

        Rectangle {
            id: searchBox
            width: Math.min(360, parent.width * 0.34)
            height: 38
            anchors.right: randomButton.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            radius: 9
            color: root.background
            border.width: searchInput.activeFocus ? 1 : 0
            border.color: root.accent

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: root.foreground
                selectionColor: root.accent
                selectedTextColor: root.background
                font.pixelSize: 14
                clip: true
                onTextEdited: {
                    if (!root.previewSearch(text)) return
                    searchTimer.restart()
                }
                onAccepted: {
                    searchTimer.stop()
                    root.search(text)
                    keyCatcher.forceActiveFocus()
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: !searchInput.text && !searchInput.activeFocus
                text: "Search stations"
                color: root.dim
                font.pixelSize: 14
            }
        }

        AppButton {
            id: randomButton
            anchors.right: closeButton.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: "Random"
            foreground: root.foreground
            accent: root.accent
            background: root.background
            hoverBackground: root.surfaceHover
            onClicked: root.tuneRandom()
        }

        AppButton {
            id: closeButton
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "×"
            fontSize: 20
            foreground: root.foreground
            accent: root.accent
            background: root.background
            hoverBackground: root.surfaceHover
            onClicked: root.closeApp()
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.faint
        }
    }

    Item {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: footer.top

        Item {
            id: mapPane
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: sidebar.left

            Globe {
                id: globe
                anchors.fill: parent
                anchors.margins: 14
                countries: root.countries
                stations: root.currentGeoStations
                selectedStation: root.currentStation || root.selectedStation
                activeCountryCode: root.activeCountryCode
                backgroundColor: root.background
                sphereColor: "#111820"
                landColor: "#28343e"
                gridColor: root.dim
                outlineColor: "#7c8b98"
                signalColor: root.foreground
                accentColor: root.accent
                textColor: root.foreground
                fontFamily: "sans-serif"
                onInteractionStarted: keyCatcher.forceActiveFocus()
                onStationActivated: function(station) { root.activateMapStation(station) }
                onCountryActivated: function(code, name) { root.browseCountry(code, name) }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                width: parent.width - 36
                text: root.errorText || (root.activeCountryName
                    ? root.activeCountryName + " · click another country to browse"
                    : "Drag globe · wheel to zoom · click a signal or country")
                color: root.errorText ? root.danger : root.dim
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: divider
            width: 1
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: sidebar.left
            color: root.faint
        }

        Rectangle {
            id: sidebar
            width: Math.max(330, Math.min(410, parent.width * 0.36))
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: root.surface

            Item {
                id: tabs
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 54

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    AppButton {
                        text: "World"
                        active: root.mode === "world"
                        foreground: root.foreground; accent: root.accent
                        background: root.background; hoverBackground: root.surfaceHover
                        onClicked: root.showWorld()
                    }
                    AppButton {
                        text: "Favorites"
                        active: root.mode === "favorites"
                        foreground: root.foreground; accent: root.accent
                        background: root.background; hoverBackground: root.surfaceHover
                        onClicked: root.showFavorites()
                    }
                    AppButton {
                        text: "Recent"
                        active: root.mode === "recent"
                        foreground: root.foreground; accent: root.accent
                        background: root.background; hoverBackground: root.surfaceHover
                        onClicked: root.showRecent()
                    }
                }

                Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.faint }
            }

            ListView {
                id: stationList
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: tabs.bottom
                anchors.bottom: playerPanel.top
                clip: true
                model: root.displayStations
                currentIndex: root.selectedIndex
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 500

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: stationList.width
                    height: 62
                    color: root.currentStation && root.currentStation.uuid === modelData.uuid
                        ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)
                        : rowMouse.containsMouse ? root.surfaceHover : "transparent"

                    Rectangle {
                        visible: root.currentStation && root.currentStation.uuid === row.modelData.uuid
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3
                        color: root.accent
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: favButton.left
                        anchors.rightMargin: 8
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        text: row.modelData.name
                        color: root.foreground
                        font.pixelSize: 14
                        font.bold: root.currentStation && root.currentStation.uuid === row.modelData.uuid
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: favButton.left
                        anchors.rightMargin: 8
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        text: RadioModel.stationMeta(row.modelData)
                            + (RadioModel.compactTags(row.modelData.tags, 2)
                               ? " · " + RadioModel.compactTags(row.modelData.tags, 2) : "")
                        color: root.dim
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    AppButton {
                        id: favButton
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.isFavorite(row.modelData.uuid) ? "★" : "☆"
                        fontSize: 17
                        horizontalPadding: 9
                        buttonHeight: 34
                        foreground: root.isFavorite(row.modelData.uuid) ? root.favoriteColor : root.dim
                        accent: root.favoriteColor
                        background: "transparent"
                        hoverBackground: root.background
                        onClicked: root.toggleFavorite(row.modelData)
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.left: parent.left
                        anchors.right: favButton.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.setSelection(row.index)
                        onClicked: {
                            root.setSelection(row.index)
                            root.playSelected()
                            keyCatcher.forceActiveFocus()
                        }
                    }

                    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.faint }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 36
                    visible: root.displayStations.length === 0
                    text: root.fetching ? "Loading stations…"
                        : (root.mode === "favorites" ? "No favorites yet"
                        : root.mode === "recent" ? "No listening history yet"
                        : "No stations found")
                    color: root.dim
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
            }

            Rectangle {
                id: playerPanel
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 132
                color: root.background

                Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: root.faint }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    text: root.currentStation ? root.currentStation.name : "Nothing playing"
                    color: root.foreground
                    font.pixelSize: 14
                    font.bold: !!root.currentStation
                    elide: Text.ElideRight
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 36
                    text: root.errorText || root.statusText
                    color: root.errorText ? root.danger : root.dim
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    spacing: 6

                    AppButton {
                        text: "◀"
                        enabled: root.displayStations.length > 0
                        foreground: root.foreground; accent: root.accent
                        background: root.surface2; hoverBackground: root.surfaceHover
                        onClicked: root.playOffset(-1)
                    }
                    AppButton {
                        text: root.playerRunning ? "Ⅱ" : "▶"
                        enabled: !!root.currentStation || !!root.selectedStation
                        foreground: root.foreground; accent: root.accent
                        background: root.surface2; hoverBackground: root.surfaceHover
                        onClicked: root.togglePlayback()
                    }
                    AppButton {
                        text: "▶|"
                        enabled: root.displayStations.length > 0
                        foreground: root.foreground; accent: root.accent
                        background: root.surface2; hoverBackground: root.surfaceHover
                        onClicked: root.playOffset(1)
                    }
                    AppButton {
                        text: "■"
                        enabled: !!root.currentStation || root.playerRunning
                        foreground: root.foreground; accent: root.accent
                        background: root.surface2; hoverBackground: root.surfaceHover
                        onClicked: root.stopPlayback()
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    spacing: 5

                    AppButton {
                        text: "−"
                        enabled: state.volume > 0
                        foreground: root.foreground; accent: root.accent
                        background: root.surface2; hoverBackground: root.surfaceHover
                        onClicked: root.changeVolume(-5)
                    }
                    Rectangle {
                        width: 48
                        height: 34
                        radius: 8
                        color: root.surface2
                        Text { anchors.centerIn: parent; text: state.volume + "%"; color: root.dim; font.pixelSize: 11 }
                    }
                    AppButton {
                        text: "+"
                        enabled: state.volume < 100
                        foreground: root.foreground; accent: root.accent
                        background: root.surface2; hoverBackground: root.surfaceHover
                        onClicked: root.changeVolume(5)
                    }
                }
            }
        }
    }

    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 30
        color: root.surface

        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: root.faint }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: root.fetching ? "Loading…" : (root.errorText ? root.errorText : root.statusText)
            color: root.errorText ? root.danger : root.dim
            font.pixelSize: 11
            elide: Text.ElideRight
            width: parent.width - shortcuts.width - 40
        }

        Text {
            id: shortcuts
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "/ search · R random · F favorite · Space play/pause · Esc close"
            color: root.dim
            font.pixelSize: 10
        }
    }
}
