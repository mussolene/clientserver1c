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

env ENV_FILE="$ENV_FILE" bash "$ROOT_DIR/scripts/ensure-its-env.sh"

docker compose --profile build build 1c-pg 1c-server 1c-client

exec docker compose up "$@"
