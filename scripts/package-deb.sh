#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

BINARY="${1:-./opencode-termux}"
OUTPUT="${2:-./opencode-termux.deb}"
VERSION="${3:-1.18.8}"
PREFIX=/data/data/com.termux/files/usr

mkdir -p .debpkg/DEBIAN
mkdir -p .debpkg"$PREFIX"/bin

cat > .debpkg/DEBIAN/control << EOF
Package: opencode
Version: $VERSION
Section: utils
Priority: optional
Architecture: aarch64
Depends: glibc, openssl-glibc, bash, ncurses
Maintainer: OpenCode Termux Builder
Description: OpenCode AI coding agent for Termux (wrapper build)
EOF

cp "$BINARY" .debpkg"$PREFIX"/bin/opencode
chmod 755 .debpkg"$PREFIX"/bin/opencode

dpkg-deb --build .debpkg "$OUTPUT"
rm -rf .debpkg
echo "[*] Built: $OUTPUT"
