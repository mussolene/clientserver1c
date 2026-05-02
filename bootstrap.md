# Bootstrap

Bootstrap больше не является host-side prompt/runbook. Runtime запускается отдельно, а подготовка agent/OACS контекста выполняется внутри уже запущенного Portable Agent Infrastructure контейнера.

## Quick Start

```bash
docker pull ghcr.io/mussolene/1c-developer:8.5.1.1302
export OACS_PASSPHRASE="<local-oacs-passphrase>"

docker run -d \
  --name 1c-dev \
  --platform linux/amd64 \
  -p 127.0.0.1:5900:5900 \
  -v onec-license-store:/var/1C/licenses \
  -v "$PWD":/workspace/project \
  -v "$PWD/.onec-runtime/data":/mnt/data \
  -v "$PWD/.onec-runtime/cache":/root/.1cv8/1C/1cv8 \
  -e ONEC_RUNTIME_MODE=shell \
  -e ONEC_PROJECT_ROOT=/workspace/project \
  -e OACS_PASSPHRASE="$OACS_PASSPHRASE" \
  ghcr.io/mussolene/1c-developer:8.5.1.1302

docker exec -it 1c-dev onec-agent bootstrap
```

Лицензия не нужна для bootstrap, OACS memory и context capsule. Для OACS нужен только локальный `OACS_PASSPHRASE`; не коммитьте его. Лицензия нужна только для запуска 1С runtime.

Есть два поддержанных пути:

- локальная ручная активация через `onec-license-store`;
- сетевой HASP через `nethasp.ini`.

Для сетевого HASP после старта контейнера:

```bash
docker cp ./nethasp.ini 1c-dev:/opt/1cv8/conf/nethasp.ini
docker cp ./nethasp.ini 1c-dev:/home/usr1cv8/.1cv8/1C/1cv8/conf/nethasp.ini
```

## What Bootstrap Does

`onec-agent bootstrap` does not pull images, create containers, stop containers, or publish ports. It only prepares the mounted project:

- initializes project-local OACS state under `.agent/oacs/`;
- writes `.agent/mcp/onec-context-mcp.json`;
- builds `.agent/context-capsules/bootstrap-context-capsule.json`;
- writes `.agent/bootstrap-report.md`;
- writes `.agent/instructions/pai-agent-instructions.md`;
- writes `.agent/instructions/oacs-memory-call-loop.md`;
- writes `.agent/AGENTS.md` only when it does not already exist;
- writes `.agent/reports/onec-agent-doctor.txt`;
- writes `.agent/reports/oacs-bootstrap-context.json`;
- writes `.agent/reports/oacs-standards-context.json`;
- writes `.agent/reports/onec-context-metadata-ensure.log`;
- records references to platform help, standards packs, project metadata status, registry, and skills.

## Agent Loop

After bootstrap, agents should use the same running container and follow the memory/context/evidence loop:

```bash
docker exec -it 1c-dev acs memory query --query "<task intent>" --scope project --json
docker exec -it 1c-dev onec-agent context --task "<task intent>" --query "<exact 1C term>" --pack platform --limit 5
docker exec -it 1c-dev sh -lc '
candidate_json=$(acs memory propose --type procedure --depth 2 --scope project --text "<verified reusable fact>" --json)
memory_id=$(printf "%s" "$candidate_json" | python3 -c "import json,sys; print(json.load(sys.stdin)[\"id\"])")
acs memory commit "$memory_id" --json
acs memory sharpen "$memory_id" --evidence "<evidence ref>" --json
'
```

Do not recreate the container for normal agent work. Keep it in `shell` runtime and run 1C-dependent commands through `docker exec`, Compose transport commands, or IDE tooling.
