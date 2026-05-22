#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

src_dir="${ONEC_BSL_SRC:-${SRC_DIR:-}}"
if [[ -z "$src_dir" ]]; then
  printf 'Set SRC_DIR to the project-relative source directory or file to format.\n' >&2
  exit 2
fi

quoted_src="$(printf '%q' "$src_dir")"
cmd="onec-agent bsl-format $quoted_src"
if [[ "${ONEC_BSL_FORMAT_CHECK:-${CHECK:-0}}" == "1" ]]; then
  cmd="export ONEC_BSL_FORMAT_CHECK=1; $cmd"
fi

CMD="$cmd"
export CMD
exec "$ROOT_DIR/scripts/agent-exec.sh"
