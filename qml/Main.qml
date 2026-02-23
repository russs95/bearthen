import QtQuick 2.12
import Ubuntu.Components 1.3
import "pages"
import "i18n/en.js" as LangEn
import "i18n/id.js" as LangId
import "i18n/iu.js" as LangIu

MainView {
    id: root
    objectName: "mainView"
    applicationName: "bearthen.russs95"
    width: units.gu(45)
    height: units.gu(80)

    property int    currentPage:     0
    property bool   isDarkMode:      true
    property bool   isLoggedIn:      false
    property string userName:        ""
    property string currentLanguage: "en"

    property var availableLanguages: [
        { code: "en", nativeName: "English",   englishName: "English"    },
        { code: "id", nativeName: "Indonesia", englishName: "Indonesian" },
        { code: "iu", nativeName: "ᐃᓄᒃᑎᑐᑦ",  englishName: "Inuktitut"  }
    ]

    function t(key) {
        var langStrings
        if      (currentLanguage === "id") langStrings = LangId.strings
        else if (currentLanguage === "iu") langStrings = LangIu.strings
        else                               langStrings = LangEn.strings
        if (langStrings && langStrings[key] !== undefined) return langStrings[key]
        if (LangEn.strings && LangEn.strings[key] !== undefined) return LangEn.strings[key]
        return key
    }

    theme.name: isDarkMode
        ? "Ubuntu.Components.Themes.SuruDark"
        : "Ubuntu.Components.Themes.Ambiance"

    // ── Pages declared first ──────────────────────────────────────────────────
    LibraryPage           { id: libraryPage       }
    DiscoverPage          { id: discoverPage      }
    BookDetailPage        { id: bookDetailPage    }
    LibraryBookDetailPage { id: libBookDetailPage }
    AccountPage           { id: accountPage       }
    SettingsPage          { id: settingsPage      }

    // ── Page stack ────────────────────────────────────────────────────────────
    PageStack {
        id: pageStack
        anchors {
            top: parent.top; left: parent.left; right: parent.right
            bottom: navBar.top
        }
        Component.onCompleted: pageStack.push(libraryPage)
    }

    // ── Bottom nav bar ────────────────────────────────────────────────────────
    Rectangle {
        id: navBar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: units.gu(8)
        color: root.isDarkMode ? "#1A1A1A" : "#F5F5F5"
        Behavior on color { ColorAnimation { duration: 250 } }

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: units.dp(1); color: "#2C5F2E"
        }

        Row {
            anchors.fill: parent

            Repeater {
                model: [
                    { icon: "stock_ebook", label: "Library"  },
                    { icon: "search",      label: "Discover" },
                    { icon: "account",     label: "Account"  },
                    { icon: "settings",    label: "Settings" }
                ]

                Item {
                    width: navBar.width / 4
                    height: navBar.height

                    Rectangle {
                        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
                        width: units.gu(4); height: units.dp(2)
                        radius: units.dp(1); color: "#2C5F2E"
                        visible: root.currentPage === index
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: units.gu(0.4)

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: units.gu(2.8); height: units.gu(2.8)
                            name: modelData.icon
                            color: root.currentPage === index ? "#4CAF50" : "#888888"
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.t(modelData.label)
                            fontSize: "x-small"
                            color: root.currentPage === index ? "#4CAF50" : "#888888"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.currentPage === index) return
                            root.currentPage = index
                            pageStack.clear()
                            switch (index) {
                                case 0: pageStack.push(libraryPage);  break
                                case 1: pageStack.push(discoverPage); break
                                case 2: pageStack.push(accountPage);  break
                                case 3: pageStack.push(settingsPage); break
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Splash screen — sits above everything ─────────────────────────────────
    Rectangle {
        id: splash
        anchors.fill: parent
        color: "#0A1A0A"
        z: 100
        visible: opacity > 0

        // Radial green glow behind the icon
        Rectangle {
            anchors.centerIn: parent
            width: units.gu(28); height: units.gu(28)
            radius: width / 2
            color: "transparent"

            // Inner glow layers
            Rectangle {
                anchors.centerIn: parent
                width: units.gu(24); height: units.gu(24)
                radius: width / 2
                color: "#0D2A0D"
            }
            Rectangle {
                anchors.centerIn: parent
                width: units.gu(18); height: units.gu(18)
                radius: width / 2
                color: "#112E11"
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: units.gu(2)

            // Bear/earth icon — using the app's ebook icon as stand-in
            // Replace with actual Bearthen SVG logo when available
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: units.gu(14); height: units.gu(14)
                name: "stock_ebook"
                color: "#4CAF50"

                // Gentle pulse on load
                SequentialAnimation on scale {
                    running: splash.visible
                    NumberAnimation { to: 1.06; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.00; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: units.gu(0.5)

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Bearthen"
                    fontSize: "x-large"
                    font.weight: Font.Light
                    color: "#FFFFFF"
                    font.letterSpacing: units.dp(3)
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "read freely"
                    fontSize: "small"
                    font.weight: Font.Light
                    color: "#4CAF50"
                    font.letterSpacing: units.dp(2)
                }
            }
        }

        // Earthen attribution at bottom
        Label {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: units.gu(4)
            }
            text: "an earthen project"
            fontSize: "x-small"
            color: "#2C5F2E"
            font.letterSpacing: units.dp(1)
        }

        // Fade out after 1.8s, then become invisible
        SequentialAnimation {
            id: splashAnim
            running: false

            PauseAnimation  { duration: 1800 }
            NumberAnimation {
                target: splash; property: "opacity"
                to: 0; duration: 600
                easing.type: Easing.InQuad
            }
        }

        Component.onCompleted: splashAnim.start()
    }
}