import QtQuick 2.12
import Ubuntu.Components 1.3

Page {
    id: libraryPage

    header: PageHeader {
        title: "Bearthen"
        subtitle: "Your Library"
        StyleHints {
            foregroundColor: "#4CAF50"
            backgroundColor: "#1A1A1A"
            dividerColor: "#2C5F2E"
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#121212"

        Column {
            anchors.centerIn: parent
            spacing: units.gu(3)

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: units.gu(14)
                height: units.gu(14)
                radius: width / 2
                color: "#1E3A1E"

                Icon {
                    anchors.centerIn: parent
                    width: units.gu(7)
                    height: units.gu(7)
                    name: "stock_ebook"
                    color: "#2C5F2E"
                }

                SequentialAnimation on opacity {
                    running: true
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.7; duration: 2000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Your library is empty"
                fontSize: "large"
                color: "#FFFFFF"
                font.weight: Font.Light
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: units.gu(32)
                text: "Discover free books from Project Gutenberg or import your own EPUB files."
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                fontSize: "small"
                color: "#888888"
                lineHeight: 1.4
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Browse Free Books"
                color: "#2C5F2E"
                width: units.gu(24)
                onClicked: console.log("Navigate to Discover")
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Import EPUB File"
                color: "transparent"
                strokeColor: "#2C5F2E"
                width: units.gu(24)
                onClicked: console.log("Import tapped")
            }
        }
    }
}
