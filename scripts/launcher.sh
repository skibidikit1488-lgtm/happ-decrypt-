#!/data/data/com.termux/files/usr/bin/bash
# OpenCode launcher for Termux
# Handles TTY cleanup, signal forwarding, and stale lock removal
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCODE_RUNTIME="$SELF_DIR/../lib/opencode/runtime/opencode"

cleanup_tty_full() {
  if [ -t 1 ]; then
    printf '\033[?1049l\033[?25h\033[0m' >/dev/tty 2>/dev/null || true
  fi
  if command -v stty >/dev/null 2>&1; then stty sane 2>/dev/null || true; fi
  if command -v tput >/dev/null 2>&1; then tput rmcup >/dev/null 2>&1 || true; fi
}

cleanup_tty_soft() {
  if command -v stty >/dev/null 2>&1; then stty sane 2>/dev/null || true; fi
  if [ -t 1 ]; then
    printf '\033[?25h\033[0m' >/dev/tty 2>/dev/null || true
  fi
}

cleanup_state_locks() {
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/opencode"
  if [ -d "$state_dir" ]; then
    find "$state_dir" -maxdepth 1 -type f -name '*.lock' -delete 2>/dev/null || true
  fi
}

# Signal handlers
trap 'cleanup_tty_full; exit 130' INT TERM HUP QUIT

# Clean stale locks on startup
cleanup_state_locks

# Disable default plugins (Termux compatibility)
: "${OPENCODE_DISABLE_DEFAULT_PLUGINS:=1}"
export OPENCODE_DISABLE_DEFAULT_PLUGINS

# Verify runtime exists
if [[ ! -x "$OPENCODE_RUNTIME" ]]; then
  echo "opencode: runtime not found at $OPENCODE_RUNTIME" >&2
  echo "Did you install glibc?  pkg install glibc openssl-glibc" >&2
  exit 1
fi

# Forward all args to OpenCode
if "$OPENCODE_RUNTIME" "$@"; then
  rc=0
else
  rc=$?
fi

# Cleanup based on exit code
if [ "$rc" -eq 0 ]; then
  cleanup_tty_soft
else
  cleanup_tty_full
fi


exit "$rc"
