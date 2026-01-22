#!/usr/bin/env bash
set -euo pipefail

msg="${1:-Claude Code}"
title="Claude Code"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
repo_name=""
if [[ -n "$repo_root" ]]; then
  repo_name="$(basename "$repo_root")"
fi

WEZTERM_BUNDLE_ID="com.github.wez.wezterm"

# Ensure WezTerm is running so click-to-focus works consistently.
open -b "$WEZTERM_BUNDLE_ID" -g >/dev/null 2>&1 || true

if command -v terminal-notifier >/dev/null 2>&1; then
  args=(
    -title "$title"
    -message "$msg"
    -sender "$WEZTERM_BUNDLE_ID"
    -activate "$WEZTERM_BUNDLE_ID"
  )
  if [[ -n "$repo_name" ]]; then
    args+=(-subtitle "$repo_name")
  fi
  terminal-notifier "${args[@]}" >/dev/null 2>&1 &
  exit 0
fi

if [[ -n "$repo_name" ]]; then
  osascript -e "display notification \"${msg}\" with title \"${title}\" subtitle \"${repo_name}\""
else
  osascript -e "display notification \"${msg}\" with title \"${title}\""
fi
