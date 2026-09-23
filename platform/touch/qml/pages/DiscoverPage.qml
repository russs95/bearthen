import QtQuick 2.12
import Ubuntu.Components 1.3
import "../js/Library.js" as Library

Page {
    id: discoverPage

    // ╔══════════════════════════════════════════════════════════════════╗
    // ║  VISUAL TWEAKS                                                   ║
    // ║  headerHeight  — matches LibraryPage green divider height        ║
    // ╚══════════════════════════════════════════════════════════════════╝
    readonly property real headerHeight: 6.7

    property var    books:        []
    property bool   isLoading:    false
    property string errorMsg:     ""
    property bool   showSources:  false
    property bool   aboutVisible: false   // world icon full-screen modal

    // Which sources are active
    property bool srcGutenberg:   true
    property bool srcStandard:    false
    property bool srcOpenLibrary: false

    // ── Header — matches LibraryPage style exactly ────────────────────────────
    header: PageHeader {
        id: pageHeader
        height: units.gu(headerHeight)

        contents: Item {
            anchors.fill: parent

            // RIGHT: book icon — left of +
            Rectangle {
                id: headerWorldBtn
                anchors { right: headerAddBtn.left; rightMargin: units.gu(0.2)
                          verticalCenter: parent.verticalCenter }
                width: units.gu(5); height: units.gu(5)
                radius: width / 2; color: "transparent"
                Icon {
                    anchors.centerIn: parent
                    width: units.gu(4.0); height: units.gu(4.0)
                    name: "stock_ebook"
                    color: root.isDarkMode ? "#666666" : "#999999"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: discoverPage.aboutVisible = true
                }
            }

            // RIGHT: + icon — far right — toggles source picker
            Rectangle {
                id: headerAddBtn
                anchors { right: parent.right; rightMargin: units.gu(0.4)
                          verticalCenter: parent.verticalCenter }
                width: units.gu(5); height: units.gu(5)
                radius: width / 2; color: "transparent"
                Icon {
                    anchors.centerIn: parent
                    width: units.gu(3.6); height: units.gu(3.6)
                    name: "add"
                    color: discoverPage.showSources
                           ? "#4CAF50"
                           : (root.isDarkMode ? "#AAAAAA" : "#666666")
                    rotation: discoverPage.showSources ? 45 : 0
                    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: discoverPage.showSources = !discoverPage.showSources
                }
            }

            // LEFT: Bearthen wordmark + "Discover Libraries"
            Column {
                anchors {
                    top: parent.top; topMargin: units.gu(0.4) + units.dp(5)
                    left: parent.left; leftMargin: units.gu(0.45)
                }
                spacing: -units.dp(3.0)

                // "B" Light + "earthen" Medium
                Row {
                    spacing: 0
                    Label {
                        text: "B"
                        font.pixelSize: units.gu(2.6)
                        font.weight: Font.Light
                        color: "#4CAF50"
                    }
                    Label {
                        text: "earthen"
                        font.pixelSize: units.gu(2.6)
                        font.weight: Font.Medium
                        color: "#4CAF50"
                    }
                }
                // "Discover" Medium + "Libraries" Light
                Row {
                    spacing: units.dp(4)
                    Label {
                        text: "Discover"
                        font.pixelSize: units.gu(1.7)
                        font.weight: Font.Medium
                        color: "#8B5A32"
                    }
                    Label {
                        text: "Libraries"
                        font.pixelSize: units.gu(1.7)
                        font.weight: Font.Light
                        color: "#8B5A32"
                    }
                }
            }
        }

        StyleHints {
            backgroundColor: root.isDarkMode ? "#1A1A1A" : "#F5F5F5"
            dividerColor: "#2C5F2E"
        }
    }

    // ── Page background ───────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: root.isDarkMode ? "#121212" : "#FFFFFF"
        Behavior on color { ColorAnimation { duration: 250 } }
        z: 0
    }

    // ── Library background texture — same tile art as library page ────────────
    Item {
        id: textureBg
        anchors { top: pageHeader.bottom; bottom: parent.bottom
                  left: parent.left; right: parent.right }
        opacity: root.isDarkMode ? 0.07 : 0.05
        Behavior on opacity { NumberAnimation { duration: 300 } }
        clip: true; z: 0
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            Repeater {
                model: 25
                Image {
                    width: textureBg.width; height: width
                    source: root.isDarkMode
                        ? Qt.resolvedUrl("../../assets/textures/library-background-night-mode.svg")
                        : Qt.resolvedUrl("../../assets/textures/library-background-day-mode.svg")
                    fillMode: Image.Stretch; smooth: true; asynchronous: true
                }
            }
        }
    }

    // ── Search bar — no source toggle button; + in header drives that ─────────
    Rectangle {
        id: searchBar
        anchors { top: pageHeader.bottom; left: parent.left; right: parent.right }
        height: units.gu(7)
        color: root.isDarkMode ? "#1A1A1A" : "#F5F5F5"
        Behavior on color { ColorAnimation { duration: 250 } }
        z: 1

        TextField {
            id: searchField
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: units.gu(2); rightMargin: units.gu(2)
            }
            placeholderText: "Search libraries..."
            onAccepted: doSearch(text)
        }
    }

    // ── Source picker panel — toggled by header + button ──────────────────────
    Rectangle {
        id: sourcePanel
        anchors { top: searchBar.bottom; left: parent.left; right: parent.right }
        height: discoverPage.showSources ? sourcePanelContent.height + units.gu(2) : 0
        clip: true
        color: root.isDarkMode ? "#141414" : "#F9F6F1"
        border.color: root.isDarkMode ? "#2A2A2A" : "#E0D8CC"
        border.width: units.dp(1)
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        z: 5   // above book grid

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

            Repeater {
                model: [
                    { key: "gutenberg",   label: "Project Gutenberg",
                      sub: "70,000+ public domain classics",     icon: "book" },
                    { key: "standard",    label: "Standard Ebooks",
                      sub: "Beautifully typeset editions",        icon: "stock_ebook" },
                    { key: "openlibrary", label: "Open Library",
                      sub: "Internet Archive — 1M+ free books",  icon: "history" },
                ]
                Rectangle {
                    width: parent.width; height: units.gu(5.5)
                    color: "transparent"
                    Row {
                        anchors { left: parent.left; right: parent.right
                                  verticalCenter: parent.verticalCenter }
                        spacing: units.gu(1.2)

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
                                name: "tick"; color: "#FFFFFF"
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
        z: 2

        // Loading — spinner + message
        Column {
            anchors.centerIn: parent
            spacing: units.gu(2)
            visible: discoverPage.isLoading

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

        // Error state — icon + message + retry
        Column {
            anchors.centerIn: parent
            spacing: units.gu(2)
            visible: !discoverPage.isLoading && discoverPage.errorMsg !== ""

            // Disconnected network icon
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: units.gu(9); height: units.gu(9)
                name: "network-offline"
                color: root.isDarkMode ? "#3A3A3A" : "#CCCCCC"
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Couldn't connect to Libraries"
                fontSize: "medium"; font.weight: Font.Medium
                color: root.isDarkMode ? "#DDDDDD" : "#333333"
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: units.gu(32)
                text: discoverPage.errorMsg
                fontSize: "x-small"
                color: root.isDarkMode ? "#666666" : "#999999"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                height: units.gu(4); width: retryRow.width + units.gu(3)
                radius: height / 2; color: "transparent"
                border.color: "#2C5F2E"; border.width: units.dp(1.5)
                Row {
                    id: retryRow
                    anchors.centerIn: parent; spacing: units.gu(0.6)
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

    // ── Book grid — 2-column card layout matching library page ────────────────
    GridView {
        id: bookGrid
        anchors {
            top: sourcePanel.bottom; left: parent.left
            right: parent.right; bottom: parent.bottom
            leftMargin: units.gu(1.5); rightMargin: units.gu(1.5)
            bottomMargin: units.gu(1.5)
        }
        topMargin: units.gu(1.5)
        clip: true
        visible: !discoverPage.isLoading && discoverPage.errorMsg === ""
        model: discoverPage.books
        cellWidth: width / 2
        cellHeight: units.gu(25)
        z: 1

        delegate: Item {
            width: bookGrid.cellWidth
            height: bookGrid.cellHeight

            Rectangle {
                anchors { fill: parent; margins: units.gu(0.5) }
                color: root.isDarkMode ? "#222222" : "#EEEEEE"
                radius: units.dp(8)
                Behavior on color { ColorAnimation { duration: 250 } }

                Column {
                    anchors { fill: parent; margins: units.gu(0.7) }
                    spacing: units.gu(0.5)

                    // ── Cover frame ───────────────────────────────────────────
                    Rectangle {
                        width: parent.width; height: units.gu(15.5)
                        color: root.isDarkMode ? "#2E2E2E" : "#E0E0E0"
                        radius: units.dp(5); clip: true
                        Behavior on color { ColorAnimation { duration: 250 } }

                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(5); height: units.gu(5)
                            name: "stock_ebook"
                            color: root.isDarkMode ? "#444444" : "#CCCCCC"
                            opacity: 0.8
                        }
                        Image {
                            anchors.fill: parent
                            source: modelData.cover || ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true; cache: true
                        }
                    }

                    // ── Title ─────────────────────────────────────────────────
                    Label {
                        width: parent.width
                        text: modelData.title || ""
                        fontSize: "x-small"; font.weight: Font.Medium
                        color: root.isDarkMode ? "#FFFFFF" : "#212121"
                        wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }

                    // ── Author ────────────────────────────────────────────────
                    Label {
                        width: parent.width
                        text: modelData.author || ""
                        fontSize: "x-small"; color: "#4CAF50"; elide: Text.ElideRight
                    }

                    // ── Badges ────────────────────────────────────────────────
                    Row {
                        spacing: units.gu(0.5)
                        Rectangle {
                            visible: modelData.hasEpub || false
                            height: units.gu(2.2); width: epubLbl.width + units.gu(1.2)
                            radius: height / 2
                            color: root.isDarkMode ? "#1E3A1E" : "#C8E6C9"
                            Label { id: epubLbl; anchors.centerIn: parent
                                    text: "EPUB"; fontSize: "x-small"
                                    color: root.isDarkMode ? "#4CAF50" : "#2C5F2E" }
                        }
                        Rectangle {
                            visible: Library.hasBook(modelData.id || "")
                            height: units.gu(2.2); width: inLibLbl.width + units.gu(1.2)
                            radius: height / 2
                            color: root.isDarkMode ? "#0D1F0D" : "#E8F5E9"
                            Label { id: inLibLbl; anchors.centerIn: parent
                                    text: "In Library"; fontSize: "x-small"
                                    color: root.isDarkMode ? "#4CAF50" : "#2C5F2E" }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        bookDetailPage.book            = modelData
                        bookDetailPage.isDownloading   = false
                        bookDetailPage.downloadProgress = 0
                        bookDetailPage.downloadStatus  = ""
                        bookDetailPage.bookDescription = ""
                        bookDetailPage.alreadyInLib    = Library.hasBook(modelData.id)
                        pageStack.push(bookDetailPage)
                    }
                }
            }
        }
    }

    // ── "Open Libraries" full-screen modal — book icon ────────────────────────
    Rectangle {
        id: discoverAboutScreen
        anchors.fill: parent
        color: root.isDarkMode ? "#0D0D0D" : "#F5F5F5"
        visible: discoverPage.aboutVisible
        opacity: discoverPage.aboutVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 220 } }
        z: 100

        MouseArea { anchors.fill: parent; onClicked: {} }

        // Library texture overlay
        Item {
            anchors.fill: parent
            opacity: root.isDarkMode ? 0.1 : 0.06
            clip: true; z: 0
            Column {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                Repeater {
                    model: 25
                    Image {
                        width: parent ? parent.width : Screen.width; height: width
                        source: root.isDarkMode
                            ? Qt.resolvedUrl("../../assets/textures/library-background-night-mode.svg")
                            : Qt.resolvedUrl("../../assets/textures/library-background-day-mode.svg")
                        fillMode: Image.Stretch; smooth: true; asynchronous: true
                    }
                }
            }
        }

        // X close button — top right, floating over content
        Rectangle {
            id: aboutCloseBtn
            anchors { top: parent.top; right: parent.right
                      topMargin: units.gu(1.5); rightMargin: units.gu(1.5) }
            width: units.gu(5); height: units.gu(5)
            radius: width / 2
            color: root.isDarkMode ? "#1E1E1E" : "#E0E0E0"
            z: 101
            Icon {
                anchors.centerIn: parent
                width: units.gu(2.4); height: units.gu(2.4)
                name: "close"
                color: root.isDarkMode ? "#888888" : "#666666"
            }
            MouseArea {
                anchors.fill: parent
                onClicked: discoverPage.aboutVisible = false
            }
        }

        // Scrollable content — full height, top margin leaves room below X button
        Flickable {
            anchors { top: parent.top; left: parent.left
                      right: parent.right; bottom: parent.bottom }
            contentHeight: discoverAboutCol.height + units.gu(8)
            clip: true; flickableDirection: Flickable.VerticalFlick
            z: 1

            Column {
                id: discoverAboutCol
                width: parent.width - units.gu(6)
                anchors { top: parent.top; topMargin: units.gu(9)
                          horizontalCenter: parent.horizontalCenter }
                spacing: units.gu(2.2)

                // Book icon (Suru)
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: units.gu(10); height: units.gu(10)
                    name: "stock_ebook"; color: "#8B5A32"
                }

                // Title
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    text: "A Library where it's about the Books"
                    font.pixelSize: units.gu(2.4); font.weight: Font.Light
                    color: root.isDarkMode ? "#2C7A30" : "#1E5C22"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width; height: units.dp(1)
                    color: root.isDarkMode ? "#1E1E1E" : "#E0E0E0"
                }

                // Main body
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    text: "You just want to read a book. Most authors they want to write them. "
                        + "In between are the platforms that just want to make money.\n\n"
                        + "When I put together Bearthen, I did it for myself: to find a little "
                        + "island of reading solace where I could read in peace and share my little "
                        + "book. Turns out lots of folks think the same way. They have worked hard "
                        + "to make millions of books open source and available to the world for the "
                        + "exact same reason.\n\n"
                        + "Bearthen lets you connect via their library APIs and get and read their "
                        + "books! No profits in between. Just great books for our fellow humans on "
                        + "planet Earth."
                    font.pixelSize: units.gu(1.75); font.weight: Font.Light
                    color: root.isDarkMode ? "#CCCCCC" : "#444444"
                    wrapMode: Text.WordWrap; lineHeight: 1.55
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    width: parent.width; height: units.dp(1)
                    color: root.isDarkMode ? "#1E1E1E" : "#E0E0E0"
                }

                // Earthen ethics note
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    text: "One of the core Earthen ethics is that of spiralling consciousness."
                    font.pixelSize: units.gu(1.6); font.weight: Font.Light
                    color: root.isDarkMode ? "#888888" : "#999999"
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                // Learn more button
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.72; height: units.gu(6)
                    radius: units.dp(10); color: "#2C5F2E"
                    border.color: "#1E4520"; border.width: units.dp(1)
                    Row {
                        anchors.centerIn: parent; spacing: units.gu(1)
                        Icon {
                            width: units.gu(2.2); height: units.gu(2.2)
                            name: "go-next"; color: "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Label {
                            text: "Learn more"
                            font.pixelSize: units.gu(2.0); font.weight: Font.Medium
                            color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Qt.openUrlExternally("https://book.earthen.io/en/awareness.html")
                    }
                }

                Item { width: 1; height: units.gu(2) }
            }
        }
    }

    // ── Functions (unchanged) ─────────────────────────────────────────────────

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
