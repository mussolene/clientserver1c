#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
name="${NAME:-${1:-}}"
if [[ -z "$name" ]]; then
  printf 'Usage: make agent-skill NAME=<context|testing|proof-loop>\n' >&2
  exit 2
fi

CMD="/opt/onec-agent/bin/onec-agent-skill '$name'"
export CMD
exec "$ROOT_DIR/scripts/agent-exec.sh"
