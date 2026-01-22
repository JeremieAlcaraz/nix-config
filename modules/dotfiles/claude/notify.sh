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

run_with_timeout() {
  local timeout="$1"
  shift
  "$@" &
  local pid=$!
  local end=$((SECONDS + timeout))
  while kill -0 "$pid" >/dev/null 2>&1; do
    if ((SECONDS >= end)); then
      kill -TERM "$pid" >/dev/null 2>&1 || true
      return 124
    fi
    sleep 0.1
  done
  wait "$pid"
}

if command -v terminal-notifier >/dev/null 2>&1; then
  notify_with_sender=(
    -title "$title"
    -message "$msg"
    -sender "$WEZTERM_BUNDLE_ID"
    -activate "$WEZTERM_BUNDLE_ID"
  )
  notify_no_sender=(
    -title "$title"
    -message "$msg"
    -activate "$WEZTERM_BUNDLE_ID"
  )
  if [[ -n "$repo_name" ]]; then
    notify_with_sender+=(-subtitle "$repo_name")
    notify_no_sender+=(-subtitle "$repo_name")
  fi

  if run_with_timeout 2 terminal-notifier "${notify_with_sender[@]}" >/dev/null 2>&1; then
    exit 0
  fi
  if run_with_timeout 2 terminal-notifier "${notify_no_sender[@]}" >/dev/null 2>&1; then
    exit 0
  fi
fi

if [[ -n "$repo_name" ]]; then
  osascript -e "display notification \"${msg}\" with title \"${title}\" subtitle \"${repo_name}\""
else
  osascript -e "display notification \"${msg}\" with title \"${title}\""
fi
