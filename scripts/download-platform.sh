#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
PLATFORM_DIR="$ROOT_DIR/.local/1c/platform"
LOGIN_URL="https://login.1c.ru/login"
RELEASES_URL="https://releases.1c.ru"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36"

usage() {
  cat <<'EOF'
Usage:
  scripts/download-platform.sh

Reads .env, downloads the 1C platform archive into .local/1c/platform,
and leaves credentials only on the host.

Expected .env variables:
  PLATFORM_VERSION
  PLATFORM_DIST_NAME
  ITS_LOGIN
  ITS_PASSWORD

Optional:
  PLATFORM_DOWNLOAD_URL
EOF
}

ensure_env_file() {
  if [[ ! -f "$ENV_FILE" ]]; then
    if [[ -f "$ROOT_DIR/.env.example" ]]; then
      cp "$ROOT_DIR/.env.example" "$ENV_FILE"
      echo "Created $ENV_FILE from .env.example"
    else
      : > "$ENV_FILE"
      echo "Created empty $ENV_FILE"
    fi
  fi
}

upsert_env_var() {
  local key="$1"
  local value="$2"
  local escaped_value

  escaped_value="$(printf '%s' "$value" | sed 's/[\/&]/\\&/g')"
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i.bak "s/^${key}=.*/${key}=${escaped_value}/" "$ENV_FILE"
    rm -f "$ENV_FILE.bak"
  else
    printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

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

prompt_and_store_its_credentials() {
  local entered_login=""
  local entered_password=""

  ensure_env_file

  if [[ -z "${ITS_LOGIN:-}" ]]; then
    read -r -p "ITS login: " entered_login
    if [[ -z "$entered_login" ]]; then
      echo "ITS login cannot be empty" >&2
      exit 1
    fi
    ITS_LOGIN="$entered_login"
    upsert_env_var "ITS_LOGIN" "$ITS_LOGIN"
    echo "Saved ITS_LOGIN to $ENV_FILE"
  fi

  if [[ -z "${ITS_PASSWORD:-}" ]]; then
    read -r -s -p "ITS password: " entered_password
    printf '\n'
    if [[ -z "$entered_password" ]]; then
      echo "ITS password cannot be empty" >&2
      exit 1
    fi
    ITS_PASSWORD="$entered_password"
    upsert_env_var "ITS_PASSWORD" "$ITS_PASSWORD"
    echo "Saved ITS_PASSWORD to $ENV_FILE"
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

INPUT_PLATFORM_VERSION="${PLATFORM_VERSION-}"
INPUT_PLATFORM_DIST_NAME="${PLATFORM_DIST_NAME-}"
INPUT_ITS_LOGIN="${ITS_LOGIN-}"
INPUT_ITS_PASSWORD="${ITS_PASSWORD-}"
INPUT_PLATFORM_DOWNLOAD_URL="${PLATFORM_DOWNLOAD_URL-}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

PLATFORM_VERSION="${INPUT_PLATFORM_VERSION:-${PLATFORM_VERSION:-8.3.22.1851}}"
PLATFORM_DIST_NAME="${INPUT_PLATFORM_DIST_NAME:-${PLATFORM_DIST_NAME:-server64_${PLATFORM_VERSION//./_}.tar.gz}}"
PLATFORM_DOWNLOAD_URL="${INPUT_PLATFORM_DOWNLOAD_URL:-${PLATFORM_DOWNLOAD_URL:-}}"
ITS_LOGIN="${INPUT_ITS_LOGIN:-${ITS_LOGIN:-}}"
ITS_PASSWORD="${INPUT_ITS_PASSWORD:-${ITS_PASSWORD:-}}"
TARGET_FILE="$PLATFORM_DIR/$PLATFORM_DIST_NAME"
TEMP_FILE="$TARGET_FILE.part"

mkdir -p "$PLATFORM_DIR"

if [[ -s "$TARGET_FILE" ]]; then
  echo "Platform archive already exists: $TARGET_FILE"
  exit 0
fi

cleanup() {
  rm -f "${COOKIE_FILE:-}" "${TEMP_FILE:-}"
}

extract_download_link() {
  tr '\n' ' ' | sed -n 's/.*href="\([^"]*\)"[^>]*>Скачать дистрибутив<.*/\1/p'
}

download_file() {
  local url="$1"
  curl --fail --location --retry 3 --show-error --silent \
    -A "$USER_AGENT" \
    -o "$TEMP_FILE" \
    "$url"
  mv "$TEMP_FILE" "$TARGET_FILE"
  echo "Downloaded: $TARGET_FILE"
}

download_via_direct_url() {
  echo "Downloading platform archive from PLATFORM_DOWNLOAD_URL"
  download_file "$PLATFORM_DOWNLOAD_URL"
}

download_via_its() {
  local login_page
  local execution
  local profile_url
  local version_page
  local detail_path
  local detail_page
  local download_path
  local normalized_version
  local platform_nick
  local seen_candidates
  local candidate
  local -a candidates

  if [[ -z "$ITS_LOGIN" || -z "$ITS_PASSWORD" ]]; then
    prompt_and_store_its_credentials
  fi

  COOKIE_FILE="$(mktemp)"
  trap cleanup EXIT

  echo "Authorizing on login.1c.ru"
  login_page="$(curl --fail --location --show-error --silent \
    -c "$COOKIE_FILE" \
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
    -b "$COOKIE_FILE" \
    -c "$COOKIE_FILE" \
    -A "$USER_AGENT" \
    --data-urlencode "inviteCode=" \
    --data-urlencode "execution=$execution" \
    --data-urlencode "_eventId=submit" \
    --data-urlencode "rememberMe=false" \
    --data-urlencode "username=$ITS_LOGIN" \
    --data-urlencode "password=$ITS_PASSWORD" \
    "$LOGIN_URL" \
    >/dev/null

  profile_url="$(curl --fail --location --show-error --silent \
    -o /dev/null \
    -w '%{url_effective}' \
    -b "$COOKIE_FILE" \
    -A "$USER_AGENT" \
    https://login.1c.ru/user/profile)"

  case "$profile_url" in
    *"/user/profile") ;;
    *)
      echo "ITS authorization failed. Check ITS_LOGIN / ITS_PASSWORD" >&2
      exit 1
      ;;
  esac

  echo "Searching release page for version $PLATFORM_VERSION"
  platform_nick="$(get_platform_nick "$PLATFORM_VERSION")"
  version_page="$(curl --fail --location --show-error --silent \
    -G \
    -b "$COOKIE_FILE" \
    -A "$USER_AGENT" \
    --data-urlencode "nick=$platform_nick" \
    --data-urlencode "ver=$PLATFORM_VERSION" \
    "$RELEASES_URL/version_files")"

  normalized_version="${PLATFORM_VERSION//./_}"
  candidates=()
  seen_candidates="|"
  for candidate in \
    "$PLATFORM_DIST_NAME" \
    "server64_${normalized_version}.tar.gz" \
    "deb64_${normalized_version}.tar.gz" \
    "deb64_${normalized_version}.zip" \
    "server64.tar.gz" \
    "deb64.tar.gz"
  do
    case "$seen_candidates" in
      *"|$candidate|"*) continue ;;
    esac
    candidates+=("$candidate")
    seen_candidates="${seen_candidates}${candidate}|"
  done

  detail_path=""
  for candidate in "${candidates[@]}"; do
    detail_path="$(printf '%s' "$version_page" \
      | grep -o 'href="[^"]*"' \
      | sed 's/^href="//; s/"$//' \
      | sed 's/&amp;/\&/g' \
      | grep '/version_file' \
      | grep "$candidate" \
      | head -n 1 || true)"
    if [[ -n "$detail_path" ]]; then
      break
    fi
  done

  if [[ -z "$detail_path" ]]; then
    echo "Could not find a matching platform file on releases.1c.ru for $PLATFORM_VERSION" >&2
    echo "Set PLATFORM_DIST_NAME explicitly or use PLATFORM_DOWNLOAD_URL" >&2
    exit 1
  fi

  case "$detail_path" in
    http://*|https://*) ;;
    *) detail_path="$RELEASES_URL$detail_path" ;;
  esac

  echo "Resolving final download link"
  detail_page="$(curl --fail --location --show-error --silent \
    -b "$COOKIE_FILE" \
    -A "$USER_AGENT" \
    "$detail_path")"
  download_path="$(printf '%s' "$detail_page" | extract_download_link)"

  if [[ -z "$download_path" ]]; then
    echo "Could not extract the final download URL from releases.1c.ru" >&2
    exit 1
  fi

  case "$download_path" in
    http://*|https://*) ;;
    *) download_path="$RELEASES_URL$download_path" ;;
  esac

  echo "Downloading platform archive to $TARGET_FILE"
  curl --fail --location --retry 3 --show-error --silent \
    -b "$COOKIE_FILE" \
    -A "$USER_AGENT" \
    -o "$TEMP_FILE" \
    "$download_path"
  mv "$TEMP_FILE" "$TARGET_FILE"
  echo "Downloaded: $TARGET_FILE"
}

if [[ -n "$PLATFORM_DOWNLOAD_URL" ]]; then
  download_via_direct_url
else
  download_via_its
fi
