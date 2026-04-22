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

project_path="${PROJECT_PATH:-${ONEC_PROJECT_PATH:-}}"
if [[ -z "$project_path" ]]; then
  printf 'Set PROJECT_PATH or ONEC_PROJECT_PATH to the host project repository.\n' >&2
  exit 2
fi

if [[ ! -d "$project_path" ]]; then
  printf 'Project path does not exist or is not a directory: %s\n' "$project_path" >&2
  exit 2
fi

export ONEC_PROJECT_PATH="$(cd "$project_path" && pwd)"

env ENV_FILE="$ENV_FILE" bash "$ROOT_DIR/scripts/prepare-platform.sh"

if ! docker volume inspect onec-license-store >/dev/null 2>&1; then
  docker volume create onec-license-store >/dev/null
fi

mapfile -d '' compose_args < <(ONEC_PLATFORM_OVERRIDE="${ONEC_PLATFORM_OVERRIDE:-}" bash "$ROOT_DIR/scripts/agent-compose-args.sh")

dev_image="mussolene/1c-developer:${PLATFORM_VERSION:-8.5.1.1302}"
if ! docker image inspect "$dev_image" >/dev/null 2>&1 \
  || ! docker run --rm --entrypoint test "$dev_image" -f /opt/onec-agent/registry.json >/dev/null 2>&1 \
  || ! docker run --rm --entrypoint test "$dev_image" -f /opt/bslls/bsl-language-server.jar >/dev/null 2>&1; then
  docker compose "${compose_args[@]}" --profile build build 1c-dev
fi

exec docker compose "${compose_args[@]}" --profile build up --no-build "$@" 1c-dev
