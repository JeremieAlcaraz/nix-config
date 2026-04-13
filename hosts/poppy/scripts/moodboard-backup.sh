#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-$HOME/apps/moodboard}"
RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive_capsule}"
RCLONE_DEST_PATH="${RCLONE_DEST_PATH:-moodboard}"
GARAGE_VOLUME_NAME="${GARAGE_VOLUME_NAME:-moodboard_garage-data}"

KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-3}"

STAMP="$(date -u +%Y-%m-%d_%H%M%S)"
ARCHIVE_NAME="moodboard-${STAMP}.tar.zst"
ARCHIVE="/tmp/${ARCHIVE_NAME}"
STAGING_DIR="/tmp/moodboard-backup-${STAMP}"

get_mountpoint() {
  nerdctl volume inspect "$GARAGE_VOLUME_NAME" | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["Mountpoint"])'
}

prune_remote_dir() {
  local tier="$1"
  local keep="$2"
  local base="${RCLONE_REMOTE}:${RCLONE_DEST_PATH}/${tier}"

  local files
  files="$(rclone lsf --files-only "$base" 2>/dev/null | sort -r || true)"
  [ -z "$files" ] && return 0

  local idx=0
  while IFS= read -r f; do
    idx=$((idx + 1))
    if [ "$idx" -gt "$keep" ]; then
      echo "[backup] prune ${tier}: $f"
      rclone deletefile "${base}/${f}" || true
    fi
  done <<< "$files"
}

copy_to_tier() {
  local tier="$1"
  local remote="${RCLONE_REMOTE}:${RCLONE_DEST_PATH}/${tier}/${ARCHIVE_NAME}"
  echo "[backup] upload -> $remote"
  rclone copyto "$ARCHIVE" "$remote"
}

MOUNTPOINT="$(get_mountpoint)"
if [ -z "$MOUNTPOINT" ] || [ ! -d "$MOUNTPOINT" ]; then
  echo "ERROR: garage volume mountpoint not found: $MOUNTPOINT" >&2
  exit 1
fi

echo "[backup] volume: $GARAGE_VOLUME_NAME"
echo "[backup] mountpoint: $MOUNTPOINT"
echo "[backup] archive: $ARCHIVE"

echo "[backup] staging files"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/garage" "$STAGING_DIR/app/assets" "$STAGING_DIR/app/.local"

cp -a "$MOUNTPOINT/." "$STAGING_DIR/garage/"

if [ -d "$APP_DIR/assets" ]; then
  rsync -a --include='*/' --include='*.json' --exclude='*' "$APP_DIR/assets/" "$STAGING_DIR/app/assets/"
fi

if [ -d "$APP_DIR/.local" ]; then
  rsync -a --include='*/' --include='*.json' --exclude='*' "$APP_DIR/.local/" "$STAGING_DIR/app/.local/"
fi

tar --zstd -cf "$ARCHIVE" -C "$STAGING_DIR" .

copy_to_tier "daily"

if [ "$(date -u +%u)" = "7" ]; then
  copy_to_tier "weekly"
fi

if [ "$(date -u +%d)" = "01" ]; then
  copy_to_tier "monthly"
fi

prune_remote_dir "daily" "$KEEP_DAILY"
prune_remote_dir "weekly" "$KEEP_WEEKLY"
prune_remote_dir "monthly" "$KEEP_MONTHLY"

echo "[backup] writing marker"
mkdir -p "$APP_DIR"
printf '%s\n' "$(date -u +%FT%TZ)" > "$APP_DIR/.last-backup"

rm -f "$ARCHIVE"
rm -rf "$STAGING_DIR"
echo "[backup] done"
