#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

compose_args=(-f "$ROOT_DIR/docker-compose.yml")
compose_args+=(-f "$ROOT_DIR/docker-compose.agent.yml")

printf '%s\0' "${compose_args[@]}"
