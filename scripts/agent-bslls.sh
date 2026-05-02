#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

src_dir="${BSLLS_SRC_DIR:-${SRC_DIR:-}}"
output_dir="${BSLLS_OUTPUT_DIR:-${OUTPUT_DIR:-}}"
reporters="${BSLLS_REPORTERS:-${REPORTERS:-}}"

cmd_parts=()
if [[ -n "$src_dir" ]]; then
  cmd_parts+=("$(printf '%q' "$src_dir")")
fi

cmd_args="${cmd_parts[*]}"
cmd="onec-agent bslls $cmd_args"
if [[ -n "$output_dir" ]]; then
  cmd="export BSLLS_OUTPUT_DIR=$(printf '%q' "$output_dir"); $cmd"
fi
if [[ -n "$reporters" ]]; then
  cmd="export BSLLS_REPORTERS=$(printf '%q' "$reporters"); $cmd"
fi

CMD="$cmd"
export CMD
exec "$ROOT_DIR/scripts/agent-exec.sh"
