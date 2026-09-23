import QtQuick 2.12
import Ubuntu.Components 1.3

Page {
    id: accountPage

    header: PageHeader {
        id: pageHeader
        height: units.gu(6.7)

        contents: Item {
            anchors.fill: parent

            Column {
                anchors {
                    top: parent.top; topMargin: units.gu(0.4) + units.dp(5)
                    left: parent.left; leftMargin: units.gu(0.45)
                }
                spacing: -units.dp(3.0)

                Row {
                    spacing: 0
                    Label {
                        text: "B"
                        font.pixelSize: units.gu(2.6); font.weight: Font.Light
                        color: "#4CAF50"
                    }
                    Label {
                        text: "earthen"
                        font.pixelSize: units.gu(2.6); font.weight: Font.Medium
                        color: "#4CAF50"
                    }
                }
                Row {
                    spacing: units.dp(4)
                    Label {
                        text: "My"
                        font.pixelSize: units.gu(1.7); font.weight: Font.Medium
                        color: "#8B5A32"
                    }
                    Label {
                        text: root.t("Account")
                        font.pixelSize: units.gu(1.7); font.weight: Font.Light
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

    Rectangle {
        anchors.fill: parent
        color: root.isDarkMode ? "#121212" : "#FFFFFF"
        Behavior on color { ColorAnimation { duration: 250 } }
    }

    // Library texture background
    Item {
        id: accountTextureBg
        anchors { top: pageHeader.bottom; bottom: parent.bottom
                  left: parent.left; right: parent.right }
        opacity: root.isDarkMode ? 0.1 : 0.06
        Behavior on opacity { NumberAnimation { duration: 300 } }
        clip: true; z: 0
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            Repeater {
                model: 25
                Image {
                    width: accountTextureBg.width; height: width
                    source: root.isDarkMode
                        ? Qt.resolvedUrl("../../assets/textures/library-background-night-mode.svg")
                        : Qt.resolvedUrl("../../assets/textures/library-background-day-mode.svg")
                    fillMode: Image.Stretch; smooth: true; asynchronous: true
                }
            }
        }
    }

    // ── Scrollable content ────────────────────────────────────────────────────
    Flickable {
        anchors {
            top: pageHeader.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        contentHeight: accountColumn.height + units.gu(4)
        clip: true
        z: 1

        Column {
            id: accountColumn
            width: parent.width
            spacing: 0

            // ── Buwana identity hero ──────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: heroColumn.height + units.gu(5)
                color: root.isDarkMode ? "#0D1F0D" : "#E8F5E9"
                Behavior on color { ColorAnimation { duration: 250 } }

                Column {
                    id: heroColumn
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: units.gu(3)
                        leftMargin: units.gu(2.5)
                        rightMargin: units.gu(2.5)
                    }
                    spacing: units.gu(1.5)

                    // Buwana identity circle
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: units.gu(12)
                        height: units.gu(12)
                        radius: width / 2
                        color: "#1E3A1E"
                        border.color: "#2C5F2E"
                        border.width: units.dp(2)

                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(5.5)
                            height: units.gu(5.5)
                            name: "system-users-symbolic"
                            color: "#4CAF50"
                        }
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Bearthen Sync"
                        fontSize: "x-large"
                        color: root.isDarkMode ? "#FFFFFF" : "#212121"
                        font.weight: Font.Light
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        text: "Save, sync and share your books and library"
                        fontSize: "x-small"
                        color: root.isDarkMode ? "#888888" : "#757575"
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.4
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                }
            }

            // ── Feature list ──────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: units.gu(1)
                color: "transparent"
            }

            Repeater {
                model: [
                    { icon: "sync",       text: "Sync reading position across devices"  },
                    { icon: "bookmark",   text: "Cloud backup for highlights and notes"  },
                    { icon: "history",    text: "Reading history and statistics"          },
                    { icon: "like",       text: "Favourites list across your devices"    },
                    { icon: "lock",       text: "Private — your data stays yours"        }
                ]

                ListItem {
                    height: units.gu(7)
                    color: root.isDarkMode ? "#121212" : "#FFFFFF"
                    Behavior on color { ColorAnimation { duration: 250 } }
                    divider.colorFrom: root.isDarkMode ? "#2A2A2A" : "#E0E0E0"
                    divider.colorTo: root.isDarkMode ? "#121212" : "#FFFFFF"

                    Item {
                        anchors {
                            fill: parent
                            leftMargin: units.gu(2)
                            rightMargin: units.gu(2)
                        }

                        Icon {
                            id: featureIcon
                            width: units.gu(2.5)
                            height: units.gu(2.5)
                            name: modelData.icon
                            color: "#8B5A32"
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            anchors {
                                left: featureIcon.right
                                leftMargin: units.gu(1.5)
                                verticalCenter: parent.verticalCenter
                                right: parent.right
                            }
                            text: modelData.text
                            fontSize: "small"
                            color: root.isDarkMode ? "#CCCCCC" : "#444444"
                            wrapMode: Text.WordWrap
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }
                    }
                }
            }

            // ── Sign in button ────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: units.gu(1.5)
                color: "transparent"
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Sign in with Buwana"
                color: "#2C5F2E"
                width: parent.width - units.gu(4)
                onClicked: Qt.openUrlExternally("https://buwana.earthen.io")
            }

            Rectangle {
                width: parent.width
                height: units.gu(1.5)
                color: "transparent"
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Create Buwana Account"
                color: "transparent"
                strokeColor: "#2C5F2E"
                width: parent.width - units.gu(4)
                onClicked: Qt.openUrlExternally("https://buwana.earthen.io/register")
            }

            Rectangle {
                width: parent.width
                height: units.gu(2)
                color: "transparent"
            }

            // ── Coming soon notice ────────────────────────────────────────────
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - units.gu(4)
                height: comingSoonLabel.height + units.gu(2.5)
                radius: units.gu(0.6)
                color: root.isDarkMode ? "#1A1A1A" : "#F0F0F0"
                border.color: "#2C5F2E"
                border.width: units.dp(1)
                Behavior on color { ColorAnimation { duration: 250 } }

                Label {
                    id: comingSoonLabel
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: units.gu(1.5)
                        leftMargin: units.gu(1.5)
                        rightMargin: units.gu(1.5)
                    }
                    text: "In-app sign-in is coming soon. Tapping the buttons above will open Buwana in your browser. Once the EarthReader backend is live at reader.earthen.io, full OAuth sync will be activated."
                    wrapMode: Text.WordWrap
                    fontSize: "x-small"
                    color: root.isDarkMode ? "#888888" : "#666666"
                    lineHeight: 1.4
                    horizontalAlignment: Text.AlignHCenter
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }

            Item { width: parent.width; height: units.gu(3) }
        }
    }
}
