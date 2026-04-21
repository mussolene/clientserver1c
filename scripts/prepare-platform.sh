#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
PLATFORM_CACHE_DIR="$ROOT_DIR/.local/1c/platform"
DEV_STAGING_DIR="$ROOT_DIR/.local/1c/dev-platform"

INPUT_PLATFORM_VERSION="${PLATFORM_VERSION-}"
INPUT_PLATFORM_ARCH="${PLATFORM_ARCH-}"
INPUT_PLATFORM_DIST_NAME="${PLATFORM_DIST_NAME-}"
INPUT_DOCKER_DEFAULT_PLATFORM="${DOCKER_DEFAULT_PLATFORM-}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

PLATFORM_VERSION="${INPUT_PLATFORM_VERSION:-${PLATFORM_VERSION:-8.5.1.1302}}"
PLATFORM_DIST_NAME="${INPUT_PLATFORM_DIST_NAME:-${PLATFORM_DIST_NAME:-}}"
DOCKER_DEFAULT_PLATFORM="${INPUT_DOCKER_DEFAULT_PLATFORM:-${DOCKER_DEFAULT_PLATFORM:-}}"
PLATFORM_ARCH="${INPUT_PLATFORM_ARCH:-${PLATFORM_ARCH:-}}"
if [[ -z "${PLATFORM_ARCH:-}" && -n "${DOCKER_DEFAULT_PLATFORM:-}" ]]; then
  case "${DOCKER_DEFAULT_PLATFORM##*/}" in
    amd64|arm64) PLATFORM_ARCH="${DOCKER_DEFAULT_PLATFORM##*/}" ;;
  esac
fi
PLATFORM_ARCH="${PLATFORM_ARCH:-amd64}"
version_underscored="${PLATFORM_VERSION//./_}"

case "$PLATFORM_ARCH" in
  amd64|arm64) ;;
  *)
    echo "Unsupported PLATFORM_ARCH: $PLATFORM_ARCH" >&2
    exit 1
    ;;
esac

mkdir -p "$PLATFORM_CACHE_DIR" "$DEV_STAGING_DIR"
find "$DEV_STAGING_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

download_env=(ENV_FILE="$ENV_FILE" PLATFORM_VERSION="$PLATFORM_VERSION" PLATFORM_ARCH="$PLATFORM_ARCH")
if [[ -n "$PLATFORM_DIST_NAME" ]]; then
  download_env+=(PLATFORM_DIST_NAME="$PLATFORM_DIST_NAME")
fi
env "${download_env[@]}" "$ROOT_DIR/scripts/download-platform.sh"

resolve_existing_file() {
  local candidate

  for candidate in "$@"; do
    if [[ -n "$candidate" && -f "$PLATFORM_CACHE_DIR/$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

copy_to_staging() {
  local source_name="$1"
  local target_dir="$2"

  cp -f "$PLATFORM_CACHE_DIR/$source_name" "$target_dir/"
}

if [[ "$PLATFORM_ARCH" == "arm64" ]]; then
  server_archive="$(resolve_existing_file \
    "$PLATFORM_DIST_NAME" \
    "server.arm.deb64_${PLATFORM_VERSION}.zip")"
  copy_to_staging "$server_archive" "$DEV_STAGING_DIR"

  client_archive="$(resolve_existing_file \
    "client.arm.deb64_${PLATFORM_VERSION}.zip" \
    "thin.client.arm.deb64_${PLATFORM_VERSION}.zip" || true)"
  if [[ -z "$client_archive" ]]; then
    env ENV_FILE="$ENV_FILE" PLATFORM_VERSION="$PLATFORM_VERSION" PLATFORM_ARCH="$PLATFORM_ARCH" \
      PLATFORM_DIST_NAME="client.arm.deb64_${PLATFORM_VERSION}.zip" \
      "$ROOT_DIR/scripts/download-platform.sh"
    client_archive="$(resolve_existing_file \
      "client.arm.deb64_${PLATFORM_VERSION}.zip" \
      "thin.client.arm.deb64_${PLATFORM_VERSION}.zip")"
  fi
  copy_to_staging "$client_archive" "$DEV_STAGING_DIR"
else
  full_client_archive="server64_with_all_clients_${version_underscored}.zip"
  setup_full_run="setup-full-${PLATFORM_VERSION}-x86_64.run"

  if [[ ! -f "$PLATFORM_CACHE_DIR/$full_client_archive" ]]; then
    env ENV_FILE="$ENV_FILE" PLATFORM_VERSION="$PLATFORM_VERSION" PLATFORM_ARCH="$PLATFORM_ARCH" PLATFORM_DIST_NAME="$full_client_archive" \
      "$ROOT_DIR/scripts/download-platform.sh"
  fi

  if [[ -f "$PLATFORM_CACHE_DIR/$setup_full_run" ]]; then
    copy_to_staging "$setup_full_run" "$DEV_STAGING_DIR"
  else
    unzip -j -q "$PLATFORM_CACHE_DIR/$full_client_archive" \
      "$setup_full_run" \
      -d "$DEV_STAGING_DIR"
  fi
fi

printf 'Prepared platform staging:\n'
printf '  developer: %s\n' "$(ls -1 "$DEV_STAGING_DIR" | tr '\n' ' ' | sed 's/ $//')"
