# Configuration

Copy `.env.example` to `.env` (`make setup` does this when `.env` is missing).

Do **not** commit `.env` or files under `caddy/certs/`.

## Variables

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `CADDY_BIND` | `127.0.0.1` | Host address for published ports **80** and **443**. Use `0.0.0.0` only when the machine must accept LAN traffic. |
| `CADDY_DOMAINS` | `sandbox.localhost dss.localhost` | Space-separated base domains on the TLS certificate. One site file (`caddy/sites/<name>.caddy`) and one stack file (`caddy/stacks/<name>.yaml`) per domain you route. |

## Certificates (`make cert`)

`scripts/gen-certs.sh` reads `CADDY_DOMAINS` from `.env` (or from CLI arguments) and runs mkcert.

For each domain `d` in the list, the certificate includes:

- `d`
- `*.d`
- `*.minio.d`
- `*.garage.d`
- `*.tts.d`

Plus the detected LAN IP, `localhost`, `127.0.0.1`, and `::1`.

After you change `CADDY_DOMAINS`, run `make cert` and restart Caddy (`make up` or `docker compose restart caddy`).

Output files:

- `caddy/certs/server.crt`
- `caddy/certs/server.key`

The Caddyfile mounts these paths; `auto_https` is off — TLS uses this static cert only.

## Align with DSS `DOMAIN`

DSS Traefik routers use `Host(<service>.${DOMAIN})`. Caddy must accept the same hostnames:

- Default DSS domain: `sandbox.localhost` → `caddy/sites/sandbox.caddy` and `caddy/stacks/sandbox.yaml`
- Legacy optional domain: `dss.localhost` → `caddy/sites/dss.caddy` and `caddy/stacks/dss.yaml`

If you set `DOMAIN=example.test` in DSS, add a new site + stack pair and append `example.test` to `CADDY_DOMAINS`, then `make cert`.

DSS service `.env` values that hard-code a hostname override root `DOMAIN`; clear them to follow `DOMAIN`. See DSS [configuration.md](https://github.com/tranthethang/docker-shared-services/blob/main/docs/configuration.md).

## Compose stack files

The Makefile builds:

```text
docker compose -f caddy/compose.yaml -f caddy/stacks/*.yaml --env-file .env
```

Every file in `caddy/stacks/` must declare an external network that already exists (created by DSS `make setup`). `make setup` here fails with the stack filename if a network is missing.
