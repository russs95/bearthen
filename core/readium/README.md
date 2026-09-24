# Readium Web JS shell (`@d-i-t-a/reader` / R2D2BC / "D2Reader")

**What this is:** the built, EPUB-only, minified JS bundle for R2D2BC (repo:
[`d-i-t-a/R2D2BC`](https://github.com/d-i-t-a/R2D2BC), npm package
`@d-i-t-a/reader`, exported class `D2Reader`). Consumes a Readium Web
Publication Manifest served by `core/streamer/bin/r2-streamer-*` and renders
paginated EPUB content into an iframe, with TOC, bookmarks, search,
annotations, and reflowable-text settings (font size/family, spacing,
day/sepia/night themes) built in.

## Why R2D2BC and not `readium/web` (`ts-toolkit`)

Evaluated 2026-09-23 (Step 5, `docs/bearthen-2-step-by-step.md`). The
"officially paired" toolkit for our Go server (`readium/cli`, which wraps
`readium/go-toolkit`) is `readium/web`/`readium/ts-toolkit` — but that ships
as low-level library pieces (`@readium/navigator`, `@readium/shared`,
`@readium/navigator-html-injectables`), not a ready reader UI; using it means
building our own paginated-reader chrome from scratch. R2D2BC is a drop-in
`D2Reader` class with mobile-aware CSS and the TOC/bookmark/settings surface
we need already built, and — being manifest-format-driven (RWPM is a spec,
not tied to a specific server implementation) — it works against our
`readium/cli`-served manifests with no adaptation. Confirmed by direct test:
pointed a built `D2Reader` instance at a local `r2-streamer-amd64 serve`
instance's `/webpub/.../manifest.json` for a real EPUB and it rendered the
cover and parsed the 9-item TOC correctly in a real browser (headless Chrome
screenshot).

## Provenance / how this was built

```bash
git clone https://github.com/d-i-t-a/R2D2BC
cd R2D2BC
npm install        # runs the `prepare` script, which builds dist/ automatically
```

That produces both `dist/esm/index.js` (ES module, for `import D2Reader from
'...'`) and `dist/reader.js` (IIFE, assigns the global `window.D2Reader` — for
a plain `<script src="...">` tag), plus a PDF.js viewer, audio worklet, and
source maps we don't need for an EPUB-only reader.

**Use `reader.js` (the IIFE build), not `esm/index.js`.** The ESM build was
tried first and works fine served over HTTP, but fails silently when loaded
via `file://` (as `ReaderPage.qml`'s WebView does): `file://` URLs carry no
`Content-Type` header, and Chromium enforces strict MIME-type checking for
`<script type="module">`, so the import throws `Failed to load module
script: The server responded with a non-JavaScript MIME type of ""`. This
was caught on real hardware — the reader's `init()` never ran, so the
book-ready signal never fired and the app's splash spinner spun forever. The
IIFE build sidesteps this entirely (no `import`, just a global assignment),
which is exactly why R2D2BC ships both formats.

```bash
# reader.js already ships minified from R2D2BC's own build (esbuild, IIFE) —
# no further minification needed, unlike the ESM build.
cp dist/reader.js .

# Keep only what an EPUB reflowable/paginated reader needs:
#   reader.js      — the D2Reader class, as window.D2Reader (IIFE)
#   reader.css     — reader chrome styles (verified: no url()/PDF references)
#   injectables/   — in-iframe pagination CSS/JS (mui, click, style/*)
# Dropped: esm/, *.map, pdf.worker.min.mjs, pdf_viewer.css, images/ (PDF.js
# viewer icons, unreferenced by reader.css), PreservePitchProcessor.js (audio).
```

Result: **2.3MB** (2.1MB JS + ~200KB CSS/injectables), well inside the
roadmap's ≤22MB arm64 package budget.

## Not yet done

This directory is the vendored shell only. `platform/touch/assets/readium/`
holds a physical copy of it plus `reader-readium.html` (the Bearthen-authored
harness `ReaderPage.qml`'s WebView actually loads via `<script
src="./reader.js">`) — see `CLAUDE.md` → "Readium Web JS shell" for how that's
wired into `ReaderPage`. Bookmarks, highlights, and font/theme settings are
not yet ported to the Readium path — Stage 8 territory.

## Rebuilding

There's no build step checked into this repo (R2D2BC isn't vendored as
source) — to rebuild, repeat the provenance steps above against a fresh
`git clone` of `d-i-t-a/R2D2BC` and copy the trimmed output back into this
directory. Pin to a specific R2D2BC release/commit if reproducibility becomes
important (not yet done — this bundle was built from `develop` HEAD as of
2026-09-23).
