import QtQuick 2.12
import Ubuntu.Components 1.3
import QtQuick.XmlListModel 2.0

Page {
    id: discoverPage

    // ── Header ────────────────────────────────────────────────────────────────
    header: PageHeader {
        id: pageHeader
        title: "Bearthen"
        subtitle: "Discover Books"

        StyleHints {
            foregroundColor: "#4CAF50"
            backgroundColor: "#1A1A1A"
            dividerColor: "#2C5F2E"
        }
    }

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#121212"
    }

    // ── State ─────────────────────────────────────────────────────────────────
    property string searchQuery: ""
    property bool isLoading: false
    property bool hasSearched: false
    property string errorMessage: ""

    // ── Gutendex API request ──────────────────────────────────────────────────
    XmlListModel {
        id: gutenbergModel
    }

    // Use Qt's XMLHttpRequest for JSON fetching
    function searchGutenberg(query) {
        discoverPage.isLoading = true
        discoverPage.hasSearched = true
        discoverPage.errorMessage = ""
        bookModel.clear()

        var url = "https://gutendex.com/books/"
        if (query && query.length > 0) {
            url += "?search=" + encodeURIComponent(query)
        } else {
            url += "?topic=fiction&languages=en"
        }

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                discoverPage.isLoading = false
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        var results = response.results
                        for (var i = 0; i < results.length; i++) {
                            var book = results[i]
                            var authorName = (book.authors && book.authors.length > 0)
                                ? book.authors[0].name
                                : "Unknown Author"
                            var coverUrl = (book.formats && book.formats["image/jpeg"])
                                ? book.formats["image/jpeg"]
                                : ""
                            var epubUrl = (book.formats && book.formats["application/epub+zip"])
                                ? book.formats["application/epub+zip"]
                                : ""
                            bookModel.append({
                                "bookId":    book.id.toString(),
                                "title":     book.title || "Untitled",
                                "author":    authorName,
                                "coverUrl":  coverUrl,
                                "epubUrl":   epubUrl,
                                "downloads": book.download_count || 0
                            })
                        }
                    } catch (e) {
                        discoverPage.errorMessage = "Could not parse results. Please try again."
                    }
                } else {
                    discoverPage.errorMessage = "Could not reach Gutenberg. Check your connection."
                }
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    // Load popular books on first appearance
    Component.onCompleted: {
        searchGutenberg("")
    }

    // ── Book data model ───────────────────────────────────────────────────────
    ListModel {
        id: bookModel
    }

    // ── Main content column ───────────────────────────────────────────────────
    Column {
        id: contentColumn
        anchors {
            top: pageHeader.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        // ── Search bar ────────────────────────────────────────────────────────
        Rectangle {
            id: searchBar
            width: parent.width
            height: units.gu(7)
            color: "#1A1A1A"

            Rectangle {
                anchors {
                    fill: parent
                    margins: units.gu(1.5)
                }
                radius: units.gu(0.6)
                color: "#2A2A2A"
                border.color: searchField.activeFocus ? "#2C5F2E" : "#333333"
                border.width: units.dp(1)

                Row {
                    anchors {
                        fill: parent
                        leftMargin: units.gu(1.5)
                        rightMargin: units.gu(1)
                    }
                    spacing: units.gu(1)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: units.gu(2.2)
                        height: units.gu(2.2)
                        name: "search"
                        color: searchField.activeFocus ? "#4CAF50" : "#666666"
                    }

                    TextField {
                        id: searchField
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - units.gu(5)
                        placeholderText: "Search 70,000 free books..."
                        color: "#FFFFFF"

                        inputMethodHints: Qt.ImhNoPredictiveText

                        onAccepted: {
                            discoverPage.searchQuery = searchField.text
                            searchGutenberg(searchField.text)
                        }
                    }
                }
            }
        }

        // ── Section label ─────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: units.gu(4)
            color: "#121212"

            Label {
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }
                text: discoverPage.searchQuery.length > 0
                    ? "Results for \"" + discoverPage.searchQuery + "\""
                    : "Popular on Project Gutenberg"
                fontSize: "small"
                color: "#888888"
                font.weight: Font.Medium
            }
        }

        // ── Loading indicator ─────────────────────────────────────────────────
        ActivityIndicator {
            id: loadingSpinner
            anchors.horizontalCenter: parent.horizontalCenter
            running: discoverPage.isLoading
            visible: discoverPage.isLoading
            height: units.gu(6)
        }

        // ── Error state ───────────────────────────────────────────────────────
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(32)
            text: discoverPage.errorMessage
            visible: discoverPage.errorMessage.length > 0
            color: "#E57373"
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            fontSize: "small"
        }

        // ── Results list ──────────────────────────────────────────────────────
        ListView {
            id: bookList
            width: parent.width
            height: contentColumn.height
                    - searchBar.height
                    - units.gu(4)
            visible: !discoverPage.isLoading && discoverPage.errorMessage.length === 0
            model: bookModel
            clip: true

            delegate: ListItem {
                id: bookDelegate
                height: units.gu(13)
                divider.colorFrom: "#2C5F2E"
                divider.colorTo: "#121212"

                // Press highlight
                color: bookDelegate.highlighted ? "#1E3A1E" : "transparent"

                Row {
                    anchors {
                        fill: parent
                        margins: units.gu(1.5)
                    }
                    spacing: units.gu(1.5)

                    // ── Cover image ───────────────────────────────────────────
                    Rectangle {
                        id: coverRect
                        width: units.gu(7)
                        height: units.gu(10)
                        radius: units.gu(0.4)
                        color: "#1E3A1E"
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: coverImage
                            anchors.fill: parent
                            source: model.coverUrl
                            fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                            visible: coverImage.status === Image.Ready

                            layer.effect: null
                        }

                        // Fallback icon when no cover
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(3)
                            height: units.gu(3)
                            name: "book"
                            color: "#2C5F2E"
                            visible: coverImage.status !== Image.Ready
                        }
                    }

                    // ── Book info ─────────────────────────────────────────────
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - units.gu(8.5)
                        spacing: units.gu(0.5)

                        Label {
                            width: parent.width
                            text: model.title
                            fontSize: "medium"
                            color: "#FFFFFF"
                            font.weight: Font.Medium
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Label {
                            width: parent.width
                            text: model.author
                            fontSize: "small"
                            color: "#4CAF50"
                            elide: Text.ElideRight
                        }

                        Row {
                            spacing: units.gu(0.5)

                            Icon {
                                width: units.gu(1.5)
                                height: units.gu(1.5)
                                name: "download"
                                color: "#666666"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                text: model.downloads.toLocaleString() + " downloads"
                                fontSize: "x-small"
                                color: "#666666"
                            }
                        }

                        // EPUB availability badge
                        Rectangle {
                            visible: model.epubUrl.length > 0
                            width: epubLabel.width + units.gu(1.5)
                            height: units.gu(2.2)
                            radius: units.gu(0.3)
                            color: "#1A3A1A"
                            border.color: "#2C5F2E"
                            border.width: units.dp(1)

                            Label {
                                id: epubLabel
                                anchors.centerIn: parent
                                text: "EPUB"
                                fontSize: "x-small"
                                color: "#4CAF50"
                                font.weight: Font.Medium
                            }
                        }
                    }
                }

                // Tap action — placeholder for book detail / download
                onClicked: {
                    console.log("Selected:", model.title, "| EPUB:", model.epubUrl)
                    downloadHint.bookTitle = model.title
                    downloadHint.visible = true
                }
            }

            // Pull to refresh feel at bottom
            footer: Item { height: units.gu(2) }
        }
    }

    // ── Download hint dialog ──────────────────────────────────────────────────
    Rectangle {
        id: downloadHint
        anchors.fill: parent
        color: "#CC000000"
        visible: false
        z: 10

        property string bookTitle: ""

        MouseArea {
            anchors.fill: parent
            onClicked: downloadHint.visible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: units.gu(36)
            height: units.gu(26)
            radius: units.gu(1)
            color: "#1E1E1E"

            Column {
                anchors {
                    fill: parent
                    margins: units.gu(3)
                }
                spacing: units.gu(2)

                Label {
                    text: "Add to Library"
                    fontSize: "large"
                    color: "#FFFFFF"
                    font.weight: Font.Medium
                }

                Label {
                    width: parent.width
                    text: "\"" + downloadHint.bookTitle + "\""
                    wrapMode: Text.WordWrap
                    fontSize: "small"
                    color: "#4CAF50"
                    font.weight: Font.Medium
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Label {
                    width: parent.width
                    text: "One-tap download to your library is coming in the next release. This book is freely available from Project Gutenberg."
                    wrapMode: Text.WordWrap
                    fontSize: "small"
                    color: "#AAAAAA"
                    lineHeight: 1.4
                }

                Button {
                    text: "Got it"
                    color: "#2C5F2E"
                    width: parent.width
                    onClicked: downloadHint.visible = false
                }
            }
        }
    }
}