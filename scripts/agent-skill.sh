#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
name="${NAME:-${1:-}}"
if [[ -z "$name" ]]; then
  printf 'Usage: make agent-skill NAME=<context|testing|memory>\n' >&2
  exit 2
fi

quoted_name="$(printf '%q' "$name")"
CMD="onec-agent skill $quoted_name"
export CMD
exec "$ROOT_DIR/scripts/agent-exec.sh"
