#!/usr/bin/env bash
#
# Full test suite, meant to run inside the clean-Ubuntu container defined in
# test/Dockerfile. It runs the real one-command install (so install.sh itself
# is exercised, incl. installing tmux on a clean box), then checks the Russian
# layout support both structurally (list-keys) and end-to-end (real keystrokes
# fed through a pty client — the only faithful way, since `send-keys` bypasses
# tmux key tables).
set -u
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 TERM=xterm-256color
REPO="${REPO:-/repo}"

pass=0; fail=0
ok()   { printf '  \033[1;32mPASS\033[0m %s\n' "$1"; pass=$((pass+1)); }
no()   { printf '  \033[1;31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1 ($2)"; else no "$1 (expected '$3', got '$2')"; fi; }

echo "== 1. one-command install on clean Ubuntu =="
command -v tmux >/dev/null && { echo "tmux pre-installed — not a clean box"; exit 2; }
FORCE=1 bash "$REPO/install.sh" >/tmp/install.log 2>&1 || { echo "install.sh failed:"; cat /tmp/install.log; exit 1; }
command -v tmux >/dev/null && ok "install.sh installed tmux" || no "tmux missing after install"
[ -L "$HOME/.tmux.conf" ]        && ok "~/.tmux.conf symlink created"   || no "~/.tmux.conf missing"
[ -f "$HOME/.tmux.conf.local" ]  && ok "~/.tmux.conf.local installed"   || no "local config missing"
[ -x "$HOME/.tmux/cyrillic-layout.sh" ] && ok "layout script installed" || no "layout script missing"

echo "== 2. config loads and mirror runs =="
tmux kill-server 2>/dev/null
tmux new-session -d -s t -x 120 -y 40 || { echo "tmux failed to start with config"; exit 1; }
# Briefly attach a client so the client-attached hook fires — this is what
# runs the mirror after oh-my-tmux finishes setting up (incl. clipboard keys).
# Bindings persist after the client detaches.
python3 -c 'import os,subprocess,time; m,s=os.openpty(); p=subprocess.Popen(["tmux","attach","-t","t"],stdin=s,stdout=s,stderr=s,close_fds=True); time.sleep(1.5); p.terminate()'
sleep 0.5

# helper: command bound to a key in a table (empty if unbound)
cmd_for(){ tmux list-keys -T "$1" 2>/dev/null | awk -v k="$2" '$4==k{$1=$2=$3=$4="";sub(/^ +/,"");print;exit}'; }

echo "== 3. structural: Cyrillic mirrors match their Latin source =="
check "root  M-я  == M-z"                 "$(cmd_for root M-я)"          "$(cmd_for root M-z)"
check "prefix с   == c"                   "$(cmd_for prefix с)"         "$(cmd_for prefix c)"
check "prefix й   == q (kill/display)"    "$(cmd_for prefix й)"         "$(cmd_for prefix q)"
check "copy-vi н  == y (copy)"            "$(cmd_for copy-mode-vi н)"   "$(cmd_for copy-mode-vi y)"
check "copy-vi и  == b (back word)"       "$(cmd_for copy-mode-vi и)"   "$(cmd_for copy-mode-vi b)"

echo "== 4. idempotency: re-running the mirror changes nothing =="
n1=$(tmux list-keys -T prefix | wc -l)
bash "$HOME/.tmux/cyrillic-layout.sh"
n2=$(tmux list-keys -T prefix | wc -l)
check "prefix binding count stable" "$n2" "$n1"

echo "== 5. end-to-end: real Cyrillic keystrokes via pty client =="
tmux kill-server 2>/dev/null
tmux new-session -d -s e -x 120 -y 40
sleep 1
tmux split-window -t e            # 2 panes so zoom is meaningful
python3 - > /tmp/e2e.env <<'PY'
import os, subprocess, time
def q(*a): return subprocess.run(['tmux',*a],capture_output=True,text=True).stdout.strip()
def send(b, w=0.6): os.write(M, b); time.sleep(w)
m, s = os.openpty(); M = m
p = subprocess.Popen(['tmux','attach','-t','e'], stdin=s, stdout=s, stderr=s, close_fds=True)
time.sleep(1.0)
# Alt+я -> zoom toggle (window has 2 panes)
z0 = q('display','-p','#{window_zoomed_flag}')
send(b'\x1b'+'я'.encode()); z1 = q('display','-p','#{window_zoomed_flag}')
send(b'\x1b'+'я'.encode()); z2 = q('display','-p','#{window_zoomed_flag}')
print(f"zoom={z0} {z1} {z2}")
# prefix(C-b) + с -> new-window
w0 = q('display','-p','#{session_windows}')
send(b'\x02'+'с'.encode()); w1 = q('display','-p','#{session_windows}')
print(f"newwin={w0} {w1}")
# regression: prefix + Latin c still works
send(b'\x02'+b'c'); w2 = q('display','-p','#{session_windows}')
print(f"newwin_latin={w1} {w2}")
# prefix + х (=[) enters copy-mode; й (=q) exits
m0 = q('display','-p','#{pane_in_mode}')
send(b'\x02'+'х'.encode()); m1 = q('display','-p','#{pane_in_mode}')
send('й'.encode());          m2 = q('display','-p','#{pane_in_mode}')
print(f"copymode={m0} {m1} {m2}")
p.terminate()
PY
get(){ awk -F= -v k="$1" '$1==k{print $2}' /tmp/e2e.env; }
check "Alt+я zoom toggle"          "$(get zoom)"         "0 1 0"
check "prefix + с -> new-window"   "$(get newwin)"       "1 2"
check "prefix + c (latin) still ok" "$(get newwin_latin)" "2 3"
check "prefix + х enter / й exit copy-mode" "$(get copymode)" "0 1 0"

echo
echo "==================================="
echo "  PASS: $pass   FAIL: $fail"
echo "==================================="
[ "$fail" -eq 0 ] || exit 1
