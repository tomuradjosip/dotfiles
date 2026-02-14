#!/usr/bin/env bash
# Restic backup from this Mac to NixOS server at /persist/backup/laptop-josip
# Uses SSH config (Host server / server-ip) for SFTP — ensure you can: ssh server
#
# Prerequisites: restic installed via chezmoi (home packages)
# Password: set RESTIC_PASSWORD in env or use keychain (see below).
# Run: restic-laptop-backup.sh   (or use launchd plist for daily run)

set -euo pipefail

# Prefix each line with timestamp for log file
ts() { while IFS= read -r line; do echo "$(date '+%Y-%m-%d %H:%M:%S') $line"; done; }

# ─── Config (edit to match your setup) ─────────────────────────────────────
# Must match an SSH Host from ~/.ssh/config (e.g. server or server-ip)
SSH_HOST="${RESTIC_SSH_HOST:-server}"
SSH_USER="${RESTIC_SSH_USER:-toka}"
REMOTE_PATH="/persist/backup/laptop-josip"
export RESTIC_REPOSITORY="sftp:${SSH_USER}@${SSH_HOST}:${REMOTE_PATH}"

# Optional: cache dir (speeds up repeated runs)
export RESTIC_CACHE_DIR="${RESTIC_CACHE_DIR:-$HOME/.cache/restic}"

# Allow-list: only these paths are backed up.
BACKUP_PATHS=(
  "$HOME/.ssh"
  "$HOME/.config/aliases"
  "$HOME/.config/aliases-private"
  "$HOME/.local/share/chezmoi"
  "$HOME/3Dprinting"
  "$HOME/archive"
  "$HOME/git"
  "$HOME/Library/Application Support/OrcaSlicer"
)

# Retention (prune after backup)
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=6
BACKUP_TAG="macos-laptop"

# Excludes within the paths above: junk, dev/build artifacts, logs
EXCLUDE_PATTERNS=(
  ".DS_Store"
  "*.tmp"
  "*.temp"
  "*.log"
  "*.pid"
  "*/logs/*"
  "*/log/*"
  "*/node_modules/*"
  "*/.venv"
  "*/venv"
  "*/__pycache__/*"
  "*.pyc"
  "*/.cache/*"
  "*/cache/*"
  "*/Cache"
  "*/Caches"
  "*/build"
  "*/dist"
  "*/target"
  "*/out"
  "*/.next"
  "*/.nuxt"
)

# ─── Password ─────────────────────────────────────────────────────────────
# Option A: export RESTIC_PASSWORD='…' before running
# Option B: macOS keychain — store with: security add-generic-password -a restic-laptop -s restic-laptop-josip -w
if [[ -z "${RESTIC_PASSWORD:-}" ]]; then
  if command -v security &>/dev/null; then
    RESTIC_PASSWORD=$(security find-generic-password -a restic-laptop -s restic-laptop-josip -w 2>/dev/null) || true
  fi
  if [[ -z "${RESTIC_PASSWORD:-}" ]]; then
    echo "Set RESTIC_PASSWORD or add keychain entry (see script header)." >&2
    exit 1
  fi
fi
export RESTIC_PASSWORD

# ─── Run ───────────────────────────────────────────────────────────────────
mkdir -p "$RESTIC_CACHE_DIR"
EXCLUDE_ARGS=()
for p in "${EXCLUDE_PATTERNS[@]}"; do EXCLUDE_ARGS+=(--exclude "$p"); done

echo "$(date '+%Y-%m-%d %H:%M:%S') Repository: $RESTIC_REPOSITORY"
echo "$(date '+%Y-%m-%d %H:%M:%S') Paths: ${BACKUP_PATHS[*]}"
echo "$(date '+%Y-%m-%d %H:%M:%S') Started."

if ! restic snapshots &>/dev/null; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') Initializing repository..."
  restic init 2>&1 | ts
  (( ${PIPESTATUS[0]} )) && exit "${PIPESTATUS[0]}"
fi

restic backup \
  --verbose \
  --tag "$BACKUP_TAG" \
  "${EXCLUDE_ARGS[@]}" \
  "${BACKUP_PATHS[@]}" 2>&1 | ts
(( ${PIPESTATUS[0]} )) && exit "${PIPESTATUS[0]}"

restic forget \
  --tag "$BACKUP_TAG" \
  --keep-daily "$KEEP_DAILY" \
  --keep-weekly "$KEEP_WEEKLY" \
  --keep-monthly "$KEEP_MONTHLY" \
  --prune 2>&1 | ts
(( ${PIPESTATUS[0]} )) && exit "${PIPESTATUS[0]}"

echo "$(date '+%Y-%m-%d %H:%M:%S') Finished."
# Record successful run for on-wake throttle (restic-laptop-backup-on-wake.sh)
mkdir -p "${HOME}/.local/state"
touch "${HOME}/.local/state/restic-laptop-last-backup"
