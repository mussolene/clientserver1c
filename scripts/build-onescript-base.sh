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

IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-mussolene}"
ONESCRIPT_BASE_IMAGE="${IMAGE_NAMESPACE}/linux-onescript"
ONESCRIPT_BASE_TAG="2.0.0"
ONESCRIPT_BUILD_IMAGE="${IMAGE_NAMESPACE}/linux-onescript-builder"
ONESCRIPT_BUILD_TAG="2.0.0"
COMMON_BASE_IMAGE="${IMAGE_NAMESPACE}/linux-common-base"
COMMON_BASE_TAG="bookworm"

build_args=(
  "--build-arg" "ONESCRIPT_BUILD_IMAGE=${ONESCRIPT_BUILD_IMAGE}:${ONESCRIPT_BUILD_TAG}"
  "--build-arg" "COMMON_BASE_IMAGE=${COMMON_BASE_IMAGE}:${COMMON_BASE_TAG}"
  "-f" "$ROOT_DIR/base/linux-onescript/Dockerfile"
  "-t" "${ONESCRIPT_BASE_IMAGE}:${ONESCRIPT_BASE_TAG}"
)

if [[ -n "${DOCKER_DEFAULT_PLATFORM:-}" ]]; then
  build_args+=("--platform" "${DOCKER_DEFAULT_PLATFORM}")
fi

docker build "${build_args[@]}" "$ROOT_DIR"
