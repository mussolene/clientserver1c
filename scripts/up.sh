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

env ENV_FILE="$ENV_FILE" bash "$ROOT_DIR/scripts/prepare-platform.sh"

if ! docker volume inspect onec-license-store >/dev/null 2>&1; then
  docker volume create onec-license-store >/dev/null
fi

compose_args=(-f "$ROOT_DIR/docker-compose.yml")
if [[ "${ONEC_PLATFORM_OVERRIDE:-}" == "native-arm" ]]; then
  compose_args+=(-f "$ROOT_DIR/docker-compose.onec-native-arm.yml")
fi

dev_image="mussolene/1c-developer:${PLATFORM_VERSION:-8.5.1.1302}"
pg_image="mussolene/postgresql:${PG_1C_VERSION:-17.7-1.1C}"
services=(1c-dev)
images_to_check=("$dev_image")

if [[ "${ONEC_WITH_PG:-0}" == "1" ]]; then
  services=(1c-pg "${services[@]}")
  images_to_check=("$pg_image" "${images_to_check[@]}")
fi

missing_services=()
for image_ref in "${images_to_check[@]}"; do
  if ! docker image inspect "$image_ref" >/dev/null 2>&1; then
    case "$image_ref" in
      "$pg_image")
        missing_services+=(1c-pg)
        ;;
      "$dev_image")
        missing_services+=(1c-dev)
        ;;
    esac
  fi
done

if [[ "${#missing_services[@]}" -gt 0 ]]; then
  docker compose "${compose_args[@]}" --profile build build "${missing_services[@]}"
fi

exec docker compose "${compose_args[@]}" --profile build up --no-build "$@" "${services[@]}"
