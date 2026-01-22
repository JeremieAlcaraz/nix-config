#!/usr/bin/env bash
set -euo pipefail

msg="${1:-Claude Code}"
title="Claude Code"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
repo_name=""
if [[ -n "$repo_root" ]]; then
  repo_name="$(basename "$repo_root")"
fi

if [[ -n "${WEZTERM_PANE:-}" ]]; then
  cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/wezterm"
  queue_file="${cache_root}/claude-notify"
  mkdir -p "$cache_root"
  printf '%s\t%s\t%s\n' "$title" "$msg" "$repo_name" >> "$queue_file"
  exit 0
fi

if command -v terminal-notifier >/dev/null 2>&1; then
  args=(
    -title "$title"
    -message "$msg"
    -execute "open -a WezTerm"
  )
  if [[ -n "$repo_name" ]]; then
    args+=(-subtitle "$repo_name")
  fi

  wezterm_app_path="$(osascript -e 'POSIX path of (path to application "WezTerm")' 2>/dev/null || true)"
  if [[ -n "$wezterm_app_path" ]]; then
    for icon in \
      "$wezterm_app_path/Contents/Resources/WezTerm.icns" \
      "$wezterm_app_path/Contents/Resources/wezterm.icns"
    do
      if [[ -f "$icon" ]]; then
        args+=(-appIcon "$icon")
        break
      fi
    done
  fi

  terminal-notifier "${args[@]}" >/dev/null 2>&1 &
  exit 0
fi

if [[ -n "$repo_name" ]]; then
  osascript -e "display notification \"${msg}\" with title \"${title}\" subtitle \"${repo_name}\""
else
  osascript -e "display notification \"${msg}\" with title \"${title}\""
fi
