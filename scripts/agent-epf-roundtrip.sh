#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

project_path="${PROJECT_PATH:-${ONEC_PROJECT_PATH:-}}"
if [[ -z "$project_path" ]]; then
  printf 'Set PROJECT_PATH or ONEC_PROJECT_PATH to the host project repository.\n' >&2
  exit 2
fi
if [[ ! -d "$project_path" ]]; then
  printf 'Project path does not exist or is not a directory: %s\n' "$project_path" >&2
  exit 2
fi
project_path="$(cd "$project_path" && pwd)"
export ONEC_PROJECT_PATH="$project_path"

epf_path="${EPF_PATH:-}"
if [[ -z "$epf_path" ]]; then
  printf 'Set EPF_PATH to an .epf path inside PROJECT_PATH.\n' >&2
  exit 2
fi

case "$epf_path" in
  "$project_path"/*)
    epf_rel="${epf_path#"$project_path"/}"
    ;;
  /*)
    printf 'EPF_PATH must be inside PROJECT_PATH: %s\n' "$epf_path" >&2
    exit 2
    ;;
  *)
    epf_rel="$epf_path"
    ;;
esac

if [[ "$epf_rel" == *".."* ]]; then
  printf 'EPF_PATH must not contain parent-directory traversal: %s\n' "$epf_path" >&2
  exit 2
fi

if [[ ! -f "$project_path/$epf_rel" ]]; then
  printf 'EPF file does not exist: %s\n' "$project_path/$epf_rel" >&2
  exit 2
fi

compose_args=()
while IFS= read -r -d '' compose_arg; do
  compose_args+=("$compose_arg")
done < <(bash "$ROOT_DIR/scripts/agent-compose-args.sh")

epf_name="$(basename "$epf_rel")"
epf_stem="${epf_name%.epf}"
roundtrip_rel="${EPF_ROUNDTRIP_DIR:-.agent/runtime/epf-roundtrip/$epf_stem}"
ib_connection="${IB_CONNECTION:-/F/mnt/data/testdb}"
db_user="${DB_USER:-Администратор}"
db_pwd="${DB_PWD:-}"
v8version="${V8_VERSION:-${PLATFORM_VERSION:-8.5.1.1302}}"
timeout_sec="${EPF_ROUNDTRIP_TIMEOUT_SEC:-240}"

exec docker compose "${compose_args[@]}" --profile build exec -T \
  -e EPF_SOURCE="/workspace/project/$epf_rel" \
  -e EPF_ROUNDTRIP_DIR="/workspace/project/$roundtrip_rel" \
  -e IB_CONNECTION="$ib_connection" \
  -e DB_USER="$db_user" \
  -e DB_PWD="$db_pwd" \
  -e V8_VERSION="$v8version" \
  -e EPF_ROUNDTRIP_TIMEOUT_SEC="$timeout_sec" \
  1c-dev bash -lc '
set -euo pipefail

in_dir="$EPF_ROUNDTRIP_DIR/in"
src_dir="$EPF_ROUNDTRIP_DIR/src"
out_dir="$EPF_ROUNDTRIP_DIR/out"
status_file="$EPF_ROUNDTRIP_DIR/status.txt"
log_file="$EPF_ROUNDTRIP_DIR/roundtrip.log"

rm -rf "$in_dir" "$src_dir" "$out_dir"
mkdir -p "$in_dir" "$src_dir" "$out_dir"
cp "$EPF_SOURCE" "$in_dir/"

epf_name="$(basename "$EPF_SOURCE")"
cache_key="pai-epf-roundtrip-$(date +%s)-$$"
db_args=()
if [[ -n "$DB_PWD" ]]; then
  db_args+=(--db-pwd "$DB_PWD")
fi

set +e
timeout "$EPF_ROUNDTRIP_TIMEOUT_SEC" vrunner decompileepf "$in_dir" "$src_dir" \
  --ibconnection "$IB_CONNECTION" \
  --db-user "$DB_USER" \
  "${db_args[@]}" \
  --v8version "$V8_VERSION" \
  --cachekey "$cache_key" >"$log_file" 2>&1
decompile_rc=$?

if [[ "$decompile_rc" -eq 0 ]]; then
  timeout "$EPF_ROUNDTRIP_TIMEOUT_SEC" vrunner compileepf "$src_dir" "$out_dir" \
    --ibconnection "$IB_CONNECTION" \
    --db-user "$DB_USER" \
    "${db_args[@]}" \
    --v8version "$V8_VERSION" \
    --cachekey "$cache_key" >>"$log_file" 2>&1
  compile_rc=$?
else
  compile_rc=127
fi
set -e

if [[ "$decompile_rc" -eq 0 && "$compile_rc" -eq 0 && -s "$out_dir/$epf_name" ]]; then
  printf "pass\n" >"$status_file"
  printf "EPF round-trip PASS: %s\n" "$EPF_ROUNDTRIP_DIR"
  exit 0
fi

printf "failed:decompile=%s compile=%s\n" "$decompile_rc" "$compile_rc" >"$status_file"
printf "EPF round-trip FAILED: %s\n" "$EPF_ROUNDTRIP_DIR" >&2
tail -n 80 "$log_file" >&2 || true
exit 1
'
