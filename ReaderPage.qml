import QtQuick 2.12
import Ubuntu.Components 1.3
import Morph.Web 0.1
import "../js/Library.js" as Library

Page {
    id: readerPage

    property var  book:         null
    property bool _barsVisible: false  // hidden by default; shown on bottom tap

    function openBook(bookObj) {
        console.log("ReaderPage.openBook:", bookObj ? bookObj.id : "null")
        navBar.visible = false           // hide immediately — reader is full-screen by default
        webView.url = "about:blank"
        book = bookObj
    }

    // Restore nav bar whenever this page becomes invisible (user goes back)
    onVisibleChanged: {
        if (!visible) {
            navBar.visible = true
        }
    }

    onBookChanged: {
        if (!book) return
        // ── EPUB source URL ───────────────────────────────────────────────
        // file_path may already carry "file://" (local imports via ContentHub),
        // or may be a bare path (Gutenberg downloads).  Never double-prefix.
        var src = ""
        if (book.file_path && book.file_path !== "") {
            src = (book.file_path.indexOf("file://") === 0)
                  ? book.file_path           // already has prefix — use as-is
                  : "file://" + book.file_path
        } else if (book.epub_url && book.epub_url !== "") {
            src = book.epub_url
        }
        if (!src) { errorRect.visible = true; return }

        var here    = Qt.resolvedUrl(".").toString()
        var appRoot = here.replace(/qml\/pages\/$/, "")
        var htmlUrl = appRoot + "assets/reader/reader.html"
        var pct     = book.read_percent || 0

        // Pass QML layout dimensions directly — far more reliable than CSS viewport units
        // inside a WebView, where 100vh can include system navigation bars.
        // webView.width/height are in QML logical pixels == CSS pixels at scale=1.0.
        // Subtract 56 for the reader's own bottom bar (defined in CSS as 56px).
        var vw = Math.round(webView.width)
        // Bottom bar is 3vh of the WebView height (reduced for more reading space)
        var barH = Math.round(webView.height * 0.03)
        var vh = Math.round(webView.height - barH)
        console.log("ReaderPage: passing viewport", vw + "x" + vh,
                    "(webView.height=" + webView.height + " barH=" + barH + ")")

        // Pass needcover=1 when the book has no stored cover yet —
        // reader.html will extract the EPUB cover thumbnail and report it back.
        var hasCover = (book.cover_local && book.cover_local !== "")
                    || (book.cover_url  && book.cover_url  !== "")
        var needCover = hasCover ? "0" : "1"

        // Build URL — include saved prefs so reader restores them
        var url = htmlUrl
                + "?url="        + encodeURIComponent(src)
                + "&title="      + encodeURIComponent(book.title || "")
                + "&percent="    + pct
                + "&vw="         + vw
                + "&vh="         + vh
                + "&needcover="  + needCover
        if (book.reader_fontsize)   url += "&fontsize="   + book.reader_fontsize
        if (book.reader_fontfamily) url += "&fontfamily=" + book.reader_fontfamily
        if (book.reader_theme)      url += "&theme="      + book.reader_theme
        if (book.reader_spacing)    url += "&spacing="    + book.reader_spacing
        if (book.reader_margins)    url += "&margins="    + book.reader_margins

        console.log("ReaderPage: loading", url)
        webView.url = url
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

            // ── Position report ─────────────────────────────────
            if (t.indexOf("PCT:") === 0) {
                var pct = parseInt(t.substring(4))
                if (!isNaN(pct) && readerPage.book) {
                    Library.init()
                    Library.updateReadPercent(readerPage.book.id, pct)
                    console.log("Reader: saved", pct + "% for", readerPage.book.id)
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

            // ── Nav bar hide/show ────────────────────────────────
            } else if (t.indexOf("HIDE_NAV:") === 0) {
                navBar.visible = (t.charAt(9) === '0')
                webView.runJavaScript("document.title=''")

            // ── Cover thumbnail (data: URI) extracted by reader.html ─────────
            // Fires on first open of a locally imported book (?needcover=1).
            // We save it as cover_url in the DB so the library grid shows it.
            } else if (t.indexOf("COVER:") === 0) {
                var dataUrl = t.substring(6)
                if (readerPage.book && dataUrl.length > 20) {
                    Library.init()
                    Library.updateCoverDataUrl(readerPage.book.id, dataUrl)
                    // Refresh the book object so the cover shows if user goes back
                    var updated = Library.getBook(readerPage.book.id)
                    if (updated) readerPage.book = updated
                    console.log("Reader: saved cover for", readerPage.book.id,
                                "bytes:", dataUrl.length)
                }
                webView.runJavaScript("document.title=''")
            }
        }

        onLoadingChanged: {
            console.log("WebView:", loadRequest.status, loadRequest.url)
            if (loadRequest.status === WebView.LoadFailedStatus)
                console.log("WebView error:", loadRequest.errorString)
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
            onClicked: {
                webView.runJavaScript("document.title=''")
                pageStack.pop()
            }
        }
    }

    // Book title — fills space between back and toc button
    Rectangle {
        anchors { top: parent.top; left: backBtn.right; right: tocBtn.left
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

    // ── TOC button — left of gear ─────────────────────────────────────────────
    Rectangle {
        id: tocBtn
        anchors { top: parent.top; right: gearBtn.left
                  topMargin: units.gu(1.2); rightMargin: units.gu(0.5) }
        width: units.gu(4.8); height: units.gu(4.8)
        radius: width / 2
        color: readerPage._barsVisible ? "#CC000000" : "#DD000000"
        Behavior on color { ColorAnimation { duration: 250 } }
        Icon {
            anchors.centerIn: parent
            width: units.gu(2.2); height: units.gu(2.2)
            name: "view-list-symbolic"
            color: readerPage._barsVisible ? "#AAAAAA" : "#DDDDDD"
            Behavior on color { ColorAnimation { duration: 250 } }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: webView.runJavaScript("readerToc.toggle()")
        }
    }

    // ── Gear icon — TOP RIGHT, ALWAYS VISIBLE ─────────────────────────────────
    Rectangle {
        id: gearBtn
        anchors { top: parent.top; right: parent.right
                  topMargin: units.gu(1.2); rightMargin: units.gu(1.2) }
        width: units.gu(4.8); height: units.gu(4.8)
        radius: width / 2
        // Slightly more opaque when bars are hidden so it's clearly findable
        color: readerPage._barsVisible ? "#CC000000" : "#DD000000"
        Behavior on color { ColorAnimation { duration: 250 } }

        Icon {
            anchors.centerIn: parent
            width: units.gu(2.2); height: units.gu(2.2)
            name: "settings"
            // Brighter when bars hidden so the user can find it
            color: readerPage._barsVisible ? "#AAAAAA" : "#DDDDDD"
            Behavior on color { ColorAnimation { duration: 250 } }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                console.log("Gear tapped — toggling settings panel")
                webView.runJavaScript("readerSettings.togglePanel()")
            }
        }
    }
}
