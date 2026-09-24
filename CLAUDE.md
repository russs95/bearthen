# CLAUDE.md — Bearthen EPUB Reader
> Technical reference for AI-assisted development. Read this before touching any file.

---

## What Bearthen Is

Bearthen is an EPUB reader for **Ubuntu Touch** (Lomiri shell), built as a **click package** using **QML + a WebView-based reader**. It is designed around the ecological ethos of the Igorot people of Northern Luzon and the Earthen Ethics framework of Banayan Angway and Russell Maier. The app also sells the EPUB edition of their foundational work *Tractatus Ayyew*.

**Package name:** `bearthen.russs95`  
**Writable data dir:** `/home/phablet/.local/share/bearthen.russs95/`  
**Install dir (read-only):** `/opt/click.ubuntu.com/bearthen.russs95/<version>/`  
**Cache dir:** `/home/phablet/.cache/bearthen.russs95/`

---

## Platform: Ubuntu Touch / Lomiri

This is **not** standard desktop Linux Qt. Key differences:

- **QML imports are Lomiri-flavoured.** Use `Ubuntu.Components 1.3`, `Ubuntu.Content 1.3`, `Morph.Web 0.1`. Do NOT use `Lomiri.Components` — that name is for newer builds not yet on all devices.
- **Build tool is `clickable`**, not cmake/make directly. `clickable build && clickable install` is the full deploy cycle.
- **AppArmor sandbox.** The app runs under a restrictive AppArmor profile declared in `bearthen.apparmor`. Network access, file access outside the home dir, and IPC are all gated. Content sharing goes through the ContentHub broker — you cannot simply `open()` a file path from another app.
- **Architecture target:** `aarch64` (arm64) — the PinePhone, Fairphone, and similar Ubuntu Touch devices.
- **Qt version is 5.6–5.12** depending on the device/OTA. Do not use Qt 6 APIs. Do not use C++17-only features in any native plugin.
- **No `QProcess`, no native file I/O plugin** available in pure QML click packages without a separate C++ plugin (which requires a manifest change and a compiled armhf/arm64 binary). All file operations must go through QML-available APIs.

---

## Project Structure

Stage 1 refactor complete. Build runs from `platform/touch/`.

```
bearthen/
├── platform/touch/               ← Ubuntu Touch click package root
│   ├── qml/
│   │   ├── Main.qml              # Root page, navBar, pageStack, isDarkMode, t() i18n
│   │   ├── pages/
│   │   │   ├── LibraryPage.qml   # Main library grid, EPUB import, About/Shop overlays
│   │   │   ├── ReaderPage.qml    # WebView wrapper for reader.html
│   │   │   ├── DiscoverPage.qml  # Gutenberg catalogue browser
│   │   │   ├── BookDetailPage.qml
│   │   │   └── SettingsPage.qml
│   │   ├── js/
│   │   │   └── Library.js        # All SQLite DB operations
│   │   └── components/
│   │       └── platform/
│   │           ├── AppWebView.qml      # Morph.Web wrapper
│   │           ├── AppFilePicker.qml   # Ubuntu.Content wrapper
│   │           └── AppHeader.qml      # PageHeader + StyleHints wrapper
│   ├── py/
│   │   └── betatest.py           # PyOtherSide exec spike tests
│   ├── assets/
│   │   ├── reader/               # epub.js reader, meta-probe, jszip
│   │   ├── textures/             # library SVG tiles (day + night)
│   │   ├── tractatus/            # Earthen Ethics book assets
│   │   └── fonts/                # Custom reading fonts
│   ├── clickable.yaml            # Build config — run clickable from here
│   ├── bearthen.apparmor
│   ├── bearthen.desktop
│   └── manifest.json
├── core/
│   ├── db/schema.sql             # Canonical schema reference
│   ├── reader/                   # (v2.0 Stage 2) R2D2BC reader bundle goes here
│   └── streamer/bin/             # (v2.0 Stage 3) r2-streamer-go binaries go here
└── docs/
```

---

## Library.js — The Database Layer

**Location:** `platform/touch/qml/js/Library.js`  
**Engine:** Qt's built-in `openDatabaseSync` (Web SQL / SQLite)  
**Import in QML:** `.import "../js/Library.js" as Library`

