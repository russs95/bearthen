import QtQuick 2.12
import Ubuntu.Components 1.3
import "../js/Library.js" as Library

Page {
    id: discoverPage

    header: PageHeader {
        id: pageHeader
        title: "Bearthen"
        subtitle: root.t("Discover Books")
        StyleHints {
            foregroundColor: "#4CAF50"
            backgroundColor: root.isDarkMode ? "#1A1A1A" : "#F5F5F5"
            dividerColor: "#2C5F2E"
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.isDarkMode ? "#121212" : "#FFFFFF"
        Behavior on color { ColorAnimation { duration: 250 } }
    }

    property var books:     []
    property bool isLoading: false
    property string errorMsg: ""

    // ── Search bar ────────────────────────────────────────────────────────────
    Rectangle {
        id: searchBar
        anchors { top: pageHeader.bottom; left: parent.left; right: parent.right }
        height: units.gu(7)
        color: root.isDarkMode ? "#1A1A1A" : "#F5F5F5"
        Behavior on color { ColorAnimation { duration: 250 } }

        TextField {
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: units.gu(2); rightMargin: units.gu(2)
            }
            placeholderText: "Search 70,000 free books…"
            onAccepted: fetchBooks(
                "https://gutendex.com/books/?search=" +
                encodeURIComponent(text) + "&languages=en")
        }
    }

    // ── Book list ─────────────────────────────────────────────────────────────
    ListView {
        anchors {
            top: searchBar.bottom; left: parent.left
            right: parent.right; bottom: parent.bottom
        }
        clip: true
        model: discoverPage.books

        delegate: ListItem {
            height: units.gu(12)
            color: root.isDarkMode ? "#121212" : "#FFFFFF"
            divider.colorFrom: root.isDarkMode ? "#2A2A2A" : "#E0E0E0"
            divider.colorTo:   root.isDarkMode ? "#121212" : "#FFFFFF"
            Behavior on color { ColorAnimation { duration: 250 } }

            onClicked: {
                bookDetailPage.book = modelData
                bookDetailPage.isDownloading    = false
                bookDetailPage.downloadProgress = 0
                bookDetailPage.downloadStatus   = ""
                bookDetailPage.bookDescription  = ""
                bookDetailPage.alreadyInLib     = Library.hasBook(modelData.id)
                pageStack.push(bookDetailPage)
            }

            Item {
                anchors {
                    fill: parent
                    leftMargin: units.gu(1.5); rightMargin: units.gu(1.5)
                    topMargin: units.gu(1);    bottomMargin: units.gu(1)
                }

                Rectangle {
                    id: coverRect
                    width: units.gu(7); height: units.gu(10)
                    color: root.isDarkMode ? "#1E3A1E" : "#E8F5E9"
                    radius: units.dp(3)
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent; anchors.margins: units.dp(2)
                        source: modelData.cover || ""
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(3.5); height: units.gu(3.5)
                        name: "stock_ebook"; color: "#2C5F2E"
                    }
                }

                Column {
                    anchors {
                        left: coverRect.right; leftMargin: units.gu(1.5)
                        right: parent.right; verticalCenter: parent.verticalCenter
                    }
                    spacing: units.gu(0.4)

                    Label {
                        width: parent.width; text: modelData.title || ""
                        fontSize: "small"; font.weight: Font.Medium
                        color: root.isDarkMode ? "#FFFFFF" : "#212121"
                        wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                    Label {
                        width: parent.width; text: modelData.author || ""
                        fontSize: "x-small"; color: "#4CAF50"; elide: Text.ElideRight
                    }
                    Row {
                        spacing: units.gu(1)
                        Label {
                            text: "↓ " + (modelData.downloads || 0).toLocaleString()
                            fontSize: "x-small"
                            color: root.isDarkMode ? "#666666" : "#999999"
                        }
                        Rectangle {
                            visible: modelData.hasEpub || false
                            height: units.gu(2.2); width: epubLbl.width + units.gu(1.2)
                            radius: height / 2; color: "#1E3A1E"
                            Label { id: epubLbl; anchors.centerIn: parent
                                    text: "EPUB"; fontSize: "x-small"; color: "#4CAF50" }
                        }
                        Rectangle {
                            visible: Library.hasBook(modelData.id || "")
                            height: units.gu(2.2); width: inLibLbl.width + units.gu(1.2)
                            radius: height / 2; color: "#0D1F0D"
                            Label { id: inLibLbl; anchors.centerIn: parent
                                    text: "✓ In Library"; fontSize: "x-small"; color: "#4CAF50" }
                        }
                    }
                }
            }
        }

        Label {
            anchors.centerIn: parent
            text: discoverPage.isLoading ? "Loading…" : discoverPage.errorMsg
            visible: discoverPage.isLoading || discoverPage.errorMsg !== ""
            color: "#888888"; fontSize: "small"
        }
    }

    // ── Functions ─────────────────────────────────────────────────────────────

    function fetchBooks(url) {
        isLoading = true; errorMsg = ""; books = []
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            isLoading = false
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    var result = []
                    for (var i = 0; i < data.results.length; i++) {
                        var b = data.results[i]
                        var authorName = (b.authors && b.authors.length > 0)
                            ? b.authors[0].name : "Unknown Author"
                        var epubUrl = ""
                        var formats = b.formats || {}
                        for (var fmt in formats) {
                            if (fmt.indexOf("epub") !== -1) { epubUrl = formats[fmt]; break }
                        }
                        result.push({
                            id:          "gutenberg-" + b.id,
                            source_id:   "" + b.id,
                            title:       b.title || "Untitled",
                            author:      authorName,
                            author_id:   authorName.toLowerCase()
                                         .replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""),
                            birth_year:  (b.authors && b.authors.length > 0)
                                         ? (b.authors[0].birth_year || 0) : 0,
                            death_year:  (b.authors && b.authors.length > 0)
                                         ? (b.authors[0].death_year || 0) : 0,
                            cover:       formats["image/jpeg"] || "",
                            epub_url:    epubUrl,
                            downloads:   b.download_count || 0,
                            hasEpub:     epubUrl !== "",
                            copyright:   b.copyright,
                            media_type:  b.media_type || "Text",
                            subjects:    b.subjects || [],
                            bookshelves: b.bookshelves || [],
                            languages:   b.languages || ["en"]
                        })
                    }
                    books = result
                } catch(e) { errorMsg = "Failed to parse results" }
            } else { errorMsg = "Network error — check your connection" }
        }
        xhr.open("GET", url); xhr.send()
    }

    Component.onCompleted: {
        fetchBooks("https://gutendex.com/books/?languages=en&sort=popular")
    }
}