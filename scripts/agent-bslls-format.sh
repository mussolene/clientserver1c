#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

src_dir="${BSLLS_SRC_DIR:-${SRC_DIR:-}}"
if [[ -z "$src_dir" ]]; then
  printf 'Set SRC_DIR to the project-relative source directory or file to format.\n' >&2
  exit 2
fi

CMD="BSLLS_MODE=format /opt/onec-agent/bin/onec-agent-bslls $(printf '%q' "$src_dir")"
export CMD
exec "$ROOT_DIR/scripts/agent-exec.sh"
