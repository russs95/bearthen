import QtQuick 2.12
import Ubuntu.Components 1.3

Rectangle {
    id: navBar

    // ── Public API ───────────────────────────────────────────────────────────
    property int currentIndex: 0
    signal navigate(int index)

    // ── Dimensions ───────────────────────────────────────────────────────────
    height: units.gu(8)
    color: "#1A1A1A"

    // ── Top border accent ────────────────────────────────────────────────────
    Rectangle {
        id: topAccent
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: units.dp(1)
        color: "#2C5F2E"
    }

    // ── Navigation items ─────────────────────────────────────────────────────
    Row {
        id: navRow
        anchors {
            top: topAccent.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        // ── Library tab ──────────────────────────────────────────────────────
        NavItem {
            id: libraryTab
            width: navRow.width / 4
            height: navRow.height
            iconName: "book"
            label: "Library"
            isActive: navBar.currentIndex === 0
            onTapped: navBar.navigate(0)
        }

        // ── Discover tab ─────────────────────────────────────────────────────
        NavItem {
            id: discoverTab
            width: navRow.width / 4
            height: navRow.height
            iconName: "search"
            label: "Discover"
            isActive: navBar.currentIndex === 1
            onTapped: navBar.navigate(1)
        }

        // ── Account tab ──────────────────────────────────────────────────────
        NavItem {
            id: accountTab
            width: navRow.width / 4
            height: navRow.height
            iconName: "contact"
            label: "Account"
            isActive: navBar.currentIndex === 2
            onTapped: navBar.navigate(2)
        }

        // ── Settings tab ─────────────────────────────────────────────────────
        NavItem {
            id: settingsTab
            width: navRow.width / 4
            height: navRow.height
            iconName: "settings"
            label: "Settings"
            isActive: navBar.currentIndex === 3
            onTapped: navBar.navigate(3)
        }
    }

    // ── NavItem sub-component ────────────────────────────────────────────────
    component NavItem: Item {
        property string iconName: ""
        property string label: ""
        property bool isActive: false
        signal tapped()

        // Active indicator bar at top of tab
        Rectangle {
            id: activeIndicator
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            width: units.gu(4)
            height: units.dp(2)
            radius: units.dp(1)
            color: "#2C5F2E"
            visible: isActive
            Behavior on visible {
                NumberAnimation { duration: 150 }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: units.gu(0.4)

            Icon {
                id: navIcon
                anchors.horizontalCenter: parent.horizontalCenter
                width: units.gu(2.8)
                height: units.gu(2.8)
                name: iconName
                color: isActive ? "#4CAF50" : "#888888"

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }

            Label {
                id: navLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: label
                fontSize: "x-small"
                color: isActive ? "#4CAF50" : "#888888"

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
        }

        // Touch area
        MouseArea {
            anchors.fill: parent
            onClicked: parent.tapped()

            // Press feedback
            Rectangle {
                anchors.fill: parent
                color: "#2C5F2E"
                opacity: parent.pressed ? 0.15 : 0.0
                Behavior on opacity {
                    NumberAnimation { duration: 100 }
                }
            }
        }
    }
}