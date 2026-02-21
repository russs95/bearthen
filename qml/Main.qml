import QtQuick 2.12
import Ubuntu.Components 1.3
import "pages"
import "components"

MainView {
    id: root
    objectName: "mainView"
    applicationName: "bearthen.russs95"

    width: units.gu(45)
    height: units.gu(80)

    // ── Theme ────────────────────────────────────────────────────────────────
    theme.name: "Ubuntu.Components.Themes.SuruDark"

    // ── App-wide state ───────────────────────────────────────────────────────
    property int currentPage: 0
    property bool isLoggedIn: false
    property string userName: ""

    // ── Page stack ───────────────────────────────────────────────────────────
    PageStack {
        id: pageStack
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: navBar.top
        }

        Component.onCompleted: {
            pageStack.push(libraryPage)
        }
    }

    // ── Pages (kept in memory for fast switching) ────────────────────────────
    LibraryPage  { id: libraryPage  }
    DiscoverPage { id: discoverPage }
    AccountPage  { id: accountPage  }
    SettingsPage { id: settingsPage }

    // ── Bottom navigation bar ────────────────────────────────────────────────
    NavBar {
        id: navBar
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        currentIndex: root.currentPage
        onNavigate: {
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