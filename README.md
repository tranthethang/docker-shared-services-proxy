# docker-shared-services-proxy

Local TLS edge for [docker-shared-services](https://github.com/tranthethang/docker-shared-services). **Caddy** listens on **80** and **443**, terminates HTTPS with mkcert, and forwards HTTP to each DSS Traefik on its Docker network.

**Local development only** — not for staging or production.

## Quick start

```bash
# 1) DSS — networks and env
cd docker-shared-services && make setup

# 2) Proxy — cert and Caddy
cd docker-shared-services-proxy && make setup && make cert && make up

# 3) DSS — Traefik and services
cd docker-shared-services && make up service=traefik && make up service=adminer

# 4) Verify
cd docker-shared-services-proxy && make verify-edge
```

Browse `https://<service>.sandbox.localhost` (for example `https://traefik.sandbox.localhost/dashboard/`).

Full walkthrough: **[docs/getting-started.md](docs/getting-started.md)**.

## Documentation

| Doc | Contents |
| --- | -------- |
| [getting-started.md](docs/getting-started.md) | Step-by-step setup, prerequisites, stop/teardown pointers |
| [configuration.md](docs/configuration.md) | `CADDY_BIND`, `CADDY_DOMAINS`, certificates, DSS `DOMAIN` alignment |
| [architecture.md](docs/architecture.md) | Request path, stack/site files, upstream naming |
| [commands.md](docs/commands.md) | Makefile targets and related DSS commands |
| [add-stack.md](docs/add-stack.md) | Second DSS stack on one host (`SANDBOX_NAME`, new site files) |
| [minio-and-tls.md](docs/minio-and-tls.md) | MinIO aliases on Caddy, mkcert trust in containers |
| [verify-edge.md](docs/verify-edge.md) | What `make verify-edge` checks and common failures |

Contributors and agents: see [AGENTS.md](AGENTS.md).
