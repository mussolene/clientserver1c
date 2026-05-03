#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
INPUT_IMAGE_NAMESPACE="${IMAGE_NAMESPACE-}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

IMAGE_NAMESPACE="${INPUT_IMAGE_NAMESPACE:-${IMAGE_NAMESPACE:-}}"
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-ghcr.io/mussolene}"
COMMON_BASE_IMAGE="${IMAGE_NAMESPACE}/linux-common-base"
COMMON_BASE_TAG="bookworm"
COMMON_BASE_DIST="bookworm"

build_args=(
  "--build-arg" "COMMON_BASE_DIST=${COMMON_BASE_DIST}"
  "-f" "$ROOT_DIR/base/linux-common/Dockerfile"
  "-t" "${COMMON_BASE_IMAGE}:${COMMON_BASE_TAG}"
)

DOCKER_DEFAULT_PLATFORM="${DOCKER_DEFAULT_PLATFORM:-linux/amd64}"
if [[ "$DOCKER_DEFAULT_PLATFORM" != "linux/amd64" ]]; then
  printf 'Unsupported DOCKER_DEFAULT_PLATFORM: %s. This project supports linux/amd64 only.\n' "$DOCKER_DEFAULT_PLATFORM" >&2
  exit 1
fi
build_args+=("--platform" "$DOCKER_DEFAULT_PLATFORM")

docker build "${build_args[@]}" "$ROOT_DIR"
