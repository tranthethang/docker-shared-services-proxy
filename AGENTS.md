# AGENTS.md

Edge proxy companion to **docker-shared-services** (DSS). This repo contains only the Caddy stack under `caddy/`. Local use only.

## Commands

```bash
make setup       # .env + check the external network of each caddy/stacks/*.yaml
make cert        # mkcert → caddy/certs/ for CADDY_DOMAINS
make up          # docker compose up -d
make down        # docker compose down
make ps
make logs
make verify-edge # each CADDY_DOMAINS entry: http redirect, Traefik 401, no loop
```

Run `make setup` in DSS before `make setup` here. Start Caddy before DSS Traefik when adopting the Caddy-first stack.

## Layout

- `caddy/compose.yaml` — Caddy service, publishes 80/443; networks come from the stack files
- `caddy/stacks/` — one Compose override per DSS stack (`<name>.yaml`): external network and MinIO aliases; the Makefile adds every file with `-f`
- `caddy/sites/` — one site file per stack (`<name>.caddy`): host matcher and upstream (`<traefik container>.<stack network>:80`); imported by the Caddyfile
- `caddy/Caddyfile` — TLS with mounted certs; `import sites/*.caddy`; 404 for an unmatched host
- `scripts/gen-certs.sh` — mkcert SANs for each domain in `CADDY_DOMAINS`
- `scripts/verify-edge.sh` — checks behind `make verify-edge`
- `.env.example` — `CADDY_BIND` (port publish address), `CADDY_DOMAINS` (certificate domains)

## Rules

- Pin image tags in `compose.yaml`.
- Do not commit `.env` or `caddy/certs/*.{crt,key}`.
- Use `compose.yaml` (not legacy `docker-compose.yml`).
- A new stack needs `stacks/<name>.yaml`, `sites/<name>.caddy` with a unique matcher name, and its domain in `CADDY_DOMAINS`. See `README.md`.
