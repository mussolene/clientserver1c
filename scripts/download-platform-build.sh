#!/usr/bin/env bash
set -euo pipefail

LOGIN_URL="https://login.1c.ru/login"
RELEASES_URL="https://releases.1c.ru"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36"

ITS_LOGIN_FILE="${ITS_LOGIN_FILE:-/run/secrets/its_login}"
ITS_PASSWORD_FILE="${ITS_PASSWORD_FILE:-/run/secrets/its_password}"
PLATFORM_DOWNLOAD_DIR="${PLATFORM_DOWNLOAD_DIR:-/var/cache/1c-platform}"
PLATFORM_VERSION="${PLATFORM_VERSION:?PLATFORM_VERSION is required}"
PLATFORM_COMPONENT="${PLATFORM_COMPONENT:?PLATFORM_COMPONENT is required}"
PLATFORM_DIST_NAME="${PLATFORM_DIST_NAME:-}"
PLATFORM_DOWNLOAD_URL="${PLATFORM_DOWNLOAD_URL:-}"
TARGETARCH="${TARGETARCH:-amd64}"
PLATFORM_PACKAGE_ARCH="${PLATFORM_PACKAGE_ARCH:-$TARGETARCH}"

get_platform_nick() {
  local version="$1"
  local major minor

  major="$(printf '%s' "$version" | cut -d. -f1)"
  minor="$(printf '%s' "$version" | cut -d. -f2)"

  if [[ -n "$major" && -n "$minor" ]]; then
    printf 'Platform%s%s\n' "$major" "$minor"
  else
    printf 'Platform83\n'
  fi
}

read_secret() {
  local path="$1"

  if [[ ! -f "$path" ]]; then
    return 1
  fi

  tr -d '\r' < "$path"
}

extract_download_link() {
  tr '\n' ' ' | sed -n 's/.*href="\([^"]*\)"[^>]*>Скачать дистрибутив<.*/\1/p'
}

resolve_candidates() {
  local version="$1"
  local component="$2"
  local arch="$3"
  local normalized_version

  normalized_version="${version//./_}"

  if [[ -n "$PLATFORM_DIST_NAME" ]]; then
    printf '%s\n' "$PLATFORM_DIST_NAME"
    return 0
  fi

  case "$component:$arch" in
    server:amd64)
      printf '%s\n' "server64_with_all_clients_${normalized_version}.zip"
      ;;
    client:amd64)
      printf '%s\n' "server64_with_all_clients_${normalized_version}.zip"
      ;;
    server:arm64)
      printf '%s\n' "server.arm.deb64_${version}.zip"
      ;;
    client:arm64)
      printf '%s\n' \
        "client.arm.deb64_${version}.zip" \
        "thin.client.arm.deb64_${version}.zip"
      ;;
    *)
      echo "Unsupported PLATFORM_COMPONENT/TARGETARCH combination: ${component}/${arch}" >&2
      exit 1
      ;;
  esac
}

download_via_direct_url() {
  local filename
  local target_path

  filename="${PLATFORM_DIST_NAME:-${PLATFORM_DOWNLOAD_URL##*/}}"
  target_path="${PLATFORM_DOWNLOAD_DIR}/${filename}"

  mkdir -p "$PLATFORM_DOWNLOAD_DIR"

  if [[ -s "$target_path" ]]; then
    echo "Using cached platform archive: $(basename "$target_path")" >&2
    printf '%s\n' "$target_path"
    return 0
  fi

  echo "Downloading platform archive via direct URL: ${filename}" >&2
  curl --fail --location --retry 3 --show-error --silent \
    -A "$USER_AGENT" \
    -o "${target_path}.part" \
    "$PLATFORM_DOWNLOAD_URL"
  mv "${target_path}.part" "$target_path"
  printf '%s\n' "$target_path"
}

