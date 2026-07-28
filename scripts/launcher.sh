#!/data/data/com.termux/files/usr/bin/bash
set -e

export OPENCODE_DISABLE_SHARE=1
export OPENCODE_DISABLE_TELEMETRY=1
export OPENCODE_DISABLE_DEFAULT_PLUGINS=1
export TMPDIR="${TMPDIR:-$PREFIX/tmp}"
export BUN_TERMUX_CACHE="${BUN_TERMUX_CACHE:-$PREFIX/var/bun-cache}"

mkdir -p "$BUN_TERMUX_CACHE"
rm -f "$TMPDIR/opencode-"* 2>/dev/null || true

exec opencode-termux "$@"
