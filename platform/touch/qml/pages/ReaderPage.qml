import QtQuick 2.12
import Ubuntu.Components 1.3
import Morph.Web 0.1
import "../js/Library.js" as Library

Page {
    id: readerPage
    head.visible: false

    property var  book:             null
    property bool _barsVisible:     false  // hidden by default; shown on bottom tap
    property bool _transitionCover: true   // opaque until fully ready; kills flash
    property bool _bookReady:       false  // true when HTML fires HIDE_NAV:1
    property bool _phasesDone:      false  // true after 400ms + 500ms splash phases complete
    property bool _showCover:       false  // true after first 400ms (cover image phase)
    property string _liveCfi:       ""     // last CFI received via POS signal; written to DB on exit
    property real   _livePct:       0      // matching percent for _liveCfi
    property int    _streamerPort:  0      // set when r2-streamer is ready
    property string _streamerManifestUrl: "" // full manifest URL from the ready signal
    property string _pendingStreamerEpub: "" // queued when openBook() fires before streamerLoader is ready
    // Step 7 debug default: force the Readium path for local EPUBs whenever the
    // streamer is available, so it can be exercised on every book during
    // development. Replace with `book.epub_version >= 3.0` once epub_version is
    // tracked in books_tb (see roadmap Stage 6). Remote (Gutenberg) books always
    // use epub.js regardless of this flag — the streamer only serves local files
    // today. Falls back to epub.js automatically if the streamer errors.
    property bool   _useReadium:    true

    // Hide transition cover only when BOTH the book is rendered AND splash phases done.
    function _checkHideCover() {
        if (_bookReady && _phasesDone) _transitionCover = false
    }

    // Push the current book's bookmark list into the WebView JS context.
    function _pushBookmarks() {
        if (!book) return
        Library.init()
        var list = Library.getBookmarks(book.id)
        webView.runJavaScript("readerBookmarks.load(" + JSON.stringify(list) + ")")
    }

    // Push the current book's highlight list into the WebView JS context.
    function _pushHighlights() {
        if (!book) return
        Library.init()
        var list = Library.getHighlights(book.id)
        webView.runJavaScript("readerHighlights.load(" + JSON.stringify(list) + ")")
    }

    function openBook(bookObj) {
        console.log("ReaderPage.openBook:", bookObj ? bookObj.id : "null")
        root.setReaderFullscreen(true)   // idempotent; openReader() already set these
        _transitionCover    = true
        _bookReady          = false
        _phasesDone         = false
        _showCover          = false
        _streamerPort       = 0
        _streamerManifestUrl = ""
        _pendingStreamerEpub = ""
        // Seed live-CFI from the book's stored position so onVisibleChanged has
        // a valid value even if no POS signal fires (e.g. user opens then immediately exits).
        _liveCfi = bookObj ? (bookObj.read_position || "") : ""
        _livePct = bookObj ? (bookObj.read_percent  || 0)  : 0
        webView.url         = "about:blank"
        book                = bookObj
        coverPhase1Timer.restart()  // start the cover splash sequence
        // Local EPUB + Readium enabled: launch r2-streamer and wait for its
        // `ready` signal (streamerLoader.onLoaded below) to load the Readium
        // harness — no urlLoadTimer/epub.js in this path unless the streamer
        // errors, in which case the error handler falls back to epub.js.
        // Remote (Gutenberg) books and the epub.js-only fallback go through
        // urlLoadTimer as before — the streamer only serves local files today.
        var useReadiumForThisBook = _useReadium && bookObj && bookObj.file_path
        if (bookObj && bookObj.file_path) {
            if (streamerLoader.status === Loader.Ready && streamerLoader.item) {
                streamerLoader.item.start(bookObj.file_path)
            } else {
                // Loader not ready yet — activate it and queue the epub path.
                // streamerLoader.onLoaded will call start() once the component is created.
                _pendingStreamerEpub = bookObj.file_path
                if (streamerLoader.status === Loader.Null)
                    streamerLoader.active = true
            }
        }
        if (!useReadiumForThisBook) {
            // Defer URL construction — Qt Quick defers layout recalculation, so
            // webView.height is stale immediately after _readerMode/FullScreen change.
            // 120ms gives layout + window manager time to settle before we measure.
            urlLoadTimer.restart()
        }
        // else: wait for streamerLoader's ready/error signal (see below) —
        // by the time it fires (~1s+), layout has long since settled, so no
        // timer is needed before reading webView.width/height for the URL.
    }

    // Build and load the reader URL. Called by urlLoadTimer, not onBookChanged,
    // so that webView.height reflects the post-layout (fullscreen) dimensions.
    function _loadReaderUrl() {
        if (!book) return
        var b   = book
        var src = ""
        if (b.file_path && b.file_path !== "") {
            // Guard against double file:// prefix
            src = (b.file_path.indexOf("file://") === 0)
                  ? b.file_path
                  : "file://" + b.file_path
        } else {
            src = b.epub_url || ""
        }
        if (!src) { errorRect.visible = true; return }

        var here    = Qt.resolvedUrl(".").toString()
        var appRoot = here.replace(/qml\/pages\/$/, "")
        var htmlUrl = appRoot + "assets/reader/reader.html"
        var pct = b.read_percent  || 0
        var cfi = b.read_position || ""

        var vw   = Math.round(webView.width)
        var vh   = Math.round(webView.height)
        console.log("ReaderPage: passing viewport", vw + "x" + vh,
                    "(webView.height=" + webView.height + ")")

        var url = htmlUrl
                + "?url="        + encodeURIComponent(src)
                + "&title="      + encodeURIComponent(b.title || "")
                + "&percent="    + pct
                + "&vw="         + vw
                + "&vh="         + vh
        if (cfi)                  url += "&cfi="        + encodeURIComponent(cfi)
        if (b.reader_fontsize)    url += "&fontsize="   + b.reader_fontsize
        if (b.reader_fontfamily)  url += "&fontfamily=" + b.reader_fontfamily
        if (b.reader_theme)       url += "&theme="      + b.reader_theme
        if (b.reader_spacing)     url += "&spacing="    + b.reader_spacing
        if (b.reader_margins)     url += "&margins="    + b.reader_margins

        console.log("ReaderPage: loading", url)
        webView.url = url
    }

    // Build and load the Readium (D2Reader) harness URL. Called once the
    // r2-streamer signals `ready` with a manifest URL (see streamerLoader
    // below) — by then layout has long settled, so webView.width/height are
    // safe to read directly without a timer.
    //
    // Loaded over http://127.0.0.1:<staticPort>/, NOT file:// — Chromium
    // hard-blocks fetch() from a file:// origin to any other origin (it
    // isn't in the handful of schemes CORS permits as a *source*, regardless
    // of the target's Access-Control-Allow-Origin header). D2Reader fetches
    // the manifest via fetch(), so a file://-loaded harness gets "blocked by
    // CORS policy" and never renders. reader_launcher.py's static server
    // (assets/ served over http://) exists solely to work around this.
    function _loadReadiumUrl(manifestUrl, staticPort) {
        if (!book) return
        var b  = book
        var vw = Math.round(webView.width)
        var vh = Math.round(webView.height)
        console.log("ReaderPage: loading Readium", vw + "x" + vh, "manifest:", manifestUrl)

        var htmlUrl = "http://127.0.0.1:" + staticPort + "/readium/reader-readium.html"
        var pct     = b.read_percent || 0

        var url = htmlUrl
                + "?manifest="   + encodeURIComponent(manifestUrl)
                + "&title="      + encodeURIComponent(b.title || "")
                + "&percent="    + pct
                + "&vw="         + vw
                + "&vh="         + vh
        if (b.reader_fontsize)    url += "&fontsize="   + b.reader_fontsize
        if (b.reader_fontfamily)  url += "&fontfamily=" + b.reader_fontfamily
        if (b.reader_theme)       url += "&theme="      + b.reader_theme
        if (b.reader_spacing)     url += "&spacing="    + b.reader_spacing
        if (b.reader_margins)     url += "&margins="    + b.reader_margins

        console.log("ReaderPage: loading", url)
        webView.url = url
    }

    // Restore nav bar whenever this page becomes invisible (user goes back).
    // Also flush any pending position save so the last page is always recorded.
    onVisibleChanged: {
        if (!visible) {
            // Synchronous DB save using the last CFI received via POS signal.
            // This runs before setReaderFullscreen() which may suspend the WebView JS
            // context and make subsequent runJavaScript calls unreliable.
            if (book && _liveCfi !== "") {
                Library.init()
                Library.updatePosition(book.id, _liveCfi, _livePct)
                book.read_position = _liveCfi
            }
            root.setReaderFullscreen(false)
            // Belt-and-suspenders: also ask JS for the exact current-page CFI in case
            // the user turned a page within the 1.5s debounce window and _liveCfi lags.
            webView.runJavaScript("if(typeof flushPosition==='function')flushPosition()")
            // Stop r2-streamer when the reader is closed.
            // Stage 7 will handle suspend/resume lifecycle; for now stop on every close.
            if (streamerLoader.item) streamerLoader.item.stop()
        }
    }

    // Re-assert head.visible=false when app returns to foreground.
    // The Ubuntu.Components PageStack resets head config on app resume,
    // making the grey header bar reappear. A short timer (50ms) lets the
    // framework finish its resume cycle before we override it back.
    Connections {
        target: Qt.application
        onActiveChanged: {
            if (!Qt.application.active && readerPage.visible) {
                // App losing focus — sync save first, then JS flush for latest page.
                if (readerPage.book && readerPage._liveCfi !== "") {
                    Library.init()
                    Library.updatePosition(readerPage.book.id, readerPage._liveCfi, readerPage._livePct)
                }
                webView.runJavaScript("if(typeof flushPosition==='function')flushPosition()")
            }
            if (Qt.application.active && readerPage.visible)
                headHideTimer.restart()
        }
    }
    Timer {
        id: headHideTimer
        interval: 50
        repeat: false
        onTriggered: readerPage.head.visible = false
    }

    // URL loading is deferred to urlLoadTimer — do not build URL here.
    // Reading webView.height synchronously in onBookChanged gives stale values
    // because Qt Quick defers layout recalculation after _readerMode changes.
    onBookChanged: { /* intentionally empty — urlLoadTimer handles URL construction */ }

    // ── r2-streamer launcher (Stage 4) ───────────────────────────────────────
    // Activated on first book open (not eagerly) to avoid racing with openBook().
    // Isolated via Loader so that missing io.thp.pyotherside degrades to epub.js only.
    Loader {
        id: streamerLoader
        active: false
        source: "../components/platform/StreamerLauncher.qml"
        onStatusChanged: {
            console.log("StreamerLauncher Loader status:", status,
                        status === Loader.Null    ? "(Null)"    :
                        status === Loader.Ready   ? "(Ready)"   :
                        status === Loader.Loading ? "(Loading)" : "(Error)")
            if (status === Loader.Error) {
                console.log("StreamerLauncher: failed to load — epub.js only mode")
                // The Loader itself failed (e.g. io.thp.pyotherside unavailable) —
                // item.ready/item.error will never fire, so fall back here too,
                // or a Readium-eligible book would be stuck on a blank screen.
                if (readerPage._useReadium && readerPage.book && readerPage.visible
                        && webView.url.toString() === "about:blank") {
                    console.log("ReaderPage: falling back to epub.js")
                    readerPage._loadReaderUrl()
                }
            }
        }
        onLoaded: {
            console.log("StreamerLauncher: component loaded OK")
            item.ready.connect(function(port, manifestUrl, staticPort) {
                readerPage._streamerPort = port
                readerPage._streamerManifestUrl = manifestUrl
                console.log("ReaderPage: r2-streamer ready on port", port,
                            "manifest:", manifestUrl, "static server port:", staticPort)
                // Only act if this signal belongs to the book still open (guards
                // against a late signal arriving after the user navigated away
                // or opened a different book) and we haven't already loaded
                // something (e.g. an error already triggered the epub.js fallback).
                if (readerPage._useReadium && readerPage.book && readerPage.visible
                        && webView.url.toString() === "about:blank") {
                    readerPage._loadReadiumUrl(manifestUrl, staticPort)
                }
            })
            item.error.connect(function(msg) {
                console.log("ReaderPage: r2-streamer error:", msg)
                // Streamer failed — fall back to epub.js so the user isn't
                // left on a blank screen. Only if nothing has loaded yet.
                if (readerPage._useReadium && readerPage.book && readerPage.visible
                        && webView.url.toString() === "about:blank") {
                    console.log("ReaderPage: falling back to epub.js")
                    readerPage._loadReaderUrl()
                }
            })
            // Dispatch epub path that arrived before the Loader was ready
            if (readerPage._pendingStreamerEpub !== "") {
                item.start(readerPage._pendingStreamerEpub)
                readerPage._pendingStreamerEpub = ""
            }
        }
    }

    // Solid black background — prevents white flash while WebView loads
    Rectangle {
        anchors.fill: parent
        color: "#111111"
        z: -1
    }

    WebView {
        id: webView
        anchors.fill: parent

        onTitleChanged: {
            var t = webView.title
            if (!t) return

            // ── Position report (exact CFI + percentage) ─────────
            if (t.indexOf("POS:") === 0) {
                try {
                    var pos = JSON.parse(t.substring(4))
                    if (readerPage.book) {
                        Library.init()
                        Library.updatePosition(readerPage.book.id,
                                               pos.cfi || "", pos.pct || 0)
                        // Keep in-memory book and live-CFI tracker in sync.
                        readerPage.book.read_position = pos.cfi || ""
                        readerPage.book.read_percent  = pos.pct  || 0
                        if (pos.cfi) {
                            readerPage._liveCfi = pos.cfi
                            readerPage._livePct  = pos.pct || 0
                        }
                        console.log("Reader: saved", (pos.pct || 0) + "% / book:",
                                    readerPage.book.id, "/ cfi:", (pos.cfi || "").substring(0, 60))
                    }
                } catch(e) {
                    console.log("Reader: POS parse error", e)
                }
                webView.runJavaScript("document.title=''")

            // ── Preferences report ──────────────────────────────
            } else if (t.indexOf("PREFS:") === 0) {
                var json = t.substring(6)
                try {
                    var p = JSON.parse(json)
                    if (readerPage.book) {
                        Library.init()
                        Library.saveReaderPrefs(readerPage.book.id, p)
                        console.log("Reader: saved prefs for", readerPage.book.id)
                    }
                } catch(e) {
                    console.log("Reader: prefs parse error", e)
                }
                webView.runJavaScript("document.title=''")

            // ── Bars state ──────────────────────────────────────
            } else if (t.indexOf("BARS:") === 0) {
                readerPage._barsVisible = (t.charAt(5) === '1')
                webView.runJavaScript("document.title=''")

            // ── Bookmark: save current position ──────────────────
            } else if (t.indexOf("BOOKMARK_SAVE:") === 0) {
                try {
                    var bm = JSON.parse(t.substring(14))
                    if (readerPage.book) {
                        Library.init()
                        var bmColor = Library.nextBookmarkColor(readerPage.book.id)
                        Library.addBookmark(readerPage.book.id, bm.cfi || "", bm.pct || 0, bm.label || "", bmColor)
                        _pushBookmarks()
                        bookmarkFlash.start()
                    }
                } catch(e) { console.log("BOOKMARK_SAVE parse error", e) }
                webView.runJavaScript("document.title=''")

            // ── Bookmark: delete by id ────────────────────────────
            } else if (t.indexOf("BOOKMARK_DEL:") === 0) {
                var bmId = t.substring(13)
                Library.init()
                Library.deleteBookmark(bmId)
                _pushBookmarks()
                webView.runJavaScript("document.title=''")

            // ── Bookmark: JS requests fresh list ──────────────────
            } else if (t.indexOf("BOOKMARK_REQ:") === 0) {
                _pushBookmarks()
                webView.runJavaScript("document.title=''")

            // ── Nav bar hide/show ────────────────────────────────
            // NOTE: navBar visibility is controlled by root._readerMode binding in
            // Main.qml (visible: !root._readerMode). Do NOT directly assign navBar.visible
            // here — it would permanently break that binding and leave a gap on close.
            } else if (t.indexOf("HIDE_NAV:") === 0) {
                readerPage._bookReady = true
                readerPage._checkHideCover()   // fade out only if splash phases also done
                _pushHighlights()              // push saved highlights once book is ready
                _pushBookmarks()               // push saved bookmarks so ribbon marker works
                webView.runJavaScript("document.title=''")

            // ── Highlight: save new highlight ─────────────────────
            } else if (t.indexOf("HIGHLIGHT_SAVE:") === 0) {
                try {
                    var hl = JSON.parse(t.substring(15))
                    if (readerPage.book) {
                        Library.init()
                        Library.addHighlight(readerPage.book.id,
                            hl.id || "", hl.cfi || "", hl.text || "", hl.color || "#FFC107")
                    }
                } catch(e) { console.log("HIGHLIGHT_SAVE parse error", e) }
                webView.runJavaScript("document.title=''")

            // ── Highlight: delete by id ───────────────────────────
            } else if (t.indexOf("HIGHLIGHT_DEL:") === 0) {
                Library.init()
                Library.deleteHighlight(t.substring(14))
                _pushHighlights()
                webView.runJavaScript("document.title=''")

            // ── Highlight: JS requests fresh list ────────────────
            } else if (t.indexOf("HIGHLIGHT_REQ:") === 0) {
                _pushHighlights()
                webView.runJavaScript("document.title=''")
            }
        }

        onLoadingChanged: {
            console.log("WebView:", loadRequest.status, loadRequest.url)
            if (loadRequest.status === WebView.LoadFailedStatus)
                console.log("WebView error:", loadRequest.errorString)
        }
    }

    // ── URL load timer ────────────────────────────────────────────────────────
    // Deferred 120ms after openBook() so that layout recalculation (navBar hide)
    // and window manager fullscreen change both settle before we read webView.height.
    Timer {
        id: urlLoadTimer
        interval: 120
        repeat: false
        onTriggered: readerPage._loadReaderUrl()
    }

    // ── Splash phase timers ───────────────────────────────────────────────────
    // Phase 1 (0 → 400ms):   black background + spinner  (_showCover = false)
    // Phase 2 (400 → 900ms): book cover image + spinner  (_showCover = true)
    // Phase 3:                fade out once BOTH phases done AND book is ready
    Timer {
        id: coverPhase1Timer
        interval: 400
        repeat: false
        onTriggered: {
            readerPage._showCover = true
            coverPhase2Timer.start()
        }
    }
    Timer {
        id: coverPhase2Timer
        interval: 500
        repeat: false
        onTriggered: {
            readerPage._phasesDone = true
            readerPage._checkHideCover()
        }
    }

    // ── Transition cover — hides old book content during navigation ───────────
    // Phase 1: solid black. Phase 2: book's cover image (with dark overlay).
    // Fades out only when the splash phases are done AND the HTML has rendered.
    Rectangle {
        id: transitionCover
        anchors.fill: parent
        color: "#111111"
        z: 1
        opacity: readerPage._transitionCover ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 350 } }
        MouseArea { anchors.fill: parent; enabled: readerPage._transitionCover }

        // Book cover image — fades in during phase 2
        Image {
            id: transitionCoverImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            visible: readerPage._showCover && status === Image.Ready
            source: {
                if (!readerPage._showCover || !readerPage.book) return ""
                var b = readerPage.book
                if (b.cover_url  && b.cover_url  !== "") return b.cover_url
                if (b.cover_local && b.cover_local !== "") return "file://" + b.cover_local
                return ""
            }
        }

        // Dark scrim so the brown spinner stays legible over bright covers
        Rectangle {
            anchors.fill: parent
            color: "#AA000000"
            visible: readerPage._showCover
        }

        // Spinner — centred, always visible while cover is showing
        ActivityIndicator {
            anchors.centerIn: parent
            running: readerPage._transitionCover
        }
    }

    // ── Error state ───────────────────────────────────────────────────────────
    Rectangle {
        id: errorRect
        visible: false; anchors.fill: parent; color: "#111111"
        Column {
            anchors.centerIn: parent; spacing: units.gu(2)
            Label { anchors.horizontalCenter: parent.horizontalCenter
                    text: "No EPUB available"; fontSize: "large"; color: "#CC4444" }
            Label { anchors.horizontalCenter: parent.horizontalCenter
                    text: "Download the book first"; fontSize: "small"; color: "#555" }
        }
    }

    // ── Top overlay row: back btn (left) + title (centre) + gear (right) ─────
    // All three fade with _barsVisible so they don't interrupt reading

    // Back button — top left
    Rectangle {
        id: backBtn
        anchors { top: parent.top; left: parent.left
                  topMargin: units.gu(1.2); leftMargin: units.gu(1.2) }
        width: units.gu(4.8); height: units.gu(4.8)
        radius: width / 2; color: "#CC000000"
        opacity: readerPage._barsVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        Icon { anchors.centerIn: parent; width: units.gu(2.2); height: units.gu(2.2)
               name: "back"; color: "#CCCCCC" }
        MouseArea {
            anchors.fill: parent
            enabled: readerPage._barsVisible
            onClicked: {
                // Flush position while page is still visible (most reliable path).
                // onVisibleChanged will also do a sync save, but this JS call catches
                // the very-latest CFI in case the user just turned a page.
                webView.runJavaScript("if(typeof flushPosition==='function')flushPosition()")
                pageStack.pop()
            }
        }
    }

    // Book title — fills space between back and bookmark button
    Rectangle {
        anchors { top: parent.top; left: backBtn.right; right: bookmarkBtn.left
                  topMargin: units.gu(1.2); leftMargin: units.gu(0.6); rightMargin: units.gu(0.6) }
        height: units.gu(4.8); radius: units.dp(10); color: "#CC000000"
        opacity: readerPage._barsVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        Label {
            anchors { verticalCenter: parent.verticalCenter
                      left: parent.left; right: parent.right
                      leftMargin: units.gu(1.4); rightMargin: units.gu(1.4) }
            text: readerPage.book ? readerPage.book.title : ""
            font.pixelSize: units.gu(1.9); font.weight: Font.Light
            color: "#BBBBBB"; elide: Text.ElideRight
        }
    }

    // ── Bookmark button — saves current position, left of TOC ────────────────
    Rectangle {
        id: bookmarkBtn
        anchors { top: parent.top; right: tocBtn.left
                  topMargin: units.gu(1.2); rightMargin: units.gu(0.5) }
        width: units.gu(4.8); height: units.gu(4.8)
        radius: width / 2
        color: "#CC000000"
        opacity: readerPage._barsVisible ? 1.0 : 0.0
        enabled: readerPage._barsVisible
        Behavior on opacity { NumberAnimation { duration: 250 } }

        Icon {
            anchors.centerIn: parent
            width: units.gu(2.2); height: units.gu(2.2)
            name: "starred"
            color: "#AAAAAA"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: webView.runJavaScript("readerBookmarks.save()")
        }

        // Brief brown flash confirms the bookmark was saved
        SequentialAnimation {
            id: bookmarkFlash
            PropertyAction  { target: bookmarkBtn; property: "color"; value: "#CC8B5A32" }
            PauseAnimation  { duration: 600 }
            PropertyAction  { target: bookmarkBtn; property: "color"; value: "#CC000000" }
        }
    }

    // ── TOC button — far right ────────────────────────────────────────────────
    Rectangle {
        id: tocBtn
        anchors { top: parent.top; right: parent.right
                  topMargin: units.gu(1.2); rightMargin: units.gu(1.2) }
        width: units.gu(4.8); height: units.gu(4.8)
        radius: width / 2
        color: "#CC000000"
        opacity: readerPage._barsVisible ? 1.0 : 0.0
        enabled: readerPage._barsVisible
        Behavior on opacity { NumberAnimation { duration: 250 } }
        Icon {
            anchors.centerIn: parent
            width: units.gu(2.2); height: units.gu(2.2)
            name: "view-list-symbolic"
            color: "#AAAAAA"
        }
        MouseArea {
            anchors.fill: parent
            onClicked: webView.runJavaScript("readerToc.toggle()")
        }
    }

}

