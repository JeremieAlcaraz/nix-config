#!/usr/bin/env bash

set -euo pipefail

state_dir="${HOME}/.cache"
state_file="${state_dir}/aerospace-last-non-raycast-workspace"
mkdir -p "${state_dir}"

focused="$(aerospace list-windows --focused --format '%{window-id}|%{workspace}|%{app-bundle-id}|%{window-title}|%{window-layout}' 2>/dev/null || true)"
[ -n "$focused" ] || exit 0

window_id="${focused%%|*}"
rest="${focused#*|}"
workspace="${rest%%|*}"
rest="${rest#*|}"
app_id="${rest%%|*}"
rest="${rest#*|}"
title="${rest%%|*}"
layout="${rest##*|}"

if [ "${app_id}" != "com.raycast.macos" ] || [ "${title}" != "AI Chat" ]; then
  printf '%s' "${workspace}" > "${state_file}"
  exit 0
fi

target_workspace="$(cat "${state_file}" 2>/dev/null || true)"

if [ -n "${target_workspace}" ] && [ "${target_workspace}" != "${workspace}" ]; then
  aerospace move-node-to-workspace --focus-follows-window --window-id "${window_id}" "${target_workspace}"
fi

case "${layout}" in
  "floating")
    exit 0
    ;;
  *)
    aerospace layout floating
    ;;
esac