Always call `Library.init()` before any other Library function in a new execution context (e.g. after a page becomes visible). `init()` is idempotent — safe to call multiple times.

### Schema (books_tb)

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PRIMARY KEY | `"local_<hash>"` for local imports, numeric string for Gutenberg |
| `title` | TEXT | Updated by MetaProbe after import |
| `author_display` | TEXT | Updated by MetaProbe after import |
| `language` | TEXT | Two-letter code, e.g. `"en"` |
| `cover_url` | TEXT | **Data URI** (`data:image/jpeg;base64,...`) for local books. Qt Image supports data URIs natively since Qt 5.6. Can be 10–40KB of base64. |
| `cover_local` | TEXT | Bare file path (no `file://`) to a local image file |
| `cover` | TEXT | URL string for remote covers (Gutenberg) |
| `file_path` | TEXT | Full `file://` URL to the EPUB. For local imports this is under `.local/share/bearthen.russs95/books/` after a successful ContentHub move. |
| `epub_url` | TEXT | Remote HTTPS URL (Gutenberg books) |
| `source` | TEXT | `"local"` or `"gutenberg"` |
| `source_id` | TEXT | Bare path (no `file://`) for local, Gutenberg ID for remote |
| `category` | TEXT | Genre tag |
| `read_percent` | INTEGER | 0–100 |
| `is_finished` | INTEGER | 0 or 1 |
| `reader_fontsize` | TEXT | Persisted reader pref |
| `reader_fontfamily` | TEXT | Persisted reader pref |
| `reader_theme` | TEXT | Persisted reader pref |
| `reader_spacing` | TEXT | Persisted reader pref |
| `reader_margins` | TEXT | Persisted reader pref |

### Key functions

```javascript
Library.init()                          // Open/create DB, run migrations
Library.addBook(bookObj)                // Insert; returns true on success
Library.hasBook(id)                     // Returns true if id exists
Library.getBooks()                      // Returns array of all book objects
Library.getBook(id)                     // Returns single book object or null
Library.updateProgress(id, pct, done)   // Save read position
Library.updateBookMeta(id, title, author, language)  // From MetaProbe
Library.updateCoverDataUrl(id, dataUrl) // Save base64 cover thumbnail
Library.deleteBook(id)                  // Remove from DB
```

---

## ContentHub EPUB Import — Critical Quirks

This is the most failure-prone part of the app. Read carefully.

### The flow

1. User taps `+` → `ContentPeerPicker` (with `contentType: ContentType.Documents`) shows the Files app.
2. User picks an EPUB → `onPeerSelected` fires → `peer.request()` creates a `ContentTransfer`.
3. Transfer cycles through states: `0→1→2→3` (Charged) `→4`.
4. At state `3` (Charged = 3), `transfer.items[0].url` contains the staged file path.

### The HubIncoming staging problem

ContentHub stages the file at:
```
/home/phablet/.cache/bearthen.russs95/HubIncoming/<N>/<filename>.epub
```
**This is temporary.** ContentHub recycles `<N>` slots between transfers, and the system cache sweeper can remove files here at any time. **Never store this path as the permanent file_path.**

**Solution:** Call `items[0].move(destDir)` while the transfer is still `Charged`. This is synchronous and relocates the file to permanent storage:
```javascript
var booksDir = "/home/phablet/.local/share/bearthen.russs95/books/"
var moved = items[0].move(booksDir)
var finalUrl = moved ? ("file://" + booksDir + fname) : url
```
If `move()` returns false or throws, fall back to the staging URL (works this session only) and log loudly.

### Book ID stability

Hash the **bare filename**, not the full path:
```javascript
var id = "local_" + Math.abs(_simpleHash(fileName))
```
This ensures re-importing the same EPUB from a different `HubIncoming/<N>/` slot correctly detects "already in library" instead of creating a duplicate.

### Double `file://` bug (historical — already fixed)

