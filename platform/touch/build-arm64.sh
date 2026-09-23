#!/bin/bash
set -e

# Build an arch-specific click package bundling the r2-streamer binary.
# Usage: ./build-arm64.sh [arm64|armhf]  (default: arm64)
#
# Prerequisites:
#   - r2-streamer binary compiled in core/streamer/bin/  (Stage 3)
#   - clickable installed (snap or pip) — the build itself runs inside
#     clickable's own docker image, which already bundles the click packaging
#     tool, so `click` does not need to be installed on the host
#   - Device connected via ADB for the install step
#
# Run: cd platform/touch && bash build-arm64.sh arm64

ARCH="${1:-arm64}"
BINARY="../../core/streamer/bin/r2-streamer-${ARCH}"

if [ ! -f "$BINARY" ]; then
    echo "ERROR: $BINARY not found."
    echo "Compile r2-streamer-go for ${ARCH} first (see Stage 3 in the roadmap)."
    exit 1
fi

# Swap in the arch-specific clickable config and manifest.
cp clickable.yaml     clickable.yaml.epub-js-backup
cp manifest.json      manifest.json.epub-js-backup
cp clickable-arm64.yaml clickable.yaml
cp manifest-arm64.json  manifest.json

# `clickable build` runs postbuild.sh INSIDE a docker container that only
# bind-mounts platform/touch/ — core/streamer/bin/ at the repo root is not
# visible in there. Stage the binary inside platform/touch/ first so it rides
# along in the mount; postbuild.sh looks for it at .stage-bin/.
mkdir -p .stage-bin
cp "$BINARY" ".stage-bin/r2-streamer-${ARCH}"

cleanup() {
    cp clickable.yaml.epub-js-backup clickable.yaml
    cp manifest.json.epub-js-backup  manifest.json
    rm -f clickable.yaml.epub-js-backup manifest.json.epub-js-backup
    rm -rf .stage-bin
}
trap cleanup EXIT

# No --container-mode: that flag tells clickable "the tools are already on the
# host," but clickable ships as a strictly-confined snap that can't see a
# host-installed `click` binary. Letting clickable use its own docker image
# (the default) is what actually works.
clickable build --arch "$ARCH"
# Install runs on the host (no docker needed) so clickable can reach ADB
clickable install --arch "$ARCH"
