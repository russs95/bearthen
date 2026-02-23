import QtQuick 2.12
import Ubuntu.Components 1.3
import "../js/Library.js" as Library

Page {
    id: bookDetailPage

    property var    book:             null
    property bool   isDownloading:    false
    property int    downloadProgress: 0
    property string downloadStatus:   ""
    property string bookDescription:  ""
    property bool   descLoading:      false
    property bool   alreadyInLib:     false

    Component.onCompleted: {
        Library.init()
        if (book) {
            alreadyInLib = Library.hasBook(book.id)
            fetchDescription(book)
        }
    }

    header: PageHeader {
        id: pageHeader
        title:    bookDetailPage.book ? bookDetailPage.book.title : ""
        subtitle: bookDetailPage.book ? bookDetailPage.book.author : ""
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

                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(8); height: units.gu(8)
                            name: "stock_ebook"
                            color: root.isDarkMode ? "#2C5F2E" : "#4CAF50"
                            opacity: 0.25
                        }
                        Image {
                            anchors.fill: parent; anchors.margins: units.dp(2)
                            source: bookDetailPage.book ? (bookDetailPage.book.cover || "") : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }

                    Column {
                        width: parent.width - units.gu(16)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.gu(0.8)

                        Label {
                            width: parent.width
                            text: bookDetailPage.book ? (bookDetailPage.book.title || "") : ""
                            fontSize: "large"; font.weight: Font.Medium
                            color: root.isDarkMode ? "#FFFFFF" : "#212121"
                            wrapMode: Text.WordWrap
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }
                        Label {
                            width: parent.width
                            text: bookDetailPage.book ? (bookDetailPage.book.author || "") : ""
                            fontSize: "small"; color: "#4CAF50"; wrapMode: Text.WordWrap
                        }
                        Label {
                            visible: bookDetailPage.book
                                     ? (bookDetailPage.book.birth_year || 0) > 0 : false
                            text: bookDetailPage.book
                                  ? (bookDetailPage.book.birth_year + " – " +
                                     (bookDetailPage.book.death_year
                                      ? bookDetailPage.book.death_year : "present")) : ""
                            fontSize: "x-small"
                            color: root.isDarkMode ? "#888888" : "#999999"
                        }
                        Row {
                            spacing: units.gu(0.5)
                            Icon {
                                width: units.gu(1.8); height: units.gu(1.8)
                                name: "save"; color: "#888888"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Label {
                                text: bookDetailPage.book
                                      ? ((bookDetailPage.book.downloads || 0)
                                         .toLocaleString() + " downloads") : ""
                                fontSize: "x-small"
                                color: root.isDarkMode ? "#888888" : "#999999"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Row {
                            spacing: units.gu(0.6)
                            Rectangle {
                                visible: bookDetailPage.book
                                         ? bookDetailPage.book.hasEpub : false
                                height: units.gu(2.4); width: epubLbl.width + units.gu(1.2)
                                radius: height / 2; color: "#1E3A1E"
                                Label { id: epubLbl; anchors.centerIn: parent
                                        text: "EPUB"; fontSize: "x-small"; color: "#4CAF50" }
                            }
                            Rectangle {
                                height: units.gu(2.4); width: freeLbl.width + units.gu(1.2)
                                radius: height / 2; color: "#1E3A1E"
                                Label { id: freeLbl; anchors.centerIn: parent
                                        text: "Free"; fontSize: "x-small"; color: "#4CAF50" }
                            }
                            Rectangle {
                                height: units.gu(2.4); width: langLbl.width + units.gu(1.2)
                                radius: height / 2
                                color: root.isDarkMode ? "#252525" : "#DDDDDD"
                                Label { id: langLbl; anchors.centerIn: parent
                                        text: bookDetailPage.book
                                              ? (bookDetailPage.book.languages
                                                 ? bookDetailPage.book.languages.join(", ").toUpperCase()
                                                 : "EN") : "EN"
                                        fontSize: "x-small"
                                        color: root.isDarkMode ? "#AAAAAA" : "#666666" }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width; height: units.gu(4)
                color: bookDetailPage.book
                       ? (bookDetailPage.book.copyright === false ? "#0A1A0A" : "#1A0A0A")
                       : "#0A1A0A"
                Row {
                    anchors { left: parent.left; leftMargin: units.gu(2)
                              verticalCenter: parent.verticalCenter }
                    spacing: units.gu(0.8)
                    Icon { width: units.gu(2); height: units.gu(2)
                           name: "security-high"; color: "#4CAF50"
                           anchors.verticalCenter: parent.verticalCenter }
                    Label {
                        text: bookDetailPage.book
                              ? (bookDetailPage.book.copyright === false
                                 ? "Public Domain — free to read, share, and remix"
                                 : "Under copyright — check usage rights") : ""
                        fontSize: "x-small"; color: "#4CAF50"
                        anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Rectangle { width: parent.width; height: units.dp(1)
                        color: root.isDarkMode ? "#2A2A2A" : "#E0E0E0" }

            Item {
                width: parent.width; height: descLbl.height + units.gu(3)
                Label {
                    id: descLbl
                    width: parent.width - units.gu(4)
                    anchors { horizontalCenter: parent.horizontalCenter
                              top: parent.top; topMargin: units.gu(1.5) }
                    text: bookDetailPage.descLoading
                          ? "Checking Open Library for description…"
                          : (bookDetailPage.bookDescription !== ""
                             ? bookDetailPage.bookDescription
                             : "No description available for this title.")
                    fontSize: "small"
                    color: bookDetailPage.descLoading ? "#888888"
                           : (root.isDarkMode ? "#CCCCCC" : "#444444")
                    wrapMode: Text.WordWrap; lineHeight: 1.6
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }

            // ── Button section ────────────────────────────────────────────────
            Column {
                width: parent.width; spacing: units.gu(0.8)
                Item { width: parent.width; height: units.gu(0.5) }

                // Add to Library button
                Rectangle {
                    anchors { left: parent.left; right: parent.right
                              leftMargin: units.gu(2); rightMargin: units.gu(2) }
                    height: units.gu(5.5); radius: units.dp(8)
                    visible: !bookDetailPage.alreadyInLib && !bookDetailPage.isDownloading
                    color: bookDetailPage.book
                           ? (bookDetailPage.book.hasEpub ? "#2C5F2E" : "#2A2A2A")
                           : "#2A2A2A"
                    Label {
                        anchors.centerIn: parent
                        text: bookDetailPage.book
                              ? (bookDetailPage.book.hasEpub ? "Add to Library" : "No EPUB Available")
                              : "Add to Library"
                        fontSize: "medium"; font.weight: Font.Medium
                        color: bookDetailPage.book
                               ? (bookDetailPage.book.hasEpub ? "#FFFFFF" : "#666666") : "#FFFFFF"
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: bookDetailPage.book !== null &&
                                 (bookDetailPage.book ? bookDetailPage.book.hasEpub : false)
                        onClicked: downloadBook(bookDetailPage.book)
                    }
                }

                Rectangle {
                    anchors { left: parent.left; right: parent.right
                              leftMargin: units.gu(2); rightMargin: units.gu(2) }
                    height: units.gu(5.5); radius: units.dp(8); color: "#1E3A1E"
                    visible: bookDetailPage.isDownloading
                    Label { anchors.centerIn: parent; text: "Downloading…"
                            fontSize: "medium"; font.weight: Font.Medium; color: "#4CAF50" }
                }

                Rectangle {
                    anchors { left: parent.left; right: parent.right
                              leftMargin: units.gu(2); rightMargin: units.gu(2) }
                    height: units.gu(5.5); radius: units.dp(8); color: "#0D1F0D"
                    border.color: "#2C5F2E"; border.width: units.dp(1)
                    visible: bookDetailPage.alreadyInLib && !bookDetailPage.isDownloading
                    Label { anchors.centerIn: parent; text: "✓ Already in your Library"
                            fontSize: "small"; color: "#4CAF50" }
                }

                Rectangle {
                    anchors { left: parent.left; right: parent.right
                              leftMargin: units.gu(2); rightMargin: units.gu(2) }
                    height: units.gu(0.5); radius: height / 2
                    color: root.isDarkMode ? "#2A2A2A" : "#E0E0E0"
                    visible: bookDetailPage.isDownloading
                    Rectangle {
                        width: parent.width * (bookDetailPage.downloadProgress / 100)
                        height: parent.height; radius: parent.radius; color: "#4CAF50"
                        Behavior on width { NumberAnimation { duration: 200 } }
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: bookDetailPage.downloadStatus; fontSize: "x-small"; color: "#4CAF50"
                    visible: bookDetailPage.downloadStatus !== ""
                }
                Item { width: parent.width; height: units.gu(1) }
            }

            Rectangle { width: parent.width; height: units.dp(1)
                        color: root.isDarkMode ? "#2A2A2A" : "#E0E0E0" }

            // Subjects
            Item {
                visible: bookDetailPage.book
                         ? ((bookDetailPage.book.subjects || []).length > 0) : false
                width: parent.width; height: subjectFlow.height + units.gu(2.4)
                Flow {
                    id: subjectFlow
                    width: parent.width - units.gu(4)
                    anchors { horizontalCenter: parent.horizontalCenter
                              top: parent.top; topMargin: units.gu(1.2) }
                    spacing: units.gu(0.6)
                    Repeater {
                        model: bookDetailPage.book
                               ? (bookDetailPage.book.subjects || []).slice(0, 8) : []
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
        }
    }

    // ── Functions ─────────────────────────────────────────────────────────────

    function fetchDescription(book) {
        descLoading = true; bookDescription = ""
        // Wikipedia summary API — fast, reliable, returns clean extract
        var title = (book.title || "").replace(/[^\w\s]/g, " ").trim().replace(/\s+/g, "_")
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            descLoading = false
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    if (data.extract && data.extract.length > 20) {
                        bookDescription = _truncate(data.extract, 80)
                        return
                    }
                } catch(e) { console.log("Wiki parse error:", e) }
            }
            // Fallback: subjects list
            if (book.subjects && book.subjects.length > 0)
                bookDescription = "Subjects: " + book.subjects.slice(0, 4).join(", ") + "."
            else
                bookDescription = ""
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

    function downloadBook(book) {
        if (!book || !book.epub_url) return
        isDownloading = true; downloadProgress = 5; downloadStatus = "Adding to library…"

        // Step 1: Insert record into SQLite with remote URLs
        var ok = Library.addBook({
            id:             book.id,
            title:          book.title,
            author_id:      book.author_id,
            author_display: book.author,
            cover_url:      book.cover || "",
            cover_local:    "",
            epub_url:       book.epub_url,
            file_path:      "",
            source:         "gutenberg",
            source_id:      book.source_id,
            category:       _guessCategory(book.subjects),
            subjects:       book.subjects || [],
            language:       (book.languages && book.languages.length > 0) ? book.languages[0] : "en",
            downloads:      book.downloads || 0,
            copyright:      book.copyright,
            birth_year:     book.birth_year || 0,
            death_year:     book.death_year || 0
        })
        console.log("Library.addBook:", ok ? "inserted" : "already exists")

        // Step 2: Download cover image to device storage
        downloadProgress = 15; downloadStatus = "Downloading cover…"
        _downloadCover(book, function(coverPath) {
            if (coverPath) {
                Library.updateCoverLocal(book.id, coverPath)
                console.log("Cover saved:", coverPath)
            } else {
                console.log("Cover download skipped or failed — using remote URL")
            }

            // Step 3: Download EPUB to device storage
            downloadProgress = 35; downloadStatus = "Downloading EPUB…"
            _downloadEpub(book, function(epubPath) {
                if (epubPath) {
                    Library.updateFilePath(book.id, epubPath)
                    console.log("EPUB saved:", epubPath)
                    downloadProgress = 100
                    downloadStatus   = "Saved to device ✓"
                } else {
                    console.log("EPUB file write failed — streaming will be used")
                    downloadProgress = 100
                    downloadStatus   = "Added to Library ✓"
                }
                isDownloading = false
                alreadyInLib  = true
            })
        })
    }

    function _downloadCover(book, cb) {
        if (!book.cover || book.cover === "") { cb(null); return }
        var path = Library.COVERS_DIR + "/" + book.id + ".jpg"
        var xhr = new XMLHttpRequest()
        xhr.responseType = "arraybuffer"
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            console.log("Cover fetch status:", xhr.status, "bytes:",
                        xhr.response ? xhr.response.byteLength : 0)
            if (xhr.status === 200 && xhr.response && xhr.response.byteLength > 0) {
                var w = new XMLHttpRequest()
                w.open("PUT", "file://" + path, false)
                w.send(xhr.response)
                console.log("Cover PUT status:", w.status, "path:", path)
                // Status 0 is success on file:// scheme in Qt
                cb((w.status === 0 || w.status === 200 || w.status === 201) ? path : null)
            } else {
                cb(null)
            }
        }
        xhr.open("GET", book.cover)
        xhr.send()
    }

    function _downloadEpub(book, cb) {
        var path = Library.BOOKS_DIR + "/" + book.id + ".epub"
        var xhr = new XMLHttpRequest()
        xhr.responseType = "arraybuffer"
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                // Update progress during download
                if (xhr.readyState === 3 && xhr.response)
                    downloadProgress = 35 + Math.min(60,
                        Math.floor((xhr.response.byteLength / 500000) * 60))
                return
            }
            console.log("EPUB fetch status:", xhr.status, "bytes:",
                        xhr.response ? xhr.response.byteLength : 0)
            if (xhr.status === 200 && xhr.response && xhr.response.byteLength > 0) {
                downloadStatus = "Saving EPUB to device…"
                var w = new XMLHttpRequest()
                w.open("PUT", "file://" + path, false)
                w.send(xhr.response)
                console.log("EPUB PUT status:", w.status, "path:", path)
                cb((w.status === 0 || w.status === 200 || w.status === 201) ? path : null)
            } else {
                cb(null)
            }
        }
        xhr.open("GET", book.epub_url)
        xhr.send()
    }

    function _guessCategory(subjects) {
        if (!subjects || subjects.length === 0) return "other"
        var s = subjects.join(" ").toLowerCase()
        if (s.indexOf("fiction") !== -1 || s.indexOf("novel") !== -1) return "fiction"
        if (s.indexOf("poetry") !== -1) return "poetry"
        if (s.indexOf("histor") !== -1) return "history"
        if (s.indexOf("science") !== -1) return "science"
        if (s.indexOf("philosoph") !== -1) return "philosophy"
        if (s.indexOf("biograph") !== -1) return "biography"
        if (s.indexOf("children") !== -1 || s.indexOf("juvenile") !== -1) return "children"
        if (s.indexOf("earth") !== -1 || s.indexOf("ecology") !== -1) return "earthen"
        return "non-fiction"
    }
}