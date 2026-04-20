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

DESKTOP_BASE_IMAGE="${DESKTOP_BASE_IMAGE:-mussolene/linux-desktop-base}"
DESKTOP_BASE_TAG="${DESKTOP_BASE_TAG:-bookworm}"
COMMON_BASE_IMAGE="${COMMON_BASE_IMAGE:-mussolene/linux-common-base}"
COMMON_BASE_TAG="${COMMON_BASE_TAG:-bookworm}"

build_args=(
  "--build-arg" "COMMON_BASE_IMAGE=${COMMON_BASE_IMAGE}:${COMMON_BASE_TAG}"
  "-f" "$ROOT_DIR/base/linux-desktop/Dockerfile"
  "-t" "${DESKTOP_BASE_IMAGE}:${DESKTOP_BASE_TAG}"
)

if [[ -n "${DOCKER_DEFAULT_PLATFORM:-}" ]]; then
  build_args+=("--platform" "${DOCKER_DEFAULT_PLATFORM}")
fi

docker build "${build_args[@]}" "$ROOT_DIR"
