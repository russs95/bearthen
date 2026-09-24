# Bearthen 2.0 / 2.1 / 2.2 / 2.3 — Full Platform Roadmap

> **Status (2026-09-24):** Stages 1 and 3–6 done, all confirmed on real hardware (Pixel 3a). Stage 6 in particular — a real EPUB actually opening and paginating through the Readium/`D2Reader` engine, not just epub.js — is confirmed working: cover + reflowable text render, swipe turns pages, tap toggles the top bar. Getting there surfaced four distinct real bugs along the way (all fixed — see the note under Stage 6 and `CLAUDE.md`'s "Readium Web JS shell" section). **Next: Stage 8** (TOC/bookmark/settings controls for the Readium path — currently missing, not broken; see the scope note under Stage 8).
> **v2.0:** Ubuntu Touch — Readium + r2-streamer-go (arm64 + armhf)
> **v2.1:** Bearthen Sync — Buwana SSO + cloud library at reader.earthen.io
> **v2.2:** Ubuntu Desktop — Electron snap with Buwana sync built in
> **v2.3:** e-ink Hardware — Raspberry Pi 3B+ kiosk with Buwana sync built in
>
> One repository. One reader engine. One identity. Four deployment targets.

---

## Confirmed: The Architecture Works... yeay!!!!

A full AppArmor exec spike was run on a live Google Pixel 3XL (arm64, Ubuntu Touch 24.04)
before any v2 development began. All critical unknowns are resolved.

| Test | Result | Notes |
|---|---|---|
| PyOtherSide loads (`io.thp.pyotherside 1.4`) | **PASS** | Pre-installed on Ubuntu Touch |
| `import subprocess` inside Python runtime | **PASS** | Python 3.12.3 on device |
| `ctypes.CDLL()` / dlopen | **PASS** | libm.so.6, sqrt(9)=3.0 |
| `subprocess.Popen` from writable data dir | **PASS** | `~/.local/share/bearthen.russs95/bin/` |
| `subprocess.Popen` from click install dir | **PASS** | `/opt/click.ubuntu.com/bearthen.russs95/` |
| `subprocess.Popen` of system binary (`/bin/true`) | Expected fail | AppArmor restricts exec to app dirs — correct |
| Go 1.24.3 arm64 binary runs on device | **PASS** | "hello from go go1.24.3 on linux/arm64" |

**Key finding:** AppArmor allows exec from the app's own directories. No special permissions
needed beyond what v1.x already uses.

---

## Target Architecture: One Repo, Four Platforms

```
bearthen/
│
├── core/                          ← 100% shared across all platforms
│   ├── reader/
│   │   ├── reader.html            ← epub.js reader
│   │   ├── meta-probe.html        ← silent metadata + cover extractor
│   │   ├── epub.min.js
│   │   └── jszip.min.js
│   ├── readium/                   ← R2D2BC dist (built in v2.0 Stage 5)
│   ├── db/
│   │   └── schema.sql             ← canonical schema reference
│   └── streamer/
│       └── bin/
│           ├── r2-streamer-arm64  ← Ubuntu Touch + Pi 3B+ (arm64)
│           ├── r2-streamer-armhf  ← older UT devices
│           └── r2-streamer-x86_64 ← Ubuntu Desktop
│
├── platform/
│   ├── touch/                     ← Ubuntu Touch (QML + PyOtherSide)
│   │   ├── qml/
│   │   │   ├── Main.qml
│   │   │   ├── pages/
│   │   │   │   └── AccountPage.qml  ← placeholder ready; activated in v2.1
│   │   │   ├── components/
│   │   │   │   └── platform/        ← AppWebView, AppFilePicker, AppHeader
│   │   │   └── py/
│   │   ├── assets/
│   │   ├── clickable.yaml
│   │   ├── manifest.json
│   │   └── bearthen.apparmor
│   │
│   ├── electron/                  ← Ubuntu Desktop (v2.2)
│   │   ├── src/
│   │   │   ├── main.js
│   │   │   ├── preload.js
│   │   │   └── renderer/
│   │   │       ├── index.html
│   │   │       ├── library.js
│   │   │       ├── account.js
│   │   │       └── styles/
│   │   │           ├── main.css
│   │   │           └── eink.css   ← e-ink overrides (v2.3)
│   │   ├── package.json
│   │   └── snapcraft.yaml
│   │
│   ├── eink/                      ← Pi 3B+ kiosk (v2.3) — lightweight wrapper
│   │   ├── launch.sh              ← starts server + Chromium kiosk
│   │   ├── gpio-buttons.py        ← systemd service, GPIO → keyboard events
│   │   ├── bearthen.service       ← systemd unit
│   │   └── setup.sh               ← Pi provisioning script
│   │
│   └── server/                    ← Cloud sync server — reader.earthen.io
│       ├── src/
│       │   ├── server.js
│       │   ├── routes/
│       │   │   ├── auth.js
│       │   │   ├── sync.js
│       │   │   └── books.js
│       │   ├── db/
│       │   │   └── pool.js
│       │   └── middleware/
│       │       └── requireUser.js
│       ├── package.json
│       └── .env.example
│
└── docs/
```

The `core/` directory is the heart of Bearthen. Every improvement to the reader engine
benefits all four targets simultaneously.

---

## Project Goals

### Package Size Targets

| Target | Goal |
|---|---|
| v2.0 Ubuntu Touch arm64 only | ≤ 22 MB |
| v2.0 Ubuntu Touch arm64 + armhf | ≤ 36 MB |
| v2.2 Electron snap | ≤ 150 MB (Electron runtime dominates) |
| v2.3 Pi 3B+ SD card | ≤ 2 GB total OS + app footprint on 8 GB card |

Strip all Go binaries at build time: `GOFLAGS="-ldflags=-s -ldflags=-w"`

### AppArmor Permission Goal (Ubuntu Touch)

**No new permissions required beyond v1.x.** `networking` + `webview` cover everything,
including Buwana OAuth2 HTTP calls and the r2-streamer localhost server.

---

## Why Upgrade? The Case for Readium

epub.js serves v1.x well for Gutenberg's EPUB 2 catalogue but has a real ceiling:

| Limitation | Impact |
|---|---|
| EPUB 3 support partial | Audio, video, MathML, complex layouts break |
| Fixed-layout unsupported | Illustrated books, manga, comics don't work |
| RTL / vertical text fragile | Arabic, Hebrew, Japanese readers underserved |
| No Media Overlays | Read-aloud / accessibility features impossible |
| CSS injection unreliable | Some EPUBs fight dark theme via `!important` wars |

Readium is the W3C reference implementation of EPUB 3, backed by EDRLab. It runs
identically in Morph.Web, Electron, and a Pi kiosk browser — one JS bundle, all platforms.

---

## v2.0 — Ubuntu Touch

### Stage 1 — Repository Refactor

**Goal:** Restructure into `core/` + `platform/touch/` so all subsequent platforms
can be added without touching Ubuntu Touch code.
**Estimated effort:** 1–2 days | **Tokens:** ~200–300K

**This is a structural refactor only. v1.x epub.js functionality must remain
100% operational after Stage 1 completes.**

Everything the v1.x user depends on — epub.js reader, ContentHub EPUB import,
Gutenberg catalogue, library grid, book detail, settings, dark mode, progress
saving, MetaProbe metadata extraction — continues to work unchanged. The refactor
moves files into new paths and abstracts three platform-specific components, but
the Ubuntu Touch build output is byte-for-byte equivalent to the pre-refactor build.

**Non-regression checklist — must pass before Stage 1 is considered done:**

- [ ] `clickable build --arch arm64` produces a passing `.click` package
- [ ] App installs and launches on device
- [ ] Library grid displays existing books with covers and progress bars
- [ ] ContentHub EPUB import completes and book appears in library
- [ ] epub.js reader opens a local EPUB and renders correctly
- [ ] epub.js reader opens a Gutenberg book and renders correctly
- [ ] Swipe navigation, auto-hide controls, and progress saving work
- [ ] Dark mode toggle works on all pages
- [ ] MetaProbe extracts title, author, and cover thumbnail after import
- [ ] Settings page saves and restores font/theme preferences

**File moves:**

| From | To |
|---|---|
| `assets/reader/` | `core/reader/` |
| `assets/textures/`, `assets/fonts/` | `platform/touch/assets/` |
| `js/Library.js` | `platform/touch/qml/js/Library.js` |
| `qml/` | `platform/touch/qml/` |
| `qml/py/` | `platform/touch/py/` |
| `clickable.yaml`, `manifest.json`, `bearthen.apparmor`, `bearthen.desktop` | `platform/touch/` |
| `bin/` | `core/streamer/bin/` |

**Create canonical schema reference** at `core/db/schema.sql` — the cloud sync
server (v2.1) and Electron (v2.2) will both derive their schemas from this file.

**Create platform wrapper components** — three thin QML files that isolate all
platform-specific imports so pages never import `Morph.Web` or `Ubuntu.Content`
directly:

```
platform/touch/qml/components/platform/
├── AppWebView.qml      ← import Morph.Web 0.1
├── AppFilePicker.qml   ← import Ubuntu.Content 1.3
└── AppHeader.qml       ← import Ubuntu.Components 1.3; PageHeader + StyleHints
```

Run the non-regression checklist in full before proceeding to Stage 2.

---

### Stage 2 — arm64 Packaging

**Goal:** click package that bundles a pre-compiled arm64 binary alongside pure QML
**Estimated effort:** 0.5–1 day | **Tokens:** ~50–100K

Switch from the `pure` builder to the `script` builder. `build.sh` copies QML/assets
and the Go binary into the install directory. `manifest.json` uses `$ENV{CLICK_ARCH}`.

Build command:
```bash
clickable build --arch arm64 && clickable install --arch arm64
```

---

### Stage 3 — Cross-Compile r2-streamer-go

**Goal:** Stripped binaries for all target architectures
**Estimated effort:** 0.5–1 day | **Tokens:** ~30–50K

```bash
# arm64 — Pixel 3XL, PinePhone, Fairphone 3/4, Pi 3B+
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" \
  -o core/streamer/bin/r2-streamer-arm64 github.com/readium/r2-streamer-go/...

# armhf — BQ Aquaris, Meizu, Fairphone 2, Nexus 4/5
GOOS=linux GOARCH=arm GOARM=7 CGO_ENABLED=0 go build -ldflags="-s -w" \
  -o core/streamer/bin/r2-streamer-armhf github.com/readium/r2-streamer-go/...

# x86_64 — Ubuntu Desktop Electron (v2.2)
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w" \
  -o core/streamer/bin/r2-streamer-x86_64 github.com/readium/r2-streamer-go/...
```

Pin to a specific release tag. `CGO_ENABLED=0` produces fully static binaries.

---

### Stage 4 — PyOtherSide Reader Launcher

**Goal:** Python subprocess launch of the streamer, port signalling back to QML
**Estimated effort:** 1–2 days | **Tokens:** ~100–150K

`platform/touch/py/reader_launcher.py` finds a free port, spawns the correct arch
binary, polls readiness, and signals `streamer_ready` back to QML via
`pyotherside.send()`. Selects binary based on `platform.machine()`:
`'aarch64'` → arm64, `'armv7l'` → armhf.

> ✅ **Done — confirmed on real hardware (2026-09-23).** Two corrections to the
> spec above: the bundled binary is `readium/cli`, not `r2-streamer-go`, and
> has no `/ping` endpoint — `reader_launcher.py` polls readiness with a raw
> TCP connect instead. It also builds the manifest URL itself
> (`streamer_ready` now sends `(port, manifestUrl)`), since the binary's own
> `--help` text advertises a stale URL pattern that 404s — see
> `bearthen-2-step-by-step.md` Step 4/6 for the full writeup.
>
> Tested end-to-end on a Pixel 3a (`sargo`, Ubuntu Touch 24.04, arm64): opening
> a book in the installed, AppArmor-confined click package launches
> `r2-streamer-arm64` via `subprocess.Popen()`, binds a free port, serves the
> manifest, and signals QML — with no `exec`-related AppArmor denial in
> `dmesg`. This is the production binary under real confinement, not the
> earlier spike's toy binary, so the roadmap's biggest open risk ("v1.x
> AppArmor blocks Go exec") is now closed.

---

### Stage 5 — Bundle Readium Web JS

**Goal:** R2D2BC reader shell built and placed in `core/readium/`
**Estimated effort:** 1 day | **Tokens:** ~50–75K

```bash
git clone https://github.com/d-i-t-a/R2D2BC
cd R2D2BC && npm install && npm run build
cp -r dist/ ../core/readium/
```

Monitor package size against the ≤ 22 MB arm64 target after this stage.

> ✅ **Done (2026-09-23).** `core/readium/` now holds a built, trimmed,
> minified R2D2BC (`@d-i-t-a/reader` / `D2Reader`) bundle — **2.3MB**, well
> under budget. See `core/readium/README.md` for full build provenance and
> the R2D2BC-vs-`readium/web` evaluation (the "officially paired" toolkit for
> our `readium/cli`-based streamer turned out to be a library-only toolkit
> requiring a custom reader UI; R2D2BC is a drop-in reader shell and consumes
> the same standard RWPM manifest format regardless of server, so it works
> unmodified). Verified end-to-end with a headless-Chrome screenshot test:
> `D2Reader.load()` pointed at a local `r2-streamer-amd64 serve` instance's
> manifest URL rendered the real book cover and parsed its 9-item TOC.
> WebView integration into `ReaderPage` is Stage 6 (Step 7), not yet done.

---

### Stage 6 — Connect ReaderPage

**Goal:** WebView loads Readium for EPUB 3; epub.js fallback for EPUB 2 intact
**Estimated effort:** 1–2 days | **Tokens:** ~150–200K

EPUB version detected at import time and stored in `books_tb`. ReaderPage branches
on `book.epub_version >= 3.0`. The existing `document.title` signal protocol
(`BARS:`, `HIDE_NAV:`, `PROGRESS:`, `FONTSIZE:`, etc.) maps to Readium Web JS events.

> ✅ **Done, confirmed on physical hardware (2026-09-24).** `ReaderPage`
> now branches to a new harness page, `platform/touch/assets/readium/
> reader-readium.html`, which loads `D2Reader` against the streamer's manifest
> URL — instead of `book.epub_version >= 3.0` (not yet tracked in `books_tb`),
> a `_useReadium` debug flag (default `true`) forces the branch for every
> local EPUB while the streamer is available, per the step-by-step plan's own
> suggestion for this stage. Falls back to epub.js automatically on any
> streamer/launcher failure, and Gutenberg (remote-only) books always use
> epub.js regardless of the flag, since the streamer only serves local files
> today.
>
> Getting this working on real hardware surfaced four distinct, real bugs
> (not device flakiness) — all fixed and documented in `CLAUDE.md`'s
> "Readium Web JS shell" section and `core/readium/README.md`: (1) ES module
> `<script type="module">` fails MIME checking over `file://` — switched to
> R2D2BC's IIFE build; (2) `file://` pages can't `fetch()` cross-origin at
> all in Chromium (not a CORS-header problem) — `reader_launcher.py` now
> also runs a small static HTTP server so the harness itself loads over
> `http://`; (3) Python's `http.server` default MIME guesser reads
> `/etc/mime.types`, denied under AppArmor — replaced with an explicit
> extension map; (4) touch/tap listeners on `document` don't fire for taps
> landing inside D2Reader's iframe — added a `#touch-layer` overlay div,
> the same pattern `reader.html` already used for epub.js.
>
> **Confirmed working on a Pixel 3a**: book renders (cover + reflowable
> text), swipe left/right turns pages, tap toggles the QML top bar.
> **Not yet working** (expected — scoped out of this stage, see Stage 8
> below): the TOC and bookmark buttons call `readerToc.toggle()` /
> `readerBookmarks.save()`, objects `reader.html` defines for itself that
> `reader-readium.html` has no equivalent of yet; there's also no in-page
> settings panel (font/theme/spacing) at all in the Readium harness — that
> whole panel is `reader.html`'s own hand-built HTML/CSS/JS, not a
> Readium/D2Reader feature, and needs an equivalent built from scratch for
> the Readium path. Only `BARS:`, `HIDE_NAV:1` (book-ready), and a
> percent-only `POS:` (no CFI — Readium locators aren't EPUB CFIs) are wired
> so far.

---

### Stage 7 — Process Lifecycle Management

**Goal:** Streamer starts, stays alive, cleans up across suspend/resume
**Estimated effort:** 1–2 days | **Tokens:** ~100–150K

Follow Sturmreader's proven pattern: restart on every book open (~200 ms Go startup).
QML connects to Lomiri's `Qt.application.state` to call `ensure_stopped()` on suspend
and relaunch on resume.

---

### Stage 8 — Readium Theme and Mobile UX

**Goal:** Reader as polished as v1.x
**Estimated effort:** 2–3 days | **Tokens:** ~150–200K

Readium CSS custom properties replace epub.js `!important` injection. Font size,
family, theme, and spacing map to `--RS__*` variables injected via `runJavaScript`.
Swipe navigation and progress reporting carry forward from v1.x. A small
CFI → percentage conversion layer maintains the existing `read_percent` field.

> **Scope clarified 2026-09-24, after Stage 6 confirmed on hardware.** Swipe
> navigation and bars-toggle already carry forward (done in Stage 6). What's
> actually missing, concretely: `reader-readium.html` needs `readerToc` and
> `readerBookmarks` objects (or equivalents) so the existing QML TOC/bookmark
> buttons work — they currently call into globals that don't exist in the
> Readium harness and silently no-op. It also needs an entire settings panel
> built from scratch: `reader.html`'s font-size/family/theme/spacing controls
> are its own hand-built in-page HTML/CSS/JS, not something Readium/D2Reader
> provides — there's no equivalent markup in `reader-readium.html` at all yet.
> D2Reader's own API (`tableOfContents`, bookmarks, `applyUserSettings()`) is
> already available to build all of this on top of; it just hasn't been done.

---

### Stage 9 — armhf Older Device Support

**Goal:** Single click package serving both arm64 and armhf Ubuntu Touch devices
**Estimated effort:** 1–2 days | **Tokens:** ~50–75K

Ubuntu Touch's most historically significant devices — BQ Aquaris and Meizu phones
that shipped pre-installed with Ubuntu Touch — are armhf. These are the devices Ubuntu
Touch is ideally suited for: giving new life to hardware Android has abandoned.

The armhf binary is already compiled in Stage 3. This stage adds it to `build.sh`
and tests on physical armhf hardware (Fairphone 2 or BQ Aquaris recommended).
`reader_launcher.py` already branches on `platform.machine()` — no Python or QML
changes needed.

---

### v2.0 Effort Summary

| Stage | Description | Effort | Tokens (est.) |
|---|---|---|---|
| 1 | Repository refactor | 1–2 days | ~200–300K |
| 2 | arm64 packaging (script builder) | 0.5–1 day | ~50–100K |
| 3 | Cross-compile r2-streamer-go | 0.5–1 day | ~30–50K |
| 4 | PyOtherSide reader launcher | 1–2 days | ~100–150K |
| 5 | Bundle Readium Web JS | 1 day | ~50–75K |
| 6 | Connect ReaderPage | 1–2 days | ~150–200K |
| 7 | Process lifecycle | 1–2 days | ~100–150K |
| 8 | Readium theme & mobile UX | 2–3 days | ~150–200K |
| 9 | armhf older device support | 1–2 days | ~50–75K |
| — | Testing & OpenStore submission | 1–3 days | ~50–100K |
| **Total** | | **~10–19 days** | **~930K–1.4M** |

---

## v2.1 — Bearthen Sync (Buwana SSO + Cloud Library)

### The Vision

The AccountPage placeholder has been in v1.0 since the beginning — the "Bearthen Sync"
hero, the feature list, the "Sign in with Buwana" button, the `reader.earthen.io`
domain. v2.1 makes it real.

A user signs in once on their Ubuntu Touch phone. Their library, reading positions,
and preferences appear on their desktop and their e-ink device automatically. Their
books are theirs — private, backed up, and portable across every device they own.

### Architecture

```
Bearthen clients (Touch / Desktop / e-ink)
  │  PKCE OAuth2 → Buwana SSO
  │  JWT (RS256) verified via JWKS
  │  POST /api/sync   GET /api/library   PUT /api/books/:id/progress
  ▼
reader.earthen.io  (platform/server/)
  │  Node.js / Express 5 — mirrors airbuddy-ONLINE architecture
  │  MySQL: bearthen_db
  │  Buwana JWKS JWT verification (buwana_sub as user identifier)
  ▼
buwana.ecobricks.org  (existing SSO — no changes needed)
  JWKS:  /.well-known/jwks.php
  Auth:  /authorize.php
  Token: /token.php
```

The server architecture is deliberately modelled on `airbuddy-ONLINE` — the same
Express + MySQL + Buwana JWKS pattern already proven in production.

### Cloud Server Schema

```sql
CREATE TABLE users_tb (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    buwana_sub   VARCHAR(255) UNIQUE NOT NULL,
    email        VARCHAR(255),
    display_name VARCHAR(255),
    created_at   DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE books_tb (
    id              VARCHAR(100),
    user_id         INT,
    title           TEXT,
    author_display  TEXT,
    language        VARCHAR(10),
    cover_url       MEDIUMTEXT,
    source          VARCHAR(20),
    source_id       TEXT,
    category        TEXT,
    epub_url        TEXT,
    PRIMARY KEY (id, user_id)
);

CREATE TABLE reading_state_tb (
    book_id      VARCHAR(100),
    user_id      INT,
    read_percent INT DEFAULT 0,
    is_finished  TINYINT DEFAULT 0,
    last_read    DATETIME,
    updated_at   DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (book_id, user_id)
);

CREATE TABLE reader_prefs_tb (
    book_id       VARCHAR(100),
    user_id       INT,
    fontsize      VARCHAR(20),
    fontfamily    VARCHAR(100),
    theme         VARCHAR(20),
    spacing       VARCHAR(20),
    margins       VARCHAR(20),
    updated_at    DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (book_id, user_id)
);
```

### Sync Strategy

Delta sync — each client sends `last_synced_at`; the server returns only records
changed since then. Conflict resolution: last-write-wins on `updated_at`. Simple,
reliable, fits the use case.

Gutenberg books sync by ID only (re-downloadable). Local EPUBs sync metadata and
reading state; the binary is not uploaded by default (privacy-respecting). Optional
cloud EPUB storage can be added later.

### Stage 2.1.1 — Cloud Server Setup

**Estimated effort:** 2–3 days | **Tokens:** ~300–400K

Spin up `reader.earthen.io` — Node.js/Express on Ubuntu VPS, Nginx reverse proxy,
MySQL, PM2, Let's Encrypt TLS. Identical infrastructure to `air2.earthen.io`.
Register Bearthen as a Buwana client at `buwana.ecobricks.org/en/app-wizard.php`.

### Stage 2.1.2 — Buwana OAuth2 in Ubuntu Touch QML

**Estimated effort:** 1–2 days | **Tokens:** ~150–200K

An embedded WebView in AccountPage hosts the Buwana authorize URL. When Buwana
redirects to the callback, `onUrlChanged` intercepts it and extracts the auth code.
PKCE code verifier and challenge generated in QML JavaScript.

### Stage 2.1.3 — Sync Client in QML

**Estimated effort:** 1–2 days | **Tokens:** ~100–150K

A `BuwanaSync.qml` component wraps `XMLHttpRequest` calls to `reader.earthen.io`.
Sync triggers: app launch (if signed in), book finish, preference change, manual
pull-to-refresh in AccountPage.

### Stage 2.1.4 — AccountPage Implementation

**Estimated effort:** 1–2 days | **Tokens:** ~100–150K

Replace the "coming soon" notice. Signed-out state: existing hero + feature list +
OAuth WebView trigger. Signed-in state: Buwana display name, last sync time, sync
status indicator, "Sync now" button, sign-out option.

---

### v2.1 Effort Summary

| Stage | Description | Effort | Tokens (est.) |
|---|---|---|---|
| 2.1.1 | Cloud server at reader.earthen.io | 2–3 days | ~300–400K |
| 2.1.2 | Buwana OAuth2 in QML | 1–2 days | ~150–200K |
| 2.1.3 | Sync client in QML | 1–2 days | ~100–150K |
| 2.1.4 | AccountPage implementation | 1–2 days | ~100–150K |
| — | Testing (multi-device sync) | 1–2 days | ~50–100K |
| **Total** | | **~6–11 days** | **~700K–1M** |

---

## v2.2 — Ubuntu Desktop (Electron Snap)

### About the Electron Target

The reader stack (epub.js, Readium Web JS) runs natively in Electron's Chromium
renderer with zero adaptation. The launcher problem that required PyOtherSide on
Ubuntu Touch is trivial in Electron:

```javascript
// main.js
const { spawn } = require('child_process')
const streamer = spawn('./bin/r2-streamer-x86_64', ['--port', port, '--epub', epubPath])
```

Buwana sync is included from day one — the server is live from v2.1 and the OAuth2
flow is simpler in Electron (system browser redirect, local HTTP catcher).

### Stage 2.2.1 — Electron Skeleton + r2-streamer x86_64

**Estimated effort:** 1–2 days | **Tokens:** ~100–150K

Set up `platform/electron/` with `main.js`, `preload.js`, `renderer/index.html`.
Wire up `child_process.spawn` of `r2-streamer-x86_64` (already compiled in v2.0
Stage 3). Confirm reader loads at `http://localhost:PORT/readium/`.

### Stage 2.2.2 — Library UI (HTML/JS Renderer)

**Estimated effort:** 2–3 days | **Tokens:** ~200–300K

The renderer mirrors `LibraryPage.qml` functionality: book grid, covers, metadata,
import, delete. SQLite via `better-sqlite3` in main process, accessed through
`contextBridge` IPC. Same schema as `core/db/schema.sql`.

### Stage 2.2.3 — File Import and MetaProbe

**Estimated effort:** 1 day | **Tokens:** ~50–100K

`dialog.showOpenDialog` replaces ContentHub. `meta-probe.html` loads in a hidden
`BrowserWindow` — the chunked `COVER_CHUNK:` protocol works unchanged via
`webContents.on('page-title-updated')`.

### Stage 2.2.4 — Buwana Sync in Electron

**Estimated effort:** 0.5–1 day | **Tokens:** ~50–75K

Server is live from v2.1. OAuth2 via system browser + local redirect catcher.
Sync calls use Node.js `fetch`. `account.js` renderer module mirrors the QML
`BuwanaSync` component logic.

### Stage 2.2.5 — Snap Packaging

**Estimated effort:** 0.5–1 day | **Tokens:** ~50–75K

`platform/electron/snapcraft.yaml` using the `electron-builder` snapcraft plugin.

### Stage 2.2.6 — Polish and Feature Parity

**Estimated effort:** 2–3 days | **Tokens:** ~150–200K

Gutenberg Discover, Settings, keyboard shortcuts, window resize handling,
drag-and-drop EPUB import.

---

### v2.2 Effort Summary

| Stage | Description | Effort | Tokens (est.) |
|---|---|---|---|
| 2.2.1 | Electron skeleton + x86_64 streamer | 1–2 days | ~100–150K |
| 2.2.2 | Library UI (HTML/JS renderer) | 2–3 days | ~200–300K |
| 2.2.3 | File import + MetaProbe | 1 day | ~50–100K |
| 2.2.4 | Buwana sync in Electron | 0.5–1 day | ~50–75K |
| 2.2.5 | Snap packaging | 0.5–1 day | ~50–75K |
| 2.2.6 | Polish & feature parity | 2–3 days | ~150–200K |
| — | Testing | 1–2 days | ~50–75K |
| **Total** | | **~7–13 days** | **~650K–975K** |

---

## v2.3 — e-ink Hardware (Raspberry Pi 3B+)

### The Vision

A purpose-built e-ink reading device powered by a Raspberry Pi 3B+, running Bearthen
as its sole application. The Pi 3B+ is a deliberate hardware constraint: a board
released in 2018 that can be purchased used for under $20, salvaged from old projects,
or sourced from school electronics recycling programmes. Building on aging hardware
rather than new is central to the Earthen Ethics philosophy — technology in service
of regeneration, not consumption.

Anyone with an old Pi 3B+ gathering dust can build their own open-source e-ink reader.
That is the goal.

### Target Hardware

| Component | Specification | Notes |
|---|---|---|
| Compute | Raspberry Pi 3B+ | 1.4 GHz quad-core Cortex-A53, arm64 |
| RAM | 1 GB LPDDR2 | Tight — drives the lightweight architecture below |
| Storage | 8 GB microSD | Sufficient: OS ~1.5 GB + app ~36 MB + headroom |
| Display | Waveshare 10.3" e-ink (HDMI) | Appears as standard monitor; no SPI drivers needed |
| Case | Custom / ecological materials | Core to the product vision |
| Buttons | 4x tactile switches via GPIO | Page fwd/back, menu, sleep |
| Power | PiJuice HAT | Safe shutdown on low battery |

The Pi 3B+ runs arm64 — the same architecture as modern Ubuntu Touch devices.
`r2-streamer-arm64` already targets it. No new binary compilation needed.

### Why Not Electron on the Pi 3B+?

Electron is the right choice for v2.2 Ubuntu Desktop (abundant RAM, x86_64). But on
the Pi 3B+'s 1 GB RAM it is a poor fit:

| Process | RAM footprint |
|---|---|
| Raspberry Pi OS | ~300–400 MB |
| Electron main + renderer | ~250–400 MB |
| r2-streamer-go | ~50 MB |
| **Total** | **~600–850 MB** — leaves little headroom |

Instead, v2.3 uses **Chromium in kiosk mode** (already on Pi OS) served by a
**lightweight local Node.js server**. The renderer HTML/CSS/JS from
`platform/electron/src/renderer/` is served as a static site — the same files,
zero rewrite:

| Process | RAM footprint |
|---|---|
| Raspberry Pi OS | ~300–400 MB |
| Chromium kiosk | ~150–250 MB |
| Node.js server | ~30–50 MB |
| r2-streamer-go | ~50 MB |
| **Total** | **~530–750 MB** — comfortable headroom |

This architecture also means the 8 GB SD card stays well within budget, and the
app loads quickly on the Pi 3B+'s modest CPU.

### Stage 2.3.1 — Hardware Setup and Kiosk Boot

**Estimated effort:** 1–2 days | **Tokens:** ~75–100K

Install Raspberry Pi OS Lite (64-bit) on an 8 GB microSD. Install Node.js, Chromium,
and the `platform/eink/` scripts.

`platform/eink/launch.sh`:
```bash
#!/bin/bash
export BEARTHEN_EINK=1
# Start the local web server
node /opt/bearthen/server.js &
# Wait for server to be ready
until curl -s http://localhost:8080 > /dev/null; do sleep 0.2; done
# Start r2-streamer (on-demand, managed by web server via child_process)
# Launch Chromium in kiosk mode
chromium-browser --kiosk --disable-pinch --noerrdialogs \
  --disable-infobars --incognito \
  http://localhost:8080
```

`platform/eink/bearthen.service` (systemd unit):
```ini
[Service]
ExecStart=/opt/bearthen/launch.sh
Restart=always
Environment=DISPLAY=:0
```

### Stage 2.3.2 — Lightweight Local Server

**Estimated effort:** 1 day | **Tokens:** ~75–100K

A minimal Node.js/Express server in `platform/eink/` serves the renderer static
files and proxies API calls to `reader.earthen.io`. This is distinct from the full
Electron main process — no IPC bridge needed, just HTTP.

```javascript
// platform/eink/server.js
const express = require('express')
const { spawn } = require('child_process')
const app = express()

app.use(express.static('/opt/bearthen/renderer'))  // same renderer/ from v2.2

// Streamer management endpoint
app.post('/local/streamer/start', (req, res) => {
    const proc = spawn('/opt/bearthen/bin/r2-streamer-arm64',
        ['--port', req.body.port, '--epub', req.body.epub])
    // ...
})

app.listen(8080)
```

### Stage 2.3.3 — e-ink CSS Theme

**Estimated effort:** 1 day | **Tokens:** ~50–75K

`platform/electron/src/renderer/styles/eink.css` already exists from v2.2. The
`BEARTHEN_EINK=1` environment variable activates it via the server's HTML response.

```css
*, *::before, *::after { transition: none !important; animation: none !important; }
body { background: #ffffff; color: #000000; }
.book-card { border: 2px solid #000; background: #fff; }
:root {
    --RS__backgroundColor: #ffffff;
    --RS__textColor: #000000;
    --RS__baseFontFamily: Georgia, serif;
    --RS__fontSize: 125%;
    --RS__lineHeight: 1.8;
}
```

E-ink specific: trigger a full Chromium refresh on page turn to clear ghosting.

### Stage 2.3.4 — GPIO Button Mapping

**Estimated effort:** 1–2 days | **Tokens:** ~75–100K

`platform/eink/gpio-buttons.py` runs as a systemd service, mapping Pi GPIO pins
to keyboard events via `xdotool`. Chromium receives standard `keydown` events.

```python
BUTTONS = { 17: 'Right', 18: 'Left', 27: 'Escape', 22: 'F1' }
# Right = page forward, Left = page back, Escape = menu, F1 = sleep
```

### Stage 2.3.5 — Power Management and Wake Sync

**Estimated effort:** 1–2 days | **Tokens:** ~75–100K

PiJuice HAT handles graceful shutdown on low battery. On wake from sleep, the
server triggers a Buwana sync so the user's reading position is current across
all their devices before they pick up the hardware.

---

### v2.3 Effort Summary

| Stage | Description | Effort | Tokens (est.) |
|---|---|---|---|
| 2.3.1 | Hardware setup + kiosk boot | 1–2 days | ~75–100K |
| 2.3.2 | Lightweight local server | 1 day | ~75–100K |
| 2.3.3 | e-ink CSS theme | 1 day | ~50–75K |
| 2.3.4 | GPIO button mapping | 1–2 days | ~75–100K |
| 2.3.5 | Power management + wake sync | 1–2 days | ~75–100K |
| — | Hardware testing + tuning | 2–3 days | ~75–100K |
| **Total** | | **~7–12 days** | **~425–575K** |

---

## Migration Strategy: v1 → v2.3

1. **v1.x ships** — epub.js, ContentHub, Gutenberg, progress saving
2. **v2.0** — Readium for EPUB 3; epub.js fallback for EPUB 2; arm64 + armhf UT
3. **v2.1** — `reader.earthen.io` live; AccountPage sync activated
4. **v2.2** — Ubuntu Desktop snap; Buwana sync from day one
5. **v2.3** — Pi 3B+ e-ink device; full library on first boot via Buwana sync
6. **v2.x+** — epub.js retired; Readium handles all formats across all platforms

---

## Full Effort Overview

| Version | Focus | Effort | Tokens (est.) |
|---|---|---|---|
| v2.0 | Ubuntu Touch + Readium | 10–19 days | ~930K–1.4M |
| v2.1 | Buwana sync + cloud server | 6–11 days | ~700K–1M |
| v2.2 | Ubuntu Desktop Electron | 7–13 days | ~650K–975K |
| v2.3 | e-ink Pi 3B+ hardware | 7–12 days | ~425–575K |
| **Total** | | **~30–55 days** | **~2.7M–4M** |

---

## Risk Table

| Risk | Likelihood | Status | Mitigation |
|---|---|---|---|
| AppArmor blocks Go exec | — | **RESOLVED** | Confirmed both dirs; re-confirmed 2026-09-23 with the production r2-streamer-arm64 binary on device, no exec denial |
| ctypes / dlopen blocked | — | **RESOLVED** | Confirmed working |
| v1.x regression after Stage 1 refactor | Low | Open | Non-regression checklist gates Stage 2 |
| r2-streamer API breaks between versions | Medium | Open | Using `readium/cli` (wraps `readium/go-toolkit`), not the archived `r2-streamer-go`; pin release tag |
| `/ping` health endpoint absent | — | **RESOLVED** | No `/ping` in `readium/cli`; TCP connect poll fallback implemented and confirmed working |
| Package size > 36 MB (UT dual-arch) | Low | Open | Monitor at Stage 5 |
| Process lifecycle on UT suspend | Medium | Open | Restart-per-book-open (Sturmreader pattern) |
| armhf memory pressure (1–2 GB RAM) | Medium | Open | Profile; lazy streamer start |
| Readium CFI → percentage conversion | Low | Open | Conversion layer in launcher |
| OAuth2 callback handling on UT | Medium | Open | Embedded WebView intercept |
| Multi-device sync conflicts | Low | Open | Last-write-wins; prompt on large divergence |
| Pi 3B+ 1 GB RAM pressure | Medium | Open | Chromium kiosk (not Electron); profiled at Stage 2.3.1 |
| e-ink display ghosting | Medium | Open | Full-refresh on page turn |
| Pi GPIO conflicts with Chromium focus | Low | Open | xdotool targets window by name |
| OpenStore review delay | Low | Open | Syncthing + Sturmreader precedent |

---

## References

- [r2-streamer-go](https://github.com/readium/r2-streamer-go) — Go EPUB streamer
- [R2D2BC / Readium Web](https://github.com/d-i-t-a/R2D2BC) — JS reader shell
- [Sturmreader](https://gitlab.com/TronFortyTwo/sturmreader) — localhost-server precedent on UT
- [Syncthing click](https://open-store.io/app/syncthing.catfriend1) — Go binary in click package
- [PyOtherSide docs](https://thp.io/2011/pyotherside/) — QML/Python bridge
- [Buwana SSO](https://buwana.ecobricks.org) — identity provider
- [Waveshare e-ink displays](https://www.waveshare.com/product/raspberry-pi/displays/e-paper.htm)
- [PiJuice HAT](https://github.com/PiSupply/PiJuice)
- [Clickable script builder](https://clickable-ut.dev/en/latest/builders.html)
- [UBports AppArmor docs](https://docs.ubports.com/en/latest/appdev/platform/apparmor.html)

---

*Bearthen — one repository, four platforms, one identity.*
*Last updated April 2026 following exec spike confirmation and full platform planning.*
