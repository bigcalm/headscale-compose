# headscale-compose

> Created with [OpenCode](https://opencode.ai) using the **Big Pickle** model.

Self-hosted [Headscale](https://headscale.net) (Tailscale control server) with a web UI and automatic HTTPS via Caddy, all running in Docker Compose.

## Services

| Service | Image | Role |
|---|---|---|
| headscale | `headscale/headscale:v0.28.0` | Tailscale-compatible coordination server |
| headscale-ui | `ghcr.io/gurucomputing/headscale-ui:2026.03.17` | Web management UI |
| caddy | `caddy:v2.11.3` | Reverse proxy with automatic TLS |

## Prerequisites

- Linux server with a public IP
- Docker + Docker Compose (v2)
- A domain (or subdomain) pointed at your server's public IP

## Setup

### 1. Configure DNS

Create an A record for your domain (e.g. `headscale.example.com`) pointing to your server's public IP. Do not use a CDN proxy (Cloudflare orange cloud, etc.) — Headscale's protocol does not work through them.

### 2. Configure the project

```bash
cp .env.example .env
```

Edit `.env` and set your domain:

```ini
DOMAIN=headscale.example.com
TZ=UTC
```

Edit `headscale-config/config.yaml` and set:

- `server_url` — must match your domain with `https://`
- `dns.base_domain` — used for MagicDNS hostnames; must differ from the server_url domain

### 3. Start everything

```bash
docker compose up -d
```

Caddy will automatically provision a TLS certificate from Let's Encrypt.

### 4. Create your first user

```bash
./headscale.sh users create default
```

List users to confirm:

```bash
./headscale.sh users list
```

### 5. Generate an API key (for the web UI)

```bash
./headscale.sh apikey
```

Copy the output key, then visit `https://<DOMAIN>/web`, open Settings, and paste the key.

### 6. Register a node

Generate a pre-authentication key:

```bash
./headscale.sh preauthkey create --user default --expiration 24h
```

On the node you want to join, install Tailscale and run:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --login-server https://<DOMAIN> --authkey <PREAUTH_KEY>
```

## Usage

### headscale.sh

All administration is done through `./headscale.sh`, which wraps `docker compose exec headscale headscale`.

```bash
# User management
./headscale.sh user create alice
./headscale.sh user list

# Node management
./headscale.sh node list
./headscale.sh node delete -i <ID>

# Pre-auth keys
./headscale.sh preauthkey create --user alice --expiration 48h
./headscale.sh preauthkey list --user alice

# API keys
./headscale.sh apikey

# Container lifecycle (docker compose shortcuts)
./headscale.sh up       # start all services
./headscale.sh down     # stop all services
./headscale.sh restart   # restart all services
./headscale.sh ps        # container status
./headscale.sh logs      # tail headscale logs
./headscale.sh logs caddy # tail caddy logs
./headscale.sh shell     # open a shell in the headscale container

# Version
./headscale.sh version
```

Any unrecognised subcommand is passed straight through to the headscale binary:

```bash
./headscale.sh debug create-node 100.64.0.1
```

### docker compose (alternative)

You can also run commands directly:

```bash
docker compose exec headscale headscale users list
docker compose logs -f headscale
docker compose ps
```

## Web UI

The headscale-ui is available at `https://<DOMAIN>/web`.

After opening it for the first time:
1. Click the settings gear icon
2. Paste your API key (generated via `./headscale.sh apikey`)
3. The UI will refresh and show your nodes, users, and routes

## Access Control (ACLs)

The default `headscale-config/acl.hujson` allows all traffic and enables Tailscale SSH for root:

```json
{
  "acls": [
    { "action": "accept", "src": ["*"], "dst": ["*:*"] }
  ],
  "ssh": [
    { "action": "accept", "src": ["autogroup:member"],
      "dst": ["autogroup:member"], "users": ["root"] }
  ]
}
```

Headscale reloads the file automatically on changes — no restart needed.

## Backup and restore

`backup.sh` and `restore.sh` handle the Docker volumes holding persistent data
(headscale SQLite DB, Noise keys, Caddy TLS certificates) **and** the manually
edited config files (`.env`, `Caddyfile`, `headscale-config/`).

Each backup is a timestamped directory under `backups/` containing:

| File | Contents |
|---|---|
| `headscale-data.tar.gz` | Headscale SQLite database, Noise keys |
| `caddy-data.tar.gz` | Caddy TLS certificates and runtime data |
| `caddy-config.tar.gz` | Caddy configuration |
| `config.tar.gz` | `.env`, `Caddyfile`, `headscale-config/config.yaml`, `headscale-config/acl.hujson` |
| `backup.json` | Metadata: creation date, service versions, file manifest |

```bash
# Create a timestamped backup
./backup.sh

# Restore from the latest backup
./restore.sh

# Restore from a specific backup
./restore.sh ./backups/backup_20260514_120000
```

The restore script compares service versions between the backup and your current
`docker-compose.yaml` and warns if they differ. Config file restoration is
prompted interactively to prevent accidental overwrites.

The `backups/` directory is gitignored.

## File layout

```
.
├── docker-compose.yaml          # Service definitions
├── .env                         # Docker Compose variables (DOMAIN, TZ)
├── .env.example                 # Template for .env
├── .gitignore                   # Ignores .env and backups/
├── AGENTS.md                    # AI coding assistant instructions
├── Caddyfile                    # Caddy reverse proxy rules
├── headscale.sh                 # Management wrapper script
├── backup.sh                    # Volume backup script
├── restore.sh                   # Volume restore script
├── README.md                    # This file
├── headscale-config/
│   ├── config.yaml              # Headscale configuration
│   └── acl.hujson               # ACL policy (HuJSON)
└── backups/                     # Backup archives (gitignored)
```

Persistent data (SQLite database, Noise keys, TLS certificates) is stored in
Docker named volumes (`headscale-data`, `caddy-data`, `caddy-config`).

## DERP relay

The embedded DERP server is disabled by default. The public Tailscale DERP map is used for relay when direct connections cannot be established. If you need a custom DERP server, see the [Headscale DERP docs](https://headscale.net/stable/ref/derp/).

## Updating

```bash
docker compose pull
docker compose up -d
```
