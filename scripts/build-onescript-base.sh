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

ONESCRIPT_BASE_IMAGE="${ONESCRIPT_BASE_IMAGE:-mussolene/linux-onescript}"
ONESCRIPT_BASE_TAG="${ONESCRIPT_BASE_TAG:-2.0.0}"
ONESCRIPT_BASE_DIST="${ONESCRIPT_BASE_DIST:-jammy}"
ONESCRIPT_BUILD_IMAGE="${ONESCRIPT_BUILD_IMAGE:-mussolene/linux-onescript-builder}"
ONESCRIPT_BUILD_TAG="${ONESCRIPT_BUILD_TAG:-2.0.0}"
VANESSA_ADD_VERSION="${VANESSA_ADD_VERSION:-6.9.5}"
VANESSA_RUNNER_VERSION="${VANESSA_RUNNER_VERSION:-2.6.0}"

build_args=(
  "--build-arg" "ONESCRIPT_BUILD_IMAGE=${ONESCRIPT_BUILD_IMAGE}"
  "--build-arg" "ONESCRIPT_BUILD_TAG=${ONESCRIPT_BUILD_TAG}"
  "--build-arg" "ONESCRIPT_BASE_DIST=${ONESCRIPT_BASE_DIST}"
  "--build-arg" "VANESSA_ADD_VERSION=${VANESSA_ADD_VERSION}"
  "--build-arg" "VANESSA_RUNNER_VERSION=${VANESSA_RUNNER_VERSION}"
  "-f" "$ROOT_DIR/base/linux-onescript/Dockerfile"
  "-t" "${ONESCRIPT_BASE_IMAGE}:${ONESCRIPT_BASE_TAG}"
)

if [[ -n "${DOCKER_DEFAULT_PLATFORM:-}" ]]; then
  build_args+=("--platform" "${DOCKER_DEFAULT_PLATFORM}")
fi

docker build "${build_args[@]}" "$ROOT_DIR"
