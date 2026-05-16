#!/usr/bin/env bash
set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$COMPOSE_DIR"

if [ ! -f .env ]; then
  echo "error: .env not found. Copy .env.example to .env and edit it first."
  exit 1
fi

set -a; source .env; set +a

: "${DOMAIN:?DOMAIN is not set in .env}"
: "${BASE_DOMAIN:?BASE_DOMAIN is not set in .env}"

TEMPLATE="headscale-config/config.yaml.example"
OUTPUT="headscale-config/config.yaml"

if [ ! -f "$TEMPLATE" ]; then
  echo "error: template not found: $TEMPLATE"
  exit 1
fi

SERVER_URL="https://${DOMAIN}"

echo "Generating headscale-config/config.yaml from template ..."
echo "  Server URL:   $SERVER_URL"
echo "  Base domain:  $BASE_DOMAIN"

sed \
  -e "s|{{SERVER_URL}}|$SERVER_URL|g" \
  -e "s|{{BASE_DOMAIN}}|$BASE_DOMAIN|g" \
  "$TEMPLATE" > "$OUTPUT"

echo "  Written: $OUTPUT"

# Ensure extra-records.json exists (writable, bind-mounted at /etc/headscale/)
if [ ! -f headscale-config/extra-records.json ]; then
  echo "  Created: headscale-config/extra-records.json (empty record set)"
  echo '[]' > headscale-config/extra-records.json
fi

echo "  Done."
