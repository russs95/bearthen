import base64
import functools
import http.server
import os
import platform
import socket
import subprocess
import threading
import time

try:
    import pyotherside
except ImportError:
    pyotherside = None

_proc = None

# Serves platform/touch/assets/ over http://127.0.0.1:<port>/ — started once,
# lazily, and never stopped (unlike the per-book streamer subprocess). Exists
# because the Readium harness page (assets/readium/reader-readium.html) must
# itself be loaded over http://, not file://: Chromium hard-blocks fetch()
# from a file:// origin to any other origin (it isn't in the small list of
# schemes CORS permits as a *source* — no response header can override this,
# unlike an ordinary cross-origin block). The epub.js path never needed this
# because reader.html doesn't fetch() anything cross-origin.
_static_httpd = None
_static_port = None
_static_lock = threading.Lock()


def _binary_path():
    """Return path to the r2-streamer binary, or None if not found."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    app_root   = os.path.dirname(script_dir)          # py/ lives one level below app root

    # Click package install: postbuild.sh copies the arch binary here as plain "r2-streamer"
    click_bin = os.path.join(app_root, 'bin', 'r2-streamer')
    if os.path.isfile(click_bin):
        return click_bin

    # Dev / desktop fallback: core/streamer/bin/r2-streamer-<arch>
    machine = platform.machine()
    if machine == 'aarch64':
        suffix = 'arm64'
    elif machine.startswith('armv7'):
        suffix = 'armhf'
    else:
        suffix = 'amd64'
    dev_bin = os.path.normpath(
        os.path.join(app_root, '..', '..', 'core', 'streamer', 'bin',
                     'r2-streamer-' + suffix)
    )
    if os.path.isfile(dev_bin):
        return dev_bin

    return None


def _find_free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


def _poll_ready(port, timeout=10.0):
    """Block until the streamer accepts a TCP connection, or timeout elapses."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            conn = socket.create_connection(('127.0.0.1', port), timeout=0.5)
            conn.close()
            return True
        except OSError:
            pass
        time.sleep(0.2)
    return False


# Explicit extension -> Content-Type map for the static server. Deliberately
# NOT relying on the stdlib `mimetypes` module: SimpleHTTPRequestHandler's
# default guess_type() lazily reads /etc/mime.types (and other system paths)
# on first call to build its lookup table, and that read is denied under the
# click app's AppArmor confinement (PermissionError: /etc/mime.types) —
# caught on real hardware; it crashed the request mid-response, and the
# WebView just saw net::ERR_EMPTY_RESPONSE with no indication why.
_MIME_TYPES = {
    '.html': 'text/html',
    '.htm':  'text/html',
    '.js':   'application/javascript',
    '.mjs':  'application/javascript',
    '.css':  'text/css',
    '.json': 'application/json',
    '.svg':  'image/svg+xml',
    '.png':  'image/png',
    '.jpg':  'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.woff':  'font/woff',
    '.woff2': 'font/woff2',
    '.ttf':   'font/ttf',
}


class _StaticHandler(http.server.SimpleHTTPRequestHandler):
    def guess_type(self, path):
        ext = os.path.splitext(str(path))[1].lower()
        return _MIME_TYPES.get(ext, 'application/octet-stream')

    def log_message(self, format, *args):
        pass  # silence per-request stderr logging — noisy in clickable logs


def _ensure_static_server():
    """Start the assets/ static file server on first use; idempotent."""
    global _static_httpd, _static_port
    with _static_lock:
        if _static_httpd is not None:
            return _static_port
        script_dir = os.path.dirname(os.path.abspath(__file__))
        app_root   = os.path.dirname(script_dir)
        assets_dir = os.path.join(app_root, 'assets')
        handler = functools.partial(_StaticHandler, directory=assets_dir)
        httpd = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
        _static_port = httpd.server_address[1]
        _static_httpd = httpd
        threading.Thread(target=httpd.serve_forever, daemon=True).start()
        return _static_port


def _manifest_url(port, fs_path):
    """Build the manifest URL for the given served file.

    NOTE: the binary's own --help text advertises the pattern
    '<port>/<base64url path>/manifest.json', but that is stale — the actual
    readium/cli router (pkg/serve/router.go) mounts publications under
    '/webpub/{path}/manifest.json', and the path segment is
    base64.RawURLEncoding (urlsafe, no padding) of the filename, decoded
    server-side in pkg/serve/auth/encoded.go. Confirmed against a live
    instance of the bundled binary — the documented pattern 404s.
    """
    basename = os.path.basename(fs_path)
    token = base64.urlsafe_b64encode(basename.encode('utf-8')).decode('ascii').rstrip('=')
    return 'http://127.0.0.1:' + str(port) + '/webpub/' + token + '/manifest.json'


def _run(epub_path, port, binary):
    global _proc
    try:
        # Strip file:// prefix so os.path.dirname gives a real filesystem path
        fs_path = epub_path[7:] if epub_path.startswith('file://') else epub_path
        epub_dir = os.path.dirname(fs_path) or '.'

        # readium serve -a 127.0.0.1 -p <port> --file-directory <dir>
        # The server exposes all EPUBs in epub_dir.
        cmd = [binary, 'serve', '-a', '127.0.0.1', '-p', str(port),
               '--file-directory', epub_dir]
        _proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        if _poll_ready(port):
            static_port = _ensure_static_server()
            if pyotherside:
                pyotherside.send('streamer_ready', port, _manifest_url(port, fs_path), static_port)
        else:
            rc = _proc.poll()
            msg = 'streamer did not come up on port ' + str(port)
            if rc is not None:
                _, err = _proc.communicate()
                if err:
                    msg += ': ' + err.decode('utf-8', errors='replace').strip()[:200]
            if pyotherside:
                pyotherside.send('streamer_error', msg)
            stop()

    except Exception as e:
        if pyotherside:
            pyotherside.send('streamer_error', str(e))


def start(epub_path):
    stop()
    binary = _binary_path()
    if not binary:
        if pyotherside:
            pyotherside.send('streamer_error',
                             'r2-streamer binary not found (arch=' + platform.machine() + ')')
        return
    port = _find_free_port()
    threading.Thread(target=_run, args=(epub_path, port, binary), daemon=True).start()


def stop():
    global _proc
    if _proc is not None:
        try:
            _proc.terminate()
            _proc.wait(timeout=3)
        except Exception:
            try:
                _proc.kill()
            except Exception:
                pass
        _proc = None