#!/usr/bin/env bash
# Generate TLS certificates for the Caddy edge with mkcert.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/gen-certs.sh CERT_DIR [DOMAIN...]

Write CERT_DIR/server.crt and CERT_DIR/server.key with mkcert. Domains come from
the arguments, else from CADDY_DOMAINS (space separated), else dss.localhost.
For each domain the certificate covers DOMAIN, *.DOMAIN, *.minio.DOMAIN,
*.garage.DOMAIN, and *.tts.DOMAIN. It also covers the first non-loopback local
IP, localhost, 127.0.0.1, and ::1.
EOF
}

if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  [[ $# -ge 1 ]] && exit 0
  exit 2
fi

cert_dir=$1
shift
if [[ $# -gt 0 ]]; then
  domains=("$@")
else
  read -r -a domains <<<"${CADDY_DOMAINS:-dss.localhost}"
fi
if [[ ${#domains[@]} -eq 0 ]]; then
  domains=(dss.localhost)
fi

sans=()
for d in "${domains[@]}"; do
  sans+=("$d" "*.$d" "*.minio.$d" "*.garage.$d" "*.tts.$d")
done

echo "Detecting local IP..."
current_ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | awk '{print $2}' | sed 's/addr://' | head -n 1 || true)
echo "Local IP detected: $current_ip"
mkdir -p "$cert_dir"

if ! command -v mkcert >/dev/null 2>&1; then
  echo "❌ Error: mkcert is not installed. Please install it first."
  exit 1
fi

mkcert -cert-file "$cert_dir/server.crt" \
  -key-file "$cert_dir/server.key" \
  "$current_ip" \
  "${sans[@]}" \
  localhost \
  127.0.0.1 \
  ::1
echo "✅ Success: Certificates are generated in $cert_dir/"
