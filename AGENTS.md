# AGENTS.md

Edge proxy companion to **docker-shared-services** (DSS). This repo contains only the Caddy stack under `caddy/`.

## Commands

```bash
make setup   # .env + check external network traefik_proxy
make cert    # mkcert → caddy/certs/
make up      # docker compose up -d
make down    # docker compose down
make ps
make logs
```

Run `make setup` in DSS before `make setup` here. Start Caddy before DSS Traefik when adopting the Caddy-first stack.

## Layout

- `caddy/compose.yaml` — Caddy service on `traefik_proxy`, publishes 80/443
- `caddy/Caddyfile` — TLS with mounted certs; reverse proxy to `traefik:80`
- `scripts/gen-certs.sh` — same SAN list as the former DSS cert script
- `.env.example` — `CADDY_BIND` for port publish address

## Rules

- Pin image tags in `compose.yaml`.
- Do not commit `.env` or `caddy/certs/*.{crt,key}`.
- Use `compose.yaml` (not legacy `docker-compose.yml`).