`ContentHub` gives `file:///home/...`. ReaderPage used to prepend `"file://"` unconditionally, producing `file://file:///home/...`. The fix:
```javascript
src = (book.file_path.indexOf("file://") === 0)
      ? book.file_path        // already prefixed — use as-is
      : "file://" + book.file_path
```

---

## MetaProbe — Silent Metadata + Cover Extraction

**Files:** `assets/reader/meta-probe.html` + `metaProbeView` WebView in LibraryPage.qml

After a successful `addBook()`, a hidden 1×1 `WebView` loads `meta-probe.html?url=<epub>`. This page uses epub.js to parse the OPF metadata and extract the cover image, then signals back to QML via `document.title`.

### The `document.title` length limit

Qt WebView caps `document.title` at approximately **32KB**. A cover thumbnail as a JPEG base64 string is 10–40KB — easily truncated, breaking JSON.parse silently.

**Solution: two-signal chunked protocol**

`meta-probe.html` sends signals in this order:

1. `META:{"title":"...","author":"...","language":"en"}` — small JSON, always fits
2. `COVER_CHUNK:0/8:<6000 chars>`, `COVER_CHUNK:1/8:<6000 chars>`, … — cover split into 6KB chunks

QML reassembles chunks in `_coverChunks` string property, saves on receipt of the last chunk.

```javascript
// In LibraryPage.qml — metaProbeView.onTitleChanged
if (t.indexOf("META:") === 0) {
    // parse JSON, call Library.updateBookMeta(), refresh grid
} else if (t.indexOf("COVER_CHUNK:") === 0) {
    // parse N/T:slice, accumulate in _coverChunks
    // on last chunk: Library.updateCoverDataUrl(), refresh grid
}
```

### Why hidden WebView instead of pure JS zip parsing

- epub.js already handles OPF edge cases (encryption, namespace variants, obfuscated covers)
- JSZip + inflate decompressor would add ~45KB to bundle
- OPF XML regex parsing is fragile against real-world EPUBs
- The WebView approach reuses already-bundled `epub.min.js` and `jszip.min.js`

---

## ReaderPage — WebView Reader

**Files:** `qml/pages/ReaderPage.qml`, `assets/reader/reader.html`

The reader is a full HTML/CSS/JS application running inside `Morph.Web`'s WebView. It uses `epub.js` to render EPUB content into a paginated iframe.

### URL parameters passed to reader.html

```
reader.html?url=<encoded epub path>
           &title=<encoded title>
           &percent=<0-100>
           &vw=<logical pixels width>
           &vh=<logical pixels height minus bar>
           &needcover=<0|1>
           &fontsize=<value>
           &fontfamily=<family name>
           &theme=<theme name>
           &spacing=<value>
           &margins=<value>
```

`vw`/`vh` are passed explicitly because `100vh` inside a Morph.Web WebView includes system navigation bars, making CSS viewport units unreliable. QML's `webView.width` / `webView.height` are the source of truth.

### QML ↔ WebView communication

All signals flow via `document.title` changes caught by `webView.onTitleChanged`:

| Signal prefix | Direction | Meaning |
|---|---|---|
| `BARS:1` / `BARS:0` | JS → QML | Show/hide top/bottom reader bars |
| `HIDE_NAV:0` / `HIDE_NAV:1` | JS → QML | Show/hide bottom nav bar |
| `PROGRESS:<percent>` | JS → QML | Save read position to DB |
| `COVER:<dataUrl>` | JS → QML | Cover thumbnail (if `needcover=1`) — **NOTE: also subject to 32KB limit; use chunking if re-implementing** |
| `FONTSIZE:<val>`, `FONTFAMILY:<val>`, etc. | JS → QML | Persist reader prefs to DB |

After processing a signal, always clear the title:
```javascript
webView.runJavaScript("document.title=''")
```

### `needcover` parameter

ReaderPage passes `needcover=1` if the book has no stored cover yet. `reader.html` extracts the cover via `book.coverUrl()`, resizes it on a `<canvas>`, and reports `COVER:<dataUrl>`. This is a fallback for the MetaProbe path — ideally MetaProbe already grabbed the cover at import time.

---

## v2.0 Readium Streamer Launcher (in progress — see `docs/bearthen-2.0-roadmap.md` Stage 4/5/6)

