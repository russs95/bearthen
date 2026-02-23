import QtQuick 2.12
import Ubuntu.Components 1.3
import "../js/Library.js" as Library

Page {
    id: libBookPage

    property var    book:            null
    property string bookDescription: ""
    property string descStatus:      "Checking Open Library for book description…"
    property bool   descLoading:     false

    // Debug fields
    property string dbgCoverUrl:    ""
    property string dbgEpubUrl:     ""
    property string dbgFilePath:    ""
    property string dbgCoverSource: "none"

    // Earthen palette
    readonly property color earthBrown:      "#783508ff"
    readonly property color earthBrownLight: "#783508ff"
    readonly property color earthBrownDark:  "#783508ff"

    Component.onCompleted: {
        if (book) {
            // Always pull fresh from SQLite
            var fresh = Library.getBook(book.id)
            if (fresh) {
                book = fresh
                console.log("LibBookDetail — from DB:")
                console.log("  cover_url:  ", fresh.cover_url)
                console.log("  cover_local:", fresh.cover_local)
                console.log("  epub_url:   ", fresh.epub_url)
                console.log("  file_path:  ", fresh.file_path)
            }

            dbgCoverUrl    = book.cover_url    || book.cover || "(none)"
            dbgEpubUrl     = book.epub_url     || "(none)"
            dbgFilePath    = book.file_path    || "(none)"
            dbgCoverSource = (book.cover_local && book.cover_local !== "")
                             ? "local: " + book.cover_local
                             : ((book.cover_url && book.cover_url !== "") || (book.cover && book.cover !== ""))
                               ? "remote URL" : "none"

            fetchDescription(book)
        }
    }

    header: PageHeader {
        id: pageHeader
        title:    libBookPage.book ? libBookPage.book.title : ""
        subtitle: libBookPage.book
                  ? (libBookPage.book.author_display || libBookPage.book.author || "") : ""
        StyleHints {
            foregroundColor: "#4CAF50"
            backgroundColor: root.isDarkMode ? "#1A1A1A" : "#F5F5F5"
            dividerColor: "#2C5F2E"
        }
        leadingActionBar.actions: [
            Action { iconName: "back"; text: "Back"; onTriggered: pageStack.pop() }
        ]
    }

    Rectangle { anchors.fill: parent
        color: root.isDarkMode ? "#121212" : "#FFFFFF"
        Behavior on color { ColorAnimation { duration: 250 } } }

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
                color: root.isDarkMode ? "#0D1F0D" : "#E8F5E9"
                Behavior on color { ColorAnimation { duration: 250 } }

                Row {
                    id: heroRow
                    anchors { top: parent.top; topMargin: units.gu(2)
                              left: parent.left; leftMargin: units.gu(2)
                              right: parent.right; rightMargin: units.gu(2) }
                    spacing: units.gu(2)

                    Rectangle {
                        width: units.gu(14); height: units.gu(20)
                        color: root.isDarkMode ? "#1A2E1A" : "#C8E6C9"
                        radius: units.dp(6)
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        // Watermark
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(8); height: units.gu(8)
                            name: "stock_ebook"
                            color: root.isDarkMode ? "#2C5F2E" : "#4CAF50"
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
                            onStatusChanged: console.log("Cover status:", status, "src:", source)
                        }
                    }

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
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }
                        Label {
                            width: parent.width
                            text: libBookPage.book
                                  ? (libBookPage.book.author_display
                                     || libBookPage.book.author || "") : ""
                            fontSize: "small"
                            color: libBookPage.earthBrown
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

                        // Downloaded + progress badges
                        Row {
                            spacing: units.gu(0.6)
                            Rectangle {
                                height: units.gu(2.4)
                                width: dlRow.width + units.gu(1.6)
                                radius: height / 2
                                color: libBookPage.earthBrown
                                Row {
                                    id: dlRow
                                    anchors.centerIn: parent
                                    spacing: units.gu(0.3)
                                    Icon {
                                        width: units.gu(1.6); height: units.gu(1.6)
                                        name: "select"
                                        color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Label {
                                        text: "Downloaded"; fontSize: "x-small"; color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                            Rectangle {
                                visible: libBookPage.book ? libBookPage.book.read_percent > 0 : false
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

                        Row {
                            spacing: units.gu(0.6)
                            Rectangle {
                                height: units.gu(2.4); width: langLbl.width + units.gu(1.2)
                                radius: height / 2
                                color: root.isDarkMode ? "#252525" : "#DDDDDD"
                                Label { id: langLbl; anchors.centerIn: parent
                                        text: libBookPage.book
                                              ? (libBookPage.book.language
                                                 ? libBookPage.book.language.toUpperCase() : "EN") : "EN"
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
                width: parent.width; height: units.gu(4); color: "#0A1A0A"
                Row {
                    anchors { left: parent.left; leftMargin: units.gu(2)
                              verticalCenter: parent.verticalCenter }
                    spacing: units.gu(0.8)
                    Icon { width: units.gu(2); height: units.gu(2)
                           name: "security-high"; color: "#4CAF50"
                           anchors.verticalCenter: parent.verticalCenter }
                    Label { text: "Public Domain — free to read, share, and remix"
                            fontSize: "x-small"; color: "#4CAF50"
                            anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Rectangle { width: parent.width; height: units.dp(1)
                        color: root.isDarkMode ? "#2A2A2A" : "#E0E0E0" }

            // ── Reading progress ──────────────────────────────────────────────
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
                        width: parent.width * ((libBookPage.book ? libBookPage.book.read_percent : 0) / 100)
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

                // Read — standard solid green button
                Rectangle {
                    anchors { left: parent.left; right: parent.right
                              leftMargin: units.gu(2); rightMargin: units.gu(2) }
                    height: units.gu(5.5); radius: units.dp(8)
                    color: "#2C5F2E"

                    Row {
                        anchors.centerIn: parent; spacing: units.gu(0.8)
                        Icon {
                            width: units.gu(2.2); height: units.gu(2.2)
                            name: "media-playback-start"; color: "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Label {
                            text: libBookPage.book
                                  ? (libBookPage.book.read_percent > 0
                                     ? "Continue Reading" : "Start Reading") : "Read"
                            fontSize: "medium"; font.weight: Font.Medium; color: "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            console.log("READ — epub_url:", libBookPage.book ? libBookPage.book.epub_url : "")
                            console.log("READ — file_path:", libBookPage.book ? libBookPage.book.file_path : "")
                            // TODO: pageStack.push(readerPage)
                        }
                    }
                }

                // Remove from Library — ghost button in earthen brown
                Rectangle {
                    anchors { left: parent.left; right: parent.right
                              leftMargin: units.gu(2); rightMargin: units.gu(2) }
                    height: units.gu(5.5); radius: units.dp(8)
                    color: "transparent"
                    border.width: units.dp(1.5)
                    border.color: root.isDarkMode
                                  ? libBookPage.earthBrownLight
                                  : libBookPage.earthBrown

                    Label {
                        anchors.centerIn: parent
                        text: "Remove from Library"
                        fontSize: "small"
                        color: root.isDarkMode
                               ? libBookPage.earthBrownLight
                               : libBookPage.earthBrown
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
                            fontSize: "x-small"; color: "#555555"
                            horizontalAlignment: Text.AlignHCenter }
                    Label { width: parent.width
                            text: "cover source: " + libBookPage.dbgCoverSource
                            fontSize: "x-small"
                            color: libBookPage.dbgCoverSource.indexOf("local") === 0
                                   ? "#4CAF50" : "#888888"
                            wrapMode: Text.WrapAnywhere }
                    Label { width: parent.width
                            text: "cover_url: " + libBookPage.dbgCoverUrl
                            fontSize: "x-small"; color: "#666666"; wrapMode: Text.WrapAnywhere }
                    Label { width: parent.width
                            text: "epub_url: " + libBookPage.dbgEpubUrl
                            fontSize: "x-small"
                            color: libBookPage.dbgEpubUrl !== "(none)" ? "#4CAF50" : "#AA4444"
                            wrapMode: Text.WrapAnywhere }
                    Label { width: parent.width
                            text: "file_path: " + libBookPage.dbgFilePath
                            fontSize: "x-small"; color: "#666666"; wrapMode: Text.WrapAnywhere }
                    Label { width: parent.width
                            text: "img: " + ["Null","Ready","Loading","Error"][coverImg.status]
                                  + " (status " + coverImg.status + ")"
                            fontSize: "x-small"
                            color: coverImg.status === Image.Ready ? "#4CAF50" : "#AA4444" }
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

    // ── Confirm remove dialog ─────────────────────────────────────────────────
    Rectangle {
        id: removeDialog
        visible: false
        anchors.fill: parent
        color: "#AA000000"
        z: 20

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - units.gu(8)
            height: dialogCol.height + units.gu(4)
            radius: units.dp(12)
            color: root.isDarkMode ? "#1E1E1E" : "#FFFFFF"

            Column {
                id: dialogCol
                anchors { top: parent.top; topMargin: units.gu(2.5)
                          left: parent.left; right: parent.right
                          leftMargin: units.gu(2); rightMargin: units.gu(2) }
                spacing: units.gu(1.5)

                Label {
                    width: parent.width
                    text: "Remove from Library?"
                    fontSize: "large"; font.weight: Font.Medium
                    color: root.isDarkMode ? "#FFFFFF" : "#212121"
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    width: parent.width
                    text: libBookPage.book ? ("\"" + libBookPage.book.title + "\"") : ""
                    fontSize: "small"; color: "#888888"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                Label {
                    width: parent.width
                    text: "Your reading progress will be lost."
                    fontSize: "x-small"; color: "#666666"
                    horizontalAlignment: Text.AlignHCenter
                }

                // Confirm — filled earthen brown
                Rectangle {
                    width: parent.width; height: units.gu(5.5)
                    radius: units.dp(8); color: libBookPage.earthBrown
                    Label {
                        anchors.centerIn: parent
                        text: "Remove"
                        fontSize: "medium"; font.weight: Font.Medium; color: "#FFFFFF"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (libBookPage.book) {
                                Library.removeBook(libBookPage.book.id)
                                console.log("Removed:", libBookPage.book.id)
                            }
                            removeDialog.visible = false
                            pageStack.pop()
                        }
                    }
                }

                // Cancel — ghost earthen brown
                Rectangle {
                    width: parent.width; height: units.gu(5.5)
                    radius: units.dp(8); color: "transparent"
                    border.color: libBookPage.earthBrown; border.width: units.dp(1.5)
                    Label {
                        anchors.centerIn: parent
                        text: "Keep in Library"
                        fontSize: "small"
                        color: root.isDarkMode
                               ? libBookPage.earthBrownLight : libBookPage.earthBrown
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: removeDialog.visible = false
                    }
                }

                Item { width: parent.width; height: units.gu(0.5) }
            }
        }
    }

    // ── Functions ─────────────────────────────────────────────────────────────

    function fetchDescription(book) {
        descLoading = true
        descStatus  = "Loading description…"
        // Wikipedia summary API — fast single request, reliable extract field
        var title = (book.title || "").split(";")[0].split(":")[0].trim()
                                       .replace(/[^a-zA-Z0-9 ]/g, " ").trim()
                                       .replace(/ +/g, "_")
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            descLoading = false
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    if (data.extract && data.extract.length > 20) {
                        descStatus = _truncate(data.extract, 80)
                        return
                    }
                } catch(e) { console.log("Wiki parse error:", e) }
            }
            // Fallback: subjects
            descStatus = (book.subjects && book.subjects.length > 0)
                         ? "Subjects: " + book.subjects.slice(0, 4).join(", ") + "."
                         : "No description available."
        }
        xhr.open("GET", "https://en.wikipedia.org/api/rest_v1/page/summary/" +
                 encodeURIComponent(title))
        xhr.send()
    }

    function _truncate(text, maxWords) {
        var clean = text.replace(/<[^>]+>/g, " ").replace(/\n+/g, " ").trim()
        var words = clean.split(/\s+/).filter(function(w) { return w.length > 0 })
        return words.length <= maxWords ? clean : words.slice(0, maxWords).join(" ") + "…"
    }
}