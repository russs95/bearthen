import QtQuick 2.12
import QtQuick.Window 2.2
import Ubuntu.Components 1.3
import "pages"
import "js/Library.js" as Library
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
    property bool   _isSliding:      false
    property bool   pageTurnEffect:  true
    property bool   _readerMode:     false

    // ── Reading List dialog — root-level so it overlays any pushed page ───────
    property bool   rlDialogVisible: false
    property var    _rlBook:         null
    property var    _rlLists:        []
    property bool   _rlShowCreate:   false
    property string _rlName:         ""

    function showRlDialog(book, forceCreate) {
        Library.init()
        _rlBook       = book
        _rlLists      = Library.getLists()
        _rlShowCreate = forceCreate || _rlLists.length === 0
        _rlName       = ""
        rlDialogVisible = true
    }

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

    function setReaderFullscreen(on) {
        _readerMode = on
        Window.window.visibility = on ? Window.FullScreen : Window.AutomaticVisibility
        // NOTE: when opening, root._readerMode and FullScreen are also set early in
        // openReader() before the loader fires, to avoid layout-measurement timing issues.
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
    BetaPage              { id: betaPage          }

    // ReaderPage lazy-loads via Loader — Morph.Web segfaults if the WebView
    // exists at startup. We activate on first use and respond via onLoaded.
    property var _pendingReaderBook: null

    Loader {
        id: readerLoader
        active: false
        source: "pages/ReaderPage.qml"
        onStatusChanged: {
            console.log("readerLoader status:", status,
                        status === Loader.Error ? "ERROR — check ReaderPage.qml" :
                        status === Loader.Ready ? "Ready" :
                        status === Loader.Loading ? "Loading" : "Null")
        }
        onLoaded: {
            // Item is fully created — safe to call methods and push
            if (root._pendingReaderBook) {
                item.openBook(root._pendingReaderBook)
                root._pendingReaderBook = null
            }
            pageStack.push(item)
        }
    }

    // Re-assert fullscreen when app returns to foreground during reading
    Connections {
        target: Qt.application
        onActiveChanged: {
            if (Qt.application.active && root._readerMode)
                fullscreenRestoreTimer.restart()
        }
    }
    Timer {
        id: fullscreenRestoreTimer
        interval: 200
        repeat: false
        onTriggered: if (root._readerMode) Window.window.visibility = Window.FullScreen
    }

    // Called by LibraryBookDetailPage — activates loader or pushes immediately
    function openReader(book) {
        console.log("openReader called, book:", book ? book.id : "null",
                    "loader status:", readerLoader.status)
        // Set reader mode immediately so navBar hides and layout starts updating
        // BEFORE the loader fires (which is synchronous) or the page is pushed.
        root._readerMode = true
        Window.window.visibility = Window.FullScreen
        if (readerLoader.status === Loader.Ready) {
            readerLoader.item.openBook(book)
            pageStack.push(readerLoader.item)
        } else {
            root._pendingReaderBook = book
            readerLoader.active = true
            console.log("openReader: activating loader, pending book:", book.id)
        }
    }

    function doNavSlide(targetIndex, direction) {
        if (root._isSliding) return
        if (!root.pageTurnEffect) {
            pageStack.clear()
            switch (targetIndex) {
                case 0: pageStack.push(libraryPage);  break
                case 1: pageStack.push(discoverPage); break
                case 2: pageStack.push(accountPage);  break
                case 3: pageStack.push(settingsPage); break
            }
            root.currentPage = targetIndex
            return
        }
        root._isSliding = true
        pageWrapper.grabToImage(function(result) {
            transitionSnapshot.source  = result.url
            transitionSnapshot.x       = 0
            transitionSnapshot.visible = true
            pageStack.clear()
            switch (targetIndex) {
                case 0: pageStack.push(libraryPage);  break
                case 1: pageStack.push(discoverPage); break
                case 2: pageStack.push(accountPage);  break
                case 3: pageStack.push(settingsPage); break
            }
            root.currentPage = targetIndex
            pageStack.x = direction > 0 ? pageWrapper.width : -pageWrapper.width
            snapshotSlideAnim.to = direction > 0 ? -pageWrapper.width : pageWrapper.width
            snapshotSlideAnim.start()
            pageSlideInAnim.start()
        })
    }

    // ── Page stack ────────────────────────────────────────────────────────────
    Item {
        id: pageWrapper
        anchors { top: parent.top; left: parent.left; right: parent.right
                  bottom: navBar.top }
        clip: true

        PageStack {
            id: pageStack
            anchors { top: parent.top; bottom: parent.bottom }
            width: parent.width
            Component.onCompleted: pageStack.push(libraryPage)
        }

        SwipeArea {
            anchors.fill: parent
            direction: SwipeArea.Leftwards
            enabled: pageStack.depth === 1
            onDraggingChanged: {
                if (!dragging && root.currentPage < 3 && !root._isSliding) {
                    doNavSlide(root.currentPage + 1, 1)
                }
            }
        }
        SwipeArea {
            anchors.fill: parent
            direction: SwipeArea.Rightwards
            enabled: pageStack.depth === 1
            onDraggingChanged: {
                if (!dragging && root.currentPage > 0 && !root._isSliding) {
                    doNavSlide(root.currentPage - 1, -1)
                }
            }
        }

        Image {
            id: transitionSnapshot
            anchors { top: parent.top; bottom: parent.bottom }
            width: parent.width
            fillMode: Image.Stretch
            visible: false
            cache: false
            z: 5
        }
    }

    PropertyAnimation {
        id: snapshotSlideAnim
        target: transitionSnapshot; property: "x"
        duration: 280; easing.type: Easing.InOutCubic
        onStopped: {
            transitionSnapshot.visible = false
            transitionSnapshot.source  = ""
            root._isSliding = false
        }
    }

    PropertyAnimation {
        id: pageSlideInAnim
        target: pageStack; property: "x"
        to: 0; duration: 280; easing.type: Easing.InOutCubic
    }

    // ── Bottom nav bar ────────────────────────────────────────────────────────
    // Height drives show/hide — when height is 0, navBar.top == parent.bottom
    // so pageWrapper fills the full screen. No separate cover rect needed.
    // Nav is hidden whenever a detail/reader page is pushed (depth > 1).
    Rectangle {
        id: navBar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: pageStack.depth <= 1 ? units.gu(8) : 0
        clip: true
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
                        radius: units.dp(1); color: "#6B3A20"
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
                            if (root._isSliding || index === root.currentPage) return
                            doNavSlide(index, index > root.currentPage ? 1 : -1)
                        }
                    }
                }
            }
        }
    }

    // ── Reading List dialog — overlays any page in the stack ─────────────────
    Rectangle {
        id: rootRlOverlay
        anchors.fill: parent
        color: "#88000000"
        visible: root.rlDialogVisible
        z: 200
        MouseArea { anchors.fill: parent; onClicked: root.rlDialogVisible = false }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - units.gu(6)
            height: rootRlCol.implicitHeight + units.gu(6)
            color: root.isDarkMode ? "#1C1C1C" : "#FFFFFF"
            radius: units.dp(14)
            clip: true
            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
                id: rootRlCol
                anchors {
                    top: parent.top; left: parent.left; right: parent.right
                    topMargin: units.gu(3)
                    leftMargin: units.gu(2.5); rightMargin: units.gu(2.5)
                }
                spacing: units.gu(1.5)

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root._rlShowCreate ? "New Reading List" : "Add to Reading List"
                    font.pixelSize: units.gu(2.3); font.weight: Font.Light
                    color: root.isDarkMode ? "#DDDDDD" : "#333333"
                }

                // Existing lists picker
                Item {
                    visible: !root._rlShowCreate && root._rlLists.length > 0
                    width: parent.width
                    height: visible ? Math.min(rootRlInner.implicitHeight, units.gu(28)) : 0
                    clip: true

                    Flickable {
                        id: rootRlFlick
                        anchors.fill: parent
                        contentHeight: rootRlInner.implicitHeight
                        contentWidth: width
                        clip: true

                        Column {
                            id: rootRlInner
                            width: rootRlFlick.width

                            Repeater {
                                model: root._rlLists
                                delegate: Item {
                                    width: rootRlInner.width
                                    height: units.gu(6.5)

                                    Rectangle {
                                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                        height: units.dp(1)
                                        color: root.isDarkMode ? "#2A2A2A" : "#EEEEEE"
                                    }
                                    Row {
                                        anchors { verticalCenter: parent.verticalCenter
                                                  left: parent.left; leftMargin: units.gu(0.5) }
                                        spacing: units.gu(1.5)
                                        Icon {
                                            width: units.gu(2.5); height: units.gu(2.5)
                                            name: "view-list-symbolic"; color: "#8B5A32"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Label {
                                            text: modelData.name
                                            font.pixelSize: units.gu(1.9)
                                            color: root.isDarkMode ? "#DDDDDD" : "#333333"
                                            anchors.verticalCenter: parent.verticalCenter
                                            elide: Text.ElideRight
                                            width: rootRlFlick.width - units.gu(11)
                                        }
                                    }
                                    Label {
                                        anchors { right: parent.right; rightMargin: units.gu(0.5)
                                                  verticalCenter: parent.verticalCenter }
                                        text: modelData.book_ids && modelData.book_ids.length > 0
                                              ? modelData.book_ids.length
                                                + (modelData.book_ids.length === 1 ? " book" : " books")
                                              : "empty"
                                        font.pixelSize: units.gu(1.6)
                                        color: root.isDarkMode ? "#666666" : "#AAAAAA"
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (!root._rlBook) { root.rlDialogVisible = false; return }
                                            Library.init()
                                            Library.addToList(modelData.id, root._rlBook.id)
                                            root.rlDialogVisible = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Name input (creator state)
                Rectangle {
                    visible: root._rlShowCreate
                    width: parent.width
                    height: root._rlShowCreate ? units.gu(5.5) : 0
                    radius: units.dp(8)
                    color: root.isDarkMode ? "#2A2A2A" : "#F2F2F2"
                    border.color: rootRlInput.activeFocus ? "#4CAF50" : "#2C5F2E"
                    border.width: units.dp(1)
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    TextInput {
                        id: rootRlInput
                        anchors { verticalCenter: parent.verticalCenter
                                  left: parent.left; right: parent.right
                                  leftMargin: units.gu(1.5); rightMargin: units.gu(1.5) }
                        text: root._rlName
                        onTextChanged: root._rlName = text
                        color: root.isDarkMode ? "#DDDDDD" : "#333333"
                        font.pixelSize: units.gu(1.9)
                        clip: true
                        Label {
                            anchors.fill: parent
                            text: "List name..."
                            font.pixelSize: units.gu(1.9)
                            color: root.isDarkMode ? "#555555" : "#BBBBBB"
                            visible: rootRlInput.text.length === 0
                        }
                    }
                }

                // "New List" button (picker state)
                Rectangle {
                    visible: !root._rlShowCreate
                    width: parent.width
                    height: !root._rlShowCreate ? units.gu(5.5) : 0
                    radius: units.dp(10)
                    color: root.isDarkMode ? "#2A2A2A" : "#F2F2F2"
                    border.color: "#2C5F2E"; border.width: units.dp(1)
                    Row {
                        anchors.centerIn: parent; spacing: units.gu(0.8)
                        Icon {
                            width: units.gu(2.2); height: units.gu(2.2)
                            name: "add"; color: "#2C5F2E"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Label {
                            text: "New List"
                            font.pixelSize: units.gu(1.9); font.weight: Font.Medium
                            color: "#2C5F2E"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { root._rlName = ""; root._rlShowCreate = true }
                    }
                }

                // Cancel / Back + Create buttons
                Row {
                    width: parent.width; spacing: units.gu(1)

                    Rectangle {
                        width: root._rlShowCreate
                               ? (parent.width - units.gu(1)) / 2 : parent.width
                        height: units.gu(5.5); radius: units.dp(10)
                        color: root.isDarkMode ? "#2A2A2A" : "#E8E8E8"
                        Label {
                            anchors.centerIn: parent
                            text: (root._rlShowCreate && root._rlLists.length > 0) ? "Back" : "Cancel"
                            font.pixelSize: units.gu(1.9); font.weight: Font.Medium
                            color: root.isDarkMode ? "#AAAAAA" : "#666666"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root._rlShowCreate && root._rlLists.length > 0) {
                                    root._rlShowCreate = false; root._rlName = ""
                                } else {
                                    root.rlDialogVisible = false; root._rlName = ""
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: root._rlShowCreate
                        width: root._rlShowCreate ? (parent.width - units.gu(1)) / 2 : 0
                        height: units.gu(5.5); radius: units.dp(10)
                        color: root._rlName.trim().length > 0 ? "#2C5F2E" : "#1A3A1A"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Label {
                            anchors.centerIn: parent; text: "Create"
                            font.pixelSize: units.gu(1.9); font.weight: Font.Medium
                            color: root._rlName.trim().length > 0 ? "#FFFFFF" : "#444444"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var name = root._rlName.trim()
                                if (name.length === 0) return
                                Library.init()
                                var newId = Library.createList(name, "")
                                if (root._rlBook && newId)
                                    Library.addToList(newId, root._rlBook.id)
                                root.rlDialogVisible = false
                                root._rlName = ""
                            }
                        }
                    }
                }

                Item { width: 1; height: units.gu(0.5) }
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

        // Large radial glow — three concentric circles, bigger than before
        Rectangle {
            anchors.centerIn: parent
            width: units.gu(44); height: units.gu(44)
            radius: width / 2; color: "#0C1F0C"
        }
        Rectangle {
            anchors.centerIn: parent
            width: units.gu(36); height: units.gu(36)
            radius: width / 2; color: "#0F280F"
        }
        Rectangle {
            anchors.centerIn: parent
            width: units.gu(26); height: units.gu(26)
            radius: width / 2; color: "#132E13"
        }

        // Title + tagline centred on screen
        Column {
            anchors.centerIn: parent
            spacing: units.gu(1.2)

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Bearthen"
                font.pixelSize: units.dp(54)
                font.weight: Font.Light
                color: "#FFFFFF"
                font.letterSpacing: units.dp(4)
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Read the Earthen way"
                fontSize: "medium"
                font.weight: Font.Light
                color: "#4CAF50"
                font.letterSpacing: units.dp(3)
            }
        }

        // "by Earthen Labs" pill — earthen brown, pinned near the bottom
        Rectangle {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: units.gu(5)
            }
            height: units.gu(3.2)
            width: byLabel.width + units.gu(2.4)
            radius: height / 2
            color: "#8B5E3C"

            Label {
                id: byLabel
                anchors.centerIn: parent
                text: "by Earthen Labs"
                fontSize: "x-small"
                font.weight: Font.Medium
                color: "#FFFFFF"
                font.letterSpacing: units.dp(1)
            }
        }

        // Fade out after 1.8s
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