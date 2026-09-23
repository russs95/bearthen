#!/bin/bash
set -e

# Runs from build/<arch>/app/ AFTER source files are copied to install/, BEFORE packaging.
# Clickable sets ARCH (arm64 | armhf | amd64).
# The precompiled builder places source files in install/ relative to this CWD.
ARCH="${ARCH:-amd64}"

# clickable build runs this INSIDE a docker container that bind-mounts only
# platform/touch/ — anything above that (e.g. the repo-root core/ dir) does not
# exist in the container's filesystem, even though the path resolves fine when
# run directly on the host. So look first for a binary staged inside
# platform/touch/.stage-bin/ (populated by build-arm64.sh before the container
# starts — three levels up from build/<arch>/app/ reaches platform/touch/),
# and fall back to the repo-root core/ path for host-side / non-container runs.
STAGED="../../../.stage-bin/r2-streamer-${ARCH}"
REPO_ROOT="../../../../../core/streamer/bin/r2-streamer-${ARCH}"

if [ -f "$STAGED" ]; then
    STREAMER="$STAGED"
elif [ -f "$REPO_ROOT" ]; then
    STREAMER="$REPO_ROOT"
else
    STREAMER=""
fi

if [ -n "$STREAMER" ]; then
    # Bundle binary and keep the arch-specific manifest declaration.
    mkdir -p install/bin
    cp "$STREAMER" install/bin/r2-streamer
    chmod +x install/bin/r2-streamer
    echo "Postbuild: bundled r2-streamer (${ARCH})"
else
    # No binary — downgrade manifest to 'all' so click-review passes.
    # Source manifest stays at $ENV{CLICK_ARCH}; only the build-dir copy is patched.
    sed -i 's/"architecture": "[^"]*"/"architecture": "all"/' install/manifest.json
    echo "Postbuild: no r2-streamer for ${ARCH} — epub.js only, architecture → all"
fi
