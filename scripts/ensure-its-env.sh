#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

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

prompt_and_store() {
  local entered_login=""
  local entered_password=""

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

ensure_env_file

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

ITS_LOGIN="${ITS_LOGIN:-}"
ITS_PASSWORD="${ITS_PASSWORD:-}"

if [[ -n "$ITS_LOGIN" && -n "$ITS_PASSWORD" ]]; then
  exit 0
fi

if [[ -n "${CI:-}" || ! -t 0 ]]; then
  echo "ITS_LOGIN and ITS_PASSWORD are required in environment or $ENV_FILE for non-interactive builds" >&2
  exit 1
fi

prompt_and_store
