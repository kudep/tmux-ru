#!/usr/bin/env bash
#
# tmux-ru installer — oh-my-tmux + mouse/clipboard/zoom tweaks + Russian
# keyboard-layout support, in one command.
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/kudep/tmux-ru/main/install.sh)"
#
# Idempotent and safe: existing tmux config is backed up, not clobbered.
set -euo pipefail

REPO_URL="https://github.com/kudep/tmux-ru"
BRANCH="main"

info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

SUDO=""
[ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null && SUDO="sudo"

apt_install() {
  command -v apt-get >/dev/null || { warn "no apt-get; install manually: $*"; return 0; }
  info "Installing: $*"
  $SUDO apt-get update -qq
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -qq "$@"
}

# --- locate source: local checkout (running from the repo) or fetch it -------
SELF="${BASH_SOURCE[0]:-$0}"
SRC=""
if SELF_DIR=$(cd "$(dirname "$SELF")" 2>/dev/null && pwd); then
  [ -f "$SELF_DIR/tmux/tmux.conf" ] && SRC="$SELF_DIR"
fi
CLEANUP=""
trap '[ -n "$CLEANUP" ] && rm -rf "$CLEANUP"' EXIT
if [ -z "$SRC" ]; then
  command -v git >/dev/null || apt_install git
  command -v git >/dev/null || die "git is required to fetch the repo"
  CLEANUP=$(mktemp -d)
  info "Fetching $REPO_URL ($BRANCH)"
  git clone --depth 1 -b "$BRANCH" "$REPO_URL" "$CLEANUP/repo" >/dev/null 2>&1 \
    || die "git clone failed"
  SRC="$CLEANUP/repo"
fi

# --- dependencies ------------------------------------------------------------
need=""
command -v tmux >/dev/null || need="$need tmux"
command -v xsel >/dev/null || command -v xclip >/dev/null || need="$need xsel"
# shellcheck disable=SC2086
[ -n "$need" ] && apt_install $need
command -v tmux >/dev/null || die "tmux not available after install"

# --- backup + install config -------------------------------------------------
ts=$(date +%Y%m%d-%H%M%S)
backup() { { [ -e "$1" ] || [ -L "$1" ]; } || return 0; mv "$1" "$1.bak-$ts"; warn "backup: $1 -> $1.bak-$ts"; }

info "Installing oh-my-tmux core + Russian-layout helper into ~/.tmux"
mkdir -p "$HOME/.tmux"
install -m 0644 "$SRC/tmux/tmux.conf"          "$HOME/.tmux/.tmux.conf"
install -m 0755 "$SRC/tmux/cyrillic-layout.sh" "$HOME/.tmux/cyrillic-layout.sh"

backup "$HOME/.tmux.conf"
ln -s "$HOME/.tmux/.tmux.conf" "$HOME/.tmux.conf"

if [ -e "$HOME/.tmux.conf.local" ] && [ -z "${FORCE:-}" ]; then
  warn "~/.tmux.conf.local exists — kept as is (set FORCE=1 to overwrite)"
else
  backup "$HOME/.tmux.conf.local"
  install -m 0644 "$SRC/tmux/tmux.conf.local" "$HOME/.tmux.conf.local"
fi

# apply now if a server is already running
if command -v tmux >/dev/null && tmux info >/dev/null 2>&1; then
  tmux source-file "$HOME/.tmux.conf" >/dev/null 2>&1 || true
  info "Reloaded the running tmux server."
fi

cat <<'EOF'

Done. Start tmux (or reload with:  tmux source-file ~/.tmux.conf)

  • Mouse on: click a window name to switch, wheel to scroll logs.
  • Alt+z: zoom / un-zoom the current pane.
  • Selecting with the mouse copies to the system clipboard (X11 + xsel).
  • Russian layout: all key bindings also work in Cyrillic (ЙЦУКЕН).
EOF
