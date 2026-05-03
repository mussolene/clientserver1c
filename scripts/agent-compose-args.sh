#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

compose_args=(-f "$ROOT_DIR/docker-compose.yml")
compose_args+=(-f "$ROOT_DIR/docker-compose.agent.yml")

if [[ -n "${NETHASP_INI_PATH:-}" ]]; then
  if [[ ! -f "$NETHASP_INI_PATH" ]]; then
    printf 'NETHASP_INI_PATH does not point to a readable file.\n' >&2
    exit 2
  fi
  if [[ ! -r "$NETHASP_INI_PATH" ]]; then
    printf 'NETHASP_INI_PATH does not point to a readable file.\n' >&2
    exit 2
  fi

  nethasp_abs="$(cd "$(dirname "$NETHASP_INI_PATH")" && pwd)/$(basename "$NETHASP_INI_PATH")"
  override_dir="$ROOT_DIR/.local/compose"
  override_file="$override_dir/nethasp.override.yml"
  mkdir -p "$override_dir"
  cat >"$override_file" <<EOF
services:
  1c-dev:
    volumes:
      - ${nethasp_abs}:/opt/1cv8/conf/nethasp.ini:ro
EOF
  compose_args+=(-f "$override_file")
fi

printf '%s\0' "${compose_args[@]}"
