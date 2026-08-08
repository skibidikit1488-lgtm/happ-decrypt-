#!/usr/bin/env bash
set -euo pipefail

NEW_VERSION="${1:-}"
if [[ -z "$NEW_VERSION" ]]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.18.10"
    exit 1
fi

if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version: $NEW_VERSION"
    echo "Expected semantic version like 1.18.10"
    exit 1
fi

echo "[bump] Updating version references to $NEW_VERSION..."

# 1. Patch file: 0001-android-support.patch
PATCH="patches/0001-android-support.patch"
if [[ -f "$PATCH" ]]; then
    sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$NEW_VERSION\"/" "$PATCH"
    echo "  ✓ $PATCH"
fi

# 2. package-deb.sh
sed -i "s/VERSION=\"[^\"]*\"/VERSION=\"$NEW_VERSION\"/" "scripts/package-deb.sh"
echo "  ✓ scripts/package-deb.sh"

# 3. termux-wrap.yml (GitHub workflow)
sed -i "s/ref: v[0-9.]*/ref: v$NEW_VERSION/" ".github/workflows/termux-wrap.yml"
echo "  ✓ .github/workflows/termux-wrap.yml"

# 4. README / any docs
sed -i "s/v[0-9.][0-9.]*[0-9]/$NEW_VERSION/g" "README.md" 2>/dev/null || true

echo "[bump]Done."
