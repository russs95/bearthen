import QtQuick 2.12
import Ubuntu.Components 1.3

PageHeader {
    id: appHeader

    StyleHints {
        backgroundColor: typeof root !== "undefined" && root.isDarkMode ? "#1A1A1A" : "#F5F5F5"
        dividerColor: "#2C5F2E"
    }
}
