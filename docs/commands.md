# Commands

All targets run from the repository root with Docker Compose v2.

| Command | Description |
| ------- | ----------- |
| `make setup` | Create `.env` from `.env.example` if missing; verify each external network referenced in `caddy/stacks/*.yaml` |
| `make cert` | Generate `caddy/certs/server.crt` and `server.key` for `CADDY_DOMAINS` |
| `make up` | Run `setup`, require cert files, start Caddy in the background |
| `make down` | Stop and remove the Caddy container |
| `make ps` | Show Caddy container status |
| `make logs` | Follow Caddy logs |
| `make verify-edge` | Run edge checks for every domain in `CADDY_DOMAINS` |

Shell scripts:

- `scripts/gen-certs.sh` — called by `make cert`
- `scripts/verify-edge.sh` — called by `make verify-edge`; supports `-h`

## Related DSS commands

This repo does not start DSS services. Typical pairing:

```bash
# In docker-shared-services
make setup
make up service=traefik
make up service=<name>
make health service=traefik
make info
```

See the DSS [usage guide](https://github.com/tranthethang/docker-shared-services/blob/main/docs/usage.md).
