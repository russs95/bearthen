# Bearthen 2.0 — Viability Assessment & Step-by-Step Development Plan

> **Purpose:** Translate the v2 architecture roadmap into an honest viability verdict and a concrete, sequenced development plan.  
> **Prerequisite:** Read `bearthen-2.0-roadmap.md` first. This document assumes it.

> **Status as of 2026-09-24:** Phase B (Steps 3–7) fully done, all confirmed on real hardware (Pixel 3a / `sargo`, Ubuntu Touch 24.04, arm64). Step 7 in particular — a real EPUB opening and paginating through the actual Readium/`D2Reader` engine, with working swipe navigation and bars toggle — is confirmed on-device, after finding and fixing four distinct real bugs along the way (see the note under Step 7). **Next: Phase C Step 10** (theme/settings/TOC/bookmark parity for the Readium path — currently has none of this UI at all, not a bug, just not built yet).

---

## Section 1 — Is This Actually Doable?

### The short answer: Yes — with one hard dependency to prove first.

The architecture is sound, the precedents are real, and the plan is better-researched than most hobby-project roadmaps. But it has one gate that everything else flows through, and two secondary risks worth understanding clearly before committing time.

---

### The One Hard Dependency: AppArmor exec permission

The entire plan rests on being able to `subprocess.Popen()` the Go binary from Python running inside PyOtherSide. That is a **process exec** from within a click-confined app. Ubuntu Touch's AppArmor policy for click packages is restrictive by default — and `exec` of arbitrary binaries is not automatically permitted by the `networking` or `webview` policy groups.

The roadmap cites Syncthing as precedent. This is partially correct: Syncthing ships a Go binary inside a click package. But Syncthing is started by the Ubuntu Touch service layer, not by PyOtherSide inside a QML subprocess chain. The confinement model is different. Sturmreader is the closer precedent — it execs a C++ binary from within the click app process — and it does work. However, Sturmreader uses a compiled QML plugin (`.so`) loaded by Qt, not a raw Python subprocess. These are different exec paths in the AppArmor policy.

**The risk is not theoretical.** If AppArmor silently denies the exec, the binary launch fails with no useful error in the QML logs. The ctypes fallback suggested in the roadmap does not apply — you cannot call a statically compiled Go binary via ctypes; it has no C ABI unless specifically built with `buildmode=c-shared`, which adds significant build complexity and its own AppArmor (shared library load) questions.

**Resolution:** This must be tested on a real device as Step 0, before any other v2 work begins. It is a two-hour spike, not a multi-day effort. If it works, the plan is green. If it fails, the fallback path is to compile the streamer as a C-shared library and load it via ctypes — viable but more complex, and worth knowing before investing weeks in the rest.

---

### Secondary Risk 1: r2-streamer-go status and API surface

`r2-streamer-go` is listed in the Readium Foundation's GitHub organisation but has not seen active development since 2021. The canonical Readium Go work has largely shifted to the Readium Go toolkit (`readium/go-toolkit`), which is more actively maintained but has a different API surface and different CLI flags. If `r2-streamer-go` no longer compiles cleanly against current Go toolchains, the plan needs to substitute `go-toolkit`'s streamer command — which is a research task, not a blocker, but worth knowing early.

The specific `/ping` health-check endpoint the launcher depends on must be confirmed against the actual binary. If it does not exist in the chosen version, the launcher's readiness poll needs an alternative (such as attempting a TCP connect to the port instead).

**Resolution:** Attempt the cross-compile in Step 2 and confirm the `/ping` endpoint exists before proceeding to integration.

---

### Secondary Risk 2: Package size

Two Go binaries (~15MB arm64, ~13MB armhf) plus the Readium Web JS bundle (~2–4MB depending on what gets trimmed) plus existing app assets (~3MB) totals approximately 33–40MB. The OpenStore soft limit is 50MB. This is comfortable but not generous.

