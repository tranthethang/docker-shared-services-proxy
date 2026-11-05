# verify-edge

`make verify-edge` runs `scripts/verify-edge.sh` for each domain in `CADDY_DOMAINS` (or pass domains as CLI arguments).

**Requires:** Caddy up, DSS Traefik up, mkcert root CA installed on the host (or the script falls back to `curl -k` with a warning).

## Checks (via 127.0.0.1)

For each domain `d`, with `host=traefik.d`:

1. **HTTP redirect** — `http://traefik.d/` returns **301** or **308** with `Location: https://…`
2. **Traefik behind Caddy** — `https://traefik.d/dashboard/` returns **401** (Traefik basic auth, not Caddy's 404)
3. **No redirect loop** — that HTTPS response must not be another **3xx** redirect

The script uses `--resolve` so DNS does not matter; traffic hits local Caddy only.

## Manual run

```bash
CADDY_DOMAINS="sandbox.localhost" ./scripts/verify-edge.sh
# or
./scripts/verify-edge.sh sandbox.localhost projb.localhost
```

## Common failures

| Symptom | Likely cause |
| ------- | ------------- |
| `000` or connection error on HTTPS | Caddy not running, wrong `CADDY_BIND`, or missing cert files |
| Dashboard not **401** | Traefik not running, wrong upstream in `.caddy`, or Traefik router missing |
| Redirect loop (**3xx** on dashboard URL) | Misconfigured forwarded headers or Traefik TLS labels (DSS should use `web` only) |
| HTTP redirect check fails | Caddy not listening on **80** or redirect block missing |

Fix upstream rules in [architecture.md](architecture.md). Full bring-up order: [getting-started.md](getting-started.md).
