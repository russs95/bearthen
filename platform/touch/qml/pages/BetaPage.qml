import QtQuick 2.12
import Ubuntu.Components 1.3

Page {
    id: betaPage

    property string status1:  "idle"  // PyOtherSide loads — set by pyRunner Loader
    property string status2:  "idle"  // subprocess module
    property string status25: "idle"  // ctypes dlopen libm
    property string status26: "idle"  // Popen from app dir
    property string status3:  "idle"  // Popen /bin/true (system path)
    property string status4:  "idle"  // Popen go-hello-arm64
    property string _log:     "[tap Run Exec Test to start]"
    property bool   _running: false

    function appendLog(msg) { _log += "\n" + msg; console.log("BetaTest: " + msg) }

    function onTestResult(step, result, msg) {
        appendLog(msg)
        if      (step === 2)  status2  = result
        else if (step === 25) status25 = result
        else if (step === 26) status26 = result
        else if (step === 3)  status3  = result
        else if (step === 4)  { status4 = result; _running = false }
    }

    function runAllTests() {
        if (status1 !== "pass") {
            _log = "[FAIL] PyOtherSide not loaded — cannot run.\n" +
                   "See setup plan: PyOtherSide must be installed on device."
            return
        }
        _running = true
        status2 = "running"; status3 = "idle"; status4 = "idle"
        _log = Qt.formatDateTime(new Date(), "hh:mm:ss") + " — starting exec spike...\n"
        pyRunner.item.runTests()
    }

    // ── PyOtherSide isolated loader ───────────────────────────────────────────
    // Loader isolates the `import io.thp.pyotherside` so if it fails the page
    // degrades gracefully rather than refusing to load.
    Loader {
        id: pyRunner
        source: Qt.resolvedUrl("BetaPyRunner.qml")
        onStatusChanged: {
            if (status === Loader.Ready) {
                betaPage.status1 = "pass"
            } else if (status === Loader.Error) {
                betaPage.status1 = "fail"
                betaPage._log = "[FAIL] Step 1: io.thp.pyotherside not importable.\n" +
                    "Install python3-pyotherside on device, or add pyotherside\n" +
                    "as a dependency in clickable.yaml."
            }
        }
    }

    // ── Header ────────────────────────────────────────────────────────────────
    header: PageHeader {
        id: betaHeader
        height: units.gu(6.7)

        contents: Item {
            anchors.fill: parent
            Column {
                anchors {
                    top: parent.top; topMargin: units.gu(0.4) + units.dp(5)
                    left: parent.left; leftMargin: units.gu(0.45)
                }
                spacing: -units.dp(3)

                Row {
                    spacing: 0
                    Label { text: "B";       font.pixelSize: units.gu(2.6); font.weight: Font.Light;  color: "#4CAF50" }
                    Label { text: "earthen"; font.pixelSize: units.gu(2.6); font.weight: Font.Medium; color: "#4CAF50" }
                }
                Row {
                    spacing: units.dp(4)
                    Label { text: "Beta";    font.pixelSize: units.gu(1.7); font.weight: Font.Medium; color: "#CC2222" }
                    Label { text: "Testing"; font.pixelSize: units.gu(1.7); font.weight: Font.Light;  color: "#CC2222" }
                }
            }
        }

        StyleHints {
            backgroundColor: root.isDarkMode ? "#1A1A1A" : "#F5F5F5"
            dividerColor: "#CC2222"
        }
    }

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: root.isDarkMode ? "#121212" : "#FFFFFF"
        Behavior on color { ColorAnimation { duration: 250 } }
    }

    // ── Scrollable content ────────────────────────────────────────────────────
    Flickable {
        anchors {
            top: betaHeader.bottom; left: parent.left
            right: parent.right;   bottom: parent.bottom
        }
        contentHeight: mainCol.height + units.gu(4)
        clip: true

        Column {
            id: mainCol
            width: parent.width
            spacing: 0

            // ── Banner ────────────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: bannerCol.height + units.gu(5)
                color: root.isDarkMode ? "#1F0808" : "#FFF5F5"
                Behavior on color { ColorAnimation { duration: 250 } }

                Column {
                    id: bannerCol
                    anchors {
                        top: parent.top; topMargin: units.gu(2.5)
                        left: parent.left; right: parent.right
                        leftMargin: units.gu(2.5); rightMargin: units.gu(2.5)
                    }
                    spacing: units.gu(1.2)

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: units.gu(5); height: units.gu(5)
                        name: "torch-on"; color: "#CC2222"
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Step 0 — AppArmor Exec Spike"
                        font.pixelSize: units.gu(2.1); font.weight: Font.Medium
                        color: root.isDarkMode ? "#EE6666" : "#AA1111"
                    }

                    Label {
                        width: parent.width; wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        text: "Tests whether a click-confined Python process can exec a static Go binary via subprocess.Popen(). This is the single gate the entire Bearthen 2.0 architecture depends on."
                        fontSize: "small"; lineHeight: 1.5
                        color: root.isDarkMode ? "#AAAAAA" : "#555555"
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                }
            }

            // ── Test step rows ────────────────────────────────────────────────
            TestRow {
                stepNum: "1"; title: "PyOtherSide loads"
                desc: "import io.thp.pyotherside 1.4 succeeds in QML"
                rowStatus: betaPage.status1
            }
            TestRow {
                stepNum: "2"; title: "subprocess module"
                desc: "import subprocess inside PyOtherSide Python runtime"
                rowStatus: betaPage.status2
            }
            TestRow {
                stepNum: "2.5"; title: "ctypes dlopen"
                desc: "ctypes.CDLL(\"libm.so.6\") — dlopen without fork/exec"
                rowStatus: betaPage.status25
            }
            TestRow {
                stepNum: "2.6"; title: "Popen from app dir"
                desc: "exec go-hello-arm64 from app's own install dir (adb push needed)"
                rowStatus: betaPage.status26
            }
            TestRow {
                stepNum: "3"; title: "Popen /bin/true"
                desc: "subprocess.Popen([\"/bin/true\"]) — system binary, outside app dir"
                rowStatus: betaPage.status3
            }
            TestRow {
                stepNum: "4"; title: "Popen go-hello-arm64"
                desc: "exec the bundled static Go binary (needs bin/ in click package)"
                rowStatus: betaPage.status4
            }

            // ── Run button ────────────────────────────────────────────────────
            Item { width: parent.width; height: units.gu(2.5) }

            Rectangle {
                anchors { left: parent.left; right: parent.right; margins: units.gu(2.5) }
                height: units.gu(6); radius: units.dp(12)
                color: _running ? "#881111" : "#CC2222"
                Behavior on color { ColorAnimation { duration: 150 } }

                Label {
                    anchors.centerIn: parent
                    text: _running ? "Running…" : "Run Exec Test"
                    font.pixelSize: units.gu(2); font.weight: Font.Medium
                    color: "#FFFFFF"
                }

                MouseArea {
                    anchors.fill: parent; enabled: !_running
                    onClicked: betaPage.runAllTests()
                }
            }

            // ── Terminal log output ───────────────────────────────────────────
            Item { width: parent.width; height: units.gu(2) }

            Rectangle {
                anchors { left: parent.left; right: parent.right; margins: units.gu(2) }
                height: logLabel.height + units.gu(3); radius: units.dp(8)
                color: "#0D0D0D"
                border.color: "#2A2A2A"; border.width: units.dp(1)

                Label {
                    id: logLabel
                    anchors {
                        top: parent.top; left: parent.left; right: parent.right
                        topMargin: units.gu(1.5); leftMargin: units.gu(1.5); rightMargin: units.gu(1.5)
                    }
                    text: _log
                    font.pixelSize: units.dp(12); font.family: "Ubuntu Mono"
                    color: "#33DD33"; wrapMode: Text.Wrap; lineHeight: 1.4
                }
            }

            Item { width: parent.width; height: units.gu(4) }
        }
    }

    // ── TestRow inline component ──────────────────────────────────────────────
    component TestRow: Item {
        property string stepNum:   "?"
        property string title:     ""
        property string desc:      ""
        property string rowStatus: "idle"  // idle | running | pass | fail | skip

        width: mainCol.width; height: units.gu(8)

        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: units.dp(1)
            color: root.isDarkMode ? "#2A2A2A" : "#EEEEEE"
        }

        Item {
            anchors { fill: parent; leftMargin: units.gu(2); rightMargin: units.gu(2) }

            Rectangle {
                id: stepCircle
                width: units.gu(3.2); height: units.gu(3.2); radius: width / 2
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                color: rowStatus === "pass"    ? "#2C5F2E"
                     : rowStatus === "fail"    ? "#CC2222"
                     : rowStatus === "running" ? "#8B5A32"
                     : rowStatus === "skip"    ? "#8B5A32"
                     : (root.isDarkMode ? "#333333" : "#CCCCCC")
                Behavior on color { ColorAnimation { duration: 200 } }

                Label {
                    anchors.centerIn: parent; text: stepNum
                    font.pixelSize: units.gu(1.5); font.weight: Font.Medium
                    color: rowStatus === "idle"
                        ? (root.isDarkMode ? "#888888" : "#888888")
                        : "#FFFFFF"
                }
            }

            Column {
                anchors {
                    left: stepCircle.right; leftMargin: units.gu(1.5)
                    right: statusIcon.left; rightMargin: units.gu(1)
                    verticalCenter: parent.verticalCenter
                }
                spacing: units.gu(0.3)

                Label {
                    text: title; fontSize: "medium"; font.weight: Font.Medium
                    color: root.isDarkMode ? "#DDDDDD" : "#333333"
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
                Label {
                    text: desc; fontSize: "x-small"; color: "#888888"
                    width: parent.width; wrapMode: Text.WordWrap
                }
            }

            Icon {
                id: statusIcon
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: units.gu(2.5); height: units.gu(2.5)
                name: rowStatus === "pass"    ? "tick"
                    : rowStatus === "fail"    ? "close"
                    : rowStatus === "skip"    ? "media-skip-forward"
                    : rowStatus === "running" ? "sync-updating"
                    : "media-record"
                color: rowStatus === "pass"    ? "#4CAF50"
                     : rowStatus === "fail"    ? "#CC2222"
                     : rowStatus === "skip"    ? "#8B5A32"
                     : rowStatus === "running" ? "#AAAAAA"
                     : "#555555"
            }
        }
    }
}