If the arm64 binary alone is sufficient (most active Ubuntu Touch devices are arm64: PinePhone, Fairphone 4/5, OnePlus 6), shipping only arm64 saves 13MB and gives clear headroom.

**Resolution:** Cross-compile both and measure before committing to dual-arch. Decide before OpenStore submission, not after.

---

### What makes the plan strong

- **The architecture has shipped.** Sturmreader, Syncthing, and Beru all validate pieces of this independently. No component here is speculative.
- **The Go binary approach is strictly simpler than the C++ alternative.** Static binary, no Qt version coupling, no `.so` plugin, cross-compiles in one command.
- **Readium is the right long-term bet.** epub.js is unmaintained for complex EPUBs. Readium is the EPUB 3 reference. The investment compounds.
- **The migration strategy is zero-regression.** Readium activates behind a version flag; epub.js stays in the build until v2.1. Users on EPUB 2 / Gutenberg books see no change.
- **v1.x is a solid foundation.** The library, metadata pipeline, cover extraction, and content hub integration all carry forward untouched.

---

### Verdict

**Proceed.** The plan is technically sound and the timeline (8–13 dev-days, 4–8 calendar weeks) is honest. Validate AppArmor exec permission first. If that passes — and the Sturmreader precedent makes it likely — the rest of the development is straightforward execution of a well-defined plan.

---

## Section 2 — Step-by-Step Development Plan

### Overview

The plan is organised into three phases:

| Phase | Goal | Steps |
|---|---|---|
| **Phase A** — Stabilise v1 | Ship a solid v1.x to the OpenStore before starting v2 | 1–2 |
| **Phase B** — Prove the infrastructure | Validate every risky assumption on real hardware | 3–6 |
| **Phase C** — Build v2 | Integrate, polish, and ship | 7–12 |

---

### Phase A — Stabilise v1.x

> Goal: A releasable v1.x is in the OpenStore before any v2 work begins. v2 development on an unstable base wastes time.

---

#### Step 1 — Complete v1.x Feature Set

Confirm all v1.x features are working on device:

- [ ] EPUB import via ContentHub (file move to permanent storage, not HubIncoming)
- [ ] MetaProbe running silently after import, updating title/author/cover
- [ ] Reader opening with correct epub.js rendering, dark mode, progress saving
- [ ] Gutenberg catalogue browsing and download
- [ ] Font size, font family, theme, spacing settings persisted per book
- [ ] Library grid displaying with texture, correct dark/light theming

**Done when:** All items pass a manual test cycle on device. No regressions.

---

#### Step 2 — OpenStore v1.x Submission

- [ ] Bump `manifest.json` version to `1.0`
- [ ] Run `clickable build` cleanly — no warnings about undefined components
- [ ] Confirm click package is under 30MB (it should be ~3–5MB)
- [ ] Submit to OpenStore
- [ ] Tag the git commit as `v1.0`

**Done when:** OpenStore listing is live, or submission is in review.

---

### Phase B — Prove the Infrastructure

> Goal: Every technical assumption the v2 architecture makes is tested in isolation before integration begins. Failures here are cheap. Failures during integration are expensive.

---

#### Step 3 — AppArmor Exec Spike (The Gate)

This is the most important step in the entire plan. Do it before writing any other v2 code.

Create a minimal test click package that:
1. Bundles a trivial static ARM binary (e.g. a Go "Hello World" that writes to a file and exits)
2. Loads PyOtherSide in QML
3. Calls `subprocess.Popen([binary_path])` from Python
4. Reports success or failure to the QML UI

Deploy to device and confirm the subprocess starts without AppArmor denial.

Confirm via:
```bash
clickable logs   # watch for AppArmor DENIED in dmesg
```

**If it passes:** Proceed to Step 4.  
**If it fails:** File a question on the UBports dev forum with the denial log. Investigate whether the `execute_unrestricted` AppArmor capability can be requested. If not available for click apps, evaluate the `buildmode=c-shared` Go library path and update the plan accordingly before proceeding.

