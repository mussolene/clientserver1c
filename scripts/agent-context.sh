#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:-${MODE:-build}}"

case "$mode" in
  build)
    task="${TASK:-repo_development}"
    cmd_parts=("acs" "context" "build" "--intent" "$task" "--scope" "project" "--json")
    ;;
  mcp-config) cmd_parts=("onec-agent" "context-mcp-config") ;;
  *) cmd_parts=("onec-agent-context" "$mode") ;;
esac

append_env() {
  local key="$1"
  local value="$2"
  if [[ -n "$value" ]]; then
    cmd_parts+=("--$key" "$value")
  fi
}

if [[ "$mode" != "build" && "$mode" != "mcp-config" ]]; then
  append_env task "${TASK:-}"
  append_env query "${QUERY:-}"
  append_env pack "${PACK:-}"
  append_env limit "${LIMIT:-}"
fi

printf -v cmd '%q ' "${cmd_parts[@]}"
CMD="${cmd% }"
export CMD
exec "$ROOT_DIR/scripts/agent-exec.sh"
