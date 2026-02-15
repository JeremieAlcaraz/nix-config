#!/bin/bash
set -euo pipefail

echo "[$(date)] Demarrage de la synchro vers Google Drive (folderID -> proxmox/)..."

rclone sync /backup-disk "gdrive_capsule:proxmox" \
  --transfers=4 \
  --fast-list \
  --progress \
  --log-level INFO \
  --log-file /var/log/rclone-sync.log

echo "[$(date)] Synchro terminee."