**Files:** `platform/touch/py/reader_launcher.py`, `platform/touch/qml/components/platform/StreamerLauncher.qml`

`ReaderPage` loads `StreamerLauncher.qml` via a `Loader` (isolated so a missing `io.thp.pyotherside` degrades gracefully to epub.js-only). On `openBook()`, it calls `reader_launcher.start(epubPath)`, which spawns the bundled Go binary and signals back over PyOtherSide.

**The bundled binary is `readium/cli`** (`github.com/readium/cli`, wraps `readium/go-toolkit`), installed as `bin/r2-streamer` in the click package by `postbuild.sh`. It is **not** the archived `r2-streamer-go` the original roadmap named — that repo is unmaintained; `readium/cli` is the current tool. Two consequences for anyone touching the launcher:

- **No `/ping` endpoint.** `reader_launcher.py`'s `_poll_ready()` polls readiness with a raw TCP connect instead.
- **The binary's own `--help` text for the manifest URL is wrong.** It advertises `<port>/<base64url filename>/manifest.json`; the real route (confirmed against `readium/cli`'s `pkg/serve/router.go` and a live request) is **`<port>/webpub/<base64url filename>/manifest.json`**, `base64.RawURLEncoding` (urlsafe, no padding). `_manifest_url()` in `reader_launcher.py` builds this correctly and documents the discrepancy inline — don't trust the `--help` text if you're re-deriving this.

`start()` sends `pyotherside.send('streamer_ready', port, manifestUrl)` once the TCP poll succeeds; `StreamerLauncher.qml`'s `ready(port, manifestUrl)` signal carries both through to `ReaderPage._streamerPort` / `_streamerManifestUrl`, which now (2026-09-23, Step 7) triggers `ReaderPage._loadReadiumUrl(manifestUrl)` — see below.

### Readium Web JS shell — `core/readium/` + `platform/touch/assets/readium/`

Built and landed 2026-09-23 (Stage 5). It's `@d-i-t-a/reader` (R2D2BC's `D2Reader` class) — **not** `readium/web`/`ts-toolkit`, the toolkit nominally paired with our `readium/cli`-based streamer, because that ships as library-only pieces with no ready reader UI. R2D2BC is a drop-in reader with TOC/bookmarks/settings already built, and consumes the standard RWPM manifest format regardless of server, so it needed no adaptation. Trimmed and minified down to 2.3MB (from an unminified ~4.0MB) — see `core/readium/README.md` for full build provenance, what was dropped, and how to rebuild.

`core/readium/` is the canonical vendored copy; `platform/touch/assets/readium/` is a physical copy of it (same pattern as `assets/reader/` for epub.js — not staged/synced at build time, just duplicated) plus one Bearthen-authored file, `reader-readium.html`, the harness `ReaderPage`'s WebView actually loads. It parses `?manifest=`/`&title=`/`&percent=`/`&vw=`/`&vh=` params (same `getParam()` convention as `reader.html`), calls `D2Reader.load({ url: manifestUrl })`, and reuses the existing swipe-to-page / tap-to-toggle-bars UX and `document.title` signal protocol from `reader.html` — but only `BARS:`, `HIDE_NAV:1`, and a percent-only `POS:` (Readium locators aren't EPUB CFIs, so `cfi` is sent empty) are wired so far. Bookmarks, highlights, and font/theme settings are **not yet ported** to this path — `ReaderPage`'s `_pushBookmarks()`/`_pushHighlights()` calls still fire against it but silently no-op (the functions they call don't exist in this harness). That parity work is Stage 8.

**Load `reader.js` (IIFE global), never `esm/index.js` (ES module).** Caught on real hardware: `<script type="module">` + `import` fails silently when loaded via `file://` (as the WebView does) — `file://` carries no `Content-Type` header, and Chromium's strict MIME checking for module scripts rejects it (`non-JavaScript MIME type of ""`), so `D2Reader` never loads, `init()` never runs, and the book-ready signal never fires — the app's splash spinner just spins forever with no visible error. `reader-readium.html` loads `reader.js` via a plain `<script src="...">` tag instead (assigns `window.D2Reader`), which has no such restriction. See `core/readium/README.md` for the full writeup.

