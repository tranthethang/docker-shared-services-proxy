#!/usr/bin/env bash
# Check that Caddy serves each domain and reaches the DSS Traefik behind it.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/verify-edge.sh [DOMAIN...]

For each domain (arguments, else CADDY_DOMAINS, else sandbox.localhost), call
127.0.0.1 with the host traefik.DOMAIN and check:
  1. http://traefik.DOMAIN/ redirects permanently to https://
  2. https://traefik.DOMAIN/dashboard/ returns 401 (Traefik answered)
  3. that response is not a redirect (a redirect means a Caddy/Traefik loop)
Use the mkcert root CA when present; otherwise use -k and warn. Exit 1 on the
first failed check.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 0 ]]; then
  domains=("$@")
else
  read -r -a domains <<<"${CADDY_DOMAINS:-sandbox.localhost}"
fi
if [[ ${#domains[@]} -eq 0 ]]; then
  domains=(sandbox.localhost)
fi

tls_args=()
ca_root=""
if command -v mkcert >/dev/null 2>&1; then
  ca_root=$(mkcert -CAROOT 2>/dev/null || true)
fi
if [[ -n "$ca_root" && -f "$ca_root/rootCA.pem" ]]; then
  tls_args=(--cacert "$ca_root/rootCA.pem")
else
  echo "WARN: mkcert root CA not found; using -k (certificate not verified)"
  tls_args=(-k)
fi

fail() {
  echo "FAIL $1: $2"
  exit 1
}

# Print the status code, or 000 when curl cannot connect.
status() {
  curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "$@" 2>/dev/null || true
}

for d in "${domains[@]}"; do
  host="traefik.$d"

  code=$(status --resolve "$host:80:127.0.0.1" "http://$host/")
  location=$(curl -sS -o /dev/null -D - --max-time 10 --resolve "$host:80:127.0.0.1" "http://$host/" 2>/dev/null |
    awk 'tolower($1) == "location:" {print $2}' | tr -d '\r' || true)
  if [[ ("$code" == "301" || "$code" == "308") && "$location" == https://* ]]; then
    echo "OK   $d http redirect: $code -> $location"
  else
    fail "$d http redirect" "got $code (location '${location:-none}'), want 301/308 to https://"
  fi

  code=$(status "${tls_args[@]}" --resolve "$host:443:127.0.0.1" "https://$host/dashboard/")
  if [[ "$code" == 3* ]]; then
    fail "$d no redirect loop" "got $code on https://$host/dashboard/"
  fi
  if [[ "$code" != "401" ]]; then
    fail "$d traefik behind caddy" "got $code on https://$host/dashboard/, want 401 (000 = no answer)"
  fi
  echo "OK   $d traefik behind caddy: 401"
  echo "OK   $d no redirect loop: 401"
done
