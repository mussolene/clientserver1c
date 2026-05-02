#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD='onec-agent doctor'
export CMD
exec "$ROOT_DIR/scripts/agent-exec.sh"
