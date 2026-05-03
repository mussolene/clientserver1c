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
ONESCRIPT_BUILD_IMAGE="${IMAGE_NAMESPACE}/linux-onescript-builder"
ONESCRIPT_BUILD_TAG="2.0.0"
ONESCRIPT_SDK_IMAGE="mcr.microsoft.com/dotnet/sdk:8.0"
ONESCRIPT_VERSION="2.0.0"

build_args=(
  "--build-arg" "ONESCRIPT_SDK_IMAGE=${ONESCRIPT_SDK_IMAGE}"
  "--build-arg" "ONESCRIPT_VERSION=${ONESCRIPT_VERSION}"
  "-f" "$ROOT_DIR/base/linux-onescript-builder/Dockerfile"
  "-t" "${ONESCRIPT_BUILD_IMAGE}:${ONESCRIPT_BUILD_TAG}"
)

DOCKER_DEFAULT_PLATFORM="${DOCKER_DEFAULT_PLATFORM:-linux/amd64}"
if [[ "$DOCKER_DEFAULT_PLATFORM" != "linux/amd64" ]]; then
  printf 'Unsupported DOCKER_DEFAULT_PLATFORM: %s. This project supports linux/amd64 only.\n' "$DOCKER_DEFAULT_PLATFORM" >&2
  exit 1
fi
build_args+=("--platform" "$DOCKER_DEFAULT_PLATFORM")

docker build "${build_args[@]}" "$ROOT_DIR"
