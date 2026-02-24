#!/usr/bin/env bash

set -euo pipefail

target_workspace_for_app() {
  case "${1:-}" in
    "Arc") echo "1" ;;
    "Notion") echo "2" ;;
    "Notion Calendar") echo "3" ;;
    "WezTerm") echo "4" ;;
    *) echo "" ;;
  esac
}

expected_app_for_workspace() {
  case "${1:-}" in
    "1") echo "Arc" ;;
    "2") echo "Notion" ;;
    "3") echo "Notion Calendar" ;;
    "4") echo "WezTerm" ;;
    *) echo "" ;;
  esac
}

# 1) Place target apps into dedicated workspaces.
while IFS='|' read -r window_id workspace app_name; do
  target_ws="$(target_workspace_for_app "$app_name")"
  if [[ -n "$target_ws" && "$workspace" != "$target_ws" ]]; then
    aerospace move-node-to-workspace --window-id "$window_id" "$target_ws" >/dev/null 2>&1 || true
  fi
done < <(aerospace list-windows --all --format '%{window-id}|%{workspace}|%{app-name}')

# 2) Ensure workspaces 1-4 contain only their dedicated apps.
overflow_toggle=0
while IFS='|' read -r window_id workspace app_name; do
  case "$workspace" in
    1|2|3|4)
      expected_app="$(expected_app_for_workspace "$workspace")"
      if [[ "$app_name" != "$expected_app" ]]; then
        if (( overflow_toggle % 2 == 0 )); then
          dest_ws="5"
        else
          dest_ws="6"
        fi
        overflow_toggle=$((overflow_toggle + 1))
        aerospace move-node-to-workspace --window-id "$window_id" "$dest_ws" >/dev/null 2>&1 || true
      fi
      ;;
  esac
done < <(aerospace list-windows --all --format '%{window-id}|%{workspace}|%{app-name}')

# 3) Normalize tree/sizes on affected workspaces.
for ws in 1 2 3 4 5 6; do
  aerospace flatten-workspace-tree --workspace "$ws" >/dev/null 2>&1 || true
  aerospace balance-sizes --workspace "$ws" >/dev/null 2>&1 || true
done

