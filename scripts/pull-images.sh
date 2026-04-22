#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
INPUT_IMAGE_NAMESPACE="${IMAGE_NAMESPACE-}"
INPUT_PLATFORM_VERSION="${PLATFORM_VERSION-}"
INPUT_PG_1C_VERSION="${PG_1C_VERSION-}"
INPUT_ONEC_WITH_PG="${ONEC_WITH_PG-}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

IMAGE_NAMESPACE="${INPUT_IMAGE_NAMESPACE:-${IMAGE_NAMESPACE:-}}"
PLATFORM_VERSION="${INPUT_PLATFORM_VERSION:-${PLATFORM_VERSION:-}}"
PG_1C_VERSION="${INPUT_PG_1C_VERSION:-${PG_1C_VERSION:-}}"
ONEC_WITH_PG="${INPUT_ONEC_WITH_PG:-${ONEC_WITH_PG:-}}"

# shellcheck source=scripts/image-refs.sh
. "$ROOT_DIR/scripts/image-refs.sh"

images=("$ONEC_DEV_IMAGE")
if [[ "${ONEC_WITH_PG:-0}" == "1" || "${1:-}" == "--with-pg" ]]; then
  images+=("$ONEC_PG_IMAGE")
fi

for image_ref in "${images[@]}"; do
  printf 'Pulling %s\n' "$image_ref"
  docker pull "$image_ref"
done
