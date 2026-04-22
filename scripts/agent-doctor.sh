#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="/opt/onec-agent/bin/onec-agent-doctor"
export CMD
exec "$ROOT_DIR/scripts/agent-exec.sh"
