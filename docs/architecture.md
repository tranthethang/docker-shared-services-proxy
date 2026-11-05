# Architecture

## Request path

```text
Browser
  → Caddy (:443 TLS on the host, or :80 → redirect to HTTPS)
  → caddy/sites/<stack>.caddy  (Host matcher)
  → reverse_proxy <traefik-container>.<stack-network>:80  (plain HTTP)
  → Traefik (DSS, web entrypoint only)
  → DSS service container
```

Traefik in DSS does **not** publish **80**/**443** on the Docker host. It listens on HTTP inside `traefik_proxy` (and related networks). Caddy terminates TLS and forwards `Host` and forwarded headers.

A hostname that no site file matches receives **404** from Caddy (`No DSS stack serves this host.`).

## One DSS stack = two repo files

| File | Role |
| ---- | ---- |
| `caddy/stacks/<name>.yaml` | Compose override: attach the `caddy` service to that stack's external Traefik network; optional MinIO DNS aliases on `caddy` |
| `caddy/sites/<name>.caddy` | Caddyfile fragment: `@<matcher> host …` and `reverse_proxy` upstream |

The root `caddy/Caddyfile` imports `sites/*.caddy` and defines global TLS and the default 404 handler.

## Default and legacy stacks shipped in this repo

| Site name | Domain | Network | Upstream (default stack) |
| --------- | ------ | ------- | ------------------------ |
| **sandbox** | `sandbox.localhost` | `traefik_proxy` | `traefik.traefik_proxy:80` |
| **dss** (legacy) | `dss.localhost` | `traefik_proxy` | `traefik.traefik_proxy:80` |

Both join the same DSS network when `SANDBOX_NAME` is empty. They differ in hostname matchers and MinIO aliases on the Caddy service.

## Upstream naming rule

Always use:

```text
<traefik-container-name>.<traefik-docker-network-name>:80
```

Examples:

- Unnamed stack: `traefik.traefik_proxy:80`
- `SANDBOX_NAME=projb`: `projb-traefik.projb_traefik_proxy:80`

Do **not** use bare `traefik:80`. Every DSS Traefik service has the alias `traefik` on its own network, and Caddy joins multiple stack networks, so an unqualified name can hit the wrong Traefik.

## Startup order

1. DSS `make setup` (networks)
2. This repo: `make setup`, `make cert`, `make up` (Caddy)
3. DSS: `make up service=traefik`, then other services

See [getting-started.md](getting-started.md).

## Local-only scope

This repository does not implement staging or production edge patterns. Remote proxies in front of DSS use published Traefik HTTP and `TRAEFIK_TRUSTED_IPS` in the DSS repo instead of Caddy.
