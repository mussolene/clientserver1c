#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

src_dir="${ONEC_BSL_SRC:-${SRC_DIR:-}}"
output_path="${ONEC_BSL_OUTPUT:-${OUTPUT_PATH:-}}"
format="${ONEC_BSL_FORMAT:-${FORMAT:-}}"
select="${ONEC_BSL_SELECT:-${SELECT:-}}"
ignore="${ONEC_BSL_IGNORE:-${IGNORE:-}}"

cmd_parts=()
if [[ -n "$src_dir" ]]; then
  cmd_parts+=("$(printf '%q' "$src_dir")")
fi

cmd="onec-agent bsl-check ${cmd_parts[*]}"
if [[ -n "$output_path" ]]; then
  cmd="export ONEC_BSL_OUTPUT=$(printf '%q' "$output_path"); $cmd"
fi
if [[ -n "$format" ]]; then
  cmd="export ONEC_BSL_FORMAT=$(printf '%q' "$format"); $cmd"
fi
if [[ -n "$select" ]]; then
  cmd="export ONEC_BSL_SELECT=$(printf '%q' "$select"); $cmd"
fi
if [[ -n "$ignore" ]]; then
  cmd="export ONEC_BSL_IGNORE=$(printf '%q' "$ignore"); $cmd"
fi

CMD="$cmd"
export CMD
exec "$ROOT_DIR/scripts/agent-exec.sh"