**The harness page itself must be loaded over `http://`, never `file://`.** Second real bug caught on hardware, distinct from the one above: even with the IIFE fix, `D2Reader.load()` still failed — `fetch()` (which it uses internally to load the manifest) throws `Access to fetch ... blocked by CORS policy: Cross origin requests are only supported for protocol schemes: http, data, chrome, ...` when the *page's own origin* is `file://`. This isn't a response-header problem (the streamer already sends `Access-Control-Allow-Origin: *`) — `file://` simply isn't in Chromium's fixed allow-list of schemes permitted to *initiate* a cross-origin `fetch()` at all, and no CORS header on the target can override that. Fix: `reader_launcher.py` now also starts a second, lightweight `http.server.ThreadingHTTPServer` (`_ensure_static_server()`) serving `platform/touch/assets/` over `http://127.0.0.1:<staticPort>/` — started once, lazily, on first book open, and never stopped (unlike the per-book streamer subprocess). Its port rides along in the existing `streamer_ready` signal (`pyotherside.send('streamer_ready', port, manifestUrl, staticPort)`); `ReaderPage._loadReadiumUrl()` builds `http://127.0.0.1:<staticPort>/readium/reader-readium.html?...` instead of a `file://` path.

**The static server must not use stdlib `mimetypes` for Content-Type guessing.** Third real bug caught on hardware: `http.server.SimpleHTTPRequestHandler`'s default `guess_type()` lazily reads `/etc/mime.types` (and other system paths) the first time it's called, to build its lookup table — and that path is outside what the confined click app can read (`PermissionError: [Errno 13] Permission denied: '/etc/mime.types'`), which crashes the request handler mid-response and surfaces to the WebView as an opaque `net::ERR_EMPTY_RESPONSE` with no indication why. Fixed with `_StaticHandler`, a `SimpleHTTPRequestHandler` subclass in `reader_launcher.py` that overrides `guess_type()` with a small explicit extension map (`_MIME_TYPES`) instead — never touches `mimetypes` or the filesystem for this. Also overrides `log_message()` to silence per-request stderr logging (was flooding `clickable logs`).

**Touch/tap handlers must bind to an overlay div, not `document`, because D2Reader renders the book inside an `<iframe>`.** Fourth real bug caught on hardware (2026-09-24): with the first three fixed, the book finally rendered (title page + text visible) — but tapping did nothing; no bars, no page turns. `reader-readium.html` had `document.addEventListener('touchstart'/'touchend', ...)`, but touches landing on the book content happen inside D2Reader's iframe, and iframe events never bubble to the parent document (it's a separate document — this isn't Readium-specific, it's how iframes always work). `reader.html` (epub.js) already solved this correctly with `#touch-layer`, a transparent `position: fixed; inset: 0; z-index: 10` div sitting *above* the iframe that intercepts all touches before they reach it. `reader-readium.html` now does the same — added `#touch-layer` and moved the touch listeners onto it instead of `document`.

### `ReaderPage` Readium branch (`_useReadium`)

`ReaderPage.qml` has a `_useReadium` property (default `true` — a debug flag per the roadmap's own suggestion, since `book.epub_version` isn't tracked in `books_tb` yet). When true and the book has a local `file_path` (Gutenberg/remote-only books always use epub.js — the streamer only serves local files today), `openBook()` skips the epub.js `urlLoadTimer` path and waits for the streamer's `ready` signal to call `_loadReadiumUrl()` instead. Three fallback paths exist so a Readium-eligible book never gets stuck on a blank screen: the streamer process erroring, the `StreamerLauncher.qml` `Loader` itself failing (e.g. `io.thp.pyotherside` missing), and (pre-existing) remote books skipping the branch entirely — all three fall back to `_loadReaderUrl()` (epub.js).

### Building/installing the arm64 click package with the streamer bundled

