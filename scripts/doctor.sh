#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

platform_version="${PLATFORM_VERSION:-8.5.1.1302}"
# shellcheck source=scripts/image-refs.sh
. "$ROOT_DIR/scripts/image-refs.sh"
dev_image="$ONEC_DEV_IMAGE"
project_path="${PROJECT_PATH:-${ONEC_PROJECT_PATH:-}}"
status=0
strict="${DOCTOR_STRICT:-0}"

print_check() {
  local label="$1"
  local state="$2"
  local detail="${3:-}"

  if [[ -n "$detail" ]]; then
    printf '%-28s %-8s %s\n' "$label:" "$state" "$detail"
  else
    printf '%-28s %s\n' "$label:" "$state"
  fi
}

require_ok() {
  print_check "$1" "OK" "${2:-}"
}

warn_missing() {
  print_check "$1" "MISSING" "${2:-}"
  status=1
}

printf 'clientserver1c doctor\n'
printf '=====================\n'

if command -v docker >/dev/null 2>&1; then
  require_ok "docker" "$(docker --version 2>/dev/null | sed 's/,.*//')"
else
  warn_missing "docker" "Install Docker or OrbStack before first start."
fi

if docker compose version >/dev/null 2>&1; then
  require_ok "docker compose" "$(docker compose version --short 2>/dev/null || true)"
else
  warn_missing "docker compose" "Docker Compose plugin is required."
fi

if [[ -f "$ENV_FILE" ]]; then
  require_ok ".env" "$ENV_FILE"
else
  warn_missing ".env" "Run: make env"
fi

image_exists=0
if docker image inspect "$dev_image" >/dev/null 2>&1; then
  image_exists=1
fi

if [[ -d "$ROOT_DIR/.local/1c/dev-platform" ]] \
  && find "$ROOT_DIR/.local/1c/dev-platform" -mindepth 1 -maxdepth 1 | read -r; then
  require_ok "platform staging" ".local/1c/dev-platform"
elif [[ "$image_exists" == "1" ]]; then
  print_check "platform staging" "OPTIONAL" "Only needed for local image build."
else
  warn_missing "platform staging" "Only needed for local build. Run: make prepare-platform"
fi

if [[ "$image_exists" == "1" ]]; then
  require_ok "developer image" "$dev_image"
  if docker run --rm --entrypoint test "$dev_image" -f /opt/onec-agent/registry.json >/dev/null 2>&1; then
    require_ok "agent layer" "/opt/onec-agent/registry.json"
  else
    warn_missing "agent layer" "Rebuild: make build"
  fi
else
  warn_missing "developer image" "Run: make pull or make build"
fi

if docker volume inspect onec-license-store >/dev/null 2>&1; then
  require_ok "local license volume" "onec-license-store"
else
  print_check "local license volume" "OPTIONAL" "Only needed for local activation; network HASP can use nethasp.ini."
fi

if [[ -n "$project_path" ]]; then
  if [[ -d "$project_path" ]]; then
    require_ok "project mount path" "$project_path"
  else
    warn_missing "project mount path" "$project_path does not exist"
  fi
else
  print_check "project mount path" "OPTIONAL" "Set ONEC_PROJECT_PATH or pass PROJECT_PATH for agent mode."
fi

printf '\nNext commands:\n'
if [[ ! -f "$ENV_FILE" ]]; then
  printf '  make env\n'
fi
printf '  make pull            # pull configured developer image\n'
printf '  make first-start     # optional local license UI start\n'
printf '  make up-file-db      # normal file DB mode after licensing is configured\n'
printf '  make ui-smoke        # Vanessa smoke when runtime is ready\n'
printf '  make agent-up PROJECT_PATH=/path/to/project\n'

if [[ "$strict" == "1" ]]; then
  exit "$status"
fi

exit 0