download_via_its() {
  local its_login
  local its_password
  local cookie_file
  local login_page
  local execution
  local profile_url
  local version_page
  local detail_path=""
  local detail_page
  local download_path
  local target_path
  local selected_candidate=""
  local candidate
  local -a candidates

  its_login="$(read_secret "$ITS_LOGIN_FILE" || true)"
  its_password="$(read_secret "$ITS_PASSWORD_FILE" || true)"

  if [[ -z "$its_login" || -z "$its_password" ]]; then
    echo "ITS secrets are required for build-time platform download" >&2
    exit 1
  fi

  echo "Authorizing on login.1c.ru for platform ${PLATFORM_VERSION} (${PLATFORM_COMPONENT}/${PLATFORM_PACKAGE_ARCH})" >&2

  mkdir -p "$PLATFORM_DOWNLOAD_DIR"
  mapfile -t candidates < <(resolve_candidates "$PLATFORM_VERSION" "$PLATFORM_COMPONENT" "$PLATFORM_PACKAGE_ARCH")

  for candidate in "${candidates[@]}"; do
    if [[ -s "$PLATFORM_DOWNLOAD_DIR/$candidate" ]]; then
      echo "Using cached platform archive: ${candidate}" >&2
      printf '%s\n' "$PLATFORM_DOWNLOAD_DIR/$candidate"
      return 0
    fi
  done

  cookie_file="$(mktemp)"
  trap 'rm -f "${cookie_file:-}"' EXIT

  login_page="$(curl --fail --location --show-error --silent \
    -c "$cookie_file" \
    -A "$USER_AGENT" \
    "$LOGIN_URL")"
  execution="$(printf '%s' "$login_page" \
    | grep -o 'name="execution" value="[^"]*"' \
    | head -n 1 \
    | sed 's/.*value="//; s/"$//' || true)"

  if [[ -z "$execution" ]]; then
    echo "Could not extract login token from login.1c.ru" >&2
    exit 1
  fi

  curl --fail --location --show-error --silent \
    -b "$cookie_file" \
    -c "$cookie_file" \
    -A "$USER_AGENT" \
    --data-urlencode "inviteCode=" \
    --data-urlencode "execution=$execution" \
    --data-urlencode "_eventId=submit" \
    --data-urlencode "rememberMe=false" \
    --data-urlencode "username=$its_login" \
    --data-urlencode "password=$its_password" \
    "$LOGIN_URL" \
    >/dev/null

  profile_url="$(curl --fail --location --show-error --silent \
    -o /dev/null \
    -w '%{url_effective}' \
    -b "$cookie_file" \
    -A "$USER_AGENT" \
    https://login.1c.ru/user/profile)"

  case "$profile_url" in
    *"/user/profile") ;;
    *)
      echo "ITS authorization failed while downloading platform" >&2
      exit 1
      ;;
  esac

  version_page="$(curl --fail --location --show-error --silent \
    -G \
    -b "$cookie_file" \
    -A "$USER_AGENT" \
    --data-urlencode "nick=$(get_platform_nick "$PLATFORM_VERSION")" \
    --data-urlencode "ver=$PLATFORM_VERSION" \
    "$RELEASES_URL/version_files")"

  for candidate in "${candidates[@]}"; do
    detail_path="$(printf '%s' "$version_page" \
      | grep -o 'href="[^"]*"' \
      | sed 's/^href="//; s/"$//' \
      | sed 's/&amp;/\&/g' \
      | grep '/version_file' \
      | grep "$candidate" \
      | head -n 1 || true)"
    if [[ -n "$detail_path" ]]; then
      selected_candidate="$candidate"
      break
    fi
  done

  if [[ -z "$detail_path" ]]; then
    echo "Could not find matching platform file for ${PLATFORM_COMPONENT}/${TARGETARCH} ${PLATFORM_VERSION}" >&2
    exit 1
  fi

  case "$detail_path" in
    http://*|https://*) ;;
    *) detail_path="$RELEASES_URL$detail_path" ;;
  esac

  detail_page="$(curl --fail --location --show-error --silent \
    -b "$cookie_file" \
    -A "$USER_AGENT" \
    "$detail_path")"
  download_path="$(printf '%s' "$detail_page" | extract_download_link)"

  if [[ -z "$download_path" ]]; then
    echo "Could not resolve final platform download URL" >&2
    exit 1
  fi

  case "$download_path" in
    http://*|https://*) ;;
    *) download_path="$RELEASES_URL$download_path" ;;
  esac

  target_path="${PLATFORM_DOWNLOAD_DIR}/${selected_candidate}"

  echo "Downloading platform archive from ITS: ${selected_candidate}" >&2

  curl --fail --location --retry 3 --show-error --silent \
    -b "$cookie_file" \
    -A "$USER_AGENT" \
    -o "${target_path}.part" \
    "$download_path"
  mv "${target_path}.part" "$target_path"
  printf '%s\n' "$target_path"
}

case "$PLATFORM_PACKAGE_ARCH" in
  amd64|arm64) ;;
  *)
    echo "Unsupported PLATFORM_PACKAGE_ARCH: $PLATFORM_PACKAGE_ARCH" >&2
    exit 1
    ;;
esac

case "$PLATFORM_COMPONENT" in
  server|client) ;;
  *)
    echo "Unsupported PLATFORM_COMPONENT: $PLATFORM_COMPONENT" >&2
    exit 1
    ;;
esac

if [[ -n "$PLATFORM_DOWNLOAD_URL" ]]; then
  download_via_direct_url
else
  download_via_its
fi
