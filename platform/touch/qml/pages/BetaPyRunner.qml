import QtQuick 2.12
import io.thp.pyotherside 1.4

// Isolated component: PyOtherSide import lives here only.
// BetaPage uses a Loader so that if this import fails the page degrades
// gracefully instead of crashing entirely.
Item {
    id: pyRunner

    function runTests() {
        betaPage.status2 = "running"
        py.call("betatest.check_subprocess", [], function(r) {
            betaPage.onTestResult(2, r.status, r.msg)
            if (r.status !== "pass") return
            betaPage.status25 = "running"
            py.call("betatest.check_ctypes_dlopen", [], function(r25) {
                betaPage.onTestResult(25, r25.status, r25.msg)
                betaPage.status26 = "running"
                py.call("betatest.check_popen_app_dir", [], function(r26) {
                    betaPage.onTestResult(26, r26.status, r26.msg)
                    betaPage.status3 = "running"
                    py.call("betatest.check_popen_true", [], function(r3) {
                        betaPage.onTestResult(3, r3.status, r3.msg)
                        betaPage.status4 = "running"
                        py.call("betatest.check_popen_go", [], function(r4) {
                            betaPage.onTestResult(4, r4.status, r4.msg)
                        })
                    })
                })
            })
        })
    }

    Python {
        id: py

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("../../py/"))
            importModule("betatest", function() {
                betaPage.appendLog("betatest module loaded OK")
            })
        }

        onError: {
            betaPage.appendLog("[PYTHON ERROR] " + traceback)
            betaPage._running = false
        }
    }
}
