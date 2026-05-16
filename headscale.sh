#!/usr/bin/env bash
set -euo pipefail

COMPOSE_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_CMD="docker compose"

if ! $COMPOSE_CMD version &>/dev/null; then
  echo "error: docker compose is not available"
  exit 1
fi

cd "$COMPOSE_PROJECT_DIR"

service_names() {
  $COMPOSE_CMD config --services 2>/dev/null
}

cmd_exec() {
  $COMPOSE_CMD exec headscale headscale "$@"
}

cmd_shell() {
  if $COMPOSE_CMD exec headscale bash -c 'exit 0' 2>/dev/null; then
    $COMPOSE_CMD exec headscale bash
  elif $COMPOSE_CMD exec headscale sh -c 'exit 0' 2>/dev/null; then
    $COMPOSE_CMD exec headscale sh
  else
    echo "error: headscale container has no shell available (distroless image)"
    return 1
  fi
}

cmd_logs() {
  local svc="${1:-}"
  if [ -n "$svc" ]; then
    shift
    $COMPOSE_CMD logs -f "$svc" "$@"
  else
    $COMPOSE_CMD logs -f headscale
  fi
}

cmd_ps() {
  $COMPOSE_CMD ps
}

cmd_up() {
  $COMPOSE_CMD up -d
}

cmd_down() {
  $COMPOSE_CMD down
}

cmd_restart() {
  $COMPOSE_CMD restart
}

cmd_apikey() {
  cmd_exec apikeys create
}

cmd_user() {
  cmd_exec users "$@"
}

cmd_node() {
  cmd_exec nodes "$@"
}

cmd_preauthkey() {
  cmd_exec preauthkeys "$@"
}

cmd_version() {
  cmd_exec version
}

cmd_rebuild_dns() {
  "$COMPOSE_PROJECT_DIR/generate-dns-records.sh"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [args]

Headscale management wrapper. Runs inside the headscale container
via docker compose — no manual "docker exec" needed.

Commands:
  <any headscale arg>     Pass through to "headscale" directly
                          e.g. $(basename "$0") users list
                          e.g. $(basename "$0") nodes list -i

  apikey                  Generate a new API key
  user   <args>           Shortcut: user create <name>, user list, etc.
  node   <args>           Shortcut: node list, node delete -i <id>, etc.
  preauthkey <args>       Shortcut: preauthkey create --user <name>, etc.

  shell                   Open a shell inside the headscale container
  logs   [service]        Tail logs (default: headscale)
  ps                      List container status
  up                      Start all services (docker compose up -d)
  down                    Stop all services
  restart                 Restart all services
  rebuild-dns             Regenerate extra DNS records (user-inclusive FQDNs)
  version                 Show headscale version
  help                    Show this help

Examples:
  $(basename "$0") users create myuser
  $(basename "$0") user create myuser
  $(basename "$0") preauthkey create --user myuser --expiration 24h
  $(basename "$0") nodes list
  $(basename "$0") apikey
  $(basename "$0") logs caddy
  $(basename "$0") shell
EOF
  exit 0
}

case "${1:-help}" in
  help|-h|--help)
    usage
    ;;
  up)
    shift
    cmd_up "$@"
    ;;
  down)
    shift
    cmd_down "$@"
    ;;
  restart)
    shift
    cmd_restart "$@"
    ;;
  ps)
    cmd_ps
    ;;
  shell)
    cmd_shell
    ;;
  logs)
    shift
    cmd_logs "$@"
    ;;
  apikey)
    cmd_apikey
    ;;
  user)
    shift
    cmd_user "$@"
    ;;
  node)
    shift
    cmd_node "$@"
    ;;
  preauthkey)
    shift
    cmd_preauthkey "$@"
    ;;
  rebuild-dns)
    cmd_rebuild_dns
    ;;
  version)
    cmd_version
    ;;
  *)
    cmd_exec "$@"
    ;;
esac
