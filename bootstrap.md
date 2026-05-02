# Bootstrap

Bootstrap больше не является host-side prompt/runbook. Runtime запускается отдельно, а подготовка agent/OACS контекста выполняется внутри уже запущенного Portable Agent Infrastructure контейнера.

## Quick Start

```bash
docker pull ghcr.io/mussolene/1c-developer:8.5.1.1302

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
  ghcr.io/mussolene/1c-developer:8.5.1.1302

docker exec -it 1c-dev onec-agent bootstrap
```

Лицензия не нужна для bootstrap, OACS memory и context capsule. Она нужна только для запуска 1С runtime.

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
- writes `.agent/AGENTS.md`;
- writes `.agent/instructions/oacs-memory-call-loop.md`;
- records references to platform help, standards packs, project metadata status, registry, and skills.

## Agent Loop

After bootstrap, agents should use the same running container and follow the memory/context/evidence loop:

```bash
docker exec -it 1c-dev onec-agent memory-query --query "<task intent>"
docker exec -it 1c-dev onec-agent context --task "<task intent>" --query "<exact 1C term>" --pack platform --limit 5
docker exec -it 1c-dev onec-agent memory-capture --summary "<verified reusable fact>" --evidence "<evidence ref>"
```

Do not recreate the container for normal agent work. Keep it in `shell` runtime and run 1C-dependent commands through `docker exec`, compose wrappers, or IDE tooling.