**Done when:** Python successfully launches a static ARM binary inside click confinement on real hardware.

> ✅ **Done — confirmed twice.** The original PyOtherSide/ctypes/Go spike passed on a Pixel 3XL (see CLAUDE.md). Step 6 below re-confirms it end-to-end with the *actual* production binary (`r2-streamer-arm64`, not a toy binary) on a Pixel 3a running Ubuntu Touch 24.04 — `subprocess.Popen()` execs cleanly under the `bearthen.russs95_bearthen_0.1.1` AppArmor profile, with no `exec`-related denial in `dmesg`. The only two denials the confined process hit (`__pycache__` mknod, `/proc/sys/net/core/somaxconn` read) are both non-fatal and don't block functionality — see Step 6.

---

#### Step 4 — Cross-Compile r2-streamer-go

On the development machine (not on device):

```bash
# Check if r2-streamer-go still compiles
git clone https://github.com/readium/r2-streamer-go
cd r2-streamer-go
GOOS=linux GOARCH=arm64 go build -o bin/r2-streamer-arm64 ./...
GOOS=linux GOARCH=arm GOARM=7 go build -o bin/r2-streamer-armhf ./...
```

If the build fails (Go API drift, missing dependencies), switch to the `readium/go-toolkit` streamer command and repeat. The goal is a working ARM binary, not loyalty to a specific repo.

Once built, test the binary locally:
```bash
./bin/r2-streamer-arm64 --port 12345 --epub /path/to/test.epub
curl http://localhost:12345/ping        # confirm health endpoint
curl http://localhost:12345/           # confirm EPUB manifest is served
```

Document the exact CLI flags and endpoint paths — these become the spec for the Python launcher.

Measure binary sizes. If arm64 alone is under 20MB, note that shipping arm64-only is a viable option.

**Done when:** Static arm64 binary compiled, `/ping` confirmed, manifest URL scheme documented.

> ✅ **Done, with two corrections to the spec above.** `core/streamer/bin/r2-streamer-{arm64,armhf,amd64}` are built and committed to the build (gitignored binaries, ~16–19MB each). The actual toolchain turned out to be **`readium/cli`** (`github.com/readium/cli`, which wraps `readium/go-toolkit`) rather than the archived `r2-streamer-go` — it ships as a `readium` binary with `serve`/`manifest` subcommands, not the flat `--port`/`--epub` flags this doc originally assumed. Two things worth recording for anyone touching the launcher again:
> - There is no `/ping` endpoint. Use `/health` (returns `200 OK`) — `reader_launcher.py`'s `_poll_ready()` uses a raw TCP-connect poll instead, which works regardless.
> - **The binary's own `--help` text for the manifest URL pattern is wrong/stale.** It advertises `<port>/<base64url filename>/manifest.json`; the real route, confirmed against the `readium/cli` source (`pkg/serve/router.go`) and a live request, is **`<port>/webpub/<base64url filename>/manifest.json`** (`base64.RawURLEncoding`, no padding). `reader_launcher.py`'s `_manifest_url()` implements the correct pattern and documents this discrepancy inline.

---

#### Step 5 — Evaluate Readium Web JS Shell

The roadmap suggests R2D2BC (`d-i-t-a/R2D2BC`). Before committing, evaluate two options side by side:

| Option | Pros | Cons |
|---|---|---|
| **R2D2BC** | Purpose-built reading system, mobile-aware CSS, Readium2 architecture | Less active maintenance, specific to one organisation's use case |
| **Readium Web (`readium/readium-js-viewer`)** | More standard, broader community | Older codebase, may not work with r2-streamer-go's manifest format |
| **Custom shell** | Full control, minimal bundle size | More JS work |

The evaluation test: take the built JS shell, point it at the local r2-streamer-go instance serving a test EPUB, and confirm it renders paginated content in a browser. If R2D2BC works, use it. If not, build a thin custom shell using `@readium/navigator` (the navigator package can be used standalone).

