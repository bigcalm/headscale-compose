#!/usr/bin/env bash
set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$COMPOSE_DIR/backups"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/backup_$TIMESTAMP"

mkdir -p "$BACKUP_DIR"
cd "$COMPOSE_DIR"

if ! docker compose version &>/dev/null; then
  echo "error: docker compose is not available"
  exit 1
fi

# Derive project name
PROJECT="$(docker compose config 2>/dev/null | awk '/^name:/{print $2}')"
[ -z "$PROJECT" ] && PROJECT="$(basename "$COMPOSE_DIR")"

# Extract image tags for version metadata
image_tag() {
  awk -v srv="$1" '
    $0 ~ "^  " srv ":" {found=1; next}
    found && /^    image:/ {print $2; found=0}
  ' docker-compose.yaml
}

HS_IMAGE="$(image_tag headscale)"
UI_IMAGE="$(image_tag headscale-ui)"
CADDY_IMAGE="$(image_tag caddy)"

echo "=== Backing up headscale-compose ==="
echo "  Backup:  backup_$TIMESTAMP"
echo "  Project: $PROJECT"
echo "  Images:  headscale=$HS_IMAGE  ui=$UI_IMAGE  caddy=$CADDY_IMAGE"
echo ""

# Stop services that hold persistent data
docker compose stop headscale caddy

backup_volume() {
  local full_name="$1"
  local short_name="$2"
  local archive="$BACKUP_DIR/${short_name}.tar.gz"
  echo "  Volume:  $short_name"
  if ! docker run --rm \
    -v "${full_name}:/source:ro" \
    -v "$BACKUP_DIR:/backup" \
    alpine tar czf "/backup/${short_name}.tar.gz" -C /source . 2>/dev/null; then
    echo "    (volume does not exist yet — skipped)"
    rm -f "$archive"
  fi
}

backup_volume "${PROJECT}_headscale-data" "headscale-data"
backup_volume "${PROJECT}_caddy-data"     "caddy-data"
backup_volume "${PROJECT}_caddy-config"   "caddy-config"

# Backup config files (headscale-config/, Caddyfile, .env)
CONFIG_ARCHIVE="$BACKUP_DIR/config.tar.gz"
echo "  Config:  headscale-config/ Caddyfile .env"
tar czf "$CONFIG_ARCHIVE" \
  headscale-config/config.yaml \
  headscale-config/acl.hujson \
  Caddyfile \
  .env \
  2>/dev/null || echo "    (some config files missing — backing up what exists)"

# Write version metadata
cat > "$BACKUP_DIR/backup.json" <<EOF
{
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project": "$PROJECT",
  "compose_file": "docker-compose.yaml",
  "services": {
    "headscale": "$HS_IMAGE",
    "headscale-ui": "$UI_IMAGE",
    "caddy": "$CADDY_IMAGE"
  },
  "volumes": ["headscale-data", "caddy-data", "caddy-config"],
  "config_files": ["headscale-config/config.yaml", "headscale-config/acl.hujson", "Caddyfile", ".env"]
}
EOF

echo "  Metadata: backup.json"
echo ""

docker compose start headscale caddy

echo "=== Done ==="
echo "  Restore with: ./restore.sh $BACKUP_DIR"
