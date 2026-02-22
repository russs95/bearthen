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

    property int currentPage: 0
    property bool isDarkMode: true
    property bool isLoggedIn: false
    property string userName: ""
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

    PageStack {
        id: pageStack
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: navBar.top
        }
        Component.onCompleted: pageStack.push(libraryPage)
    }

    LibraryPage  { id: libraryPage  }
    DiscoverPage { id: discoverPage }
    AccountPage  { id: accountPage  }
    SettingsPage { id: settingsPage }

    Rectangle {
        id: navBar
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: units.gu(8)
        color: root.isDarkMode ? "#1A1A1A" : "#F5F5F5"
        Behavior on color { ColorAnimation { duration: 250 } }

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: units.dp(1)
            color: "#2C5F2E"
        }

        Row {
            anchors.fill: parent

            Repeater {
                model: [
                    { icon: "stock_ebook", code: "Library"  },
                    { icon: "search",      code: "Discover" },
                    { icon: "account",     code: "Account"  },
                    { icon: "settings",    code: "Settings" }
                ]

                Item {
                    width: navBar.width / 4
                    height: navBar.height

                    Column {
                        anchors.centerIn: parent
                        spacing: units.gu(0.4)

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: units.gu(2.8)
                            height: units.gu(2.8)
                            name: modelData.icon
                            color: currentPage === index ? "#4CAF50" : "#888888"
                        }

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.t(modelData.code)
                            fontSize: "x-small"
                            color: currentPage === index ? "#4CAF50" : "#888888"
                        }
                    }

                    Rectangle {
                        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
                        width: units.gu(4)
                        height: units.dp(2)
                        radius: units.dp(1)
                        color: "#2C5F2E"
                        visible: currentPage === index
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            currentPage = index
                            pageStack.clear()
                            switch(index) {
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
}