Build the chosen shell:
```bash
cd R2D2BC && npm install && npm run build   # or equivalent
du -sh dist/   # measure output size
```

**Done when:** A built JS bundle renders an EPUB served by r2-streamer-go in a desktop browser.

> ✅ **Done (2026-09-23).** Chose R2D2BC over `readium/web`/`ts-toolkit` — even
> though the latter is the toolkit "officially" paired with our
> `readium/cli`/`go-toolkit`-based server, it's library-only pieces
> (`@readium/navigator`, `@readium/shared`, `@readium/navigator-html-injectables`)
> with no ready reader UI, meaning building our own paginated-reader chrome
> from scratch. R2D2BC ships a drop-in `D2Reader` class with TOC, bookmarks,
> search, annotations, and reflowable-text settings already built, and since
> it consumes the standard Readium Web Publication Manifest format (a spec,
> not tied to a specific server), it works against our `readium/cli`-served
> manifests with zero adaptation.
>
> Built from `d-i-t-a/R2D2BC` (`npm install`, which runs the build
> automatically), then trimmed for an EPUB-only reader — dropped source maps,
> the PDF.js viewer/worker, and the audio worklet (none needed) — and
> minified the JS with `esbuild` (`--minify`), cutting the shipped bundle
> from an unminified ~4.0MB down to **2.3MB total** (2.1MB JS + ~200KB
> CSS/injectables). Landed in `core/readium/` — see `core/readium/README.md`
> for full provenance and rebuild steps.
>
> Verified end-to-end with a real test: started `r2-streamer-amd64 serve` on
> a directory containing a real EPUB, pointed a minimal harness page's
> `D2Reader.load({ url: <manifest URL> })` at its `/webpub/.../manifest.json`,
> and rendered the page in headless Chrome. Screenshot confirmed the actual
> book cover rendered and the TOC parsed correctly (9 real chapter entries).
> Both the unminified and minified builds were tested and produced identical
> output.

---

#### Step 6 — PyOtherSide Launcher Prototype

Create `qml/py/reader_launcher.py` as specified in the roadmap (Stage 1). Test it in isolation:

```bash
python3 reader_launcher.py   # call launch_streamer() directly
```

Confirm:
- Free port discovery works
- Binary launches without error
- Health poll succeeds within 5 seconds
- `ensure_stopped()` terminates the process cleanly

Then integrate into a minimal QML test page (not ReaderPage yet) — a QML window with a `Python {}` block, a `WebView`, and a button that calls `py.call('reader_launcher.launch_streamer', [...])` and loads the result URL.

Deploy this minimal test to device. Confirm the full chain works: PyOtherSide → Python → Go binary → WebView renders EPUB content.

**Done when:** EPUB renders in a WebView on physical Ubuntu Touch hardware via the PyOtherSide → Go → Readium Web chain.

