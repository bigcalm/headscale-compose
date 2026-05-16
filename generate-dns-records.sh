#!/usr/bin/env bash
set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$COMPOSE_DIR"

# Read base_domain from headscale config
BASE_DOMAIN="$(sed -n '/^  base_domain:/s/.*base_domain: *//p' headscale-config/config.yaml | tr -d '"')"
if [ -z "$BASE_DOMAIN" ]; then
  echo "error: could not determine base_domain from headscale-config/config.yaml"
  exit 1
fi

echo "  Base domain: $BASE_DOMAIN"

# Get nodes as JSON
NODES_JSON="$(docker compose exec -T headscale headscale nodes list -o json 2>/dev/null)" || {
  echo "error: failed to list nodes (is headscale running?)"
  exit 1
}

# Generate extra records: hostname.user.base_domain -> each IP
# shellcheck disable=SC2207
RECORDS=()
while read -r node; do
  hostname="$(echo "$node" | jq -r '.given_name // .hostname // .name' 2>/dev/null)"
  user="$(echo "$node" | jq -r '.user.name // .user // empty' 2>/dev/null)"
  ipv4="$(echo "$node" | jq -r '.ip_addresses[0] // empty' 2>/dev/null)"
  ipv6="$(echo "$node" | jq -r '.ip_addresses[1] // empty' 2>/dev/null)"

  [ -z "$hostname" ] && continue
  [ -z "$user" ] && user="default"

  fqdn="${hostname}.${user}.${BASE_DOMAIN}"

  if [ -n "$ipv4" ]; then
    RECORDS+=("$(printf '{"name":"%s","type":"A","value":"%s"}' "$fqdn" "$ipv4")")
  fi
  if [ -n "$ipv6" ]; then
    RECORDS+=("$(printf '{"name":"%s","type":"AAAA","value":"%s"}' "$fqdn" "$ipv6")")
  fi
done < <(echo "$NODES_JSON" | jq -c '.[]' 2>/dev/null)

if [ ${#RECORDS[@]} -eq 0 ]; then
  echo "  No nodes found — writing empty record set"
fi

# Build JSON array
JSON="["
first=true
for record in "${RECORDS[@]}"; do
  if [ "$first" = true ]; then
    first=false
  else
    JSON+=","
  fi
  JSON+="$record"
done
JSON+="]"

# Write to extra-records.json (bind-mounted into the headscale container)
echo "  Writing ${#RECORDS[@]} records to headscale-config/extra-records.json"
echo "$JSON" > "headscale-config/extra-records.json"

echo "  Done"
