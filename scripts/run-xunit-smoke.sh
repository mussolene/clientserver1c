#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

compose=(docker compose --profile build)
service_name="${ONEC_DEV_SERVICE:-1c-dev}"
workspace_host="${WORKSPACE_HOST_PATH:-$repo_root/volumes/1c-dev/data/workspace}"
workspace_container="${WORKSPACE_CONTAINER_PATH:-/mnt/data/workspace}"
xunit_path_glob="${XUNIT_PATH_GLOB:-$workspace_container/tests/xunit/epf/*.epf}"
artifacts_dir_rel="${ARTIFACTS_DIR_REL:-artifacts}"
ib_connection="${IB_CONNECTION:-/F/mnt/data/testdb}"
db_user="${DB_USER:-Администратор}"
db_pwd="${DB_PWD:-}"
v8version="${V8_VERSION:-${PLATFORM_VERSION:-8.5.1.1302}}"
xunit_timeout_sec="${XUNIT_TIMEOUT_SEC:-240}"
xunit_runner="${XUNIT_RUNNER:-/opt/onescript/lib/add/xddTestRunner.epf}"
xunit_config="${XUNIT_CONFIG:-/opt/onescript/lib/add/tools/json/xUnitParams.json}"
skip_recreate="${ONEC_SKIP_RECREATE:-0}"

mkdir -p "$workspace_host/$artifacts_dir_rel/xunit"
rm -f "$workspace_host/$artifacts_dir_rel/xunit/status.txt"

if [[ "$skip_recreate" != "1" ]]; then
  env ONEC_RUNTIME_MODE=shell "${compose[@]}" up -d --no-build --force-recreate "$service_name" >/dev/null
fi

set +e
"${compose[@]}" exec -T "$service_name" sh -lc "
  mkdir -p '$workspace_container/$artifacts_dir_rel/xunit' &&
  cd '$workspace_container' &&
  timeout '$xunit_timeout_sec' vrunner xunit '$xunit_path_glob' \
    --ibconnection '$ib_connection' \
    --db-user '$db_user' \
    $(if [[ -n "$db_pwd" ]]; then printf -- "--db-pwd '%s' " "$db_pwd"; fi) \
    --pathxunit '$xunit_runner' \
    --reportsxunit 'ГенераторОтчетаJUnitXML{$workspace_container/$artifacts_dir_rel/xunit/junit.xml}' \
    --xddExitCodePath '$workspace_container/$artifacts_dir_rel/xunit/status.txt' \
    --xddConfig '$xunit_config' \
    --v8version '$v8version'
"
run_rc=$?
set -e

if [[ "$run_rc" -ne 0 ]]; then
  "${compose[@]}" exec -T "$service_name" sh -lc \
    "pkill -f '1cv8c.*(xddTestRunner|TESTCLIENT|TESTMANAGER)' >/dev/null 2>&1 || true"
  "${compose[@]}" exec -T "$service_name" sh -lc \
    "ps -ef | rg -i 'vrunner|1cv8|TestClient|xddTestRunner' || true" \
    > "$workspace_host/$artifacts_dir_rel/xunit/processes.txt" 2>&1 || true
fi

if [[ ! -f "$workspace_host/$artifacts_dir_rel/xunit/status.txt" ]]; then
  printf '%s\n' "$run_rc" > "$workspace_host/$artifacts_dir_rel/xunit/status.txt"
fi
cat "$workspace_host/$artifacts_dir_rel/xunit/status.txt"
exit "$run_rc"
