#!/usr/bin/env bash
set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$COMPOSE_DIR/backups"

cd "$COMPOSE_DIR"

if ! docker compose version &>/dev/null; then
  echo "error: docker compose is not available"
  exit 1
fi

# Determine which backup to restore from
if [ $# -ge 1 ]; then
  RESTORE_SRC="$1"
else
  RESTORE_SRC="$(ls -dt "$BACKUP_ROOT"/backup_* 2>/dev/null | head -1)" || {
    echo "error: no backups found in $BACKUP_ROOT"
    echo "usage: $0 [<backup-dir>]"
    exit 1
  }
fi

if [ ! -d "$RESTORE_SRC" ]; then
  echo "error: backup directory not found: $RESTORE_SRC"
  exit 1
fi

echo "=== Restoring headscale-compose ==="
echo "  Source: $RESTORE_SRC"
echo ""

# Load backup metadata if available
if [ -f "$RESTORE_SRC/backup.json" ]; then
  echo "  Backup created: $(sed -n '/"created_at"/s/.*"created_at": "\(.*\)".*/\1/p' "$RESTORE_SRC/backup.json")"
  echo "  Project:        $(sed -n '/"project"/s/.*"project": "\(.*\)".*/\1/p' "$RESTORE_SRC/backup.json")"

  echo ""
  echo "  --- Service versions (backup vs current) ---"

  # Extract image tags from backup.json
  backup_tag() {
    sed -n '/"'"$1"'"/s/.*"'"$1"'": "\(.*\)".*/\1/p' "$RESTORE_SRC/backup.json"
  }

  # Extract resolved image tags from docker compose config
  current_tag() {
    docker compose config 2>/dev/null | awk -v srv="$1" '
      $0 ~ "^  " srv ":" {found=1; next}
      found && /^    image:/ {print $2; found=0}
    '
  }

  for svc in headscale headscale-ui caddy; do
    backup_ver="$(backup_tag "$svc")"
    current_ver="$(current_tag "$svc")"
    if [ "$backup_ver" = "$current_ver" ]; then
      echo "    $svc: $backup_ver  (match)"
    else
      echo "    $svc: $backup_ver (backup) vs $current_ver (current)  *** DIFFERENT ***"
    fi
  done
  echo ""
else
  echo "  Warning: no backup.json metadata found"
  echo ""
fi

# Stop services
docker compose stop headscale caddy

# Restore volumes
echo "  --- Restoring volumes ---"
for vol in headscale-data caddy-data caddy-config; do
  archive="$RESTORE_SRC/${vol}.tar.gz"
  if [ ! -f "$archive" ]; then
    echo "    Skipping $vol — no backup file found"
    continue
  fi
  echo "    Restoring $vol ..."

  # Derive full volume name
  PROJECT="$(docker compose config 2>/dev/null | awk '/^name:/{print $2}')"
  [ -z "$PROJECT" ] && PROJECT="$(basename "$COMPOSE_DIR")"

  docker run --rm \
    -v "${PROJECT}_${vol}:/target" \
    -v "$RESTORE_SRC:/backup" \
    alpine tar xzf "/backup/${vol}.tar.gz" -C /target
done

# Restore config files (prompt for confirmation)
CONFIG_ARCHIVE="$RESTORE_SRC/config.tar.gz"
if [ -f "$CONFIG_ARCHIVE" ]; then
  echo ""
  echo "  --- Config files ---"
  echo "    A config backup exists: headscale-config/ Caddyfile .env"
  echo "    Restoring will overwrite current files with backed-up versions."
  read -r -p "    Restore config files? [y/N] " REPLY
  if [[ "$REPLY" =~ ^[Yy] ]]; then
    echo "    Restoring config files ..."
    tar xzf "$CONFIG_ARCHIVE" -C "$COMPOSE_DIR"
    echo "    Done."
  else
    echo "    Skipped."
  fi
fi

echo ""

docker compose start headscale caddy

echo "=== Restore complete ==="
