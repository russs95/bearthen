import QtQuick 2.12
import Ubuntu.Components 1.3

Page {
    id: settingsPage

    header: PageHeader {
        id: pageHeader
        title: "Bearthen"
        subtitle: root.t("Settings")
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

    Flickable {
        anchors {
            top: pageHeader.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        contentHeight: settingsColumn.height + units.gu(4)
        clip: true

        Column {
            id: settingsColumn
            width: parent.width

            // ── Mission banner ─────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: missionColumn.height + units.gu(4)
                color: root.isDarkMode ? "#0D1F0D" : "#E8F5E9"
                Behavior on color { ColorAnimation { duration: 250 } }

                Column {
                    id: missionColumn
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: units.gu(2.5)
                        leftMargin: units.gu(2.5)
                        rightMargin: units.gu(2.5)
                    }
                    spacing: units.gu(1.5)

                    // Two icons side by side — settings gear + human figure
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: units.gu(2)

                        Icon {
                            width: units.gu(5.5)
                            height: units.gu(5.5)
                            name: "settings"
                            color: "#2C5F2E"
                        }

                        Icon {
                            width: units.gu(5.5)
                            height: units.gu(5.5)
                            name: "preferences-desktop-accessibility-symbolic"
                            color: "#2C5F2E"
                        }
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        text: root.t("Mission")
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        fontSize: "small"
                        color: root.isDarkMode ? "#AAAAAA" : "#555555"
                        lineHeight: 1.5
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                }
            }

            // ── APPEARANCE ────────────────────────────────────────────────────
            SectionHeader { label: root.t("Appearance") }

            ToggleRow {
                iconName: "display-brightness-symbolic"
                labelText: root.t("Dark Mode")
                subText: root.isDarkMode
                    ? root.t("Dark theme active")
                    : root.t("Light theme active")
                isChecked: root.isDarkMode
                onToggled: root.isDarkMode = val
            }

            // ── LANGUAGE ──────────────────────────────────────────────────────
            SectionHeader { label: root.t("Language") }

            Repeater {
                model: root.availableLanguages

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

                        Rectangle {
                            id: dot
                            width: units.gu(1.2)
                            height: units.gu(1.2)
                            radius: width / 2
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.currentLanguage === modelData.code
                                ? "#4CAF50" : "transparent"
                            border.color: root.currentLanguage === modelData.code
                                ? "#4CAF50" : "#666666"
                            border.width: units.dp(1.5)
                        }

                        Column {
                            anchors {
                                left: dot.right
                                leftMargin: units.gu(1.5)
                                right: langTick.left
                                rightMargin: units.gu(1)
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: units.gu(0.2)

                            Label {
                                text: modelData.nativeName
                                fontSize: "medium"
                                font.weight: root.currentLanguage === modelData.code
                                    ? Font.Medium : Font.Normal
                                color: root.currentLanguage === modelData.code
                                    ? "#4CAF50"
                                    : (root.isDarkMode ? "#FFFFFF" : "#212121")
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }

                            Label {
                                text: modelData.englishName
                                fontSize: "x-small"
                                color: "#888888"
                                visible: modelData.nativeName !== modelData.englishName
                            }
                        }

                        Icon {
                            id: langTick
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            width: units.gu(2.2)
                            height: units.gu(2.2)
                            name: "tick"
                            color: "#4CAF50"
                            visible: root.currentLanguage === modelData.code
                        }
                    }

                    onClicked: root.currentLanguage = modelData.code
                }
            }

            // ── READING ───────────────────────────────────────────────────────
            SectionHeader { label: root.t("Reading") }

            ToggleRow {
                iconName: "bookmark"
                labelText: root.t("Auto-Bookmark")
                subText: root.t("Save position when closing a book")
                isChecked: true
                onToggled: console.log("Auto-bookmark:", val)
            }

            ToggleRow {
                iconName: "torch-on"
                labelText: root.t("Keep Screen Awake")
                subText: root.t("Prevent sleep while reading")
                isChecked: false
                onToggled: console.log("Keep awake:", val)
            }

            // ── AI CONNECTOR ──────────────────────────────────────────────────
            SectionHeader { label: root.t("AI Connector") }

            ChevronRow {
                iconName: "edit"
                labelText: root.t("AI Endpoint URL")
                subText: "e.g. http://localhost:11434"
            }

            ToggleRow {
                iconName: "search"
                labelText: root.t("AI Features")
                subText: root.t("Translate, summarise, define")
                isChecked: false
                onToggled: console.log("AI features:", val)
            }

            // ── ABOUT ─────────────────────────────────────────────────────────
            SectionHeader { label: root.t("About") }

            ChevronRow {
                iconName: "stock_ebook"
                labelText: "Bearthen"
                subText: "v0.1.1 — EarthReader Beta Shell"
            }

            // Open Source row — tapping opens GitHub README in system browser
            ListItem {
                height: units.gu(8)
                color: root.isDarkMode ? "#121212" : "#FFFFFF"
                Behavior on color { ColorAnimation { duration: 250 } }
                divider.colorFrom: root.isDarkMode ? "#2A2A2A" : "#E0E0E0"
                divider.colorTo: root.isDarkMode ? "#121212" : "#FFFFFF"

                onClicked: Qt.openUrlExternally(
                    "https://github.com/russs95/bearthen/blob/main/README.md"
                )

                Item {
                    anchors {
                        fill: parent
                        leftMargin: units.gu(2)
                        rightMargin: units.gu(2)
                    }

                    Icon {
                        id: osIcon
                        width: units.gu(2.8)
                        height: units.gu(2.8)
                        name: "stock_website"
                        color: "#4CAF50"
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors {
                            left: osIcon.right
                            leftMargin: units.gu(1.5)
                            right: osChevron.left
                            rightMargin: units.gu(1)
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: units.gu(0.3)

                        Label {
                            text: root.t("Open Source")
                            fontSize: "medium"
                            color: root.isDarkMode ? "#FFFFFF" : "#212121"
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }

                        Label {
                            text: "github.com/russs95/bearthen"
                            fontSize: "x-small"
                            color: "#4CAF50"
                            width: parent.width
                            elide: Text.ElideRight
                        }
                    }

                    Icon {
                        id: osChevron
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        width: units.gu(2)
                        height: units.gu(2)
                        name: "go-next"
                        color: "#555555"
                    }
                }
            }

            Item { width: parent.width; height: units.gu(3) }
        }
    }

    // ── Section header ────────────────────────────────────────────────────────
    component SectionHeader: Rectangle {
        property string label: ""
        width: settingsColumn.width
        height: units.gu(4.5)
        color: root.isDarkMode ? "#1E1E1E" : "#EEEEEE"
        Behavior on color { ColorAnimation { duration: 250 } }

        Label {
            anchors {
                left: parent.left
                leftMargin: units.gu(2)
                verticalCenter: parent.verticalCenter
            }
            text: label.toUpperCase()
            fontSize: "x-small"
            color: "#4CAF50"
            font.weight: Font.Medium
        }
    }

    // ── Toggle row ────────────────────────────────────────────────────────────
    component ToggleRow: ListItem {
        property string iconName: ""
        property string labelText: ""
        property string subText: ""
        property bool isChecked: false
        signal toggled(bool val)

        height: units.gu(8)
        color: root.isDarkMode ? "#121212" : "#FFFFFF"
        divider.colorFrom: root.isDarkMode ? "#2A2A2A" : "#E0E0E0"
        divider.colorTo: root.isDarkMode ? "#121212" : "#FFFFFF"
        Behavior on color { ColorAnimation { duration: 250 } }

        Item {
            anchors {
                fill: parent
                leftMargin: units.gu(2)
                rightMargin: units.gu(2)
            }

            Icon {
                id: tIcon
                width: units.gu(2.8)
                height: units.gu(2.8)
                name: iconName
                color: "#4CAF50"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors {
                    left: tIcon.right
                    leftMargin: units.gu(1.5)
                    right: tSwitch.left
                    rightMargin: units.gu(1)
                    verticalCenter: parent.verticalCenter
                }
                spacing: units.gu(0.3)

                Label {
                    text: labelText
                    fontSize: "medium"
                    color: root.isDarkMode ? "#FFFFFF" : "#212121"
                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                Label {
                    text: subText
                    fontSize: "x-small"
                    color: "#888888"
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
            }

            Switch {
                id: tSwitch
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                checked: isChecked
                onCheckedChanged: toggled(checked)
            }
        }
    }

    // ── Chevron row ───────────────────────────────────────────────────────────
    component ChevronRow: ListItem {
        property string iconName: ""
        property string labelText: ""
        property string subText: ""

        height: units.gu(8)
        color: root.isDarkMode ? "#121212" : "#FFFFFF"
        divider.colorFrom: root.isDarkMode ? "#2A2A2A" : "#E0E0E0"
        divider.colorTo: root.isDarkMode ? "#121212" : "#FFFFFF"
        Behavior on color { ColorAnimation { duration: 250 } }

        Item {
            anchors {
                fill: parent
                leftMargin: units.gu(2)
                rightMargin: units.gu(2)
            }

            Icon {
                id: cIcon
                width: units.gu(2.8)
                height: units.gu(2.8)
                name: iconName
                color: "#4CAF50"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors {
                    left: cIcon.right
                    leftMargin: units.gu(1.5)
                    right: cChevron.left
                    rightMargin: units.gu(1)
                    verticalCenter: parent.verticalCenter
                }
                spacing: units.gu(0.3)

                Label {
                    text: labelText
                    fontSize: "medium"
                    color: root.isDarkMode ? "#FFFFFF" : "#212121"
                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                Label {
                    text: subText
                    fontSize: "x-small"
                    color: "#888888"
                    width: parent.width
                    elide: Text.ElideRight
                }
            }

            Icon {
                id: cChevron
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                width: units.gu(2)
                height: units.gu(2)
                name: "go-next"
                color: "#555555"
            }
        }
    }
}
