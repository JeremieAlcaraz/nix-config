#!/usr/bin/env bash

set -euo pipefail

AEROSPACE_BIN="${AEROSPACE_BIN:-/opt/homebrew/bin/aerospace}"
direction="${1:-right}"

case "$direction" in
  left|right|up|down) ;;
  *)
    echo "Direction invalide: $direction" >&2
    exit 2
    ;;
esac

focused="$("$AEROSPACE_BIN" list-windows --focused --format '%{window-id}|%{workspace}' 2>/dev/null || true)"
[ -n "$focused" ] || exit 0

current_window_id="${focused%%|*}"
current_workspace="${focused#*|}"

choices_file="$(mktemp)"
trap 'rm -f "$choices_file"' EXIT

"$AEROSPACE_BIN" list-windows --all --format '%{window-id}|%{workspace}|%{app-name}|%{window-title}' \
  | awk -F'|' -v cur="$current_window_id" '
      $1 != cur {
        title = $4
        if (title == "") title = "(sans titre)"
        printf "%s | [%s] %s - %s\n", $1, $2, $3, title
      }
    ' > "$choices_file"

if [ ! -s "$choices_file" ]; then
  exit 0
fi

if [ "${AERO_SPLIT_PICKER_TEST:-0}" = "1" ]; then
  head -n 5 "$choices_file"
  exit 0
fi

picked="$(osascript - "$choices_file" "$direction" <<'OSA'
on run argv
  set choicesPath to POSIX file (item 1 of argv)
  set splitDirection to item 2 of argv
  set fh to open for access choicesPath
  set content to read fh as «class utf8»
  close access fh
  set itemsList to paragraphs of content
  if (count of itemsList) is 0 then return ""
  set selected to choose from list itemsList with title "Aero Split" with prompt "Direction: " & splitDirection & return & "Choisis une fenêtre à splitter" OK button name "Split" cancel button name "Annuler"
  if selected is false then return ""
  return item 1 of selected
end run
OSA
)"

[ -n "$picked" ] || exit 0

target_window_id="${picked%% |*}"
[ -n "$target_window_id" ] || exit 0

"$AEROSPACE_BIN" move-node-to-workspace --window-id "$target_window_id" "$current_workspace" >/dev/null 2>&1 || true
"$AEROSPACE_BIN" focus --window-id "$current_window_id" >/dev/null 2>&1 || true

join_ok=0
for d in "$direction" right left down up; do
  if "$AEROSPACE_BIN" join-with "$d" >/dev/null 2>&1; then
    join_ok=1
    break
  fi
done

"$AEROSPACE_BIN" balance-sizes --workspace "$current_workspace" >/dev/null 2>&1 || true

if [ "$join_ok" -ne 1 ]; then
  osascript -e 'display notification "Split impossible dans cette direction" with title "AeroSpace"'
fi

