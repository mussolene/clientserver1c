# Agent Prompt: Bootstrap 1C Runtime Fast

Скопируй этот промпт агенту целиком. Это не runbook для человека: агент должен сам создать файл `run-bootstrap.sh`, запустить его, собрать артефакты и вернуть короткий отчет.

````text
Ты DevOps/QA инженер по 1С. Твоя задача — максимально быстро получить первый проверяемый smoke/BDD результат в автономной Docker-среде 1С.

Цель TTM:
- Сначала доведи до первого meaningful результата, потом улучшай детали.
- Создай один файл `run-bootstrap.sh` в изолированной папке `ONEC_BOOTSTRAP_HOME` и запусти его.
- Не создавай runtime-файлы в текущем проекте пользователя.
- Если не хватает `DT_PATH`, спроси только абсолютный путь к DT и продолжай.

Параметры, которые можно переопределять через env:
- `ONEC_BOOTSTRAP_HOME`, default: `$HOME/onec-bootstrap-runtime`
- `IMAGE`, default: `ghcr.io/mussolene/1c-developer:8.5.1.1302`
- `CONTAINER`, default: `onec-runtime`
- `PLATFORM`, default: `linux/amd64`
- `PROJECT_DIR`, default: `$ONEC_BOOTSTRAP_HOME/project`
- `LICENSE_SERVER_ADDR`, default: `192.168.0.0`
- `LICENSE_PORT`, default: `475`
- `OACS_PASSPHRASE`, default: `clientserver1c-bootstrap-oacs`
- `DT_PATH`, required for restore/smoke
- `VANESSA_ADD_PATH`, default: `/opt/onescript/lib/add/bddRunner.epf`
- `ONLY_STEP`, optional: `setup`, `restore`, `agent`, `smoke`, `report`

Правила надежности:
- Не скрывай ошибки через `|| true` в статусных шагах.
- На любой ошибке выведи: шаг, точную команду повтора, путь к логам/артефактам.
- Контейнер должен работать как Portable Agent Infrastructure сам по себе: обязательно смонтируй `PROJECT_DIR` в `/workspace/project` и все agent/OACS проверки выполняй внутри контейнера через `onec-agent` и `acs`.
- RestoreIB считай успешным только если команда завершилась успешно, лог скопирован на хост, каталог `/mnt/data/testdb` непустой, а лог не содержит явных маркеров ошибок.
- Проверку agent layer считай успешной только если есть `onec-agent`, `onec-agent-skill`, `acs`, `onec-agent-context-mcp`, `/opt/onec-agent/registry.json` и ожидаемые `SKILL.md`.
- Smoke запускай только после проверки восстановленной базы, `vrunner` и `VANESSA_ADD_PATH`.
- Финальный отчет должен содержать статус контейнера, лицензии, RestoreIB, agent/OACS, smoke и пути к артефактам.

Ожидаемые skills:
- `onec-vanessa-skill`: `/opt/onec-skills/onec-vanessa-skill/skill/core/SKILL.md`
- `onec-context-toolkit`: `/opt/onec-skills/onec-context-toolkit/skill/SKILL.md`
- `onec-agent-memory`: `/opt/onec-agent/skills/memory/SKILL.md`

Выполни:
1. Создай `$ONEC_BOOTSTRAP_HOME`.
2. Запиши туда `run-bootstrap.sh` с содержимым ниже.
3. Сделай `chmod +x run-bootstrap.sh`.
4. Запусти:
   - если `DT_PATH` уже известен: `DT_PATH="/absolute/path/to/base.dt" ./run-bootstrap.sh`
   - если `DT_PATH` неизвестен: спроси путь и запусти с ним.
5. Если упал отдельный шаг, после исправления перезапусти только его через `ONLY_STEP=<step> ./run-bootstrap.sh`.
6. Верни краткий отчет и путь к `$ONEC_BOOTSTRAP_HOME/report.md`.

