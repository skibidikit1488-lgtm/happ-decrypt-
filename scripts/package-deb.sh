#!/bin/bash
set -euo pipefail

# package-deb.sh <wrapped-binary> <version> <output-dir>
BINARY="${1:-}"
VERSION="${2:-0.0.0}"
OUTDIR="${3:-$(pwd)}"

if [[ -z "$BINARY" || ! -f "$BINARY" ]]; then
  echo "Usage: $0 <wrapped-binary> <version> [output-dir]" >&2
  exit 1
fi

PKGNAME="opencode"
ARCH="aarch64"
DEBVER="${VERSION//-/_}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# Directory structure
mkdir -p "$WORKDIR/DEBIAN"
mkdir -p "$WORKDIR/data/data/com.termux/files/usr/bin"
mkdir -p "$WORKDIR/data/data/com.termux/files/usr/lib/opencode/runtime"
mkdir -p "$WORKDIR/data/data/com.termux/files/usr/lib/opencode/tools"
mkdir -p "$WORKDIR/data/data/com.termux/files/usr/share/opencode/docs"

# Install binary
install -m 755 "$BINARY" "$WORKDIR/data/data/com.termux/files/usr/lib/opencode/runtime/opencode"

# Install launcher
install -m 755 "$(dirname "$0")/launcher.sh" \
  "$WORKDIR/data/data/com.termux/files/usr/bin/opencode"

# Control file
cat > "$WORKDIR/DEBIAN/control" << EOF
Package: ${PKGNAME}
Version: ${DEBVER}
Architecture: ${ARCH}
Maintainer: OpenCode Termux Builder <builder@localhost>
Depends: glibc, openssl-glibc, bash, ncurses
Section: devel
Priority: optional
Description: OpenCode AI coding assistant for Termux
 OpenCode is an open-source AI coding agent.
 This package wraps the upstream Linux ARM64 binary
 for Android/Bionic via bun-termux-loader.
 Requires glibc (install: pkg install glibc).
EOF

# Pre-install: check glibc
# Post-install: success message
# Post-remove: cleanup

# Build package
fakeroot dpkg-deb --build "$WORKDIR" "$OUTDIR/${PKGNAME}_${DEBVER}_${ARCH}.deb"
echo "Built: $OUTDIR/${PKGNAME}_${DEBVER}_${ARCH}.deb"
