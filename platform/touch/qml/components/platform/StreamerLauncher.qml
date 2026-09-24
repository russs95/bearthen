import QtQuick 2.12
import io.thp.pyotherside 1.4

// Isolated component: PyOtherSide import lives here only.
// ReaderPage loads this via a Loader so that if io.thp.pyotherside is absent
// the app degrades gracefully (epub.js only) without crashing.
// Pattern mirrors BetaPyRunner.qml.
Item {
    id: streamerLauncher

    signal ready(int port, string manifestUrl, int staticPort)
    signal error(string message)

    property bool   _moduleReady: false
    property string _pendingEpub: ""

    function start(epubPath) {
        if (_moduleReady) {
            py.call("reader_launcher.start", [epubPath], function() {})
        } else {
            _pendingEpub = epubPath
        }
    }

    function stop() {
        py.call("reader_launcher.stop", [], function() {})
    }

    Python {
        id: py

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("../../../py/"))
            importModule("reader_launcher", function() {
                console.log("StreamerLauncher: reader_launcher module loaded")
                streamerLauncher._moduleReady = true
                if (streamerLauncher._pendingEpub !== "") {
                    py.call("reader_launcher.start",
                            [streamerLauncher._pendingEpub], function() {})
                    streamerLauncher._pendingEpub = ""
                }
            })
        }

        onReceived: {
            // pyotherside.send('streamer_ready', port, manifestUrl, staticPort)
            // pyotherside.send('streamer_error', message)
            if (data[0] === "streamer_ready") {
                console.log("StreamerLauncher: ready on port", data[1],
                            "manifest:", data[2], "static server port:", data[3])
                streamerLauncher.ready(data[1], data[2], data[3])
            } else if (data[0] === "streamer_error") {
                console.log("StreamerLauncher: error:", data[1])
                streamerLauncher.error(data[1])
            }
        }

        onError: {
            console.log("StreamerLauncher Python error:", traceback)
            streamerLauncher.error("Python error: " + traceback)
        }
    }
}
