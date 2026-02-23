import QtQuick 2.12
import Ubuntu.Components 1.3
import "../js/Library.js" as Library

Page {
    id: libraryPage

    header: PageHeader {
        id: pageHeader
        title: "Bearthen"
        subtitle: root.t("Your Library")
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

    property var books: []

    function refresh() {
        Library.init()
        books = Library.getBooks()
        console.log("LibraryPage: refreshed, book count:", books.length)
    }

    // Init on first load
    Component.onCompleted: refresh()

    // Refresh every time this page becomes visible (e.g. after returning from BookDetail)
    onVisibleChanged: {
        if (visible) refresh()
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
            Behavior on color { ColorAnimation { duration: 250 } }
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
        cellHeight: units.gu(24)
        model: libraryPage.books

        delegate: Item {
            width: bookGrid.cellWidth
            height: bookGrid.cellHeight

            Rectangle {
                anchors { fill: parent; margins: units.gu(0.5) }
                color: root.isDarkMode ? "#1A1A1A" : "#F5F5F5"
                radius: units.dp(6)
                Behavior on color { ColorAnimation { duration: 250 } }

                Column {
                    anchors { fill: parent; margins: units.gu(0.8) }
                    spacing: units.gu(0.5)

                    // ── Cover ─────────────────────────────────────────────────
                    Rectangle {
                        width: parent.width
                        height: units.gu(15)
                        color: root.isDarkMode ? "#1A2E1A" : "#C8E6C9"
                        radius: units.dp(4)
                        clip: true

                        // Watermark icon — always rendered, image paints over it
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(5); height: units.gu(5)
                            name: "stock_ebook"
                            color: root.isDarkMode ? "#2C5F2E" : "#4CAF50"
                            opacity: 0.25
                        }

                        Image {
                            anchors.fill: parent; anchors.margins: units.dp(2)
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
                            // Renders on top of watermark when ready
                        }

                        // Read progress bar along bottom of cover
                        Rectangle {
                            visible: modelData.read_percent > 0
                            anchors {
                                left: parent.left; right: parent.right; bottom: parent.bottom
                                leftMargin: units.dp(3); rightMargin: units.dp(3); bottomMargin: units.dp(3)
                            }
                            height: units.dp(3); radius: height / 2
                            color: root.isDarkMode ? "#0D1F0D" : "#C8E6C9"
                            Rectangle {
                                width: parent.width * (modelData.read_percent / 100)
                                height: parent.height; radius: parent.radius; color: "#4CAF50"
                            }
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

                    // ── Progress label ────────────────────────────────────────
                    Label {
                        width: parent.width
                        text: modelData.is_finished
                              ? "Finished ✓"
                              : (modelData.read_percent > 0
                                 ? (modelData.read_percent + "% read")
                                 : "Not started")
                        fontSize: "x-small"; color: "#888888"
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
}