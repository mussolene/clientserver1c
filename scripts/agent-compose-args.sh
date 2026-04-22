#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

compose_args=(-f "$ROOT_DIR/docker-compose.yml")
if [[ "${ONEC_PLATFORM_OVERRIDE:-}" == "native-arm" ]]; then
  compose_args+=(-f "$ROOT_DIR/docker-compose.onec-native-arm.yml")
fi
compose_args+=(-f "$ROOT_DIR/docker-compose.agent.yml")

printf '%s\0' "${compose_args[@]}"
