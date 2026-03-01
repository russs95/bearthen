import QtQuick 2.12
import Ubuntu.Components 1.3
import Ubuntu.Content 1.3
import Morph.Web 0.1
import "../js/Library.js" as Library

Page {
    id: libraryPage

    // ╔══════════════════════════════════════════════════════════════════╗
    // ║  VISUAL TWEAKS — change these to adjust layout/appearance       ║
    // ╠══════════════════════════════════════════════════════════════════╣
    // ║  headerHeight     gu units — controls where the green divider   ║
    // ║                   line sits (PageHeader height)                 ║
    // ║  texOpacityDark   0.0‒1.0 — texture brightness, dark mode      ║
    // ║  texOpacityLight  0.0‒1.0 — texture brightness, light mode     ║
    // ║  texAspect        height/width ratio of one SVG tile            ║
    // ╚══════════════════════════════════════════════════════════════════╝
    readonly property real headerHeight:    9     // *** HEADER HEIGHT *** change this number
    readonly property real texOpacityDark:  0.07  // ← dark  mode texture intensity
    readonly property real texOpacityLight: 0.05  // ← light mode texture intensity
    readonly property real texAspect:       1.0   // ← 1.0 = square tile (locked to width)

    // ── About overlay ────────────────────────────────────────────────────────
    property bool aboutVisible: false
    onAboutVisibleChanged: {
        if (typeof navBar !== "undefined") navBar.visible = !aboutVisible
    }

    // ── Header ───────────────────────────────────────────────────────────────
    header: PageHeader {
        id: pageHeader
        // ── GREEN DIVIDER HEIGHT ──────────────────────────────────
        // *** HEADER HEIGHT — change headerHeight in TWEAKS block at top of file ***
        height: units.gu(headerHeight)

        // ── Full-width header: [title] [...+ book] ────────────────
        contents: Item {
            anchors.fill: parent

            // RIGHT: book/about icon — left of + icon
            Rectangle {
                id: headerBookBtn
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
                    onClicked: libraryPage.aboutVisible = true
                }
            }

            // RIGHT: + icon — far right
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
                    color: root.isDarkMode ? "#AAAAAA" : "#666666"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("EPUB import: showing ContentPeerPicker")
                        libraryPage._importStatus = ""
                        peerPicker.visible = true
                    }
                }
            }

            // LEFT: title block — Bearthen wordmark + My Library
            Column {
                anchors {
                    top: parent.top; topMargin: units.gu(0.4) + units.dp(5)
                    left: parent.left; leftMargin: units.gu(0.45)
                }
                spacing: -units.dp(3.0)

                // "B" light + "earthen" one step heavier (Medium) — subtle contrast
                Row {
                    spacing: 0
                    Label {
                        text: "B"
                        font.pixelSize: units.gu(2.6)
                        font.weight: Font.Medium   // Bearthen wordmark = Ubuntu Medium
                        color: "#4CAF50"
                    }
                    Label {
                        text: "earthen"
                        font.pixelSize: units.gu(2.6)
                        font.weight: Font.Medium
                        color: "#4CAF50"
                    }
                }
                // "My" = Ubuntu Light,  "Library" = Ubuntu Medium
                Row {
                    spacing: units.dp(4)
                    Label {
                        text: "My"
                        font.pixelSize: units.gu(1.7)
                        font.weight: Font.Light
                        color: "#8B5A32"
                    }
                    Label {
                        text: "Library"
                        font.pixelSize: units.gu(1.7)
                        font.weight: Font.Medium
                        color: "#8B5A32"
                    }
                }
            }
        }

        StyleHints {
            // Solid header background — same dark tone as the bottom nav bar
            // No texture bleeds through — header is a clean chrome element
            backgroundColor: root.isDarkMode ? "#111111" : "#F0F0F0"
            dividerColor: "#2C5F2E"
        }
    }

    // ── Page background ───────────────────────────────────────────────────────
    Rectangle {
        id: pageBg
        anchors.fill: parent
        color: root.isDarkMode ? "#121212" : "#FFFFFF"
        Behavior on color { ColorAnimation { duration: 250 } }
        z: 0
    }

    // ── Keith Haring-inspired SVG texture — tiled vertically, full width ──────
    // Pure B&W line art. Tiled with a Repeater inside a Column.
    // Dark mode:  black lines at low opacity make a subtle etched feel.
    // Light mode: same lines at slightly lower opacity on white.
    //
    // ▶ To adjust intensity:  change texOpacityDark / texOpacityLight in TWEAKS
    // ▶ To adjust tile ratio: change texAspect in TWEAKS
    Item {
        id: textureBg
        anchors { top: parent.top; bottom: parent.bottom
                  left: parent.left; right: parent.right }
        opacity: root.isDarkMode ? libraryPage.texOpacityDark
                                 : libraryPage.texOpacityLight
        Behavior on opacity { NumberAnimation { duration: 300 } }
        clip: true; z: 1

        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            Repeater {
                model: 25   // enough tiles to fill any phone screen
                Image {
                    width:  textureBg.width
                    height: width  // square tile — height locked to width, no vertical stretch
                    source: Qt.resolvedUrl("../../assets/textures/library-background.svg")
                    fillMode: Image.Stretch
                    smooth: true; asynchronous: true
                }
            }
        }
    }

    property var books: []

    function refresh() {
        Library.init()
        books = Library.getBooks()
        console.log("LibraryPage: refreshed, book count:", books.length)
    }

    Component.onCompleted: refresh()
    onVisibleChanged: { if (visible) refresh() }

    // ── EPUB File Browser state ──────────────────────────────────────────────
    property bool   browserVisible: false
    property string _importStatus:  ""
    property var    _activeTransfer: null

    // ── Metadata probe state ─────────────────────────────────────────────────
    property string _pendingBookId: ""   // book id waiting for probe to complete

    // ── Silent metadata + cover probe WebView ────────────────────────────────
    // meta-probe.html sends TWO kinds of title signals:
    //   "META:{title,author,language}"      — small JSON, fits in title
    //   "COVER_CHUNK:N/T:<base64slice>"     — cover in 6KB chunks, reassembled here
    // Chunking is required because Qt WebView caps document.title at ~32KB,
    // which a cover JPEG base64 easily exceeds.
    property string _coverChunks: ""    // accumulates cover base64 chunks

    WebView {
        id: metaProbeView
        visible: false
        width: 1; height: 1   // must be non-zero for WebView to render

        onTitleChanged: {
            var t = metaProbeView.title
            if (!t) return

            // ── Metadata signal ──────────────────────────────────────────────
            if (t.indexOf("META:") === 0) {
                var json = t.substring(5)
                console.log("MetaProbe META:", json.substring(0, 120))
                try {
                    var meta = JSON.parse(json)
                    var bid  = libraryPage._pendingBookId
                    if (bid && !meta.error) {
                        Library.init()
                        Library.updateBookMeta(bid,
                            meta.title    || "",
                            meta.author   || "",
                            meta.language || "")
                        console.log("MetaProbe: updated", bid,
                            "→", meta.title, "|", meta.author)
                        libraryPage.refresh()   // show title/author immediately
                    } else if (meta.error) {
                        console.log("MetaProbe error:", meta.error)
                    }
                } catch(e) {
                    console.log("MetaProbe META parse error:", e, "| raw:", json.substring(0,80))
                }
                libraryPage._coverChunks = ""   // reset cover buffer for this book

            // ── Cover chunk signal ───────────────────────────────────────────
            // Format: "COVER_CHUNK:N/T:<chars>"
            //   N = 0-based chunk index
            //   T = total number of chunks
            //   <chars> = CHUNK_SIZE slice of the full data: URI string
            //
            // The full data: URI is a PNG (lossless, always valid in Qt):
            //   "data:image/png;base64,iVBORw0KGgo..."
            //
            // Chunks are reassembled into _coverChunks, then saved on last chunk.
            // The pendingBookId is cleared only after the last chunk so that
            // a late-arriving META signal (if any) can still update the record.
            } else if (t.indexOf("COVER_CHUNK:") === 0) {
                var rest  = t.substring(12)        // "N/T:<data>"
                var slash = rest.indexOf('/')
                var colon = rest.indexOf(':')
                if (slash < 0 || colon < 0) {
                    console.log("MetaProbe: malformed COVER_CHUNK signal, skipping")
                    return
                }
                var cIdx   = parseInt(rest.substring(0, slash))
                var cTotal = parseInt(rest.substring(slash + 1, colon))
                var cSlice = rest.substring(colon + 1)

                // Log first chunk so we can verify data format in logcat
                if (cIdx === 0) {
                    console.log("MetaProbe: cover — total chunks:", cTotal,
                                "| first 40 chars:", cSlice.substring(0, 40))
                }

                libraryPage._coverChunks += cSlice

                if (cIdx === cTotal - 1) {
                    // All chunks received — save the complete data: URI
                    var cBid  = libraryPage._pendingBookId
                    var cFull = libraryPage._coverChunks

                    // Validate: must start with data: prefix
                    if (cFull.indexOf("data:") !== 0) {
                        console.log("MetaProbe: cover data malformed — missing data: prefix.",
                                    "First 60:", cFull.substring(0, 60))
                        libraryPage._coverChunks = ""
                        return
                    }

                    console.log("MetaProbe: cover reassembled —", cFull.length,
                                "chars, format:", cFull.substring(0, 22))

                    libraryPage._coverChunks = ""
                    libraryPage._pendingBookId = ""
                    metaProbeView.url = "about:blank"

                    if (cBid && cFull.length > 50) {
                        Library.init()
                        Library.updateCoverDataUrl(cBid, cFull)
                        console.log("MetaProbe: cover saved for", cBid)
                        libraryPage.refresh()
                    }
                } else {
                    // Intermediate chunk — log progress every 5 chunks
                    if (cIdx % 5 === 0) {
                        console.log("MetaProbe: cover chunk", cIdx + 1, "/", cTotal,
                                    "accumulated:", libraryPage._coverChunks.length, "chars")
                    }
                }
            }
        }

        onLoadingChanged: {
            if (loadRequest.status === WebView.LoadFailedStatus)
                console.log("MetaProbe: load failed:", loadRequest.errorString)
        }
    }

    // ── Content Hub EPUB import ───────────────────────────────────────────────
    // ContentPeerPicker shows the SYSTEM UI (Files app chooser).
    // ContentPeer.request() fires silently with no visible picker — avoid it.
    // content_exchange in bearthen.apparmor authorises this.

    ContentPeerPicker {
        id: peerPicker
        visible: false
        // ContentType.Documents shows Files app; Unknown shows all sources
        contentType: ContentType.Documents
        handler:     ContentHandler.Source
        anchors.fill: parent
        z: 210

        onPeerSelected: {
            console.log("EPUB picker: peer selected:", peer)
            visible = false
            var transfer = peer.request()
            libraryPage._activeTransfer = transfer
            console.log("EPUB transfer created:", transfer, "state:", transfer ? transfer.state : "null")
            if (transfer) {
                transfer.stateChanged.connect(function() {
                    var st = transfer.state
                    console.log("EPUB stateChanged:", st,
                        "Charged=", ContentTransfer.Charged,
                        "Aborted=", ContentTransfer.Aborted)
                    if (st === ContentTransfer.Charged) {
                        var items = transfer.items
                        console.log("EPUB charged, items:", items ? items.length : "null")
                        if (items && items.length > 0) {
                            var url = items[0].url.toString()
                            var fname = url.split("/").pop()
                            // URL-decode filename (spaces become %20 etc.)
                            try { fname = decodeURIComponent(fname) } catch(e) {}
                            console.log("EPUB file url:", url, "filename:", fname)
                            if (fname.toLowerCase().slice(-5) === ".epub") {
                                // ── PERSIST the file before ContentHub cleans it up ──
                                // ContentHub stages uploads in a TEMPORARY cache dir:
                                //   .cache/bearthen.russs95/HubIncoming/<N>/<file>
                                // We MUST move it to permanent storage NOW, while the
                                // ContentTransfer is still Charged. After this state
                                // the HubIncoming slot can be recycled at any time.
                                //
                                // ContentItem.move(destDir) relocates the file to the
                                // app's writable data dir and returns true on success.
                                // On failure we fall back to the original URL (will
                                // work this session, but may break after cache sweep).
                                var booksDir = "/home/phablet/.local/share/bearthen.russs95/books/"
                                var moved = false
                                try {
                                    moved = items[0].move(booksDir)
                                } catch(moveErr) {
                                    console.log("EPUB move() threw:", moveErr)
                                }
                                var finalUrl = moved
                                    ? ("file://" + booksDir + fname)
                                    : url
                                console.log("EPUB move:", moved ? "OK → " + finalUrl : "FAILED, using staging: " + url)
                                libraryPage._importEpub(finalUrl, fname)
                            } else {
                                libraryPage._importStatus = "✗ Not an EPUB: " + fname
                            }
                        } else {
                            libraryPage._importStatus = "✗ No file received"
                        }
                    } else if (st === ContentTransfer.Aborted) {
                        libraryPage._importStatus = ""
                    }
                })
            }
        }

        onCancelPressed: {
            console.log("EPUB picker: cancelled by user")
            visible = false
            libraryPage._importStatus = ""
        }
    }

    ContentTransferHint {
        anchors.fill: parent
        activeTransfer: libraryPage._activeTransfer
        z: 209
    }

    // Status toast shown after import attempt
    Rectangle {
        id: importToast
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: units.gu(6)
        color: root.isDarkMode ? "#1A1A1A" : "#F0F0F0"
        visible: libraryPage._importStatus !== ""
        z: 202
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: units.dp(1)
            color: libraryPage._importStatus.indexOf("✓") >= 0 ? "#4CAF50"
                 : libraryPage._importStatus.indexOf("✗") >= 0 ? "#CC4444" : "#555555"
        }
        Label {
            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: units.gu(2) }
            text: libraryPage._importStatus; fontSize: "small"
            color: libraryPage._importStatus.indexOf("✓") >= 0 ? "#4CAF50"
                 : libraryPage._importStatus.indexOf("✗") >= 0 ? "#CC4444" : "#AAAAAA"
        }
    }

    // ── Import EPUB function ──────────────────────────────────────────────────
    function _importEpub(fileUrl, fileName) {
        libraryPage._importStatus = "Importing…"
        console.log("_importEpub: url=" + fileUrl + " name=" + fileName)
        // Strip file:// prefix for the raw path stored in the DB.
        // NOTE: filePath is the moved path under .local/share/.../books/
        // (or the HubIncoming staging path if move() failed — see caller).
        var filePath = fileUrl.toString().replace(/^file:\/\//, "")

        // Build a clean title from the filename
        var rawName = fileName
        if (rawName.toLowerCase().slice(-5) === ".epub")
            rawName = rawName.slice(0, -5)
        var title = rawName.replace(/[_-]/g, " ").replace(/\s+/g, " ").trim()
        // Title-case: capitalise first letter of each word
        var words = title.split(" ")
        var titleCased = []
        for (var i = 0; i < words.length; i++) {
            var w = words[i]
            if (w.length > 0)
                titleCased.push(w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
        }
        title = titleCased.join(" ") || fileName

        // ── Stable book ID ──────────────────────────────────────────────
        // Hash the bare FILENAME (not the full path) so that re-importing
        // the same EPUB always yields the same book ID, regardless of which
        // HubIncoming/<N>/ slot ContentHub originally staged it in, and
        // regardless of whether move() succeeded or not.
        var bareFilename = fileName   // already decoded by caller
        var id = "local_" + Math.abs(_simpleHash(bareFilename))

        if (Library.hasBook(id)) {
            libraryPage._importStatus = "✓ Already in your library: " + title
            var clearTimer = Qt.createQmlObject('import QtQuick 2.12; Timer { interval: 2500; repeat: false }', libraryPage)
            clearTimer.triggered.connect(function() {
                libraryPage.browserVisible = false
                libraryPage._importStatus = ""
            })
            clearTimer.start()
            return
        }

        var book = {
            id:             id,
            title:          title,
            author_display: "Unknown Author",
            file_path:      fileUrl.toString(),
            source:         "local",
            source_id:      filePath,
            category:       "other",
            language:       "en"
        }

        Library.init()
        var ok = Library.addBook(book)
        if (ok) {
            libraryPage._importStatus = "✓ Added: " + title
            refresh()

            // ── Launch silent metadata + cover probe ──────────────
            // meta-probe.html uses epub.js to read OPF and extract the
            // cover thumbnail. Result comes back via onTitleChanged above.
            libraryPage._pendingBookId = id
            var here     = Qt.resolvedUrl(".").toString()
            var appRoot  = here.replace(/qml\/pages\/$/, "")
            var probeUrl = appRoot + "assets/reader/meta-probe.html"
                         + "?url=" + encodeURIComponent(fileUrl.toString())
            console.log("MetaProbe: launching →", probeUrl)
            metaProbeView.url = probeUrl

            var doneTimer = Qt.createQmlObject('import QtQuick 2.12; Timer { interval: 2000; repeat: false }', libraryPage)
            doneTimer.triggered.connect(function() {
                libraryPage.browserVisible = false
                libraryPage._importStatus = ""
            })
            doneTimer.start()
        } else {
            libraryPage._importStatus = "✗ Could not import file"
        }
    }

    // Simple djb2-style hash for stable book IDs from file paths
    function _simpleHash(str) {
        var hash = 5381
        for (var i = 0; i < str.length; i++) {
            hash = ((hash << 5) + hash) + str.charCodeAt(i)
            hash = hash & hash  // convert to 32-bit int
        }
        return hash
    }

    // ── Empty state ───────────────────────────────────────────────────────────
    Column {
        anchors.centerIn: parent
        spacing: units.gu(2.5)
        visible: libraryPage.books.length === 0

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(10); height: units.gu(10)
            name: "stock_ebook"; color: "#2C5F2E"
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 1500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 1500; easing.type: Easing.InOutSine }
            }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.t("Your library is empty")
            fontSize: "large"
            color: root.isDarkMode ? "#FFFFFF" : "#212121"
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(32)
            text: "Discover free books and tap\n\"Add to Library\" to get started."
            fontSize: "small"; color: "#888888"
            horizontalAlignment: Text.AlignHCenter; lineHeight: 1.4
        }
        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.t("Browse Free Books")
            color: "#2C5F2E"
            onClicked: {
                root.currentPage = 1
                pageStack.clear()
                pageStack.push(discoverPage)
            }
        }
    }

    // ── Book grid ─────────────────────────────────────────────────────────────
    GridView {
        id: bookGrid
        anchors {
            top: pageHeader.bottom
            left: parent.left; right: parent.right; bottom: parent.bottom
            margins: units.gu(1.5)
        }
        visible: libraryPage.books.length > 0
        clip: true
        cellWidth: (width - units.gu(1)) / 2
        cellHeight: units.gu(25)
        model: libraryPage.books

        delegate: Item {
            width: bookGrid.cellWidth
            height: bookGrid.cellHeight

            Rectangle {
                anchors { fill: parent; margins: units.gu(0.5) }
                // Card background: slightly lighter than page
                // Solid background — opaque so texture shows behind cards, not through
                color: root.isDarkMode ? "#222222" : "#EEEEEE"
                radius: units.dp(8)
                Behavior on color { ColorAnimation { duration: 250 } }

                Column {
                    anchors { fill: parent; margins: units.gu(0.7) }
                    spacing: units.gu(0.5)

                    // ── Cover frame ───────────────────────────────────────────
                    Rectangle {
                        width: parent.width
                        height: units.gu(15.5)
                        // Solid cover placeholder — opaque
                        color: root.isDarkMode ? "#2E2E2E" : "#E0E0E0"
                        radius: units.dp(5)
                        clip: true
                        Behavior on color { ColorAnimation { duration: 250 } }

                        // Watermark book icon — shows when no cover
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(5); height: units.gu(5)
                            name: "stock_ebook"
                            color: root.isDarkMode ? "#444444" : "#CCCCCC"
                            opacity: 0.8
                        }

                        Image {
                            anchors.fill: parent
                            source: {
                                if (modelData.cover_local && modelData.cover_local !== "")
                                    return "file://" + modelData.cover_local
                                if (modelData.cover_url && modelData.cover_url !== "")
                                    return modelData.cover_url
                                if (modelData.cover && modelData.cover !== "")
                                    return modelData.cover
                                return ""
                            }
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
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
                        text: modelData.author_display || modelData.author || ""
                        fontSize: "x-small"; color: "#4CAF50"; elide: Text.ElideRight
                    }

                    // ── Progress bar — brown track, green fill ─────────────────
                    Rectangle {
                        visible: modelData.read_percent > 0
                        width: parent.width
                        height: units.dp(4)
                        radius: height / 2
                        color: root.isDarkMode ? "#0A2A0A" : "#C8DFC8"
                        Behavior on color { ColorAnimation { duration: 250 } }
                        Rectangle {
                            width: parent.width * (modelData.read_percent / 100)
                            height: parent.height; radius: parent.radius
                            // Gradient: earthen brown → forest green (brown=start, green=end)
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "#8B5A32" }  // brown ←
                                GradientStop { position: 1.0; color: "#2C5F2E" }  // → green
                            }
                        }
                    }

                    // ── Progress label ────────────────────────────────────────
                    Label {
                        width: parent.width
                        text: modelData.is_finished
                              ? "Finished ✓"
                              : (modelData.read_percent > 0
                                 ? (modelData.read_percent + "% read")
                                 : "Not started")
                        fontSize: "x-small"; color: "#666666"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        libBookDetailPage.book            = modelData
                        libBookDetailPage.bookDescription = ""
                        pageStack.push(libBookDetailPage)
                    }
                }
            }
        }
    }

    // ── About screen — centered in viewport, no nav bar ─────────────────────
    Rectangle {
        id: aboutScreen
        anchors.fill: parent
        color: root.isDarkMode ? "#0D0D0D" : "#F5F5F5"
        visible: libraryPage.aboutVisible
        opacity: libraryPage.aboutVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 220 } }
        z: 100

        MouseArea { anchors.fill: parent; onClicked: {} }

        // SVG texture — same tile as main library, slightly different opacity
        Item {
            anchors.fill: parent
            opacity: root.isDarkMode ? libraryPage.texOpacityDark * 1.5
                                     : libraryPage.texOpacityLight * 1.5
            Behavior on opacity { NumberAnimation { duration: 300 } }
            clip: true; z: 0
            Column {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                Repeater {
                    model: 25
                    Image {
                        width:  parent ? parent.width : Screen.width
                        height: width  // square tile — height locked to width, no vertical stretch
                        source: Qt.resolvedUrl("../../assets/textures/library-background.svg")
                        fillMode: Image.Stretch
                        smooth: true; asynchronous: true
                    }
                }
            }
        }

        // Close button — top right ONLY (no nav bar)
        AbstractButton {
            id: aboutCloseBtn
            anchors { top: parent.top; right: parent.right
                      topMargin: units.gu(1.5); rightMargin: units.gu(1.5) }
            width: units.gu(5); height: units.gu(5)
            Icon { anchors.centerIn: parent; width: units.gu(2.8); height: units.gu(2.8)
                   name: "close"; color: root.isDarkMode ? "#555555" : "#AAAAAA" }
            onClicked: libraryPage.aboutVisible = false
        }

        // Content — vertically centred in the full screen
        Column {
            anchors.centerIn: parent
            width: parent.width - units.gu(6)
            spacing: units.gu(2.2)

            // Brown book icon
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: units.gu(10); height: units.gu(10)
                name: "stock_ebook"
                color: "#8B5A32"
            }

            // Wordmark: B (Normal) + earthen (Medium) — subtle one-step difference
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0
                Label { text: "B"; font.pixelSize: units.gu(4.5)
                        font.weight: Font.Light; color: "#4CAF50" }
                Label { text: "earthen"; font.pixelSize: units.gu(4.5)
                        font.weight: Font.Medium; color: "#4CAF50" }
            }

            // Tagline — dark green in both modes
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                text: "Read Books the Earthen Way"
                font.pixelSize: units.gu(2); font.weight: Font.Light
                color: root.isDarkMode ? "#2C7A30" : "#1E5C22"
                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
            }

            // Divider
            Rectangle {
                width: parent.width; height: units.dp(1)
                color: root.isDarkMode ? "#1E1E1E" : "#E0E0E0"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Earthen Ethics text — centred
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                text: "Bearthen is inspired and its design guided by the ecological ethos of the Igorot people of Northern Luzon and the theory of Earthen Ethics developed by Banayan Angway and Russell Maier. Support the Bearthen project by purchasing the EPUB edition of their foundational work."
                font.pixelSize: units.gu(1.75); font.weight: Font.Light
                color: root.isDarkMode ? "#CCCCCC" : "#444444"
                wrapMode: Text.WordWrap; lineHeight: 1.55
                horizontalAlignment: Text.AlignHCenter
            }

            // Support button — forest green
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.7; height: units.gu(6)
                radius: units.dp(10)
                color: "#2C5F2E"
                border.color: "#1E4520"
                border.width: units.dp(1)
                Row {
                    anchors.centerIn: parent; spacing: units.gu(1)
                    Icon { width: units.gu(2.6); height: units.gu(2.6)
                           name: "thumb-up"; color: "#FFFFFF"
                           anchors.verticalCenter: parent.verticalCenter }
                    Label { text: "Support"
                            font.pixelSize: units.gu(2.0); font.weight: Font.Medium
                            color: "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: libraryPage.shopVisible = true
                }
            }

            // Version + lab pill + github — below support button
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Alpha version 0.0.2"
                font.pixelSize: units.gu(1.7)
                color: root.isDarkMode ? "#444444" : "#BBBBBB"
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: labelsText.width + units.gu(3); height: units.gu(3.2)
                radius: height / 2; color: "#3A1A08"
                border.color: "#5A2A10"; border.width: 1
                Label { id: labelsText; anchors.centerIn: parent
                        text: "Earthen Labs"; font.pixelSize: units.gu(1.6)
                        font.weight: Font.Medium; color: "#C8A070" }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "github.com/russs95/bearthen"
                font.pixelSize: units.gu(1.6); color: "#8B5A32"
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // ── Shop / Support overlay ────────────────────────────────────────────────
    property bool shopVisible: false

    Rectangle {
        id: shopScreen
        anchors.fill: parent
        color: root.isDarkMode ? "#0D0D0D" : "#F5F5F5"
        visible: libraryPage.shopVisible
        opacity: libraryPage.shopVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 220 } }
        z: 110

        MouseArea { anchors.fill: parent; onClicked: {} }

        // ── Shop Header ──────────────────────────────────────────────────────
        Rectangle {
            id: shopHeader
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: units.gu(8)
            color: root.isDarkMode ? "#111111" : "#F0F0F0"
            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: units.dp(1); color: "#2C5F2E"
            }

            // Back button
            AbstractButton {
                anchors { left: parent.left; leftMargin: units.gu(1.2)
                          verticalCenter: parent.verticalCenter }
                width: units.gu(5); height: units.gu(5)
                Icon { anchors.centerIn: parent; width: units.gu(2.5); height: units.gu(2.5)
                       name: "back"; color: root.isDarkMode ? "#AAAAAA" : "#666666" }
                onClicked: libraryPage.shopVisible = false
            }

            // Title
            Column {
                anchors { verticalCenter: parent.verticalCenter; horizontalCenter: parent.horizontalCenter }
                spacing: units.dp(2)
                Label { anchors.horizontalCenter: parent.horizontalCenter
                        text: "Earthen Ethics"; font.pixelSize: units.gu(2.4)
                        font.weight: Font.Light; color: "#4CAF50" }
                Label { anchors.horizontalCenter: parent.horizontalCenter
                        text: "Tractatus Ayyew"; font.pixelSize: units.gu(1.6)
                        font.weight: Font.Light
                        color: root.isDarkMode ? "#666666" : "#999999" }
            }
        }

        // ── Shop listings ────────────────────────────────────────────────────
        Flickable {
            anchors { top: shopHeader.bottom; left: parent.left
                      right: parent.right; bottom: parent.bottom }
            contentHeight: shopCol.height + units.gu(4)
            clip: true; flickableDirection: Flickable.VerticalFlick

            Column {
                id: shopCol
                width: parent.width
                spacing: 0

                // Helper repeated pattern: each listing is a Row card
                // Product 1 — EPUB (English)
                ShopItem {
                    coverPath: Qt.resolvedUrl("../../assets/tractatus/2025-buy-epub-500px.webp")
                    title: "Earthen Ethics"
                    subtitle: "Tractatus Ayyew · Book One"
                    description: "EPUB eBook. 2nd Edition, 2025. Ideal for Bearthen, Kindles, iPhones, eReaders & Android viewers."
                    badgeColor: "#2C5F2E"
                    price: "Buy $10"
                    purchaseUrl: "https://buy.stripe.com/28og1Z9OS3f7eqc6op"
                }

                // Product 2 — PDF
                ShopItem {
                    coverPath: Qt.resolvedUrl("../../assets/tractatus/2025-buy-pdf-500px.webp")
                    title: "Earthen Ethics"
                    subtitle: "Tractatus Ayyew · Book One"
                    description: "PDF. 2nd Edition, 2025. Print or screen ready for full page reading. Printable on A4 sheets."
                    badgeColor: "#555555"
                    price: "Buy $10"
                    purchaseUrl: "https://buy.stripe.com/9AQ2b90eicPH3LyfZ0"
                }

                // Product 3 — Retroactive Gratitude
                ShopItem {
                    coverPath: Qt.resolvedUrl("../../assets/tractatus/2025-buy-gratitude-500px.webp")
                    title: "Retroactive Gratitude"
                    subtitle: "Earthen Ethics · Book One"
                    description: "Already read the free version? Make a retroactive purchase to support the authors."
                    badgeColor: "#3A7A3A"
                    price: "± $10"
                    purchaseUrl: "https://buy.stripe.com/4gw9DB7GK8zr3LyeV0"
                }

                // Product 4 — French edition (coming soon)
                ShopItem {
                    coverPath: Qt.resolvedUrl("../../assets/tractatus/cover-300px-FR.webp")
                    title: "D'une éthique terrestre"
                    subtitle: "Tractatus Ayyew · Édition Française"
                    description: "EPUB. Édition Française. L'éthique de la terre des peuples Igorot des Philippines."
                    badgeColor: "#555555"
                    price: "Acheter $10"
                    purchaseUrl: "https://buy.stripe.com/aEU7vt3qu9Dveqc5kn"
                    comingSoon: true
                }

                Item { width: 1; height: units.gu(3) }
            }
        }
    }

    // ── ShopItem component ────────────────────────────────────────────────────
    component ShopItem: Rectangle {
        property url    coverPath
        property string title:       ""
        property string subtitle:    ""
        property string description: ""
        property color  badgeColor:  "#2C5F2E"
        property bool   comingSoon:  false
        property string price:       ""
        property string purchaseUrl: ""

        width: parent ? parent.width : 0
        height: cardRow.height + units.gu(3)
        color: "transparent"

        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: units.dp(1); color: root.isDarkMode ? "#1A1A1A" : "#E8E8E8"
        }

        Row {
            id: cardRow
            anchors { left: parent.left; right: parent.right
                      top: parent.top; topMargin: units.gu(1.5)
                      leftMargin: units.gu(2); rightMargin: units.gu(2) }
            spacing: units.gu(1.8)

            // Cover image — fills to top, no background box
            Rectangle {
                width: units.gu(12); height: units.gu(17)
                radius: units.dp(6); clip: true
                color: "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    source: coverPath
                    fillMode: Image.PreserveAspectFill
                    verticalAlignment: Image.Top
                    asynchronous: true
                    smooth: true
                }
            }

            // Text + button
            Column {
                width: parent.width - units.gu(12) - units.gu(1.8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: units.gu(0.7)

                Label {
                    width: parent.width; text: title
                    font.pixelSize: units.gu(2.1); font.weight: Font.Medium
                    color: root.isDarkMode ? "#FFFFFF" : "#111111"
                    wrapMode: Text.WordWrap
                }
                Label {
                    width: parent.width; text: subtitle
                    font.pixelSize: units.gu(1.6); font.weight: Font.Light
                    color: "#4CAF50"
                }
                Label {
                    width: parent.width; text: description
                    font.pixelSize: units.gu(1.55); font.weight: Font.Light
                    color: root.isDarkMode ? "#888888" : "#666666"
                    wrapMode: Text.WordWrap; lineHeight: 1.4
                }
                Item { width: 1; height: units.gu(0.5) }
                Rectangle {
                    width: parent.width; height: units.gu(4.5)
                    radius: units.dp(8)
                    color: comingSoon ? "#333333" : badgeColor
                    opacity: comingSoon ? 0.6 : 1.0
                    Label {
                        anchors.centerIn: parent
                        text: comingSoon ? "Coming Soon" : price
                        font.pixelSize: units.gu(1.8); font.weight: Font.Medium
                        color: comingSoon ? "#777777" : "#FFFFFF"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!comingSoon) Qt.openUrlExternally(purchaseUrl)
                        }
                    }
                }
            }
        }
    }
}