import QtQuick 2.12
import Ubuntu.Components 1.3

Page {
    id: settingsPage

    // ── Header ────────────────────────────────────────────────────────────────
    header: PageHeader {
        id: pageHeader
        title: "Bearthen"
        subtitle: "Settings"

        StyleHints {
            foregroundColor: "#4CAF50"
            backgroundColor: root.isDarkMode ? "#1A1A1A" : "#F5F5F5"
            dividerColor: "#2C5F2E"
        }
    }

    // ── Background — responds to theme ────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: root.isDarkMode ? "#121212" : "#FFFFFF"

        Behavior on color {
            ColorAnimation { duration: 250 }
        }
    }

    // ── Scrollable content ────────────────────────────────────────────────────
    Flickable {
        id: scrollArea
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

            // ════════════════════════════════════════════════════════════════
            // SECTION: Appearance
            // ════════════════════════════════════════════════════════════════
            SettingsSectionHeader {
                label: "Appearance"
            }

            // Dark / Light mode toggle
            SettingsRow {
                iconName: root.isDarkMode ? "night-mode" : "display-brightness-symbolic"
                label: "Dark Mode"
                description: root.isDarkMode ? "Dark theme active" : "Light theme active"

                Switch {
                    id: darkModeSwitch
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.isDarkMode
                    onCheckedChanged: {
                        root.isDarkMode = checked
                        root.theme.name = checked
                            ? "Ubuntu.Components.Themes.SuruDark"
                            : "Ubuntu.Components.Themes.Ambiance"
                    }
                }
            }

            // Font size
            SettingsRow {
                iconName: "font-size-plus"
                label: "Reading Font Size"
                description: "Adjust text size while reading"
                showChevron: true
                onTapped: fontHint.visible = true
            }

            // Reading theme
            SettingsRow {
                iconName: "visual-memory-indicator"
                label: "Reading Theme"
                description: "Paper, Sepia, Night"
                showChevron: true
                onTapped: themeHint.visible = true
            }

            // ════════════════════════════════════════════════════════════════
            // SECTION: Reading
            // ════════════════════════════════════════════════════════════════
            SettingsSectionHeader {
                label: "Reading"
            }

            SettingsRow {
                iconName: "media-skip-forward"
                label: "Page Turn Style"
                description: "Scroll or paginate"
                showChevron: true
                onTapped: pageHint.visible = true
            }

            SettingsRow {
                iconName: "bookmark"
                label: "Auto-Bookmark"
                description: "Save position when closing a book"

                Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: true
                }
            }

            SettingsRow {
                iconName: "torch-on"
                label: "Keep Screen Awake"
                description: "Prevent sleep while reading"

                Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: false
                }
            }

            // ════════════════════════════════════════════════════════════════
            // SECTION: AI Connector
            // ════════════════════════════════════════════════════════════════
            SettingsSectionHeader {
                label: "AI Connector"
            }

            SettingsRow {
                iconName: "edit"
                label: "AI Endpoint URL"
                description: "e.g. http://localhost:11434 for Ollama"
                showChevron: true
                onTapped: aiHint.visible = true
            }

            SettingsRow {
                iconName: "lock"
                label: "API Key"
                description: "Optional — leave blank for local models"
                showChevron: true
                onTapped: aiHint.visible = true
            }

            SettingsRow {
                iconName: "system-devices-panel-symbolic"
                label: "AI Features"
                description: "Translate, summarise, define"

                Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: false
                }
            }

            // ════════════════════════════════════════════════════════════════
            // SECTION: Storage
            // ════════════════════════════════════════════════════════════════
            SettingsSectionHeader {
                label: "Storage"
            }

            SettingsRow {
                iconName: "save"
                label: "Books Location"
                description: "~/Books/Bearthen"
                showChevron: true
                onTapped: storageHint.visible = true
            }

            SettingsRow {
                iconName: "delete"
                label: "Clear Cache"
                description: "Remove temporary cover art and data"
                showChevron: true
                onTapped: storageHint.visible = true
            }

            // ════════════════════════════════════════════════════════════════
            // SECTION: About
            // ════════════════════════════════════════════════════════════════
            SettingsSectionHeader {
                label: "About"
            }

            SettingsRow {
                iconName: "info"
                label: "Bearthen"
                description: "Version 0.1.0 — Beta Shell"
            }

            SettingsRow {
                iconName: "stock_website"
                label: "EarthReader Project"
                description: "reader.earthen.io"
                showChevron: true
                onTapped: console.log("Open reader.earthen.io")
            }

            SettingsRow {
                iconName: "contacts-app-symbolic"
                label: "Buwana Identity"
                description: "buwana.earthen.io"
                showChevron: true
                onTapped: console.log("Open buwana.earthen.io")
            }

            SettingsRow {
                iconName: "like"
                label: "Open Source"
                description: "github.com/russs95/bearthen"
                showChevron: true
                onTapped: console.log("Open GitHub repo")
            }

            // Bottom breathing room
            Item { width: parent.width; height: units.gu(3) }
        }
    }

    // ── Inline sub-components ─────────────────────────────────────────────────

    // Section header label
    component SettingsSectionHeader: Rectangle {
        property string label: ""
        width: settingsColumn.width
        height: units.gu(5)
        color: root.isDarkMode ? "#1A1A1A" : "#EEEEEE"

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
            letterSpacing: 1.2
        }
    }

    // Settings row — icon, label, description, optional right-side slot
    component SettingsRow: ListItem {
        id: rowItem
        property string iconName: ""
        property string label: ""
        property string description: ""
        property bool showChevron: false
        signal tapped()

        width: settingsColumn.width
        height: units.gu(8)
        color: root.isDarkMode ? "#121212" : "#FFFFFF"
        divider.colorFrom: root.isDarkMode ? "#2A2A2A" : "#E0E0E0"
        divider.colorTo:   root.isDarkMode ? "#121212" : "#FFFFFF"

        Behavior on color { ColorAnimation { duration: 250 } }

        onClicked: rowItem.tapped()

        Row {
            anchors {
                fill: parent
                leftMargin:  units.gu(2)
                rightMargin: units.gu(2)
            }
            spacing: units.gu(1.5)

            // Row icon
            Icon {
                width: units.gu(2.8)
                height: units.gu(2.8)
                name: iconName
                color: "#4CAF50"
                anchors.verticalCenter: parent.verticalCenter
            }

            // Label + description
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                       - units.gu(2.8)           // icon
                       - units.gu(1.5)           // left spacing
                       - (showChevron ? units.gu(3) : units.gu(1))
                spacing: units.gu(0.3)

                Label {
                    text: rowItem.label
                    fontSize: "medium"
                    color: root.isDarkMode ? "#FFFFFF" : "#212121"
                    font.weight: Font.Normal
                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                Label {
                    text: rowItem.description
                    fontSize: "x-small"
                    color: root.isDarkMode ? "#888888" : "#757575"
                    wrapMode: Text.WordWrap
                    width: parent.width
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }

            // Chevron
            Icon {
                visible: showChevron
                width: units.gu(2)
                height: units.gu(2)
                name: "go-next"
                color: root.isDarkMode ? "#555555" : "#BBBBBB"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ── Placeholder hint dialogs ──────────────────────────────────────────────
    HintDialog {
        id: fontHint
        title: "Reading Font Size"
        message: "A font size slider will appear in the reader toolbar when a book is open. Pinch-to-zoom will also be supported."
    }

    HintDialog {
        id: themeHint
        title: "Reading Theme"
        message: "Choose between Paper (white), Sepia (warm), and Night (true black) reading themes. Coming in the next release."
    }

    HintDialog {
        id: pageHint
        title: "Page Turn Style"
        message: "Switch between smooth scrolling and paginated (swipe left/right) reading modes. Readium Web supports both natively."
    }

    HintDialog {
        id: aiHint
        title: "AI Connector"
        message: "Point Bearthen at any OpenAI-compatible endpoint — Ollama running locally, a cloud API, or your own agent. Your reading data never leaves your device without your configuration."
    }

    HintDialog {
        id: storageHint
        title: "Storage"
        message: "Book storage management and cache clearing are coming in the next release. Books currently save to your app's confined data directory."
    }

    // Reusable hint dialog component
    component HintDialog: Rectangle {
        id: hintRoot
        property string title: ""
        property string message: ""

        anchors.fill: parent
        color: "#CC000000"
        visible: false
        z: 10

        MouseArea {
            anchors.fill: parent
            onClicked: hintRoot.visible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: units.gu(36)
            height: dialogColumn.height + units.gu(4)
            radius: units.gu(1)
            color: root.isDarkMode ? "#1E1E1E" : "#FFFFFF"

            Behavior on color { ColorAnimation { duration: 250 } }

            Column {
                id: dialogColumn
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: units.gu(3)
                }
                spacing: units.gu(2)

                Label {
                    text: hintRoot.title
                    fontSize: "large"
                    color: root.isDarkMode ? "#FFFFFF" : "#212121"
                    font.weight: Font.Medium
                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                Label {
                    width: parent.width
                    text: hintRoot.message
                    wrapMode: Text.WordWrap
                    fontSize: "small"
                    color: root.isDarkMode ? "#AAAAAA" : "#555555"
                    lineHeight: 1.4
                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                Button {
                    text: "Got it"
                    color: "#2C5F2E"
                    width: parent.width
                    onClicked: hintRoot.visible = false
                }
            }
        }
    }
}