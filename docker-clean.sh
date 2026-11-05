#!/usr/bin/env bash
# docker-clean: clean up Docker/OrbStack in one command.
# By default, volumes are KEPT (Postgres, Redis, Garage data, etc.).
# Use --volumes to also remove ALL volumes (data is permanently lost).

set -uo pipefail

ASSUME_YES=0
WITH_VOLUMES=0
DRY_RUN=0
RESTART_ENGINE=0

usage() {
  cat <<'EOF'
Usage: docker-clean.sh [options]

Options:
  -y, --yes            Do not ask for confirmation
  -v, --volumes        Remove ALL volumes, including named ones (data is lost)
  -r, --restart-engine Restart the OrbStack Docker engine at the end
                       (helps when the Builds tab still shows old entries)
  -n, --dry-run        Only show current disk usage and build history, remove nothing
  -h, --help           Show this help

By default it will:
  1. Stop and remove all containers
  2. Remove networks, all images (including unused ones), and build cache
  3. Remove build history (the Builds tab in OrbStack) for every builder
  4. Keep all volumes
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1 ;;
    -v|--volumes) WITH_VOLUMES=1 ;;
    -r|--restart-engine) RESTART_ENGINE=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

log() { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }

if ! command -v docker >/dev/null 2>&1; then
  echo "The docker command was not found." >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "The Docker engine is not running (start OrbStack/Docker Desktop first)." >&2
  exit 1
fi

# Run a command over a list of IDs, portable across macOS (no xargs -r) and Linux.
run_on_ids() {
  # $1: newline-separated IDs; remaining args: the command to run
  local ids="$1"; shift
  [ -n "$ids" ] || return 0
  printf '%s\n' "$ids" | xargs "$@"
}

# List builder names (one per line). Falls back to "default".
list_builders() {
  local names
  names="$(docker buildx ls --format '{{.Name}}' 2>/dev/null | tr -d '*' | sort -u)"
  if [ -z "$names" ]; then
    # Older buildx without --format: parse the first column of non-indented lines
    names="$(docker buildx ls 2>/dev/null | awk 'NR>1 && $1 !~ /^[\\_]/ {gsub(/\*/,"",$1); print $1}' | sort -u)"
  fi
  [ -n "$names" ] || names="default"
  printf '%s\n' "$names"
}

# Print the build history refs of a builder (one per line, header skipped).
history_refs() {
  docker buildx history ls --builder "$1" 2>/dev/null | awk 'NR>1 && NF>0 {print $1}'
}

# Count history entries of a builder.
history_count() {
  history_refs "$1" | grep -c . || true
}

log "Docker context and builders"
echo "Current context: $(docker context show 2>/dev/null || echo unknown)"
docker buildx ls

log "Current disk usage"
docker system df

if [ "$DRY_RUN" -eq 1 ]; then
  log "Existing volumes"
  docker volume ls
  log "Build history (per builder)"
  for b in $(list_builders); do
    echo "-- builder: $b ($(history_count "$b") entries)"
    docker buildx history ls --builder "$b" 2>&1 | head -n 30
  done
  exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
  echo
  echo "This will remove: containers, networks, images, build cache, build history."
  if [ "$WITH_VOLUMES" -eq 1 ]; then
    echo "WARNING: ALL volumes will be removed. Data cannot be recovered."
  else
    echo "Volumes will be kept."
  fi
  printf 'Continue? [y/N] '
  read -r answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled."; exit 0 ;;
  esac
fi

log "1/7 Stop and remove all containers"
run_on_ids "$(docker ps -aq)" docker rm -f

log "2/7 Remove unused networks"
docker network prune -f

log "3/7 Remove all images"
docker image prune -a -f

log "4/7 Remove build cache (current builder)"
docker builder prune -a -f
# Plain buildx prune on the current builder: this is the command confirmed to
# clear the Builds tab in OrbStack, so it runs before the per-builder loop.
docker buildx prune -a -f

log "5/7 Remove build cache and build history for every buildx builder"
HISTORY_LEFT=0
for b in $(list_builders); do
  echo "-- builder: $b"

  echo "   pruning cache..."
  if ! docker buildx prune -a -f --builder "$b"; then
    warn "cache prune failed for builder '$b' (see error above)"
  fi

  before="$(history_count "$b")"
  echo "   build history entries before: $before"

  if [ "$before" -gt 0 ]; then
    # Attempt 1: remove everything at once. Errors are shown, not hidden.
    echo "   removing history with --all..."
    if ! docker buildx history rm --all --builder "$b"; then
      warn "'history rm --all' failed for builder '$b' (see error above)"
    fi

    # Attempt 2: remove remaining entries by ref, in batches of 20.
    remaining="$(history_refs "$b")"
    if [ -n "$remaining" ]; then
      echo "   entries remain, removing by ref..."
      printf '%s\n' "$remaining" | xargs -n 20 docker buildx history rm --builder "$b" \
        || warn "removal by ref failed for builder '$b' (see error above)"
    fi
  fi

  after="$(history_count "$b")"
  echo "   build history entries after: $after"
  HISTORY_LEFT=$((HISTORY_LEFT + after))
done

if [ "$WITH_VOLUMES" -eq 1 ]; then
  log "6/7 Remove ALL volumes"
  run_on_ids "$(docker volume ls -q)" docker volume rm -f
else
  log "6/7 Keeping volumes (use --volumes to remove them)"
fi

if [ "$RESTART_ENGINE" -eq 1 ]; then
  log "Restarting the OrbStack Docker engine"
  if command -v orb >/dev/null 2>&1; then
    orb restart docker || warn "'orb restart docker' failed; quit and reopen OrbStack manually"
  else
    warn "orb CLI not found; quit and reopen OrbStack manually"
  fi
fi

log "7/7 Result"
docker system df
echo
echo "Remaining volumes:"
docker volume ls
echo

if [ "$HISTORY_LEFT" -gt 0 ]; then
  warn "$HISTORY_LEFT build history entries still remain."
  echo "Next steps:"
  echo "  1. Re-run with --restart-engine, or quit and reopen OrbStack."
  echo "  2. Check the errors printed in step 5 above."
  echo "  3. As a last resort, reset the OrbStack Docker data (this deletes ALL"
  echo "     containers, images and volumes). Check 'orb --help' or OrbStack Settings"
  echo "     for the exact command or menu in your version."
else
  echo "Build history is empty. If the Builds tab in OrbStack still shows entries,"
  echo "run again with --restart-engine, or quit and reopen OrbStack."
fi