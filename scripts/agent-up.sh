#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
INPUT_IMAGE_NAMESPACE="${IMAGE_NAMESPACE-}"
INPUT_PLATFORM_VERSION="${PLATFORM_VERSION-}"
INPUT_ONEC_PLATFORM_OVERRIDE="${ONEC_PLATFORM_OVERRIDE-}"
INPUT_PROJECT_PATH="${PROJECT_PATH-}"
INPUT_ONEC_PROJECT_PATH="${ONEC_PROJECT_PATH-}"
INPUT_OACS_VERSION="${OACS_VERSION-}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

IMAGE_NAMESPACE="${INPUT_IMAGE_NAMESPACE:-${IMAGE_NAMESPACE:-}}"
PLATFORM_VERSION="${INPUT_PLATFORM_VERSION:-${PLATFORM_VERSION:-}}"
ONEC_PLATFORM_OVERRIDE="${INPUT_ONEC_PLATFORM_OVERRIDE:-${ONEC_PLATFORM_OVERRIDE:-}}"
PROJECT_PATH="${INPUT_PROJECT_PATH:-${PROJECT_PATH:-}}"
ONEC_PROJECT_PATH="${INPUT_ONEC_PROJECT_PATH:-${ONEC_PROJECT_PATH:-}}"
OACS_VERSION="${INPUT_OACS_VERSION:-${OACS_VERSION:-}}"

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

compose_args=()
while IFS= read -r -d '' compose_arg; do
  compose_args+=("$compose_arg")
done < <(ONEC_PLATFORM_OVERRIDE="${ONEC_PLATFORM_OVERRIDE:-}" bash "$ROOT_DIR/scripts/agent-compose-args.sh")

# shellcheck source=scripts/image-refs.sh
. "$ROOT_DIR/scripts/image-refs.sh"

needs_build=0
if ! docker image inspect "$ONEC_DEV_IMAGE" >/dev/null 2>&1; then
  docker pull "$ONEC_DEV_IMAGE" >/dev/null 2>&1 || needs_build=1
fi

if [[ "$needs_build" == "0" ]] \
  && { ! docker run --rm --entrypoint test "$ONEC_DEV_IMAGE" -f /opt/onec-agent/registry.json >/dev/null 2>&1 \
    || ! docker run --rm --entrypoint test "$ONEC_DEV_IMAGE" -f /opt/bslls/bsl-language-server.jar >/dev/null 2>&1; }; then
  needs_build=1
fi

if [[ "$needs_build" == "0" ]] \
  && ! docker run --rm --entrypoint sh "$ONEC_DEV_IMAGE" -c 'command -v acs' >/dev/null 2>&1; then
  needs_build=1
fi

if [[ "$needs_build" == "1" ]]; then
  env ENV_FILE="$ENV_FILE" bash "$ROOT_DIR/scripts/prepare-platform.sh"
  docker compose "${compose_args[@]}" --profile build build 1c-dev
fi

if ! docker volume inspect onec-license-store >/dev/null 2>&1; then
  docker volume create onec-license-store >/dev/null
fi

exec docker compose "${compose_args[@]}" --profile build up --no-build "$@" 1c-dev
