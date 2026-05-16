# AGENTS.md — headscale-compose

AI coding assistant instructions for this project.

## Project overview

Docker Compose stack running three services:
- **headscale** — Tailscale-compatible coordination server
- **[headscale-ui](https://github.com/gurucomputing/headscale-ui)** — web management UI served at `/web` (by [Guru Computing](https://github.com/gurucomputing))
- **caddy** — reverse proxy with automatic TLS, fronting both services on the same domain

## Commands

### Container lifecycle

```bash
docker compose up -d       # start all services
docker compose down        # stop all services
docker compose restart     # restart all services
docker compose ps          # container status
docker compose logs -f     # tail logs
```

### headscale administration

Use the wrapper script (avoids raw docker exec/compose exec):

```bash
./headscale.sh user create <name>
./headscale.sh user list
./headscale.sh node list
./headscale.sh node delete -i <id>
./headscale.sh preauthkey create --user <name> --expiration 24h
./headscale.sh preauthkey list --user <name>
./headscale.sh apikey
./headscale.sh shell       # shell inside headscale container
./headscale.sh logs        # tail headscale logs
./headscale.sh logs caddy  # tail caddy logs
./headscale.sh rebuild-dns # regenerate user-inclusive DNS records
./headscale.sh version
```

Pass-through: any unrecognised arg runs `docker compose exec headscale headscale <args>`.

## Project structure

```
.
├── docker-compose.yaml          # Service definitions
├── .env                         # Docker Compose variables (DOMAIN, versions, TZ)
├── .env.example                 # Template for .env
├── .gitignore                   # Ignores .env and backups/
├── AGENTS.md                    # This file
├── Caddyfile                    # Caddy reverse proxy rules
├── headscale.sh                 # Management wrapper script
├── backup.sh                    # Volume backup script
├── restore.sh                   # Volume restore script
├── README.md                    # Project documentation
├── headscale-config/
│   ├── config.yaml              # Headscale configuration
│   └── acl.hujson               # ACL policy (HuJSON)
└── backups/                     # Backup archives (gitignored)
```

## Conventions

- **Never commit changes unless the user explicitly asks.** Do not make SCM commits proactively — only when requested.
- **Config is bind-mounted read-only** — headscale config lives in `headscale-config/` and is mounted at `/etc/headscale` with `:ro`.
- **Data is stored in Docker named volumes** — `headscale-data`, `caddy-data`, `caddy-config`. Use `backup.sh` / `restore.sh` to save/restore them.
- **headscale-ui** is served at `/web` on the same domain as headscale.
- **Caddyfile** uses `{$DOMAIN}` — the value comes from the `.env` file.
- **Container image versions** come from `.env` variables (`HS_VERSION`, `UI_VERSION`, `CADDY_VERSION`).
- **headscale-config/config.yaml** uses hardcoded values — `${DOMAIN}` syntax is not supported by headscale. The user must edit this file and keep `server_url` in sync with `.env`.

## Headscale config notes

- `server_url` must be `https://<DOMAIN>`.
- `dns.base_domain` must differ from the `server_url` domain.
- TLS is handled by Caddy; headscale's built-in Let's Encrypt is disabled.
- The ACL file is at `headscale-config/acl.hujson` and is hot-reloaded by headscale.

## Backup and restore

```bash
./backup.sh                     # save all volumes + config to ./backups/
./restore.sh                    # restore from latest backup
./restore.sh ./backups/backup_20260514_120000  # specific backup
```

Backups include config files (`.env`, `Caddyfile`, `headscale-config/`) and a
`backup.json` that records the image versions for each service. The restore
script compares these versions against the current `docker-compose.yaml` and
warns on mismatch.

## Extra DNS records

`generate-dns-records.sh` creates `hostname.user.base_domain` A/AAAA records
via `dns.extra_records_path` (since headscale v0.23.0 removed the username
from MagicDNS). Run `./headscale.sh rebuild-dns` after node changes.

## Common errors

| Error | Fix |
|---|---|
| `DOMAIN is missing a value` | Create `.env` from `.env.example` and set `DOMAIN` |
| `Volume does not exist` | Run `docker compose up -d` first to create volumes |
| Nodes can't connect | Ensure DNS A record points to the server and Cloudflare proxy is off |
| Web UI shows blank page | Generate an API key (`./headscale.sh apikey`) and paste it in Settings |