> ✅ **Launcher chain confirmed end-to-end, both on desktop and on real device.** The WebView-renders-Readium-content half is deferred to Step 7 (no Readium Web JS shell exists yet — that's Step 5) — what's proven here is everything up to and including the manifest being served correctly.
>
> **Desktop isolation test** (`platform/touch/py/reader_launcher.py` called directly, amd64 binary, real EPUB): free-port discovery, binary launch, TCP readiness poll, correct `/webpub/.../manifest.json` URL construction, HTTP 200 manifest fetch with valid RWPM JSON, and clean `stop()` all passed. This also caught and fixed a real bug: the dev-fallback binary path in `_binary_path()` had one `..` too many and resolved outside the repo entirely.
>
> **On-device test** (Pixel 3a, `sargo`, Ubuntu Touch 24.04, arm64 click package built via `platform/touch/build-arm64.sh`): opened a real book (`local_944895864`) in the installed, AppArmor-confined app and captured via `clickable logs --arch arm64`:
> ```
> StreamerLauncher: reader_launcher module loaded
> StreamerLauncher: ready on port 48553 manifest: http://127.0.0.1:48553/webpub/VGhlIFdheWZpbmRlciAtIEFkYW0gSm9obnNvbi5lcHVi/manifest.json
> ReaderPage: r2-streamer ready on port 48553 manifest: ... — reserved for Readium in Stage 6
> ```
> `adb shell dmesg | grep -i denied` showed no `exec`-related denial for `r2-streamer` — the process ran under the `bearthen.russs95_bearthen_0.1.1` profile (`comm="r2-streamer"` appears in its own denial lines, proving the exec itself succeeded). The two denials the streamer/launcher did hit are both non-fatal: a `mknod` on a Python `__pycache__/*.pyc` file (writing to the read-only click install dir — correctly denied, Python just skips bytecode caching) and an `open` on `/proc/sys/net/core/somaxconn` (the server still bound and served the manifest with HTTP 200 regardless).
>
> Also fixed along the way: `postbuild.sh`'s streamer-binary lookup reached `../../../../../core/streamer/bin/...` from inside `clickable build`'s docker container — but that container only bind-mounts `platform/touch/`, so the repo-root `core/` directory doesn't exist inside it, and the binary was silently never bundled. `build-arm64.sh` now stages the binary inside `platform/touch/.stage-bin/` before invoking `clickable build` (gitignored), and `postbuild.sh` checks there first. Also removed the `--container-mode` flag from the build step — it tells clickable "the tools are already on the host," but clickable ships as a strictly-confined snap that can't see a host-installed `click` binary, so that flag was routing the build to fail outright with `click: command not found`.

---

### Phase C — Build v2

> Phase B validated every assumption. Phase C is integration and polish.

---

#### Step 7 — Integrate Launcher into ReaderPage

Modify `qml/pages/ReaderPage.qml`:

1. Add `Python { id: py }` block with module import and `onReceived` handler
2. Add a `useReadium` computed property based on `book.epub_version >= 3.0` (or a debug flag initially set to `true` to test with all books)
3. Branch the reader launch: if `useReadium`, call the launcher; otherwise use existing epub.js path
4. Handle the `streamer_ready` signal by constructing the Readium Web URL and setting `webView.url`
5. On `Component.onDestruction`, call `py.call('reader_launcher.ensure_stopped', [])`

Keep the epub.js path completely intact. The v2 path is additive — nothing is removed.

**Done when:** A test EPUB opens in Readium via ReaderPage, and closing the page terminates the streamer.

> ✅ **Done, confirmed on physical hardware (2026-09-24).** Adapted to
> what Steps 4–6 actually built (`reader_launcher.py`/`StreamerLauncher.qml`
> already existed from Step 6, so items 1 and 5 above were already done —
> `streamerLoader.item.stop()` on `onVisibleChanged` was already the
> termination point, unaffected by this step):
> - `_useReadium` debug flag (default `true`) added to `ReaderPage.qml`, per
>   this step's own suggested fallback since `book.epub_version` isn't tracked
>   yet
> - `openBook()` now skips the epub.js `urlLoadTimer` path for local EPUBs
>   when `_useReadium` is true, and instead waits for the streamer's `ready`
>   signal
> - New `_loadReadiumUrl(manifestUrl, staticPort)` builds a URL to a new
>   harness page, `platform/touch/assets/readium/reader-readium.html`, which
>   loads `D2Reader` (from `core/readium/`, Step 5) against the manifest URL
> - Three fallback paths added so a `_useReadium`-eligible book never gets
>   stuck on a blank screen: streamer process error, `StreamerLauncher.qml`
>   Loader failing to load at all (e.g. `io.thp.pyotherside` missing), and the
>   pre-existing remote-book (no `file_path`) case — all fall back to
>   `_loadReaderUrl()` (epub.js)
> - The harness wires `BARS:`/`HIDE_NAV:1` (reusing `ReaderPage`'s existing
>   `_bookReady`/transition-cover logic unchanged) and a percent-only `POS:`
>   signal (Readium locators aren't EPUB CFIs, so `cfi` is sent empty — full
>   position-restore parity is Stage 8 work). Bookmarks/highlights/font
>   settings are not yet ported — `_pushBookmarks()`/`_pushHighlights()` still
>   fire but no-op harmlessly against functions that don't exist in the
>   Readium harness.
>
> **On-device testing surfaced four real, distinct bugs — all found and
> fixed through this session's actual hardware test cycles, not guessed at:**
> 1. `<script type="module">` fails MIME checking over `file://` — switched
>    the harness to R2D2BC's IIFE build (`reader.js`, global `window.D2Reader`)
> 2. Even fixed, `D2Reader.load()`'s internal `fetch()` was blocked: Chromium
>    disallows cross-origin `fetch()` from a `file://`-origin page entirely
>    (not a CORS-header issue — the streamer already sends
>    `Access-Control-Allow-Origin: *`). Fixed by having `reader_launcher.py`
>    also run a lightweight `http.server.ThreadingHTTPServer`
>    (`_ensure_static_server()`) so the harness itself loads over `http://`
> 3. That static server's default MIME-type guesser tried to read
>    `/etc/mime.types` and got `PermissionError` under AppArmor confinement,
>    crashing every request. Fixed with an explicit extension-to-MIME map
>    instead of stdlib `mimetypes`
> 4. Touches landing on the book content did nothing — `reader-readium.html`
>    had listeners on `document`, but D2Reader renders into an `<iframe>` and
>    iframe events don't bubble to the parent document. Fixed with a
>    `#touch-layer` overlay div above the iframe, the same pattern
>    `reader.html` already used successfully for epub.js
>
> **Confirmed working on a Pixel 3a**: book opens and renders (cover +
> reflowable text), swipe left/right turns pages, tap toggles the QML top
> bar. **Confirmed not yet working, expected** (Stage 8 scope, not a bug):
> TOC button, bookmark button, and any font/theme/spacing settings — see the
> Stage 8 scope note in `bearthen-2.0-roadmap.md`.

---

#### Step 8 — AppArmor & Click Package Policy

Update `bearthen.apparmor` if needed for subprocess exec. Update `clickable.json` to:

1. Include PyOtherSide as a dependency
2. Bundle `bin/r2-streamer-arm64` (and optionally `bin/r2-streamer-armhf`) in the click package
3. Bundle the Readium Web JS bundle under `assets/readium/`

Build the full click package and measure size:
```bash
clickable build
ls -lh build/*.click
```

If over 45MB, drop armhf binary and target arm64 only.

Deploy to device and run the full reader flow under confinement (not just in dev mode).

**Done when:** Confined click package on device opens a book via Readium. No AppArmor denials in logs.

---

#### Step 9 — Process Lifecycle Management

Implement the full lifecycle as specified in roadmap Stage 5:

- Streamer starts on first book open, not at app launch
- If the streamer process crashes mid-read, ReaderPage detects a dead port and restarts it
- On `Qt.application.stateChanged` (`Qt.ApplicationSuspended`), call `ensure_stopped()`
- On app resume, streamer restarts on next book open (no pre-emptive launch)
- `atexit.register(ensure_stopped)` in Python as belt-and-suspenders

Test scenarios:
- Open book → background app → foreground app → confirm reader still works
- Open book → switch books rapidly → confirm no port conflicts
- Open book → kill process manually → confirm graceful restart

**Done when:** All lifecycle scenarios pass on device without hangs or stale port errors.

---

#### Step 10 — Readium Theme & Settings Integration

Map v1.x reader settings to Readium's CSS custom property API:

| v1.x epub.js setting | Readium CSS variable |
|---|---|
| `theme: "dark"` | `--RS__backgroundColor: #121212; --RS__textColor: #DDD8CC` |
| `fontsize: 18` | `--RS__fontSize: 18px` |
| `fontfamily: "Georgia"` | `--RS__baseFontFamily: Georgia, serif` |
| `spacing: 1.6` | `--RS__lineHeight: 1.6` |

The Readium Web shell exposes a JS API or CSS injection point for these. Implement a `configureReadium(settings)` JS function in a small bridge file bundled alongside the Readium assets. ReaderPage calls it via `webView.runJavaScript(...)` after the reader signals ready.

Port the `BARS`, `HIDE_NAV`, `PROGRESS`, and pref-persistence signals from reader.html to the Readium shell. The Readium navigator exposes equivalent events; wire them to the same `document.title` signalling protocol already in place for QML.

**Done when:** Dark mode, font size, font family, and progress saving all work via Readium the same way they work in epub.js.

---

#### Step 11 — Regression Testing & v2.0 Build

With both reader paths now working, run a full regression pass:

- [ ] Gutenberg EPUB 2 books open correctly (epub.js path, no regression)
- [ ] Local EPUB 3 books open correctly (Readium path)
- [ ] Import flow unchanged
- [ ] MetaProbe unchanged
- [ ] Library grid, covers, progress indicators all correct
- [ ] Settings persist correctly for both reader paths
- [ ] App suspends and resumes cleanly
- [ ] Device does not overheat or drain battery faster with Go binary running

Bump `manifest.json` to `2.0`. Build and measure final click package size.

**Done when:** Zero regressions found. Click package within size limit.

---

#### Step 12 — OpenStore v2.0 Submission

- [ ] Tag git commit as `v2.0`
- [ ] Write OpenStore release notes (highlight EPUB 3 support, Readium foundation)
- [ ] Submit click package
- [ ] Monitor for AppArmor-related crash reports in first 48 hours post-release

**Done when:** v2.0 is live in the OpenStore.

---

### Post-v2.0: Step 13 — Retire epub.js (v2.1)

Once v2.0 has been in the store for 2–4 weeks without EPUB 2 regression reports:

- Remove the epub.js conditional branch from ReaderPage
- Remove `epub.min.js`, `jszip.min.js`, `reader.html`, and `meta-probe.html` from the build
- The Readium streamer handles all EPUB versions; no more version-detection flag needed
- Implement a native Readium-based MetaProbe replacement (or use the streamer's OPF endpoint directly for metadata extraction)

This step is optional and can be deferred indefinitely — the dual-path architecture is not a maintenance burden if both paths work. Do it when you're confident Readium handles the full Gutenberg catalogue cleanly.

---

## Summary Timeline

| Step | What | Phase | Effort |
|---|---|---|---|
| 1 | Complete v1.x features | A | 1–3 days |
| 2 | OpenStore v1.x submission | A | 0.5 days |
| 3 | **AppArmor exec spike** (THE GATE) | B | 0.5–1 day |
| 4 | Cross-compile r2-streamer-go | B | 0.5–1 day |
| 5 | Evaluate & build Readium Web JS | B | 1 day |
| 6 | PyOtherSide launcher prototype on device | B | 1–2 days |
| 7 | Integrate launcher into ReaderPage | C | 1–2 days |
| 8 | AppArmor + click package assembly | C | 0.5–1 day |
| 9 | Process lifecycle management | C | 1–2 days |
| 10 | Readium theme & settings integration | C | 2–3 days |
| 11 | Regression testing + v2.0 build | C | 1–2 days |
| 12 | OpenStore v2.0 submission | C | 0.5 days |
| **Total** | | | **~10–19 dev-days** |

At part-time pace (2–3 hours/day): **6–10 calendar weeks** after v1.x ships.

The critical path is Steps 3 → 4 → 6 → 7 → 9. Everything else is parallelisable or can flex.

---

*See also: [v2 architecture roadmap](bearthen-2.0-roadmap.md)*
