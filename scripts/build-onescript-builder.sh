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

ONESCRIPT_BUILD_IMAGE="${ONESCRIPT_BUILD_IMAGE:-mussolene/linux-onescript-builder}"
ONESCRIPT_BUILD_TAG="${ONESCRIPT_BUILD_TAG:-2.0.0}"
ONESCRIPT_SDK_IMAGE="${ONESCRIPT_SDK_IMAGE:-mcr.microsoft.com/dotnet/sdk:8.0}"
ONESCRIPT_VERSION="${ONESCRIPT_VERSION:-2.0.0}"

build_args=(
  "--build-arg" "ONESCRIPT_SDK_IMAGE=${ONESCRIPT_SDK_IMAGE}"
  "--build-arg" "ONESCRIPT_VERSION=${ONESCRIPT_VERSION}"
  "-f" "$ROOT_DIR/base/linux-onescript-builder/Dockerfile"
  "-t" "${ONESCRIPT_BUILD_IMAGE}:${ONESCRIPT_BUILD_TAG}"
)

if [[ -n "${DOCKER_DEFAULT_PLATFORM:-}" ]]; then
  build_args+=("--platform" "${DOCKER_DEFAULT_PLATFORM}")
fi

docker build "${build_args[@]}" "$ROOT_DIR"
