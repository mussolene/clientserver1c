#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

compose=(docker compose --profile build)
service_name="${ONEC_DEV_SERVICE:-1c-dev}"
workspace_host="${WORKSPACE_HOST_PATH:-$repo_root/volumes/1c-dev/data/workspace}"
workspace_container="${WORKSPACE_CONTAINER_PATH:-/mnt/data/workspace}"
feature_src="${FEATURE_TEMPLATE_PATH:-$repo_root/artifacts/tests/ui/smoke/manager-bootstrap.feature}"
config_src="${VAPARAMS_TEMPLATE_PATH:-$repo_root/artifacts/config/va-file-db-smoke.json}"
feature_dst_rel="${FEATURE_DEST_REL:-tests/ui/smoke/open-test-client.feature}"
config_dst_rel="${VAPARAMS_DEST_REL:-config/va-file-db-smoke.json}"
artifacts_dir_rel="${ARTIFACTS_DIR_REL:-artifacts}"
ib_connection="${IB_CONNECTION:-/F/mnt/data/testdb}"
db_user="${DB_USER:-Администратор}"
db_pwd="${DB_PWD:-}"
v8version="${V8_VERSION:-${PLATFORM_VERSION:-8.5.1.1302}}"
skip_recreate="${ONEC_SKIP_RECREATE:-0}"

mkdir -p \
  "$workspace_host/$(dirname "$feature_dst_rel")" \
  "$workspace_host/$(dirname "$config_dst_rel")" \
  "$workspace_host/$artifacts_dir_rel/screenshots" \
  "$workspace_host/$artifacts_dir_rel/allure" \
  "$workspace_host/$artifacts_dir_rel/cucumber"

cp "$feature_src" "$workspace_host/$feature_dst_rel"
cp "$config_src" "$workspace_host/$config_dst_rel"
rm -f \
  "$workspace_host/$artifacts_dir_rel/ui-smoke.log" \
  "$workspace_host/$artifacts_dir_rel/ui-smoke-status.txt"

if [[ "$skip_recreate" != "1" ]]; then
  env ONEC_RUNTIME_MODE=shell "${compose[@]}" up -d --no-build --force-recreate "$service_name" >/dev/null
fi

cleanup_windows() {
  local titles=(
    "Рекомендуется обновить версию конфигурации"
    "Обновление версии программы"
    "Информация - "
  )
  local deadline=$((SECONDS + 90))

  while (( SECONDS < deadline )); do
    for title in "${titles[@]}"; do
      "${compose[@]}" exec -T "$service_name" sh -lc \
        "if command -v xdotool >/dev/null 2>&1; then \
           DISPLAY=:0 xdotool search --name '$title' windowactivate --sync key --clearmodifiers Alt+F4 2>/dev/null || true; \
         else \
           ids=\$(DISPLAY=:0 xwininfo -root -tree 2>/dev/null | awk '/$title/ {print \$1}'); \
           for id in \$ids; do DISPLAY=:0 xkill -id \"\$id\" >/dev/null 2>&1 || true; done; \
         fi" \
        >/dev/null 2>&1 || true
    done
    sleep 1
  done
}

cleanup_windows &
cleanup_pid=$!
trap 'kill "$cleanup_pid" >/dev/null 2>&1 || true; wait "$cleanup_pid" >/dev/null 2>&1 || true' EXIT

"${compose[@]}" exec -T "$service_name" sh -lc "
  mkdir -p '$workspace_container/$artifacts_dir_rel/screenshots' '$workspace_container/$artifacts_dir_rel/allure' '$workspace_container/$artifacts_dir_rel/cucumber' &&
  cd '$workspace_container' &&
  vrunner vanessa \
    --ibconnection '$ib_connection' \
    --db-user '$db_user' \
    $(if [[ -n "$db_pwd" ]]; then printf -- "--db-pwd '%s' " "$db_pwd"; fi) \
    --workspace '$workspace_container' \
    --vanessasettings '$workspace_container/$config_dst_rel' \
    --path '$workspace_container/$feature_dst_rel' \
    --v8version '$v8version' \
    --additional '/DisableUnsafeActionProtection /DisplayAllFunctions'
"

kill "$cleanup_pid" >/dev/null 2>&1 || true
wait "$cleanup_pid" >/dev/null 2>&1 || true
trap - EXIT

if [[ -f "$workspace_host/$artifacts_dir_rel/ui-smoke-status.txt" ]]; then
  cat "$workspace_host/$artifacts_dir_rel/ui-smoke-status.txt"
else
  printf 'status file was not created\n' >&2
  exit 1
fi
