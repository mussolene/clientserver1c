#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
PLATFORM_CACHE_DIR="$ROOT_DIR/.local/1c/platform"
SERVER_STAGING_DIR="$ROOT_DIR/.local/1c/server-platform"
CLIENT_STAGING_DIR="$ROOT_DIR/.local/1c/client-platform"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

PLATFORM_VERSION="${PLATFORM_VERSION:-8.3.22.1851}"
PLATFORM_DIST_NAME="${PLATFORM_DIST_NAME:-}"
version_underscored="${PLATFORM_VERSION//./_}"

mkdir -p "$PLATFORM_CACHE_DIR" "$SERVER_STAGING_DIR" "$CLIENT_STAGING_DIR"
find "$SERVER_STAGING_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
find "$CLIENT_STAGING_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

download_env=(ENV_FILE="$ENV_FILE" PLATFORM_VERSION="$PLATFORM_VERSION")
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

server_archive="$(resolve_existing_file \
  "$PLATFORM_DIST_NAME" \
  "deb64_${version_underscored}.zip" \
  "server64_${version_underscored}.zip" \
  "server64_${version_underscored}.tar.gz")"
copy_to_staging "$server_archive" "$SERVER_STAGING_DIR"

if [[ "$PLATFORM_VERSION" == 8.5.* ]]; then
  full_client_archive="server64_with_all_clients_${version_underscored}.zip"
  full_client_installer="setup-full-${PLATFORM_VERSION}-x86_64.run"

  if [[ ! -f "$PLATFORM_CACHE_DIR/$full_client_archive" ]]; then
    env ENV_FILE="$ENV_FILE" PLATFORM_VERSION="$PLATFORM_VERSION" PLATFORM_DIST_NAME="$full_client_archive" \
      "$ROOT_DIR/scripts/download-platform.sh"
  fi

  if [[ ! -f "$PLATFORM_CACHE_DIR/$full_client_installer" ]]; then
    unzip -p "$PLATFORM_CACHE_DIR/$full_client_archive" "$full_client_installer" > "$PLATFORM_CACHE_DIR/$full_client_installer"
    chmod +x "$PLATFORM_CACHE_DIR/$full_client_installer"
  fi

  copy_to_staging "$full_client_installer" "$CLIENT_STAGING_DIR"
else
  client_archive="$(resolve_existing_file \
    "client_${version_underscored}.deb64.zip" \
    "server64_with_all_clients_${version_underscored}.zip" \
    "server64_with_clients_${version_underscored}.zip" \
    "server64_${version_underscored}.tar.gz" \
    "thin.client_${version_underscored}.deb64.zip")"
  copy_to_staging "$client_archive" "$CLIENT_STAGING_DIR"
fi

printf 'Prepared platform staging:\n'
printf '  server: %s\n' "$(ls -1 "$SERVER_STAGING_DIR" | tr '\n' ' ' | sed 's/ $//')"
printf '  client: %s\n' "$(ls -1 "$CLIENT_STAGING_DIR" | tr '\n' ' ' | sed 's/ $//')"
