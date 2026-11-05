# Add another DSS stack

Use this when a second DSS instance runs on the same Docker host with its own `SANDBOX_NAME` and `DOMAIN` (for example `projb` and `projb.localhost`).

## 1 — Prepare DSS

In that stack's DSS root `.env`:

```env
SANDBOX_NAME=projb
DOMAIN=projb.localhost
SANDBOX_SUBNET_BASE=10
```

Run `make setup` in DSS so networks such as `projb_traefik_proxy` exist. Pick a `SANDBOX_SUBNET_BASE` that does not overlap other stacks (each stack uses three consecutive `/16` subnets). See DSS [configuration.md](https://github.com/tranthethang/docker-shared-services/blob/main/docs/configuration.md#several-stacks-on-one-host).

Start Traefik and services with the same `SANDBOX_NAME` in `.env`:

```bash
make up service=traefik
make up service=postgres
```

## 2 — Stack Compose override

Create `caddy/stacks/projb.yaml`:

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

The Makefile picks up every `caddy/stacks/*.yaml` automatically.

## 3 — Site file

Create `caddy/sites/projb.caddy`. The matcher name (`@projb`) must be unique across all site files:

```caddy
@projb host projb.localhost *.projb.localhost *.*.projb.localhost
handle @projb {
	reverse_proxy projb-traefik.projb_traefik_proxy:80 {
		header_up Host {http.request.host}
	}
}
```

Validate:

```bash
docker run --rm -v "$PWD/caddy:/etc/caddy" -w /etc/caddy caddy:2.9.1-alpine \
  caddy validate --config /etc/caddy/Caddyfile
```

## 4 — Certificate and Caddy

Append the domain to `.env`:

```env
CADDY_DOMAINS=sandbox.localhost dss.localhost projb.localhost
```

Then:

```bash
make cert
make up
make verify-edge
```

## Checklist

- [ ] DSS network exists (`docker network inspect projb_traefik_proxy`)
- [ ] Traefik container name matches the upstream (`projb-traefik`)
- [ ] Domain in `CADDY_DOMAINS` matches `DOMAIN` in DSS
- [ ] `make verify-edge` passes for the new domain

MinIO public URLs and container TLS trust: [minio-and-tls.md](minio-and-tls.md).