`clickable build --arch arm64` alone won't bundle the streamer — use `platform/touch/build-arm64.sh arm64`, which swaps in `clickable-arm64.yaml`/`manifest-arm64.json`, stages the right-arch binary from `core/streamer/bin/` into `platform/touch/.stage-bin/` (gitignored), builds, installs, then restores the original config. The staging step matters because `clickable build` runs `postbuild.sh` **inside a docker container that only bind-mounts `platform/touch/`** — a path reaching up to the repo-root `core/` dir (as the original `postbuild.sh` did) resolves fine on the host but silently doesn't exist in that container, so the binary would never get bundled. `postbuild.sh` checks `platform/touch/.stage-bin/` first, falling back to the repo-root path for host-side/non-container runs.

Do **not** pass `--container-mode` to `clickable build` on a normal dev machine — that flag means "the build tools are already present in this environment," but the `clickable` snap is strictly confined and can't see a host-installed `click` packaging tool, so the build fails with `click: command not found`. Let `clickable build` use its own docker image (the default) instead; only `clickable install` needs to run outside a container, to reach `adb`.

`clickable` (as a snap) and most of its invocations need a real TTY — if scripting/automating it, wrap with `script -qc "..." /dev/null` or similar, or it will hang indefinitely with no output.

---

## LibraryPage Visual Architecture

### TWEAKS block (top of LibraryPage.qml)

All layout constants are declared as `readonly property real` at the top of the file:

```qml
readonly property real headerHeight:    9     // *** HEADER HEIGHT *** — green divider position
readonly property real texOpacityDark:  0.07  // texture intensity, dark mode
readonly property real texOpacityLight: 0.05  // texture intensity, light mode
readonly property real texAspect:       1.0   // tile height/width ratio (1.0 = square)
```

Search for `***` in the file to jump to the primary tweak points.

### Header (PageHeader)

- `height: units.gu(headerHeight)` — the `height` property on `PageHeader` itself controls where the green divider line sits. `implicitHeight` on the `contents` Item does **not** propagate to `PageHeader` — this is a common Qt trap.
- `StyleHints.backgroundColor` controls the header fill colour (set to solid, same as nav bar — no texture).
- The wordmark column uses `verticalCenter: parent.verticalCenter` + `verticalCenterOffset` for reliable centering regardless of header height.

### SVG Texture Background

- File: `assets/textures/library-background.svg` — Keith Haring-inspired B&W line art, square proportions.
- Tiled via `Repeater { model: 25 }` inside a `Column` — 25 tiles fills any phone screen vertically.
- `height: width` on each tile (not a ratio) — locks aspect to 1:1, prevents vertical stretch.
- Applied to both the main library grid AND the About overlay.
- `texOpacityDark` / `texOpacityLight` control visibility. `fillMode: Image.Stretch` per tile.

### Book Card Colours (must be solid, not transparent)

Cards must be **opaque** so the texture shows in the gaps between cards but not through card content:

| Element | Dark | Light |
|---|---|---|
| Card body | `#222222` | `#EEEEEE` |
| Cover placeholder frame | `#2E2E2E` | `#E0E0E0` |

### Progress Bar Gradient

Brown (start/left) → Green (end/right) — Earthen → Growth direction:
```qml
GradientStop { position: 0.0; color: "#8B5A32" }  // brown
GradientStop { position: 1.0; color: "#2C5F2E" }  // green
```

---

## Colour Palette

| Name | Hex | Usage |
|---|---|---|
| Forest Green | `#2C5F2E` | Dividers, progress bar end, Gutenberg badges |
| Bright Green | `#4CAF50` | Wordmark "Bearthen", author names, icons |
| Dark Green (tagline) | `#1E5C22` / `#2C7A30` | "Read Books the Earthen Way" |
| Earthen Brown | `#8B5A32` | "My Library" subtitle, progress bar start |
| Dark bg | `#121212` | Page background, dark mode |
| Card dark | `#222222` | Book card body |
| Header dark | `#111111` | PageHeader + nav bar, dark mode |

---

## Typography / Wordmark

The app uses Ubuntu font family throughout. The **Bearthen wordmark** pattern:

- `"B"` → `Font.Medium`, green `#4CAF50`
- `"earthen"` → `Font.Medium`, green `#4CAF50`
- `"My"` → `Font.Light`, brown `#8B5A32`
- `"Library"` → `Font.Medium`, brown `#8B5A32`

