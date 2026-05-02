#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:-${MODE:-build}}"

case "$mode" in
  build) cmd_parts=("onec-agent" "context") ;;
  query) cmd_parts=("onec-agent" "memory-query") ;;
  capture) cmd_parts=("onec-agent" "memory-capture") ;;
  *) cmd_parts=("onec-agent-context" "$mode") ;;
esac

append_env() {
  local key="$1"
  local value="$2"
  if [[ -n "$value" ]]; then
    cmd_parts+=("--$key" "$value")
  fi
}

append_env task "${TASK:-}"
append_env query "${QUERY:-}"
append_env pack "${PACK:-}"
append_env limit "${LIMIT:-}"
append_env summary "${SUMMARY:-}"
append_env type "${TYPE:-}"
append_env depth "${DEPTH:-}"
append_env evidence "${EVIDENCE:-}"

printf -v cmd '%q ' "${cmd_parts[@]}"
CMD="${cmd% }"
export CMD
exec "$ROOT_DIR/scripts/agent-exec.sh"
