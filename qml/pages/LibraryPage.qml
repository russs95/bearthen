import QtQuick 2.12
import Ubuntu.Components 1.3

Page {
    id: libraryPage

    // ── Header ───────────────────────────────────────────────────────────────
    header: PageHeader {
        id: pageHeader
        title: "Bearthen"
        subtitle: "Your Library"

        StyleHints {
            foregroundColor: "#4CAF50"
            backgroundColor: "#1A1A1A"
            dividerColor: "#2C5F2E"
        }

        trailingActionBar.actions: [
            Action {
                iconName: "import"
                text: "Import Book"
                onTriggered: importHint.visible = true
            },
            Action {
                iconName: "view-grid-symbolic"
                text: "Grid View"
                onTriggered: console.log("Grid view — coming soon")
            }
        ]
    }

    // ── Background ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#121212"
    }

    // ── Empty state ───────────────────────────────────────────────────────────
    Column {
        id: emptyState
        anchors.centerIn: parent
        spacing: units.gu(3)
        visible: true        // will be toggled false when library has books

        // Leaf / book icon
        Rectangle {
            id: iconCircle
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(14)
            height: units.gu(14)
            radius: width / 2
            color: "#1E3A1E"

            Icon {
                anchors.centerIn: parent
                width: units.gu(7)
                height: units.gu(7)
                name: "book"
                color: "#2C5F2E"
            }

            // Subtle pulse animation
            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite
                NumberAnimation { to: 0.7; duration: 2000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
            }
        }

        // Headline
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Your library is empty"
            fontSize: "large"
            color: "#FFFFFF"
            font.weight: Font.Light
        }

        // Subtext
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: units.gu(32)
            text: "Discover free books from Project Gutenberg or import your own EPUB files to get started."
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            fontSize: "small"
            color: "#888888"
            lineHeight: 1.4
        }

        // ── Discover CTA button ───────────────────────────────────────────────
        Button {
            id: discoverButton
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Browse Free Books"
            color: "#2C5F2E"
            width: units.gu(24)

            onClicked: {
                // Signal up to root to switch to Discover tab
                root.currentPage = 1
                pageStack.clear()
                pageStack.push(discoverPage)
            }
        }

        // ── Import hint button ────────────────────────────────────────────────
        Button {
            id: importButton
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Import EPUB File"
            color: "transparent"
            strokeColor: "#2C5F2E"
            width: units.gu(24)

            onClicked: importHint.visible = true
        }
    }

    // ── Book grid (hidden until library has content) ──────────────────────────
    GridView {
        id: bookGrid
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: units.gu(1.5)
        }
        visible: false      // shown when library model is populated
        cellWidth: units.gu(14)
        cellHeight: units.gu(20)
        clip: true

        model: ListModel { id: libraryModel }

        delegate: Item {
            width: bookGrid.cellWidth
            height: bookGrid.cellHeight

            Column {
                anchors {
                    fill: parent
                    margins: units.gu(0.75)
                }
                spacing: units.gu(0.75)

                // Cover placeholder
                Rectangle {
                    width: parent.width
                    height: units.gu(15)
                    radius: units.gu(0.5)
                    color: "#1E3A1E"

                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(4)
                        height: units.gu(4)
                        name: "book"
                        color: "#2C5F2E"
                    }
                }

                // Book title
                Label {
                    width: parent.width
                    text: model.title || "Unknown Title"
                    fontSize: "x-small"
                    color: "#FFFFFF"
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                // Author
                Label {
                    width: parent.width
                    text: model.author || ""
                    fontSize: "x-small"
                    color: "#888888"
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: console.log("Open book:", model.title)
            }
        }
    }

    // ── Import hint dialog ────────────────────────────────────────────────────
    Rectangle {
        id: importHint
        anchors.fill: parent
        color: "#CC000000"
        visible: false
        z: 10

        MouseArea {
            anchors.fill: parent
            onClicked: importHint.visible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: units.gu(36)
            height: units.gu(22)
            radius: units.gu(1)
            color: "#1E1E1E"

            Column {
                anchors {
                    fill: parent
                    margins: units.gu(3)
                }
                spacing: units.gu(2)

                Label {
                    text: "Import EPUB Files"
                    fontSize: "large"
                    color: "#FFFFFF"
                    font.weight: Font.Medium
                }

                Label {
                    width: parent.width
                    text: "EPUB import via the Content Hub is coming soon. You'll be able to open any EPUB file from your file manager or browser directly into Bearthen."
                    wrapMode: Text.WordWrap
                    fontSize: "small"
                    color: "#AAAAAA"
                    lineHeight: 1.4
                }

                Button {
                    text: "Got it"
                    color: "#2C5F2E"
                    width: parent.width
                    onClicked: importHint.visible = false
                }
            }
        }
    }
}