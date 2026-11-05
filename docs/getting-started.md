# Getting started

Step-by-step setup for local HTTPS to [docker-shared-services](https://github.com/tranthethang/docker-shared-services) (DSS) through Caddy.

Caddy is **local development only**. Do not use it in staging or production.

## Prerequisites

Install on the host:

- Docker Compose v2
- [mkcert](https://github.com/FiloSottile/mkcert) (`mkcert -install` once so browsers trust the local CA)

Clone both repos as siblings (paths below assume `docker-shared-services` and `docker-shared-services-proxy`).

## Step 1 — DSS networks and env

In the **docker-shared-services** repo:

```bash
cd docker-shared-services
make setup
```

This creates shared Docker networks (`traefik_proxy`, `backend_net`, `data_net`) and prepares root and service `.env` files.

Confirm the root `.env` uses your intended domain (default):

```env
DOMAIN=sandbox.localhost
SANDBOX_NAME=
SANDBOX_SUBNET_BASE=0
```

See [configuration.md](configuration.md) in the DSS repo for `DOMAIN`, `SANDBOX_NAME`, and per-service overrides.

## Step 2 — Proxy env, certificate, and Caddy

In **docker-shared-services-proxy**:

```bash
cd docker-shared-services-proxy
make setup    # copies .env.example → .env if missing; checks stack networks exist
make cert     # writes caddy/certs/server.crt and server.key via mkcert
make up       # starts Caddy on ports 80 and 443 (bind address from CADDY_BIND)
```

Default `CADDY_DOMAINS` in `.env.example` is `sandbox.localhost dss.localhost`. Each entry needs a matching pair under `caddy/stacks/` and `caddy/sites/`. Details: [configuration.md](configuration.md).

## Step 3 — DSS Traefik

Back in **docker-shared-services**:

```bash
cd docker-shared-services
make up service=traefik
```

Wait until Traefik and the socket proxy are healthy (`make health service=traefik`).

Start Caddy **before** Traefik when you adopt this Caddy-first layout (Step 2 before Step 3).

## Step 4 — Services you need

Still in **docker-shared-services**, start backends (order matters when services depend on databases):

```bash
make up service=postgres    # example database
make up service=adminer     # example UI
# make up service=<name>    # repeat for each service
```

Or use `make manage` for an interactive selection.

## Step 5 — Verify the edge path

In **docker-shared-services-proxy**:

```bash
make verify-edge
```

You should see `OK` lines for each domain in `CADDY_DOMAINS` (HTTP redirect, Traefik `401` on the dashboard, no redirect loop). See [verify-edge.md](verify-edge.md) if a check fails.

## Step 6 — Use the stack in a browser

Open (with mkcert installed):

- Traefik dashboard: `https://traefik.sandbox.localhost/dashboard/` (BasicAuth: `admin` + `DSS_SHARED_PASSWORD` from DSS root `.env`)
- Example UI: `https://adminer.sandbox.localhost/`

Replace `sandbox.localhost` with your `DOMAIN` if you changed it. Every DSS hostname must have a Caddy site matcher for that domain; see [add-stack.md](add-stack.md).

## Minimal stack recap

| Order | Repo   | Command |
| ----- | ------ | ------- |
| 1 | DSS | `make setup` |
| 2 | Proxy | `make setup && make cert && make up` |
| 3 | DSS | `make up service=traefik` |
| 4 | DSS | `make up service=<name>` … |
| 5 | Proxy | `make verify-edge` |

## Stop without deleting images

```bash
# DSS (per service)
make down service=adminer
make down service=postgres
make down service=traefik

# Proxy
cd ../docker-shared-services-proxy && make down
```

To remove data volumes and reset `.env` files, use DSS `make down` with `compose down -v` per service and DSS `make remove-config` / `make setup` — see the DSS [usage guide](https://github.com/tranthethang/docker-shared-services/blob/main/docs/usage.md).

## Next steps

- [configuration.md](configuration.md) — `CADDY_BIND`, `CADDY_DOMAINS`, certificates
- [add-stack.md](add-stack.md) — second DSS stack on one host (`SANDBOX_NAME`, extra site files)
- [architecture.md](architecture.md) — how Caddy, Traefik, and DSS fit together
