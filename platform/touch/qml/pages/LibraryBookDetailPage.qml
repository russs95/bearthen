import QtQuick 2.12
import Ubuntu.Components 1.3
import "../js/Library.js" as Library

Page {
    id: libBookPage

    property var    book:            null
    property string bookDescription: ""
    property string descStatus:      "Loading description…"
    property bool   descLoading:     false

    // ════════════════════════════════════════════════════════════════════════════
    // COLOUR PALETTE — tweak here, effects ripple through the whole page
    // ════════════════════════════════════════════════════════════════════════════

    // ── Browns (earthen / bark palette) ──────────────────────────────────────
    // Primary brown — used for: header "Your Books", Remove button, debug labels
    readonly property color clrBrown:       root.isDarkMode ? "#A07040" : "#6B3A20"
    // Lighter brown — available for hover states, accents
    readonly property color clrBrownLight:  root.isDarkMode ? "#C09060" : "#8B5228"

    // ── Greens (forest palette) ───────────────────────────────────────────────
    // Dark green — used for: Start Reading button bg, progress bar fill, divider
    readonly property color clrGreenDark:   "#2C5F2E"
    // Bright green — used for: badge text, Public Domain bar, link accents
    readonly property color clrGreenBright: "#4CAF50"

    // ── Surfaces ──────────────────────────────────────────────────────────────
    // Hero section background
    readonly property color clrHeroBg:      root.isDarkMode ? "#1A0D06" : "#F5EAD0"
    // Page background
    readonly property color clrPageBg:      root.isDarkMode ? "#121212" : "#FFFFFF"
    // Header bar background
    readonly property color clrHeaderBg:    root.isDarkMode ? "#1A1A1A" : "#F5F5F5"

    // ── Text ──────────────────────────────────────────────────────────────────
    // Primary body text
    readonly property color clrTextPrimary: root.isDarkMode ? "#FFFFFF" : "#212121"
    // Secondary / subtitle text
    readonly property color clrTextMuted:   root.isDarkMode ? "#AAAAAA" : "#666666"

    // ── Legacy aliases (keep so nothing breaks mid-refactor) ──────────────────
    readonly property color earthBrown:      clrBrown
    readonly property color earthBrownLight: clrBrownLight
    readonly property color earthBrownMid:   clrBrown

    // Guard against re-entrant calls: book = fresh triggers onBookChanged
    // which would call _initBook again → infinite recursion → stack overflow.
    property bool _initialising: false

    function _initBook(b) {
        if (!b || _initialising) return
        _initialising = true
        var fresh = Library.getBook(b.id)
        if (fresh) {
            book = fresh          // triggers onBookChanged — guard blocks re-entry
            b = fresh
        }
        _initialising = false     // re-enable before any further work
        bookDescription = b.description || ""
        if (bookDescription !== "") {
            // Use embedded EPUB metadata description — no network call needed
            descStatus  = bookDescription
            descLoading = false
        } else {
            descStatus  = "Loading description…"
            fetchDescription(b)
        }
    }

    Component.onCompleted: { _initBook(book) }
    onBookChanged:          { _initBook(book) }

    header: PageHeader {
        id: pageHeader
        contents: Item {
            anchors { fill: parent; leftMargin: units.gu(1) }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "Your Books"
                fontSize: "large"
                font.weight: Font.Light
                color: libBookPage.clrBrown
            }
        }
        StyleHints {
            backgroundColor: libBookPage.clrHeaderBg
            dividerColor: "#2C5F2E"
        }
        leadingActionBar.actions: [
            Action { iconName: "back"; text: "Back"; onTriggered: pageStack.pop() }
        ]
    }

    // Page background — solid colour + library texture behind all content
    Rectangle {
        anchors.fill: parent
        color: libBookPage.clrPageBg
        Behavior on color { ColorAnimation { duration: 250 } }
    }
    Item {
        anchors.fill: parent
        opacity: root.isDarkMode ? 0.10 : 0.06
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            Repeater {
                model: 20
                Image {
                    width: parent ? parent.width : 300; height: width
                    source: root.isDarkMode
                        ? Qt.resolvedUrl("../../assets/textures/library-background-night-mode.svg")
                        : Qt.resolvedUrl("../../assets/textures/library-background-day-mode.svg")
                    fillMode: Image.Stretch; smooth: true; asynchronous: true
                }
            }
        }
    }

    Flickable {
        anchors { top: pageHeader.bottom; left: parent.left
                  right: parent.right; bottom: parent.bottom }
        contentHeight: contentCol.height + units.gu(4)
        clip: true; flickableDirection: Flickable.VerticalFlick

        Column {
            id: contentCol
            width: parent.width
            spacing: 0

            // ── Hero ──────────────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: heroRow.height + units.gu(4)
                color: libBookPage.clrHeroBg
                Behavior on color { ColorAnimation { duration: 250 } }

                Row {
                    id: heroRow
                    anchors { top: parent.top; topMargin: units.gu(2)
                              left: parent.left; leftMargin: units.gu(2)
                              right: parent.right; rightMargin: units.gu(2) }
                    spacing: units.gu(2)

                    // Cover
                    Rectangle {
                        width: units.gu(14); height: units.gu(20)
                        color: root.isDarkMode ? "#2A1508" : "#E8D5B0"
                        radius: units.dp(6)
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(8); height: units.gu(8)
                            name: "stock_ebook"
                            color: root.isDarkMode ? "#8B5A32" : "#A0784A"
                            opacity: 0.25
                        }
                        Image {
                            id: coverImg
                            anchors.fill: parent; anchors.margins: units.dp(2)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true; cache: false
                            source: {
                                if (!libBookPage.book) return ""
                                if (libBookPage.book.cover_local && libBookPage.book.cover_local !== "")
                                    return "file://" + libBookPage.book.cover_local
                                if (libBookPage.book.cover_url && libBookPage.book.cover_url !== "")
                                    return libBookPage.book.cover_url
                                if (libBookPage.book.cover && libBookPage.book.cover !== "")
                                    return libBookPage.book.cover
                                return ""
                            }
                        }
                    }

                    // Metadata
                    Column {
                        width: parent.width - units.gu(16)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.gu(0.8)

                        Label {
                            width: parent.width
                            text: libBookPage.book ? (libBookPage.book.title || "") : ""
                            fontSize: "large"; font.weight: Font.Medium
                            color: root.isDarkMode ? "#FFFFFF" : "#212121"
                            wrapMode: Text.WordWrap
                        }
                        Label {
                            width: parent.width
                            text: libBookPage.book
                                  ? (libBookPage.book.author_display
                                     || libBookPage.book.author || "") : ""
                            fontSize: "small"
                            color: root.isDarkMode ? "#AAAAAA" : "#666666"
                            wrapMode: Text.WordWrap
                        }
                        Label {
                            visible: libBookPage.book
                                     ? (libBookPage.book.publisher || "") !== "" : false
                            width: parent.width
                            text: libBookPage.book ? (libBookPage.book.publisher || "") : ""
                            fontSize: "x-small"
                            color: root.isDarkMode ? "#888888" : "#999999"
                        }
                        Label {
                            visible: libBookPage.book
                                     ? (libBookPage.book.published_date || "") !== "" : false
                            width: parent.width
                            text: libBookPage.book
                                  ? _formatDate(libBookPage.book.published_date || "") : ""
                            fontSize: "x-small"
                            color: root.isDarkMode ? "#888888" : "#999999"
                        }
                        Label {
                            visible: libBookPage.book
                                     ? (libBookPage.book.file_size_kb || 0) > 0 : false
                            width: parent.width
                            text: libBookPage.book
                                  ? _formatSize(libBookPage.book.file_size_kb || 0) : ""
                            fontSize: "x-small"
                            color: root.isDarkMode ? "#888888" : "#999999"
                        }
                        Label {
                            visible: libBookPage.book
                                     ? (libBookPage.book.birth_year || 0) > 0 : false
                            text: libBookPage.book
                                  ? (libBookPage.book.birth_year + " – " +
                                     (libBookPage.book.death_year
                                      ? libBookPage.book.death_year : "present")) : ""
                            fontSize: "x-small"
                            color: root.isDarkMode ? "#888888" : "#999999"
                        }
                        Item { width: 1; height: units.gu(0.2) }

                        // Badges row
                        Row {
                            spacing: units.gu(0.6)
                            Rectangle {
                                height: units.gu(2.4)
                                width: srcBadgeRow.width + units.gu(1.6)
                                radius: height / 2
                                color: libBookPage.book && libBookPage.book.source === "local"
                                       ? "#666666" : "#8B5A32"
                                Row {
                                    id: srcBadgeRow
                                    anchors.centerIn: parent
                                    spacing: units.gu(0.3)
                                    Icon {
                                        width: units.gu(1.5); height: units.gu(1.5)
                                        name: libBookPage.book && libBookPage.book.source === "local"
                                              ? "add" : "tick"
                                        color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Label {
                                        text: libBookPage.book && libBookPage.book.source === "local"
                                              ? "Added by user" : "Downloaded"
                                        fontSize: "x-small"; color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        // Language + category tags
                        Row {
                            spacing: units.gu(0.6)
                            Rectangle {
                                height: units.gu(2.4); width: langLbl.width + units.gu(1.2)
                                radius: height / 2
                                color: root.isDarkMode ? "#252525" : "#DDDDDD"
                                Label { id: langLbl; anchors.centerIn: parent
                                        text: libBookPage.book
                                              ? (libBookPage.book.language || "EN").toUpperCase() : "EN"
                                        fontSize: "x-small"
                                        color: root.isDarkMode ? "#AAAAAA" : "#666666" }
                            }
                            Rectangle {
                                height: units.gu(2.4); width: catLbl.width + units.gu(1.2)
                                radius: height / 2
                                color: root.isDarkMode ? "#252525" : "#DDDDDD"
                                Label { id: catLbl; anchors.centerIn: parent
                                        text: libBookPage.book
                                              ? (libBookPage.book.category || "other") : ""
                                        fontSize: "x-small"
                                        color: root.isDarkMode ? "#AAAAAA" : "#666666" }
                            }
                        }
                    }
                }
            }

            // ── Reading progress bar — above description ──────────────────────
            Rectangle {
                visible: libBookPage.book ? libBookPage.book.read_percent > 0 : false
                width: parent.width; height: units.gu(5.5)
                color: libBookPage.clrHeroBg
                Behavior on color { ColorAnimation { duration: 250 } }
                Label {
                    anchors { left: parent.left; leftMargin: units.gu(2)
                              top: parent.top; topMargin: units.gu(1) }
                    text: libBookPage.book
                          ? (libBookPage.book.is_finished ? "Finished ✓"
                             : "Reading — " + parseFloat(libBookPage.book.read_percent).toFixed(1) + "% complete") : ""
                    fontSize: "x-small"; color: "#888888"
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                              leftMargin: units.gu(2); rightMargin: units.gu(2)
                              bottomMargin: units.gu(1) }
                    height: units.dp(3); radius: height / 2
                    color: root.isDarkMode ? "#2A2A2A" : "#E0E0E0"
                    Rectangle {
                        width: parent.width * ((libBookPage.book
                               ? libBookPage.book.read_percent : 0) / 100)
                        height: parent.height; radius: parent.radius
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#8B5A32" }
                            GradientStop { position: 1.0; color: "#2C5F2E" }
                        }
                        Behavior on width { NumberAnimation { duration: 400 } }
                    }
                }
            }

            // ── Description ───────────────────────────────────────────────────
            Rectangle {
                width: parent.width; height: descLbl.height + units.gu(4)
                color: libBookPage.clrHeroBg
                Behavior on color { ColorAnimation { duration: 250 } }
                Label {
                    id: descLbl
                    width: parent.width - units.gu(4)
                    anchors { horizontalCenter: parent.horizontalCenter
                              top: parent.top; topMargin: units.gu(2) }
                    text: libBookPage.descStatus
                    fontSize: "small"
                    color: libBookPage.descLoading ? "#888888"
                           : (root.isDarkMode ? "#CCCCCC" : "#444444")
                    wrapMode: Text.WordWrap; lineHeight: 1.6
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }

            // ── Public Domain banner ──────────────────────────────────────────
            Rectangle {
                visible: libBookPage.book ? libBookPage.book.source !== "local" : false
                width: parent.width; height: units.gu(4)
                color: root.isDarkMode ? "#0A1A0A" : "#4CAF50"
                Row {
                    anchors { left: parent.left; leftMargin: units.gu(2)
                              verticalCenter: parent.verticalCenter }
                    spacing: units.gu(0.8)
                    Icon { width: units.gu(2); height: units.gu(2)
                           name: "stock_ebook"
                           color: root.isDarkMode ? "#4CAF50" : "#FFFFFF"
                           anchors.verticalCenter: parent.verticalCenter }
                    Label { text: "Public Domain — free to read, share, and remix"
                            fontSize: "x-small"
                            color: root.isDarkMode ? "#4CAF50" : "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter }
                }
            }

            // ── Buttons + subjects — transparent, page texture shows through ──
            Item {
                width: parent.width
                height: actionCol.height

                Column {
                    id: actionCol
                    width: parent.width
                    spacing: units.gu(1.2)

                    Item { width: parent.width; height: units.gu(1.5) }

                    // Start Reading — solid green
                    Rectangle {
                        anchors { left: parent.left; right: parent.right
                                  leftMargin: units.gu(2); rightMargin: units.gu(2) }
                        height: units.gu(5.5); radius: units.dp(8)
                        color: libBookPage.clrGreenDark
                        Row {
                            anchors.centerIn: parent; spacing: units.gu(0.8)
                            Icon {
                                width: units.gu(2.2); height: units.gu(2.2)
                                name: "media-playback-start"
                                color: "#FFFFFF"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Label {
                                text: libBookPage.book
                                      ? (libBookPage.book.read_percent > 0
                                         ? "Continue Reading" : "Start Reading") : "Read"
                                fontSize: "medium"; font.weight: Font.Medium
                                color: "#FFFFFF"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root && root.openReader) root.openReader(libBookPage.book)
                            }
                        }
                    }

                    // Add to Reading List — solid bg with green border
                    Rectangle {
                        anchors { left: parent.left; right: parent.right
                                  leftMargin: units.gu(2); rightMargin: units.gu(2) }
                        height: units.gu(5.5); radius: units.dp(8)
                        color: libBookPage.clrPageBg
                        border.color: "#2C5F2E"; border.width: units.dp(1)
                        Row {
                            anchors.centerIn: parent; spacing: units.gu(0.8)
                            Icon {
                                width: units.gu(2); height: units.gu(2)
                                name: "add"; color: "#4CAF50"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Label {
                                text: "Add to Reading List"
                                fontSize: "small"; color: "#4CAF50"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.showRlDialog(libBookPage.book)
                        }
                    }

                    // Remove from Library — solid bg with brown border
                    Rectangle {
                        anchors { left: parent.left; right: parent.right
                                  leftMargin: units.gu(2); rightMargin: units.gu(2) }
                        height: units.gu(5.5); radius: units.dp(8)
                        color: libBookPage.clrPageBg
                        border.color: libBookPage.earthBrown; border.width: units.dp(1)
                        Row {
                            anchors.centerIn: parent; spacing: units.gu(0.8)
                            Icon {
                                width: units.gu(2); height: units.gu(2)
                                name: "close"; color: libBookPage.earthBrown
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Label {
                                text: "Remove from Library"
                                fontSize: "small"; color: libBookPage.earthBrown
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: removeDialog.visible = true
                        }
                    }

                    // ── Subject tag pills ─────────────────────────────────────
                    Item {
                        visible: libBookPage.book
                                 ? ((libBookPage.book.subjects || []).length > 0) : false
                        width: parent.width
                        height: visible ? subjectFlow.height + units.gu(1.2) : 0
                        Flow {
                            id: subjectFlow
                            width: parent.width - units.gu(4)
                            anchors { horizontalCenter: parent.horizontalCenter
                                      top: parent.top; topMargin: units.gu(0.6) }
                            spacing: units.gu(0.6)
                            Repeater {
                                model: libBookPage.book
                                       ? (libBookPage.book.subjects || []).slice(0, 8) : []
                                Rectangle {
                                    height: units.gu(2.8); width: subjLbl.width + units.gu(1.4)
                                    radius: height / 2
                                    color: root.isDarkMode ? "#222222" : "#EEEEEE"
                                    Label { id: subjLbl; anchors.centerIn: parent
                                            text: modelData.length > 30
                                                  ? modelData.substr(0, 30) + "…" : modelData
                                            fontSize: "x-small"
                                            color: root.isDarkMode ? "#AAAAAA" : "#666666" }
                                }
                            }
                        }
                    }

                    Item { width: parent.width; height: units.gu(4) }
                }
            }
        }
    }

    // Confirm remove
    Rectangle {
        id: removeDialog
        visible: false; z: 50
        anchors.fill: parent
        color: "#CC000000"
        MouseArea { anchors.fill: parent }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - units.gu(8)
            radius: units.dp(12)
            color: root.isDarkMode ? "#1E1E1E" : "#FFFFFF"
            height: rmCol.height + units.gu(4)
            Column {
                id: rmCol
                anchors { top: parent.top; topMargin: units.gu(2.5)
                          left: parent.left; right: parent.right
                          leftMargin: units.gu(2.5); rightMargin: units.gu(2.5) }
                spacing: units.gu(1.5)
                Label {
                    width: parent.width; text: "Remove from Library?"
                    fontSize: "large"; font.weight: Font.Medium
                    color: root.isDarkMode ? "#FFFFFF" : "#212121"
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: libBookPage.book
                          ? ("Remove " + libBookPage.book.title
                             + "? Your reading progress will be lost.") : ""
                    fontSize: "small"
                    color: root.isDarkMode ? "#CCCCCC" : "#555555"
                    horizontalAlignment: Text.AlignHCenter
                }
                // Confirm — solid earthen brown
                Rectangle {
                    width: parent.width; height: units.gu(5.5); radius: units.dp(8)
                    color: libBookPage.earthBrown
                    Label { anchors.centerIn: parent; text: "Remove"
                            fontSize: "medium"; font.weight: Font.Medium; color: "#FFFFFF" }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (libBookPage.book) Library.removeBook(libBookPage.book.id)
                            removeDialog.visible = false
                            pageStack.pop()
                        }
                    }
                }
                // Cancel — ghost earthen brown
                Rectangle {
                    width: parent.width; height: units.gu(5.5); radius: units.dp(8)
                    color: "transparent"
                    border.color: libBookPage.earthBrown; border.width: units.dp(1.5)
                    Label { anchors.centerIn: parent; text: "Keep in Library"
                            fontSize: "small"; color: libBookPage.earthBrown }
                    MouseArea { anchors.fill: parent
                                onClicked: removeDialog.visible = false }
                }
                Item { width: 1; height: units.gu(0.5) }
            }
        }
    }

    // ── Functions ─────────────────────────────────────────────────────────────

    function fetchDescription(book) {
        descLoading = true
        descStatus  = "Loading description…"

        // ── Path 1: Gutenberg books — Open Library ID lookup (accurate) ─────────
        var gutId = ""
        if ((book.source || "") === "gutenberg")
            gutId = book.source_id || ""

        if (gutId !== "") {
            var xhr = new XMLHttpRequest()
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                descLoading = false
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText)
                        var doc = (data.docs && data.docs.length > 0) ? data.docs[0] : null
                        if (doc) {
                            var raw = ""
                            if (doc.description) {
                                raw = (typeof doc.description === "string")
                                    ? doc.description : (doc.description.value || "")
                            }
                            if (raw.length < 20 && doc.first_sentence) {
                                raw = (typeof doc.first_sentence === "string")
                                    ? doc.first_sentence : (doc.first_sentence.value || "")
                            }
                            if (raw.length > 20) {
                                descStatus = _truncate(raw, 80); return
                            }
                        }
                    } catch(e) { console.log("OL parse error:", e) }
                }
                descStatus = (book.subjects && book.subjects.length > 0)
                    ? "Subjects: " + book.subjects.slice(0, 4).join(", ") + "."
                    : "No description available."
            }
            xhr.open("GET", "https://openlibrary.org/search.json?id_project_gutenberg="
                     + encodeURIComponent(gutId)
                     + "&fields=key,title,description,first_sentence")
            xhr.send()
            return
        }

        // ── Path 2: local / other — Wikipedia with author disambiguation ────────
        var rawTitle = (book.title || "").split(";")[0].split(":")[0].trim()
        var titleChars = []
        for (var ci = 0; ci < rawTitle.length; ci++) {
            var ch = rawTitle.charCodeAt(ci)
            var isAlNum = (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122)
                          || (ch >= 48 && ch <= 57) || ch === 32
            titleChars.push(isAlNum ? rawTitle[ci] : " ")
        }
        var cleanTitle = titleChars.join("").trim()
        var authorLast = (book.author_display || "").split(",")[0].trim()
        var wikiQuery = (authorLast.length > 0 ? cleanTitle + " " + authorLast : cleanTitle)
                        .replace(/ +/g, "_")
        var xhr2 = new XMLHttpRequest()
        xhr2.onreadystatechange = function() {
            if (xhr2.readyState !== XMLHttpRequest.DONE) return
            descLoading = false
            if (xhr2.status === 200) {
                try {
                    var data = JSON.parse(xhr2.responseText)
                    if (data.extract && data.extract.length > 20) {
                        descStatus = _truncate(data.extract, 80); return
                    }
                } catch(e) { console.log("Wiki parse error:", e) }
            }
            descStatus = (book.subjects && book.subjects.length > 0)
                         ? "Subjects: " + book.subjects.slice(0, 4).join(", ") + "."
                         : "No description available."
        }
        xhr2.open("GET", "https://en.wikipedia.org/api/rest_v1/page/summary/"
                  + encodeURIComponent(wikiQuery))
        xhr2.send()
    }

    function _formatSize(kb) {
        if (!kb || kb <= 0) return ""
        if (kb >= 1024) return (kb / 1024).toFixed(1) + " MB"
        return kb + " KB"
    }

    function _formatDate(dateStr) {
        if (!dateStr || dateStr === "") return ""
        // Extract 4-digit year if present
        if (dateStr.length >= 4) {
            var yr = parseInt(dateStr.substring(0, 4))
            if (yr > 1000 && yr < 2100) return String(yr)
        }
        return dateStr
    }

    function _truncate(text, maxWords) {
        // Strip HTML tags without using > inside regex char class (Qt 5.12 parser bug)
        var clean = text
        while (clean.indexOf("<") !== -1) {
            var open = clean.indexOf("<")
            var close = clean.indexOf(">", open)
            if (close === -1) break
            clean = clean.substring(0, open) + " " + clean.substring(close + 1)
        }
        clean = clean.replace(/\n+/g, " ").trim()
        var words = clean.split(/\s+/).filter(function(w) { return w.length > 0 })
        return words.length <= maxWords ? clean : words.slice(0, maxWords).join(" ") + "…"
    }
}