The Light/Medium pairing (not Bold) is a deliberate design choice — it reads as refined rather than aggressive, fitting the ecological/contemplative aesthetic.

---

## AppArmor Notes

**File:** `bearthen.apparmor`

Current grants include:
- `content_exchange` — required for ContentHub EPUB import (ContentPeerPicker)
- `networking` — for Gutenberg catalogue fetching and Stripe purchase links
- Read access to the click install dir is implicit
- Write access to `.local/share/bearthen.russs95/` is implicit for click packages

**Do not need** to add permissions for:
- Reading your own bundled assets (fonts, SVG, HTML)
- SQLite DB (handled within your writable data dir)

**Would need** new permissions for:
- System fonts dir
- Other app data directories
- Bluetooth, camera, contacts, etc.

---

## Custom Fonts (Future Implementation)

Strategy for adding reading fonts to the app:

1. **Add TTF/OTF files** to `assets/fonts/`
2. **QML UI:** `FontLoader { source: Qt.resolvedUrl("../assets/fonts/Merriweather-Regular.ttf") }`
3. **reader.html:** Add `@font-face` declarations with `src: url('../fonts/...')` — relative to the HTML file
4. **epub.js integration:** Apply via `rendition.themes.register()` / `rendition.themes.select()`
5. **URL param:** Pass `&fontfamily=Merriweather` from ReaderPage; already handled
6. **DB persistence:** Already stored in `reader_fontfamily` column per book

Recommended open-license fonts for reading: Literata, Atkinson Hyperlegible, Merriweather, Source Serif 4.

---

## Common Mistakes to Avoid

| Mistake | Correct approach |
|---|---|
| `implicitHeight` on PageHeader contents Item | Set `height` directly on `PageHeader` |
| `"file://" + book.file_path` unconditionally | Check `indexOf("file://") === 0` first |
| Storing `HubIncoming/<N>/` path in DB | Call `items[0].move(booksDir)` first |
| Sending large data via `document.title` | Chunk into ≤6KB signals with `COVER_CHUNK:N/T:` protocol |
| Hashing full file path for book ID | Hash the bare filename for stable IDs across HubIncoming slots |
| `Lomiri.Components` import | Use `Ubuntu.Components 1.3` |
| Transparent card backgrounds over texture | Cards must be solid opaque — texture shows in gaps |
| `fillMode: Image.TileVertically` for SVG | Use a `Repeater` inside a `Column`; set `height: width` on each tile |
| `texAspect` ratio for tile height | Set `height: width` directly — ratio approach causes drift |
| `<script type="module">` + `import` in any WebView-loaded HTML | `file://` has no `Content-Type` header — module scripts fail MIME checking silently. Use a plain `<script src="...">` + IIFE/global build instead |
| A WebView page that `fetch()`es anything, loaded via `file://` | `file://` isn't in Chromium's allowed CORS-source-scheme list — no response header fixes it. Serve the page itself over `http://` (see `reader_launcher.py`'s static server) |
| Python's `http.server.SimpleHTTPRequestHandler` default `guess_type()` under confinement | Reads `/etc/mime.types` on first call — denied by AppArmor, crashes the request. Override `guess_type()` with an explicit extension map instead |
| Touch/click listeners on `document` in a WebView page whose content renders inside an `<iframe>` | Iframe events don't bubble to the parent document. Use a transparent overlay div positioned above the iframe instead (see `#touch-layer` in `reader.html`/`reader-readium.html`) |

---

## Build & Deploy

All build commands run from `platform/touch/`:

```bash
cd platform/touch
clickable build          # compile click package
clickable install        # push to connected device via ADB
clickable logs           # stream device logs (very useful)
clickable shell          # ADB shell into the device
```

SQLite DB location on device:
```bash
/home/phablet/.local/share/bearthen.russs95/Databases/
```

Inspect DB from shell:
```bash
sqlite3 /home/phablet/.local/share/bearthen.russs95/Databases/*.sqlite
.tables
SELECT id, title, author_display, length(cover_url) FROM books_tb;
```

Books permanent storage:
```bash
/home/phablet/.local/share/bearthen.russs95/books/
```