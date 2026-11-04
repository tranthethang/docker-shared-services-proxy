# docker-shared-services-proxy

TLS edge for [docker-shared-services](https://github.com/tranthethang/docker-shared-services) (DSS). **Caddy** terminates HTTPS on host ports **80** and **443** and forwards plain HTTP to Traefik on the shared Docker network `traefik_proxy`.

## Prerequisites

- Docker Compose v2
- [mkcert](https://github.com/FiloSottile/mkcert) for local certificates
- DSS networks created once from the DSS repo: `make setup`

## Startup order

1. In **docker-shared-services**: `make setup` (creates `traefik_proxy`, `backend_net`, `data_net`).
2. In this repo: `make setup`, `make cert`, `make up`.
3. In **docker-shared-services**: `make up service=traefik`, then `make up service=<name>` for each service you need.

Browse services at `https://<service>.dss.localhost` (for example `https://traefik.dss.localhost` for the Traefik dashboard).

## Commands

| Command | Description |
| ------- | ----------- |
| `make setup` | Copy `.env.example` to `.env` if missing; verify `traefik_proxy` exists |
| `make cert` | Generate `caddy/certs/server.crt` and `server.key` with mkcert |
| `make up` | Start Caddy |
| `make down` | Stop Caddy |
| `make ps` | Show Caddy container status |
| `make logs` | Follow Caddy logs |

## Configuration

Copy `.env.example` to `.env`. Set `CADDY_BIND` to `127.0.0.1` for local development (default) or `0.0.0.0` when the host must accept LAN or public traffic.

Do not commit `.env` or files under `caddy/certs/`.

## Architecture

```text
Browser → Caddy (:443 TLS, traefik_proxy) → http://traefik:80 → DSS services
```

Traefik in DSS routes by `Host(...)` on the `web` entrypoint only; it does not publish 80/443 on the Docker host.
