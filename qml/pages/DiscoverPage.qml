import QtQuick 2.12
import Ubuntu.Components 1.3
import "../js/Library.js" as Library

Page {
    id: discoverPage

    property var    books:        []
    property bool   isLoading:    false
    property string errorMsg:     ""
    property bool   showSources:  false

    // Which sources are active
    property bool srcGutenberg:   true
    property bool srcStandard:    false
    property bool srcOpenLibrary: false

    header: PageHeader {
        id: pageHeader
        contents: Item {
            // PageHeader contents slot: left edge starts after the leading action bar (~9.5gu)
            // We anchor with explicit left margin so labels never slide under the back chevron
            anchors { fill: parent; leftMargin: units.gu(1) }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: units.dp(2)
                Label {
                    text: "Bearthen"
                    fontSize: "large"
                    font.weight: Font.Light
                    color: "#4CAF50"
                    elide: Text.ElideRight
                    width: parent.width
                }
                Label {
                    text: root.t("Discover Books")
                    fontSize: "small"
                    font.weight: Font.Light
                    color: "#6B3A20"
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }
        StyleHints {
            backgroundColor: root.isDarkMode ? "#1A1A1A" : "#F5F5F5"
            dividerColor: "#2C5F2E"
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.isDarkMode ? "#121212" : "#FFFFFF"
        Behavior on color { ColorAnimation { duration: 250 } }
    }

    // ── Search bar ────────────────────────────────────────────────────────────
    Rectangle {
        id: searchBar
        anchors { top: pageHeader.bottom; left: parent.left; right: parent.right }
        height: units.gu(7)
        color: root.isDarkMode ? "#1A1A1A" : "#F5F5F5"
        Behavior on color { ColorAnimation { duration: 250 } }

        Row {
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: units.gu(2); rightMargin: units.gu(1.5)
            }
            spacing: units.gu(1)

            TextField {
                id: searchField
                width: parent.width - sourceBtn.width - parent.spacing
                placeholderText: "Search libraries..."
                onAccepted: doSearch(text)
            }

            // Source picker toggle button
            Rectangle {
                id: sourceBtn
                width: units.gu(4); height: searchField.height
                radius: units.dp(8)
                color: discoverPage.showSources
                       ? "#6B3A20"
                       : (root.isDarkMode ? "#252525" : "#E8E8E8")
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 180 } }

                Icon {
                    anchors.centerIn: parent
                    width: units.gu(2.4); height: units.gu(2.4)
                    name: "add"
                    color: discoverPage.showSources ? "#FFFFFF"
                           : (root.isDarkMode ? "#AAAAAA" : "#555555")
                    Behavior on color { ColorAnimation { duration: 180 } }

                    // Rotate to X when open
                    rotation: discoverPage.showSources ? 45 : 0
                    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: discoverPage.showSources = !discoverPage.showSources
                }
            }
        }
    }

    // ── Source picker panel ───────────────────────────────────────────────────
    Rectangle {
        id: sourcePanel
        anchors { top: searchBar.bottom; left: parent.left; right: parent.right }
        height: discoverPage.showSources ? sourcePanelContent.height + units.gu(2) : 0
        clip: true
        color: root.isDarkMode ? "#141414" : "#F9F6F1"
        border.color: root.isDarkMode ? "#2A2A2A" : "#E0D8CC"
        border.width: units.dp(1)
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Column {
            id: sourcePanelContent
            anchors { top: parent.top; topMargin: units.gu(1.2)
                      left: parent.left; right: parent.right
                      leftMargin: units.gu(2); rightMargin: units.gu(2) }
            spacing: 0

            Label {
                text: "Search libraries"
                fontSize: "x-small"; font.weight: Font.Medium
                color: root.isDarkMode ? "#666666" : "#999999"
                font.letterSpacing: units.dp(1)
            }
            Item { width: 1; height: units.gu(0.8) }

            // Source row component repeated 3 times
            Repeater {
                model: [
                    { key: "gutenberg",   label: "Project Gutenberg",
                      sub: "70,000+ public domain classics",
                      icon: "book" },
                    { key: "standard",    label: "Standard Ebooks",
                      sub: "Beautifully typeset editions",
                      icon: "stock_ebook" },
                    { key: "openlibrary", label: "Open Library",
                      sub: "Internet Archive — 1M+ free books",
                      icon: "history" },
                ]
                Rectangle {
                    width: parent.width; height: units.gu(5.5)
                    color: "transparent"
                    Row {
                        anchors { left: parent.left; right: parent.right
                                  verticalCenter: parent.verticalCenter }
                        spacing: units.gu(1.2)

                        // Checkbox
                        Rectangle {
                            width: units.gu(2.4); height: units.gu(2.4)
                            radius: units.dp(5)
                            anchors.verticalCenter: parent.verticalCenter
                            color: isChecked ? "#6B3A20" : "transparent"
                            border.color: isChecked ? "#6B3A20"
                                          : (root.isDarkMode ? "#444444" : "#BBBBBB")
                            border.width: units.dp(1.5)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            property bool isChecked: {
                                if (modelData.key === "gutenberg")   return discoverPage.srcGutenberg
                                if (modelData.key === "standard")    return discoverPage.srcStandard
                                return discoverPage.srcOpenLibrary
                            }
                            Icon {
                                anchors.centerIn: parent
                                width: units.gu(1.4); height: units.gu(1.4)
                                name: "tick"
                                color: "#FFFFFF"
                                visible: parent.isChecked
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: units.gu(0.1)
                            Label {
                                text: modelData.label
                                fontSize: "small"; font.weight: Font.Medium
                                color: root.isDarkMode ? "#DDDDDD" : "#222222"
                            }
                            Label {
                                text: modelData.sub
                                fontSize: "x-small"
                                color: root.isDarkMode ? "#666666" : "#999999"
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (modelData.key === "gutenberg")
                                discoverPage.srcGutenberg = !discoverPage.srcGutenberg
                            else if (modelData.key === "standard")
                                discoverPage.srcStandard = !discoverPage.srcStandard
                            else
                                discoverPage.srcOpenLibrary = !discoverPage.srcOpenLibrary
                        }
                    }
                }
            }

            // Search button
            Rectangle {
                width: parent.width; height: units.gu(4.5); radius: units.dp(8)
                color: "#2C5F2E"
                Label {
                    anchors.centerIn: parent
                    text: "Search selected libraries"
                    fontSize: "small"; font.weight: Font.Medium; color: "#FFFFFF"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        discoverPage.showSources = false
                        doSearch(searchField.text)
                    }
                }
            }

            Item { width: 1; height: units.gu(0.4) }
        }
    }

    // ── Loading / error state ─────────────────────────────────────────────────
    Item {
        anchors {
            top: sourcePanel.bottom; left: parent.left
            right: parent.right; bottom: parent.bottom
        }
        visible: discoverPage.isLoading || discoverPage.errorMsg !== ""

        // Loading — spinner + message
        Column {
            anchors.centerIn: parent
            spacing: units.gu(2)
            visible: discoverPage.isLoading

            // Spinning circle
            Rectangle {
                id: spinnerOuter
                width: units.gu(5.5); height: units.gu(5.5)
                radius: width / 2; color: "transparent"
                border.color: root.isDarkMode ? "#2A2A2A" : "#E0E0E0"
                border.width: units.dp(3)
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    width: units.gu(5.5); height: units.gu(5.5)
                    radius: width / 2; color: "transparent"
                    border.color: "#4CAF50"; border.width: units.dp(3)
                    // Clip to quarter arc
                    Rectangle {
                        width: parent.width / 2; height: parent.height / 2
                        anchors { top: parent.top; right: parent.right }
                        color: root.isDarkMode ? "#121212" : "#FFFFFF"
                    }
                    RotationAnimation on rotation {
                        running: discoverPage.isLoading
                        loops: Animation.Infinite; from: 0; to: 360; duration: 1000
                    }
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Loading epic books from Project Gutenberg..."
                fontSize: "small"; color: root.isDarkMode ? "#888888" : "#999999"
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // Error state — disconnected icon + message + retry
        Column {
            anchors.centerIn: parent
            spacing: units.gu(1.5)
            visible: !discoverPage.isLoading && discoverPage.errorMsg !== ""

            // Unplugged icon — two rectangles + gap
            Item {
                width: units.gu(7); height: units.gu(7)
                anchors.horizontalCenter: parent.horizontalCenter

                // Cable top
                Rectangle {
                    width: units.gu(1); height: units.gu(2.5)
                    anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
                    radius: units.dp(4)
                    color: root.isDarkMode ? "#444444" : "#BBBBBB"
                }
                // Plug head top
                Rectangle {
                    width: units.gu(3); height: units.gu(1.2)
                    anchors { top: parent.top; topMargin: units.gu(2.2)
                              horizontalCenter: parent.horizontalCenter }
                    radius: units.dp(3)
                    color: root.isDarkMode ? "#555555" : "#AAAAAA"
                }
                // Gap — sparks
                Label {
                    anchors { top: parent.top; topMargin: units.gu(3.6)
                              horizontalCenter: parent.horizontalCenter }
                    text: "- -"
                    fontSize: "small"
                    color: "#4CAF50"
                    font.letterSpacing: units.dp(2)
                }
                // Plug head bottom
                Rectangle {
                    width: units.gu(3); height: units.gu(1.2)
                    anchors { top: parent.top; topMargin: units.gu(4.5)
                              horizontalCenter: parent.horizontalCenter }
                    radius: units.dp(3)
                    color: root.isDarkMode ? "#555555" : "#AAAAAA"
                }
                // Cable bottom
                Rectangle {
                    width: units.gu(1); height: units.gu(1.3)
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                    radius: units.dp(4)
                    color: root.isDarkMode ? "#444444" : "#BBBBBB"
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No connection to the library"
                fontSize: "medium"; font.weight: Font.Medium
                color: root.isDarkMode ? "#DDDDDD" : "#333333"
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: discoverPage.errorMsg
                fontSize: "x-small"
                color: root.isDarkMode ? "#666666" : "#999999"
                horizontalAlignment: Text.AlignHCenter
            }

            // Retry link
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                height: units.gu(4); width: retryRow.width + units.gu(3)
                radius: height / 2
                color: "transparent"
                border.color: "#2C5F2E"; border.width: units.dp(1.5)
                Row {
                    id: retryRow
                    anchors.centerIn: parent
                    spacing: units.gu(0.6)
                    Icon {
                        width: units.gu(1.8); height: units.gu(1.8)
                        name: "reload"; color: "#4CAF50"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: "Try again"
                        fontSize: "small"; color: "#4CAF50"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: fetchBooks("https://gutendex.com/books/?languages=en&sort=popular")
                }
            }
        }
    }

    // ── Book list ─────────────────────────────────────────────────────────────
    ListView {
        id: bookList
        anchors {
            top: sourcePanel.bottom; left: parent.left
            right: parent.right; bottom: parent.bottom
        }
        clip: true
        visible: !discoverPage.isLoading && discoverPage.errorMsg === ""
        model: discoverPage.books

        delegate: ListItem {
            height: units.gu(12)
            color: root.isDarkMode ? "#121212" : "#FFFFFF"
            divider.colorFrom: root.isDarkMode ? "#2A2A2A" : "#E0E0E0"
            divider.colorTo:   root.isDarkMode ? "#121212" : "#FFFFFF"
            Behavior on color { ColorAnimation { duration: 250 } }

            onClicked: {
                bookDetailPage.book            = modelData
                bookDetailPage.isDownloading   = false
                bookDetailPage.downloadProgress = 0
                bookDetailPage.downloadStatus  = ""
                bookDetailPage.bookDescription = ""
                bookDetailPage.alreadyInLib    = Library.hasBook(modelData.id)
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
                        visible: coverImg.status !== Image.Ready
                    }
                    Image {
                        id: coverImg
                        anchors.fill: parent; anchors.margins: units.dp(2)
                        source: modelData.cover || ""
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
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
                                    text: "In Library"; fontSize: "x-small"; color: "#4CAF50" }
                        }
                    }
                }
            }
        }
    }

    // ── Functions ─────────────────────────────────────────────────────────────

    function doSearch(query) {
        books = []
        errorMsg = ""

        if (srcGutenberg) {
            var url = query && query.length > 0
                ? "https://gutendex.com/books/?search=" + encodeURIComponent(query) + "&languages=en"
                : "https://gutendex.com/books/?languages=en&sort=popular"
            fetchGutenberg(url)
        } else if (srcStandard) {
            fetchStandardEbooks(query)
        } else if (srcOpenLibrary) {
            fetchOpenLibrary(query)
        } else {
            // Nothing checked — default to Gutenberg popular
            fetchGutenberg("https://gutendex.com/books/?languages=en&sort=popular")
        }
    }

    function fetchBooks(url) {
        fetchGutenberg(url)
    }

    function fetchGutenberg(url) {
        isLoading = true; errorMsg = ""
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
                            author_id:   authorName.toLowerCase().replace(/ /g, "-"),
                            birth_year:  (b.authors && b.authors.length > 0)
                                         ? (b.authors[0].birth_year || 0) : 0,
                            death_year:  (b.authors && b.authors.length > 0)
                                         ? (b.authors[0].death_year || 0) : 0,
                            cover:       formats["image/jpeg"] || "",
                            epub_url:    epubUrl,
                            downloads:   b.download_count || 0,
                            hasEpub:     epubUrl !== "",
                            copyright:   b.copyright,
                            subjects:    b.subjects || [],
                            languages:   b.languages || ["en"],
                            source:      "Project Gutenberg"
                        })
                    }
                    books = result
                } catch(e) { errorMsg = "Could not read response" }
            } else {
                errorMsg = "HTTP " + xhr.status + " — check your connection"
            }
        }
        xhr.open("GET", url); xhr.send()
    }

    function fetchStandardEbooks(query) {
        isLoading = true; errorMsg = ""
        // Standard Ebooks provides an OPDS 1.2 catalog — we use their search endpoint
        // which returns Atom/XML. Since QML can't parse XML easily, we map their
        // book slugs to direct epub URLs using their predictable URL scheme.
        // Fallback: show popular Standard Ebooks titles via their JSON feed.
        var url = "https://standardebooks.org/ebooks.json"
        if (query && query.length > 0) {
            url = "https://standardebooks.org/ebooks.json?query=" + encodeURIComponent(query)
        }
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            isLoading = false
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    var result = []
                    var items = Array.isArray(data) ? data : (data.ebooks || [])
                    for (var i = 0; i < Math.min(items.length, 20); i++) {
                        var b = items[i]
                        var slug = b.url || b.id || ""
                        var epubUrl = slug
                            ? "https://standardebooks.org" + slug + "/downloads/se-ebook.epub"
                            : ""
                        result.push({
                            id:        "se-" + (b.id || i),
                            source_id: slug,
                            title:     b.title || "Untitled",
                            author:    (b.authors && b.authors.length > 0)
                                       ? b.authors.join(", ") : "Unknown",
                            author_id: "se-author",
                            birth_year:  0, death_year: 0,
                            cover:     slug
                                       ? "https://standardebooks.org" + slug
                                         + "/downloads/cover.jpg" : "",
                            epub_url:  epubUrl,
                            downloads: 0,
                            hasEpub:   epubUrl !== "",
                            copyright: false,
                            subjects:  b.subjects || [],
                            languages: ["en"],
                            source:    "Standard Ebooks"
                        })
                    }
                    if (result.length === 0)
                        errorMsg = "No results found in Standard Ebooks"
                    else
                        books = result
                } catch(e) {
                    errorMsg = "Could not parse Standard Ebooks response"
                }
            } else {
                errorMsg = "Standard Ebooks unavailable (HTTP " + xhr.status + ")"
            }
        }
        xhr.open("GET", url); xhr.send()
    }

    function fetchOpenLibrary(query) {
        isLoading = true; errorMsg = ""
        var q = (query && query.length > 0) ? query : "classic literature"
        var url = "https://openlibrary.org/search.json?q=" + encodeURIComponent(q)
                + "&has_fulltext=true&ebook_access=public&limit=20&fields="
                + "key,title,author_name,cover_i,first_publish_year,id_project_gutenberg,"
                + "subject,language,edition_count"
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            isLoading = false
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    var result = []
                    var docs = data.docs || []
                    for (var i = 0; i < docs.length; i++) {
                        var b = docs[i]
                        // Open Library entries with Gutenberg IDs can link to epub
                        var gutId = (b.id_project_gutenberg && b.id_project_gutenberg.length > 0)
                                    ? b.id_project_gutenberg[0] : ""
                        var epubUrl = gutId
                            ? "https://www.gutenberg.org/ebooks/" + gutId + ".epub.images"
                            : ""
                        var coverId = b.cover_i || 0
                        result.push({
                            id:        "ol-" + (b.key || i).replace("/works/", ""),
                            source_id: b.key || "",
                            title:     b.title || "Untitled",
                            author:    (b.author_name && b.author_name.length > 0)
                                       ? b.author_name[0] : "Unknown",
                            author_id: "ol-author",
                            birth_year: 0, death_year: 0,
                            cover:     coverId > 0
                                       ? "https://covers.openlibrary.org/b/id/"
                                         + coverId + "-M.jpg" : "",
                            epub_url:  epubUrl,
                            downloads: b.edition_count || 0,
                            hasEpub:   epubUrl !== "",
                            copyright: false,
                            subjects:  b.subject ? b.subject.slice(0, 5) : [],
                            languages: b.language || ["en"],
                            source:    "Open Library"
                        })
                    }
                    if (result.length === 0)
                        errorMsg = "No downloadable results found in Open Library"
                    else
                        books = result
                } catch(e) {
                    errorMsg = "Could not parse Open Library response"
                }
            } else {
                errorMsg = "Open Library unavailable (HTTP " + xhr.status + ")"
            }
        }
        xhr.open("GET", url); xhr.send()
    }

    Component.onCompleted: {
        fetchBooks("https://gutendex.com/books/?languages=en&sort=popular")
    }
}