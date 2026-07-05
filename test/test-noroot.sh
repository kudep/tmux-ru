#!/usr/bin/env bash
#
# Regression test for the gpu12 case: an unprivileged user, tmux already
# installed, no clipboard tool, no sudo. install.sh must NOT require admin
# rights — it should install the config and just warn that clipboard
# integration is off.
set -u
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 TERM=xterm-256color

pass=0; fail=0
ok(){ printf '  \033[1;32mPASS\033[0m %s\n' "$1"; pass=$((pass+1)); }
no(){ printf '  \033[1;31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }

echo "== preconditions (must mimic gpu12) =="
[ "$(id -u)" -ne 0 ]              && ok "running unprivileged"         || { no "running as root"; exit 2; }
command -v tmux >/dev/null        && ok "tmux preinstalled"            || { no "tmux missing"; exit 2; }
! command -v xsel  >/dev/null && ! command -v xclip >/dev/null && ok "no clipboard tool" || no "clipboard tool present"
! command -v sudo  >/dev/null     && ok "no sudo available"            || no "sudo present"

echo "== install without admin =="
FORCE=1 bash /repo/install.sh >/tmp/out.log 2>&1; rc=$?
sed 's/^/    | /' /tmp/out.log
[ "$rc" -eq 0 ]                        && ok "install.sh exited 0 (no admin needed)" || no "install.sh failed (rc=$rc)"
[ -L "$HOME/.tmux.conf" ]              && ok "~/.tmux.conf symlink created"          || no "symlink missing"
[ -f "$HOME/.tmux.conf.local" ]        && ok "~/.tmux.conf.local installed"          || no "local config missing"
[ -x "$HOME/.tmux/cyrillic-layout.sh" ] && ok "layout script installed"             || no "layout script missing"
grep -qi "clipboard integration off" /tmp/out.log && ok "warned that clipboard is off" || no "missing clipboard warning"
! grep -qiE "password|permission denied|not in the sudoers" /tmp/out.log && ok "no admin/password prompt in output" || no "admin was requested"

echo "== tmux starts with the installed config =="
tmux kill-server 2>/dev/null
tmux new-session -d -s t -x 80 -y 24 && ok "tmux starts" || no "tmux failed to start"
tmux kill-server 2>/dev/null

echo
echo "  PASS: $pass   FAIL: $fail"
[ "$fail" -eq 0 ] || exit 1
