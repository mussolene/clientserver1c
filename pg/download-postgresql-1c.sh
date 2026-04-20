#!/usr/bin/env bash
set -euo pipefail

LOGIN_URL="https://login.1c.ru/login"
RELEASES_URL="https://releases.1c.ru"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36"

ITS_LOGIN_FILE="${ITS_LOGIN_FILE:-/run/secrets/its_login}"
ITS_PASSWORD_FILE="${ITS_PASSWORD_FILE:-/run/secrets/its_password}"
PG_DOWNLOAD_DIR="${PG_DOWNLOAD_DIR:-/tmp/pg1c}"
PG_1C_VERSION="${PG_1C_VERSION:?PG_1C_VERSION is required}"
PG_REPO_DIST="${PG_REPO_DIST:-bookworm}"
TARGETARCH="${TARGETARCH:-amd64}"
PG_1C_RELEASE_DIST="${PG_1C_RELEASE_DIST:-}"

read_secret() {
  local path="$1"

  if [[ ! -f "$path" ]]; then
    echo "Missing required secret file: $path" >&2
    exit 1
  fi

  tr -d '\r' < "$path"
}

map_release_dist() {
  local value="$1"

  case "$value" in
    bookworm) printf 'debian_12.11\n' ;;
    trixie) printf 'debian_13.0\n' ;;
    bullseye) printf 'debian_11.11\n' ;;
    jammy) printf 'ubuntu_22.04\n' ;;
    noble) printf 'ubuntu_24.04\n' ;;
    focal) printf 'ubuntu_20.04\n' ;;
    debian_11.11|debian_12.11|debian_13.0|ubuntu_20.04|ubuntu_22.04|ubuntu_24.04)
      printf '%s\n' "$value"
      ;;
    *)
      echo "Unsupported PG_REPO_DIST/PG_1C_RELEASE_DIST: $value" >&2
      exit 1
      ;;
  esac
}

map_release_arch() {
  case "$1" in
    amd64) printf 'x86_64\n' ;;
    arm64) printf 'aarch64\n' ;;
    *)
      echo "Unsupported TARGETARCH: $1" >&2
      exit 1
      ;;
  esac
}

extract_download_link() {
  tr '\n' ' ' | sed -n 's/.*href="\([^"]*\)"[^>]*>Скачать дистрибутив<.*/\1/p'
}

ITS_LOGIN="$(read_secret "$ITS_LOGIN_FILE")"
ITS_PASSWORD="$(read_secret "$ITS_PASSWORD_FILE")"
PG_1C_RELEASE_DIST="$(map_release_dist "${PG_1C_RELEASE_DIST:-$PG_REPO_DIST}")"
PG_1C_RELEASE_ARCH="$(map_release_arch "$TARGETARCH")"

mkdir -p "$PG_DOWNLOAD_DIR"

COOKIE_FILE="$(mktemp)"
ARCHIVE_FILE="$(mktemp --suffix=.tar.bz2)"

cleanup() {
  rm -f "$COOKIE_FILE" "$ARCHIVE_FILE"
}
trap cleanup EXIT

echo "Authorizing on login.1c.ru for PostgreSQL 1C ${PG_1C_VERSION}"
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
    echo "ITS authorization failed while downloading PostgreSQL 1C" >&2
    exit 1
    ;;
esac

version_page="$(curl --fail --location --show-error --silent \
  -G \
  -b "$COOKIE_FILE" \
  -A "$USER_AGENT" \
  --data-urlencode "nick=AddCompPostgre" \
  --data-urlencode "ver=$PG_1C_VERSION" \
  "$RELEASES_URL/version_files")"

detail_path=""
for candidate_suffix in \
  "_${PG_1C_RELEASE_DIST}_${PG_1C_RELEASE_ARCH}_package.tar.bz2" \
  "_${PG_1C_RELEASE_DIST}_${PG_1C_RELEASE_ARCH}_install.tar.bz2"
do
  detail_path="$(printf '%s' "$version_page" \
    | grep -o 'href="[^"]*"' \
    | sed 's/^href="//; s/"$//' \
    | sed 's/&amp;/\&/g' \
    | grep '/version_file' \
    | grep "$candidate_suffix" \
    | head -n 1 || true)"
  if [[ -n "$detail_path" ]]; then
    break
  fi
done

if [[ -z "$detail_path" ]]; then
  echo "Could not find PostgreSQL 1C archive for ${PG_1C_VERSION} (${PG_1C_RELEASE_DIST}, ${PG_1C_RELEASE_ARCH})" >&2
  exit 1
fi

case "$detail_path" in
  http://*|https://*) ;;
  *) detail_path="$RELEASES_URL$detail_path" ;;
esac

detail_page="$(curl --fail --location --show-error --silent \
  -b "$COOKIE_FILE" \
  -A "$USER_AGENT" \
  "$detail_path")"
download_path="$(printf '%s' "$detail_page" | extract_download_link)"

if [[ -z "$download_path" ]]; then
  echo "Could not extract the final PostgreSQL 1C download URL" >&2
  exit 1
fi

case "$download_path" in
  http://*|https://*) ;;
  *) download_path="$RELEASES_URL$download_path" ;;
esac

echo "Downloading PostgreSQL 1C archive for ${PG_1C_RELEASE_DIST}/${PG_1C_RELEASE_ARCH}"
curl --fail --location --retry 3 --show-error --silent \
  -b "$COOKIE_FILE" \
  -A "$USER_AGENT" \
  -o "$ARCHIVE_FILE" \
  "$download_path"

tar -xjf "$ARCHIVE_FILE" -C "$PG_DOWNLOAD_DIR"
