#!/usr/bin/env bash
set -euo pipefail

OPENCODE_DIR="${1:-./opencode}"
TARGET_VERSION="${2:-}"
PATCH_DIR="${3:-./patches}"

if [[ -z "$TARGET_VERSION" ]]; then
    echo "Usage: $0 <opencode-dir> <version> [patch-dir]"
    exit 1
fi

if [[ ! "$TARGET_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid OpenCode version: $TARGET_VERSION"
    echo "Expected semantic version like 1.18.10"
    exit 1
fi

if [[ ! -d "$PATCH_DIR" ]]; then
    echo "Patch directory does not exist: $PATCH_DIR"
    exit 1
fi

echo "[auto-patch] Target: OpenCode v$TARGET_VERSION"
echo "[auto-patch] Patch dir: $PATCH_DIR"

# 1. Bump versions in our repo first
bash scripts/bump-version.sh "$TARGET_VERSION"

# 2. Clone/checkout target version
if [[ -d "$OPENCODE_DIR/.git" ]]; then
    git -C "$OPENCODE_DIR" fetch --depth 1 origin "v$TARGET_VERSION"
    git -C "$OPENCODE_DIR" checkout -f "FETCH_HEAD"
else
    git clone --depth 1 --branch "v$TARGET_VERSION" \
        https://github.com/anomalyco/opencode.git "$OPENCODE_DIR"
fi

# 3. Check patch compatibility
if ! bash scripts/check-patch-compatibility.sh "$OPENCODE_DIR" "$PATCH_DIR"; then
    echo "[auto-patch] ✗ Patches incompatible with v$TARGET_VERSION"
    echo "[auto-patch] Manual fix required. Aborting."
    exit 1
fi

# 4. Apply patches
echo "[auto-patch] Applying patches..."
for patch in "$PATCH_DIR"/*.patch; do
    [[ -f "$patch" ]] || continue
    git -C "$OPENCODE_DIR" apply "$patch"
    echo "  ✓ $(basename "$patch")"
done

# 5. Run sed-based patches (termux-patch.sh)
bash scripts/termux-patch.sh "$OPENCODE_DIR"

echo "[auto-patch] ✓ Ready to build v$TARGET_VERSION"
