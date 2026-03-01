import QtQuick 2.12
import Ubuntu.Components 1.3
import "../js/Library.js" as Library

Page {
    id: libBookPage

    property var    book:            null
    property string bookDescription: ""
    property string descStatus:      "Loading description…"
    property bool   descLoading:     false

    // Debug fields
    property string dbgCoverUrl:    ""
    property string dbgEpubUrl:     ""
    property string dbgFilePath:    ""
    property string dbgCoverSource: "none"

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
    // Debug panel labels
    readonly property color clrTextDebug:   libBookPage.clrTextDebug

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
        dbgCoverUrl    = b.cover_url    || b.cover || "(none)"
        dbgEpubUrl     = b.epub_url     || "(none)"
        dbgFilePath    = b.file_path    || "(none)"
        dbgCoverSource = (b.cover_local && b.cover_local !== "")
                         ? "local: " + b.cover_local
                         : ((b.cover_url && b.cover_url !== "")
                            || (b.cover && b.cover !== ""))
                           ? "remote URL" : "none"
        bookDescription = ""
        descStatus = "Loading description…"
        fetchDescription(b)
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

    Rectangle {
        anchors.fill: parent
        color: libBookPage.clrPageBg
        Behavior on color { ColorAnimation { duration: 250 } }
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
                            onStatusChanged: console.log("Cover:", status, source)
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
                        // Author in earthen brown
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
                            // Downloaded — earthen brown with native check icon
                            Rectangle {
                                height: units.gu(2.4)
                                width: dlBadgeRow.width + units.gu(1.6)
                                radius: height / 2
                                color: libBookPage.earthBrown
                                Row {
                                    id: dlBadgeRow
                                    anchors.centerIn: parent
                                    spacing: units.gu(0.3)
                                    Icon {
                                        width: units.gu(1.5); height: units.gu(1.5)
                                        name: "tick"
                                        color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Label {
                                        text: "Downloaded"
                                        fontSize: "x-small"; color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                            // Progress badge
                            Rectangle {
                                visible: libBookPage.book
                                         ? libBookPage.book.read_percent > 0 : false
                                height: units.gu(2.4); width: pctLbl.width + units.gu(1.2)
                                radius: height / 2
                                color: root.isDarkMode ? "#252525" : "#DDDDDD"
                                Label { id: pctLbl; anchors.centerIn: parent
                                        text: libBookPage.book
                                              ? (libBookPage.book.is_finished ? "Finished ✓"
                                                 : libBookPage.book.read_percent + "% read") : ""
                                        fontSize: "x-small"
                                        color: root.isDarkMode ? "#AAAAAA" : "#666666" }
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

            // ── Public Domain banner ──────────────────────────────────────────
            Rectangle {
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

            Rectangle { width: parent.width; height: units.dp(1)
                        color: root.isDarkMode ? "#2A2A2A" : "#E0E0E0" }

            // ── Reading progress bar ──────────────────────────────────────────
            Item {
                visible: libBookPage.book ? libBookPage.book.read_percent > 0 : false
                width: parent.width; height: units.gu(5)
                Label {
                    anchors { left: parent.left; leftMargin: units.gu(2)
                              top: parent.top; topMargin: units.gu(1) }
                    text: libBookPage.book
                          ? (libBookPage.book.is_finished ? "Finished ✓"
                             : "Reading — " + libBookPage.book.read_percent + "% complete") : ""
                    fontSize: "x-small"; color: "#888888"
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                              leftMargin: units.gu(2); rightMargin: units.gu(2)
                              bottomMargin: units.gu(0.8) }
                    height: units.dp(3); radius: height / 2
                    color: root.isDarkMode ? "#2A2A2A" : "#E0E0E0"
                    Rectangle {
                        width: parent.width * ((libBookPage.book
                               ? libBookPage.book.read_percent : 0) / 100)
                        height: parent.height; radius: parent.radius; color: "#4CAF50"
                        Behavior on width { NumberAnimation { duration: 400 } }
                    }
                }
            }

            // ── Description ───────────────────────────────────────────────────
            Item {
                width: parent.width; height: descLbl.height + units.gu(3)
                Label {
                    id: descLbl
                    width: parent.width - units.gu(4)
                    anchors { horizontalCenter: parent.horizontalCenter
                              top: parent.top; topMargin: units.gu(1.5) }
                    text: libBookPage.descStatus
                    fontSize: "small"
                    color: libBookPage.descLoading ? "#888888"
                           : (root.isDarkMode ? "#CCCCCC" : "#444444")
                    wrapMode: Text.WordWrap; lineHeight: 1.6
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }

            Rectangle { width: parent.width; height: units.dp(1)
                        color: root.isDarkMode ? "#2A2A2A" : "#E0E0E0" }

            // ── Buttons ───────────────────────────────────────────────────────
            Column {
                width: parent.width; spacing: units.gu(1.2)
                Item { width: parent.width; height: units.gu(1) }

                // Start Reading — solid green
                Rectangle {
                    anchors { left: parent.left; right: parent.right
                              leftMargin: units.gu(2); rightMargin: units.gu(2) }
                    height: units.gu(5.5); radius: units.dp(8)
                    color: libBookPage.clrGreenDark   // always green — text goes dark in dark mode
                    Row {
                        anchors.centerIn: parent; spacing: units.gu(0.8)
                        Icon {
                            width: units.gu(2.2); height: units.gu(2.2)
                            name: "media-playback-start"
                            color: root.isDarkMode ? "#0A0A0A" : "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Label {
                            text: libBookPage.book
                                  ? (libBookPage.book.read_percent > 0
                                     ? "Continue Reading" : "Start Reading") : "Read"
                            fontSize: "medium"; font.weight: Font.Medium
                            color: root.isDarkMode ? "#0A0A0A" : "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            console.log("StartReading tapped, book:", libBookPage.book ? libBookPage.book.id : "null")
                            if (root && root.openReader) {
                                root.openReader(libBookPage.book)
                            } else {
                                console.log("ERROR: root.openReader not found, root=", root)
                            }
                        }
                    }
                }

                // + Add to Reading List — ghost green
                Rectangle {
                    anchors { left: parent.left; right: parent.right
                              leftMargin: units.gu(2); rightMargin: units.gu(2) }
                    height: units.gu(5.5); radius: units.dp(8)
                    color: "transparent"
                    border.color: "#2C5F2E"
                    border.width: units.dp(1)
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
                        onClicked: readingListDialog.visible = true
                    }
                }

                // ✕ Remove from Library — ghost earthen brown
                Rectangle {
                    anchors { left: parent.left; right: parent.right
                              leftMargin: units.gu(2); rightMargin: units.gu(2) }
                    height: units.gu(5.5); radius: units.dp(8)
                    color: "transparent"
                    border.color: libBookPage.earthBrown
                    border.width: units.dp(1)
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

                Item { width: parent.width; height: units.gu(0.5) }
            }

            // ── Debug panel ───────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: dbgCol.height + units.gu(2)
                color: root.isDarkMode ? "#0A0A0A" : "#F0F0F0"
                Column {
                    id: dbgCol
                    width: parent.width - units.gu(4)
                    anchors { horizontalCenter: parent.horizontalCenter
                              top: parent.top; topMargin: units.gu(1) }
                    spacing: units.gu(0.4)
                    Label { width: parent.width; text: "— debug info —"
                            fontSize: "x-small"; color: libBookPage.clrTextDebug
                            horizontalAlignment: Text.AlignHCenter }
                    Label { width: parent.width
                            text: "cover source: " + libBookPage.dbgCoverSource
                            fontSize: "x-small"; color: libBookPage.clrTextDebug
                            wrapMode: Text.WrapAnywhere }
                    Label { width: parent.width
                            text: "cover_url: " + libBookPage.dbgCoverUrl
                            fontSize: "x-small"; color: libBookPage.clrTextDebug; wrapMode: Text.WrapAnywhere }
                    Label { width: parent.width
                            text: "epub_url: " + libBookPage.dbgEpubUrl
                            fontSize: "x-small"; color: libBookPage.clrTextDebug
                            wrapMode: Text.WrapAnywhere }
                    Label { width: parent.width
                            text: "file_path: " + libBookPage.dbgFilePath
                            fontSize: "x-small"; color: libBookPage.clrTextDebug
                            wrapMode: Text.WrapAnywhere }
                    Label { width: parent.width
                            text: "img: " + ["Null","Ready","Loading","Error"][coverImg.status]
                                  + " (status " + coverImg.status + ")"
                            fontSize: "x-small"; color: libBookPage.clrTextDebug }
                }
            }

            Rectangle { width: parent.width; height: units.dp(1)
                        color: root.isDarkMode ? "#2A2A2A" : "#E0E0E0" }

            // ── Subjects ──────────────────────────────────────────────────────
            Item {
                visible: libBookPage.book
                         ? ((libBookPage.book.subjects || []).length > 0) : false
                width: parent.width; height: subjectFlow.height + units.gu(2.4)
                Flow {
                    id: subjectFlow
                    width: parent.width - units.gu(4)
                    anchors { horizontalCenter: parent.horizontalCenter
                              top: parent.top; topMargin: units.gu(1.2) }
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
            Item { width: parent.width; height: units.gu(2) }
        }
    }

    // ── Shared modal overlay component ───────────────────────────────────────
    // Simple Rectangle overlay — no Dialog type needed, works on all Qt 5.12 builds

    // "Add to Reading List" — coming soon
    Rectangle {
        id: readingListDialog
        visible: false; z: 50
        anchors.fill: parent
        color: "#CC000000"
        MouseArea { anchors.fill: parent }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - units.gu(8)
            radius: units.dp(12)
            color: root.isDarkMode ? "#1E1E1E" : "#FFFFFF"
            height: rlCol.height + units.gu(4)
            Column {
                id: rlCol
                anchors { top: parent.top; topMargin: units.gu(2.5)
                          left: parent.left; right: parent.right
                          leftMargin: units.gu(2.5); rightMargin: units.gu(2.5) }
                spacing: units.gu(1.5)
                Label {
                    width: parent.width; text: "Reading lists coming soon"
                    fontSize: "large"; font.weight: Font.Medium
                    color: root.isDarkMode ? "#FFFFFF" : "#212121"
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.5
                    text: "Reading lists let you organise books into curated collections "
                        + "like Want to Read, Ecology, or Gifts for Friends. "
                        + "Coming soon!"
                    fontSize: "small"
                    color: root.isDarkMode ? "#CCCCCC" : "#555555"
                    horizontalAlignment: Text.AlignHCenter
                }
                Rectangle {
                    width: parent.width; height: units.gu(5.5); radius: units.dp(8)
                    color: "#2C5F2E"
                    Label { anchors.centerIn: parent; text: "Got it"
                            fontSize: "medium"; font.weight: Font.Medium; color: "#FFFFFF" }
                    MouseArea { anchors.fill: parent
                                onClicked: readingListDialog.visible = false }
                }
                Item { width: 1; height: units.gu(0.5) }
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
        // Clean title safely without regex char classes that confuse Qt 5.12 parser
        var rawTitle = (book.title || "").split(";")[0].split(":")[0].trim()
        var titleChars = []
        for (var ci = 0; ci < rawTitle.length; ci++) {
            var ch = rawTitle.charCodeAt(ci)
            var isAlNum = (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122)
                          || (ch >= 48 && ch <= 57) || ch === 32
            titleChars.push(isAlNum ? rawTitle[ci] : " ")
        }
        var title = titleChars.join("").trim().replace(/ +/g, "_")
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            descLoading = false
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    if (data.extract && data.extract.length > 20) {
                        descStatus = _truncate(data.extract, 80); return
                    }
                } catch(e) { console.log("Wiki parse error:", e) }
            }
            descStatus = (book.subjects && book.subjects.length > 0)
                         ? "Subjects: " + book.subjects.slice(0, 4).join(", ") + "."
                         : "No description available."
        }
        xhr.open("GET", "https://en.wikipedia.org/api/rest_v1/page/summary/" +
                 encodeURIComponent(title))
        xhr.send()
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