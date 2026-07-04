#!/usr/bin/env bash
#
# cyrillic-layout.sh — mirror Latin tmux key bindings onto their Russian
# (ЙЦУКЕН) equivalents, so keybindings keep working when the keyboard layout
# is switched to Cyrillic.
#
# When the layout is Russian, a physical key sends a Cyrillic character
# (z->я, q->й, y->н, ...). tmux then looks up that Cyrillic key in its key
# tables and finds nothing, so the binding appears "broken". This script
# reads every binding in the relevant key tables and creates a duplicate
# binding under the Cyrillic character that shares the same physical key.
#
# It is idempotent: Cyrillic keys are never themselves in the map, so
# re-running (e.g. on config reload) does not cascade.
#
# Invoked from ~/.tmux.conf.local via:  run-shell 'bash "$HOME/.tmux/cyrillic-layout.sh"'
set -euo pipefail

# Positional Latin -> Cyrillic map for the standard Russian ЙЦУКЕН layout,
# lowercase then uppercase, plus the unshifted punctuation that maps cleanly.
# (Shifted symbols like % " ! live on different physical keys between layouts
#  and are intentionally left out.)
MAP="q й w ц e у r к t е y н u г i ш o щ p з [ х ] ъ \
a ф s ы d в f а g п h р j о k л l д ; ж ' э \
z я x ч c с v м b и n т m ь , б . ю \
Q Й W Ц E У R К T Е Y Н U Г I Ш O Щ P З \
A Ф S Ы D В F А G П H Р J О K Л L Д \
Z Я X Ч C С V М B И N Т M Ь"

TABLES="prefix copy-mode copy-mode-vi root"

tmpf="$(mktemp)"
trap 'rm -f "$tmpf"' EXIT

for tbl in $TABLES; do
  # list-keys prints re-runnable "bind-key [-r] -T <table> <key> <command>"
  # lines. We locate the <key> token, and if it is a single Latin character
  # (optionally with an M- modifier) that has a Cyrillic counterpart, we emit
  # an identical binding under the Cyrillic key.
  tmux list-keys -T "$tbl" 2>/dev/null | awk -v MAP="$MAP" -v TBL="$tbl" '
    BEGIN { n = split(MAP, a, " "); for (i = 1; i <= n; i += 2) m[a[i]] = a[i+1] }
    {
      ti = 0
      for (i = 1; i <= NF; i++) if ($i == "-T") { ti = i; break }
      if (!ti) next
      key = $(ti + 2)
      mod = ""
      if (key ~ /^M-.$/) { mod = "M-"; base = substr(key, 3) }
      else               { base = key }
      if (length(base) != 1) next
      if (!(base in m))       next
      cyr = mod m[base]
      # Take the command VERBATIM: drop the first (ti+2) tokens (bind-key,
      # optional -r, -T, table, key) from the raw line, keeping the rest
      # exactly — quotes, "=" and all. Rebuilding it field-by-field would
      # corrupt commands that contain quoted strings.
      line = $0
      for (c = 1; c <= ti + 2; c++) sub(/^[ \t]*[^ \t]+/, "", line)
      sub(/^[ \t]+/, "", line)
      # Skip commands that do not survive a re-parse: those containing ${...}
      # (tmux re-expands them on source-file and errors out). These are the
      # niche config-editing bindings (e.g. prefix+e); nav/copy/zoom are fine.
      if (line ~ /\$\{/) next
      rflag = ($2 == "-r") ? "-r " : ""
      printf "bind-key %s-T %s %s %s\n", rflag, TBL, cyr, line
    }
  ' >> "$tmpf"
done

# Apply all generated bindings through tmux's own parser (robust quoting).
[ -s "$tmpf" ] && tmux source-file "$tmpf"
