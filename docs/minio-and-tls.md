# MinIO aliases and TLS trust

## Why MinIO hostnames sit on Caddy

DSS Traefik no longer exposes the Docker aliases `minio.<domain>` and `s3.minio.<domain>`. Each `caddy/stacks/<name>.yaml` attaches those names to the **caddy** service on the stack's Traefik network.

Traffic flow for `https://s3.minio.<domain>` from a container on that network:

```text
Container → Caddy (TLS) → Traefik (HTTP) → MinIO
```

## Who uses these URLs

Most DSS services use internal HTTP (`http://minio:9000`, `http://garage:3900`) and never need the public MinIO hostname.

Callers of `https://*.<domain>` through Caddy include:

- Your applications on the host or in custom containers
- **oauth2-proxy** when `OAUTH2_PROXY_OIDC_ISSUER_HOST` is set (issuer reaches the host gateway, which is Caddy on **443**)

## Trusting mkcert inside a container

If a container verifies TLS against Caddy's certificate, it must trust the mkcert root CA:

```yaml
volumes:
  - ${MKCERT_CAROOT}/rootCA.pem:/etc/ssl/certs/mkcert-rootCA.pem:ro
environment:
  SSL_CERT_FILE: /etc/ssl/certs/mkcert-rootCA.pem
```

Set `MKCERT_CAROOT=$(mkcert -CAROOT)` on the host when you compose the file.

Alternatives: `AWS_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS`, or use internal HTTP endpoints instead of `https://s3.minio.<domain>`.

## Certificate SANs

`make cert` already adds `*.minio.<d>`, `*.garage.<d>`, and `*.tts.<d>` for each `d` in `CADDY_DOMAINS`. Re-run `make cert` and restart Caddy after you add a domain.
