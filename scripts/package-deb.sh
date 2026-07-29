#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

BINARY="./opencode-termux"
OUTPUT="./opencode-termux.deb"
VERSION="1.18.9"

while [[ $# -gt 0 ]]; do
  case $1 in
    --binary) BINARY="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    *) BINARY="$1"; OUTPUT="${2:-$OUTPUT}"; break ;;
  esac
done

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