Содержимое `run-bootstrap.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/mussolene/1c-developer:8.5.1.1302}"
CONTAINER="${CONTAINER:-onec-runtime}"
PLATFORM="${PLATFORM:-linux/amd64}"
ONEC_BOOTSTRAP_HOME="${ONEC_BOOTSTRAP_HOME:-$HOME/onec-bootstrap-runtime}"
PROJECT_DIR="${PROJECT_DIR:-$ONEC_BOOTSTRAP_HOME/project}"
LICENSE_SERVER_ADDR="${LICENSE_SERVER_ADDR:-192.168.0.0}"
LICENSE_PORT="${LICENSE_PORT:-475}"
OACS_PASSPHRASE="${OACS_PASSPHRASE:-clientserver1c-bootstrap-oacs}"
DT_PATH="${DT_PATH:-}"
VANESSA_ADD_PATH="${VANESSA_ADD_PATH:-/opt/onescript/lib/add/bddRunner.epf}"
ONLY_STEP="${ONLY_STEP:-all}"

mkdir -p "$ONEC_BOOTSTRAP_HOME" "$PROJECT_DIR"
ONEC_BOOTSTRAP_HOME="$(cd "$ONEC_BOOTSTRAP_HOME" && pwd)"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

RUNTIME_DIR="$ONEC_BOOTSTRAP_HOME/runtime"
LOG_DIR="$ONEC_BOOTSTRAP_HOME/logs"
ART_DIR="$ONEC_BOOTSTRAP_HOME/artifacts"
REPORT="$ONEC_BOOTSTRAP_HOME/report.md"
RESTORE_LOG="$LOG_DIR/restore-ib.log"

mkdir -p "$RUNTIME_DIR/data" "$RUNTIME_DIR/cache" "$PROJECT_DIR" "$LOG_DIR" "$ART_DIR/agent" "$ART_DIR/smoke"

current_step="init"
fail() {
  echo "ERROR[$current_step]: $*" >&2
  echo "Re-run all: cd \"$ONEC_BOOTSTRAP_HOME\" && DT_PATH=\"/absolute/path/to/base.dt\" ./run-bootstrap.sh" >&2
  echo "Re-run step: cd \"$ONEC_BOOTSTRAP_HOME\" && ONLY_STEP=\"$current_step\" DT_PATH=\"/absolute/path/to/base.dt\" ./run-bootstrap.sh" >&2
  echo "Logs: $LOG_DIR" >&2
  echo "Artifacts: $ART_DIR" >&2
  exit 1
}

want_step() {
  [ "$ONLY_STEP" = "all" ] || [ "$ONLY_STEP" = "$1" ]
}

require_container() {
  docker ps --format '{{.Names}}' | grep -Fxq "$CONTAINER" || fail "container is not running: $CONTAINER"
}

container_sh() {
  docker exec "$CONTAINER" sh -lc "$1"
}

container_agent() {
  docker exec \
    -e ONEC_PROJECT_ROOT=/workspace/project \
    -e ONEC_AGENT_REGISTRY=/opt/onec-agent/registry.json \
    -e OACS_PASSPHRASE="$OACS_PASSPHRASE" \
    "$CONTAINER" \
    onec-agent "$@"
}

wait_for_agent() {
  current_step="setup"
  local attempt=0
  until container_agent doctor >/dev/null 2>"$LOG_DIR/onec-agent-doctor-wait.err"; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 30 ]; then
      sed -n '1,160p' "$LOG_DIR/onec-agent-doctor-wait.err" >&2 || true
      fail "container did not become agent-ready"
    fi
    sleep 1
  done
}

setup_runtime() {
  current_step="setup"
  command -v docker >/dev/null 2>&1 || fail "docker is not installed or not in PATH"
  docker info >/dev/null 2>&1 || fail "docker daemon is not available"

  cat > "$ONEC_BOOTSTRAP_HOME/nethasp.ini" <<EOF_NETHASP
[NH_COMMON]
NH_TCPIP = Enabled

[NH_TCPIP]
NH_SERVER_ADDR = ${LICENSE_SERVER_ADDR}
NH_PORT_NUMBER = ${LICENSE_PORT}
NH_TCPIP_METHOD = UDP
NH_USE_BROADCAST = Disabled
EOF_NETHASP

  docker volume inspect onec-license-store >/dev/null 2>&1 || docker volume create onec-license-store >/dev/null

  if docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER"; then
    docker rm -f "$CONTAINER" >/dev/null
  fi

  docker pull --platform "$PLATFORM" "$IMAGE" 2>&1 | tee "$LOG_DIR/docker-pull.log"
  docker run -d \
    --name "$CONTAINER" \
    --platform "$PLATFORM" \
    -p 127.0.0.1:5900:5900 \
    -e ONEC_RUNTIME_MODE=shell \
    -e ONEC_PROJECT_ROOT=/workspace/project \
    -e ONEC_AGENT_REGISTRY=/opt/onec-agent/registry.json \
    -e OACS_PASSPHRASE="$OACS_PASSPHRASE" \
    -e ONEC_FILE_DB_PATH=/mnt/data/testdb \
    -e ONEC_DISABLE_UNSAFE_ACTION_PROTECTION='.*' \
    -v onec-license-store:/var/1C/licenses \
    -v "$PROJECT_DIR:/workspace/project" \
    -v "$RUNTIME_DIR/data:/mnt/data" \
    -v "$RUNTIME_DIR/cache:/root/.1cv8/1C/1cv8" \
    "$IMAGE" >/dev/null

  wait_for_agent

  container_sh 'mkdir -p /opt/1cv8/conf /home/usr1cv8/.1cv8/1C/1cv8/conf /workspace/project/.agent/oacs'
  docker cp "$ONEC_BOOTSTRAP_HOME/nethasp.ini" "$CONTAINER:/opt/1cv8/conf/nethasp.ini"
  docker cp "$ONEC_BOOTSTRAP_HOME/nethasp.ini" "$CONTAINER:/home/usr1cv8/.1cv8/1C/1cv8/conf/nethasp.ini"
  container_sh 'test -s /opt/1cv8/conf/nethasp.ini && test -s /home/usr1cv8/.1cv8/1C/1cv8/conf/nethasp.ini'
}

restore_db() {
  current_step="restore"
  require_container
  [ -n "$DT_PATH" ] || fail "DT_PATH is required"
  [ -f "$DT_PATH" ] || fail "DT file not found: $DT_PATH"

  docker cp "$DT_PATH" "$CONTAINER:/tmp/input.dt"
  container_sh '
    set -eu
    rm -rf /mnt/data/testdb
    mkdir -p /mnt/data/testdb
    /opt/1cv8/current/1cv8 DESIGNER \
      /F /mnt/data/testdb \
      /RestoreIB /tmp/input.dt \
      /DisableStartupDialogs \
      /DisableStartupMessages \
      /Out /tmp/restore-ib.log
    test -s /tmp/restore-ib.log
    test -d /mnt/data/testdb
    find /mnt/data/testdb -mindepth 1 -maxdepth 2 | head -n 1 | grep -q .
  ' || fail "RestoreIB command failed"

  docker cp "$CONTAINER:/tmp/restore-ib.log" "$RESTORE_LOG"
  if grep -Eiq 'ошиб|error|failed|exception|critical' "$RESTORE_LOG"; then
    sed -n '1,220p' "$RESTORE_LOG" >&2
    fail "restore log contains error markers"
  fi
}

inspect_agent_layer() {
  current_step="agent"
  require_container
  container_sh 'command -v onec-agent >/dev/null' || fail "onec-agent is missing"
  container_sh 'command -v onec-agent-skill >/dev/null' || fail "onec-agent-skill is missing"
  container_sh 'command -v acs >/dev/null' || fail "OACS acs CLI is missing"
  container_sh 'command -v onec-agent-context-mcp >/dev/null' || fail "onec-agent-context-mcp is missing"
  container_sh 'test -s /opt/onec-agent/registry.json' || fail "registry.json is missing"

  container_agent doctor | tee "$ART_DIR/agent/onec-agent-doctor.txt"
  container_agent registry | tee "$ART_DIR/agent/registry.json" >/dev/null
  container_agent skills | tee "$ART_DIR/agent/onec-agent-skill-list.txt"
  container_agent skill context > "$ART_DIR/agent/skill-context.md"
  container_agent skill testing > "$ART_DIR/agent/skill-testing.md"
  container_agent skill memory > "$ART_DIR/agent/skill-memory.md"
  container_agent context-mcp-config | tee "$ART_DIR/agent/onec-context-mcp.json" >/dev/null
  container_agent context --task "bootstrap_agent_check" --query "ЗаписьJSON" --pack platform --limit 1 \
    | tee "$ART_DIR/agent/onec-agent-context.json" >/dev/null

  docker exec \
    -e OACS_DB=/workspace/project/.agent/oacs/oacs.db \
    -e OACS_PASSPHRASE="$OACS_PASSPHRASE" \
    "$CONTAINER" sh -lc '
      set -eu
      onec-agent context-mcp-config > /tmp/onec-context-mcp.json
      acs mcp import /tmp/onec-context-mcp.json --json >/tmp/oacs-mcp-import.json
      acs mcp list --json >/tmp/oacs-mcp-list.json
      acs tool call onec_status --execute-mcp --payload "{\"workspace_root\":\"/opt/onec-agent/context-workspace\"}" --json >/tmp/oacs-mcp-onec-status.json
      acs context build --intent "bootstrap_agent_check" --json >/tmp/oacs-context.json
      acs audit verify --json >/tmp/oacs-audit.json
    ' || fail "OACS/MCP bootstrap check failed"

  docker cp "$CONTAINER:/tmp/oacs-mcp-import.json" "$ART_DIR/agent/oacs-mcp-import.json"
  docker cp "$CONTAINER:/tmp/oacs-mcp-list.json" "$ART_DIR/agent/oacs-mcp-list.json"
  docker cp "$CONTAINER:/tmp/oacs-mcp-onec-status.json" "$ART_DIR/agent/oacs-mcp-onec-status.json"
  docker cp "$CONTAINER:/tmp/oacs-context.json" "$ART_DIR/agent/oacs-context.json"
  docker cp "$CONTAINER:/tmp/oacs-audit.json" "$ART_DIR/agent/oacs-audit.json"

  for path in \
    /opt/onec-skills/onec-vanessa-skill/skill/core/SKILL.md \
    /opt/onec-skills/onec-context-toolkit/skill/SKILL.md \
    /opt/onec-agent/skills/memory/SKILL.md
  do
    container_sh "test -s '$path'" || fail "skill doc is missing: $path"
  done
}

run_smoke() {
  current_step="smoke"
  require_container
  container_sh 'test -d /mnt/data/testdb && find /mnt/data/testdb -mindepth 1 -maxdepth 2 | head -n 1 | grep -q .' || fail "database is not restored at /mnt/data/testdb"
  container_sh 'command -v vrunner >/dev/null' || fail "vrunner is missing in container"
  container_sh "test -s '$VANESSA_ADD_PATH'" || fail "Vanessa ADD runner is missing: $VANESSA_ADD_PATH"

  docker exec "$CONTAINER" sh -s -- "$VANESSA_ADD_PATH" <<'EOS_SMOKE'
set -eu
VANESSA_ADD_PATH="$1"
WORKDIR="/mnt/data/workspace"
ART="/mnt/data/workspace/artifacts"
mkdir -p "$WORKDIR/tests/ui/smoke" "$ART/allure" "$ART/cucumber" "$ART/screenshots"

cat > "$WORKDIR/tests/ui/smoke/open-test-client.feature" <<'EOF_FEATURE'
# language: ru
Функционал: Минимальный smoke
Сценарий: Пауза
    Когда Пауза 1
EOF_FEATURE

cat > "$WORKDIR/va.json" <<EOF_JSON
{
  "\$schema": "https://github.com/vanessa-opensource/vanessa-runner/develop/behavior-schema.json",
  "ИмяСборки": "file-db-smoke",
  "СтрокаПодключенияКБазе": "/F/mnt/data/testdb",
  "ПутьКVanessaADD": "$VANESSA_ADD_PATH",
  "КаталогПроекта": "/mnt/data/workspace",
  "КаталогФич": "/mnt/data/workspace/tests/ui/smoke",
  "ВыполнитьСценарии": true,
  "ВыгружатьСтатусВыполненияСценариевВФайл": true,
  "ПутьКФайлуДляВыгрузкиСтатусаВыполненияСценариев": "/mnt/data/workspace/artifacts/ui-smoke-status.txt"
}
EOF_JSON

vrunner vanessa \
  --ibconnection '/F/mnt/data/testdb' \
  --workspace "$WORKDIR" \
  --vanessasettings "$WORKDIR/va.json" \
  --path "$WORKDIR/tests/ui/smoke/open-test-client.feature" \
  --additional '/DisableUnsafeActionProtection /DisplayAllFunctions'
EOS_SMOKE

  docker cp "$CONTAINER:/mnt/data/workspace/artifacts/." "$ART_DIR/smoke/" || fail "failed to copy smoke artifacts"
  find "$ART_DIR/smoke" -maxdepth 3 -type f | sort | tee "$LOG_DIR/smoke-artifacts.txt"
}

write_report() {
  current_step="report"
  {
    echo "# 1C Bootstrap Report"
    echo
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    echo "## Container"
    docker ps --filter "name=$CONTAINER" --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
    echo
    echo "## Project Mount"
    echo "Host: $PROJECT_DIR"
    echo "Container: /workspace/project"
    echo "OACS DB: $PROJECT_DIR/.agent/oacs/oacs.db"
    echo
    echo "## License Files"
    container_sh 'ls -l /opt/1cv8/conf/nethasp.ini /home/usr1cv8/.1cv8/1C/1cv8/conf/nethasp.ini'
    echo
    echo "## Restore Log"
    if [ -s "$RESTORE_LOG" ]; then
      sed -n '1,80p' "$RESTORE_LOG"
    else
      echo "Restore log is not available. Run with DT_PATH and include the restore step."
    fi
    echo
    echo "## Agent/OACS Artifacts"
    find "$ART_DIR/agent" -maxdepth 2 -type f | sort
    echo
    echo "## Smoke Artifacts"
    find "$ART_DIR/smoke" -maxdepth 3 -type f | sort
    echo
    echo "## Rerun"
    echo '```bash'
    echo "cd \"$ONEC_BOOTSTRAP_HOME\""
    echo "DT_PATH=\"/absolute/path/to/base.dt\" ./run-bootstrap.sh"
    echo "ONLY_STEP=agent ./run-bootstrap.sh"
    echo "ONLY_STEP=smoke DT_PATH=\"/absolute/path/to/base.dt\" ./run-bootstrap.sh"
    echo '```'
  } | tee "$REPORT"
}

cd "$ONEC_BOOTSTRAP_HOME"
want_step setup && setup_runtime
want_step restore && restore_db
want_step agent && inspect_agent_layer
want_step smoke && run_smoke
want_step report && write_report

echo "OK: bootstrap finished. Report: $REPORT"
```

Когда закончишь, верни только:
- итоговый статус;
- путь к report.md;
- путь к логам и smoke artifacts;
- какой шаг упал и команду повтора, если статус не PASS.
````
