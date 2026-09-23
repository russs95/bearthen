import sys
import os


def check_subprocess():
    try:
        import subprocess
        ver = sys.version.split()[0]
        return {"status": "pass", "msg": "[PASS] Step 2: subprocess available (Python " + ver + ")"}
    except Exception as e:
        return {"status": "fail", "msg": "[FAIL] Step 2: " + str(e)}


def check_ctypes_dlopen():
    try:
        import ctypes
        # libm is always present on Ubuntu Touch — tests dlopen without any exec
        lib = ctypes.CDLL("libm.so.6")
        lib.sqrt.restype = ctypes.c_double
        lib.sqrt.argtypes = [ctypes.c_double]
        result = lib.sqrt(ctypes.c_double(9.0))
        return {"status": "pass", "msg": "[PASS] Step 2.5: ctypes dlopen works, sqrt(9)=" + str(result)}
    except Exception as e:
        return {"status": "fail", "msg": "[FAIL] Step 2.5: ctypes dlopen blocked: " + str(e)}


def check_popen_true():
    try:
        import subprocess
        p = subprocess.Popen(["/bin/true"])
        ret = p.wait()
        return {"status": "pass", "msg": "[PASS] Step 3: Popen(/bin/true) exit=" + str(ret)}
    except Exception as e:
        return {"status": "fail", "msg": "[FAIL] Step 3: " + str(e)}


def check_popen_app_dir():
    try:
        import subprocess
        # Writable data dir — adb-pushable without root
        data_dir = os.path.join(os.path.expanduser("~"), ".local", "share",
                                "bearthen.russs95")
        go_bin   = os.path.join(data_dir, "bin", "go-hello-arm64")

        if not os.path.exists(go_bin):
            return {
                "status": "skip",
                "msg": "[SKIP] Step 2.6: binary not found at " + go_bin +
                       "\n       Run: adb push go-hello-arm64 "
                       "/home/phablet/.local/share/bearthen.russs95/bin/"
            }

        p = subprocess.Popen([go_bin], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, _ = p.communicate(timeout=5)
        return {"status": "pass",
                "msg": "[PASS] Step 2.6: exec from writable data dir works! out=" +
                       out.decode("utf-8", errors="replace").strip()}
    except Exception as e:
        return {"status": "fail",
                "msg": "[FAIL] Step 2.6: exec from writable data dir blocked: " + str(e)}


def check_popen_go():
    try:
        import subprocess
        # Path: qml/py/betatest.py -> qml/py/ -> qml/ -> app_root/ -> bin/
        script_dir = os.path.dirname(os.path.abspath(__file__))
        app_root   = os.path.dirname(os.path.dirname(script_dir))
        go_bin     = os.path.join(app_root, "bin", "go-hello-arm64")

        if not os.path.exists(go_bin):
            return {
                "status": "skip",
                "msg": "[SKIP] Step 4: binary not found at " + go_bin +
                       "\n       Compile go-hello-arm64 and add to click package."
            }

        p = subprocess.Popen([go_bin], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = p.communicate(timeout=5)
        out_str = out.decode("utf-8", errors="replace").strip()
        return {
            "status": "pass",
            "msg": "[PASS] Step 4: Go binary exit=" + str(p.returncode) + ' out="' + out_str + '"'
        }
    except Exception as e:
        return {"status": "fail", "msg": "[FAIL] Step 4: " + str(e)}
