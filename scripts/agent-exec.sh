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
export ONEC_PROJECT_PATH="$project_path"

cmd="${CMD:-}"
if [[ -z "$cmd" && "$#" -gt 0 ]]; then
  cmd="$*"
fi
if [[ -z "$cmd" ]]; then
  cmd="bash"
fi

mapfile -d '' compose_args < <(ONEC_PLATFORM_OVERRIDE="${ONEC_PLATFORM_OVERRIDE:-}" bash "$ROOT_DIR/scripts/agent-compose-args.sh")

exec docker compose "${compose_args[@]}" --profile build exec 1c-dev \
  bash -lc "cd /workspace/project && $cmd"
