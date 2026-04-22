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

compose_args=(-f "$ROOT_DIR/docker-compose.yml")
if [[ "${ONEC_PLATFORM_OVERRIDE:-}" == "native-arm" ]]; then
  compose_args+=(-f "$ROOT_DIR/docker-compose.onec-native-arm.yml")
fi

# shellcheck source=scripts/image-refs.sh
. "$ROOT_DIR/scripts/image-refs.sh"
services=(1c-dev)
images_to_check=("$ONEC_DEV_IMAGE")

if [[ "${ONEC_WITH_PG:-0}" == "1" ]]; then
  services=(1c-pg "${services[@]}")
  images_to_check=("$ONEC_PG_IMAGE" "${images_to_check[@]}")
fi

missing_services=()
for image_ref in "${images_to_check[@]}"; do
  if docker image inspect "$image_ref" >/dev/null 2>&1; then
    continue
  fi
  if docker pull "$image_ref" >/dev/null 2>&1; then
    continue
  fi

  case "$image_ref" in
    "$ONEC_PG_IMAGE")
      missing_services+=(1c-pg)
      ;;
    "$ONEC_DEV_IMAGE")
      missing_services+=(1c-dev)
      ;;
  esac
done

if [[ "${#missing_services[@]}" -gt 0 ]]; then
  env ENV_FILE="$ENV_FILE" bash "$ROOT_DIR/scripts/prepare-platform.sh"
  docker compose "${compose_args[@]}" --profile build build "${missing_services[@]}"
fi

if ! docker volume inspect onec-license-store >/dev/null 2>&1; then
  docker volume create onec-license-store >/dev/null
fi

exec docker compose "${compose_args[@]}" --profile build up --no-build "$@" "${services[@]}"
