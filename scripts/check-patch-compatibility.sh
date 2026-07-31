#!/usr/bin/env bash
set -euo pipefail

OPENCODE_DIR="${1:-./opencode}"
PATCH_DIR="${2:-./patches}"

echo "[check] Dry-running patches against $OPENCODE_DIR..."

for patch in "$PATCH_DIR"/*.patch; do
    [[ -f "$patch" ]] || continue
    echo "  → $(basename "$patch")"
    if ! git -C "$OPENCODE_DIR" apply --check "$patch" 2>/dev/null; then
        echo "    ✗ FAIL — patch incompatible"
        exit 1
    fi
    echo "    ✓ OK"
done

echo "[check] All patches compatible."
