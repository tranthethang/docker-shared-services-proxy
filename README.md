# docker-shared-services-proxy

TLS edge for [docker-shared-services](https://github.com/tranthethang/docker-shared-services) (DSS). **Caddy** terminates HTTPS on host ports **80** and **443** and forwards plain HTTP to the Traefik of each DSS stack over that stack's Docker network.

Caddy is for **local use only**. Do not use it in staging or production.

## Prerequisites

- Docker Compose v2
- [mkcert](https://github.com/FiloSottile/mkcert) for local certificates
- DSS networks created once from the DSS repo: `make setup`

## Startup order

1. In **docker-shared-services**: `make setup` (creates `traefik_proxy`, `backend_net`, `data_net`).
2. In this repo: `make setup`, `make cert`, `make up`.
3. In **docker-shared-services**: `make up service=traefik`, then `make up service=<name>` for each service you need.
4. In this repo: `make verify-edge`.

Browse services at `https://<service>.sandbox.localhost` (for example `https://traefik.sandbox.localhost` for the Traefik dashboard).

## Commands

| Command            | Description                                                                           |
| ------------------ | ------------------------------------------------------------------------------------- |
| `make setup`       | Copy `.env.example` to `.env` if missing; verify the network of each `caddy/stacks/*.yaml` exists |
| `make cert`        | Generate `caddy/certs/server.crt` and `server.key` with mkcert for `CADDY_DOMAINS`    |
| `make up`          | Start Caddy                                                                           |
| `make down`        | Stop Caddy                                                                            |
| `make ps`          | Show Caddy container status                                                           |
| `make logs`        | Follow Caddy logs                                                                     |
| `make verify-edge` | Check each domain through Caddy (HTTP redirect, Traefik answers 401, no redirect loop) |

## Configuration

Copy `.env.example` to `.env`.

- `CADDY_BIND`: `127.0.0.1` for local development (default) or `0.0.0.0` when the host must accept LAN or public traffic.
- `CADDY_DOMAINS`: space-separated domains on the certificate, one site file per domain. Default in `.env.example` is `sandbox.localhost dss.localhost`. Each domain gets the SANs `<d>`, `*.<d>`, `*.minio.<d>`, `*.garage.<d>`, and `*.tts.<d>`. Run `make cert` and restart Caddy after a change.

Do not commit `.env` or files under `caddy/certs/`.

## Architecture

```text
Browser → Caddy (:443 TLS) → sites/<name>.caddy host match → <traefik container>.<stack network>:80 → DSS services
```

Traefik in DSS routes by `Host(...)` on the `web` entrypoint only; it does not publish 80/443 on the Docker host. A host that no site file matches gets `404` from Caddy.

A stack is two files:

- `caddy/stacks/<name>.yaml`: Compose override that joins `caddy` to the stack's external network.
- `caddy/sites/<name>.caddy`: host matcher and upstream.

The default local domain is **sandbox** (`caddy/stacks/sandbox.yaml`, `caddy/sites/sandbox.caddy`, network `traefik_proxy`, upstream `traefik.traefik_proxy:80`, domain `sandbox.localhost`). The **dss** stack and site files remain for `dss.localhost` and its MinIO aliases.

## Add a DSS stack

Example: a DSS stack started with `DSS_NAME=projb` and `DOMAIN=projb.localhost`. Its network is `projb_traefik_proxy` and its Traefik container is `projb-traefik`.

1. Create `caddy/stacks/projb.yaml`:

   ```yaml
   services:
     caddy:
       networks:
         projb_traefik_proxy:
           aliases:
             - minio.projb.localhost
             - s3.minio.projb.localhost

   networks:
     projb_traefik_proxy:
       name: projb_traefik_proxy
       external: true
   ```

2. Create `caddy/sites/projb.caddy`. Use a matcher name that is unique across site files:

   ```caddy
   @projb host projb.localhost *.projb.localhost *.*.projb.localhost
   handle @projb {
   	reverse_proxy projb-traefik.projb_traefik_proxy:80 {
   		header_up Host {http.request.host}
   	}
   }
   ```

3. Add the domain to `CADDY_DOMAINS` in `.env`: `CADDY_DOMAINS="sandbox.localhost dss.localhost projb.localhost"`.
4. Run `make cert`, then `make up`. Run `make verify-edge` to check.

**Upstream rule:** use `<traefik container>.<stack network>:80`, which is `<DSS_NAME>-traefik.<DSS_NAME>_traefik_proxy:80` (`traefik.traefik_proxy:80` for the default stack). Every DSS Traefik has the service alias `traefik` on its own network, and Caddy is on all stack networks, so Docker DNS can answer a bare `traefik` with another stack's Traefik. The network suffix limits the lookup to that one network. Create the DSS network first (`make setup` in DSS with `DSS_NAME=projb`); `make setup` here stops with the stack file name when a network is missing.

## MinIO aliases and CA trust

DSS Traefik no longer carries the aliases `minio.<domain>` and `s3.minio.<domain>`. Each stack file puts them on the `caddy` service, so a container on that stack network that calls `https://s3.minio.<domain>` reaches Caddy (TLS), then Traefik, then MinIO.

By default no DSS container calls these URLs: MinIO, Temporal, and Garage UI use internal HTTP (`http://minio:9000`, `http://garage:3900`). Only user apps, and `oauth2-proxy` when `OAUTH2_PROXY_OIDC_ISSUER_HOST` is set (that host maps to the Docker host, which is Caddy on 443), call `https://*.<domain>` through Caddy.

A container that calls such a URL must trust the mkcert root CA, or Caddy's certificate fails verification. Mount the CA and point the client at it:

```yaml
volumes:
  - ${MKCERT_CAROOT}/rootCA.pem:/etc/ssl/certs/mkcert-rootCA.pem:ro # MKCERT_CAROOT=$(mkcert -CAROOT)
environment:
  SSL_CERT_FILE: /etc/ssl/certs/mkcert-rootCA.pem # or AWS_CA_BUNDLE, NODE_EXTRA_CA_CERTS
```

Or call internal HTTP (`http://minio:9000`) instead.

## verify-edge

`make verify-edge` runs `scripts/verify-edge.sh` for each domain in `CADDY_DOMAINS`, through `127.0.0.1`:

1. `http://traefik.<domain>/` returns a permanent redirect to `https://`.
2. `https://traefik.<domain>/dashboard/` returns `401`, which shows Traefik answered behind Caddy.
3. That response is not a redirect. A redirect means a loop between Caddy and Traefik.

It uses the mkcert root CA when present, otherwise `-k` with a warning. It exits non-zero on the first failed check. DSS Traefik and Caddy must be up.
