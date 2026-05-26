# Bootstrap

Bootstrap выполняется внутри уже запущенного Portable Agent Infrastructure
контейнера с mounted project. Он не управляет Docker lifecycle и не заменяет
README: здесь только команды для подготовки project-local agent/OACS контекста.

Для первого запуска без проекта используйте `onec-agent quickstart` из
README. `onec-agent bootstrap` нужен позже, когда конкретный 1С-проект
смонтирован в `/workspace/project`.

## Project Bootstrap

```bash
docker pull ghcr.io/mussolene/1c-developer:8.5.1.1343
mkdir -p .onec-runtime/data .onec-runtime/cache

docker run -d \
  --name 1c-dev \
  --platform linux/amd64 \
  -p 127.0.0.1:5900:5900 \
  -v onec-license-store:/var/1C/licenses \
  -v "$PWD":/workspace/project \
  -v "$PWD/.onec-runtime/data":/mnt/data \
  -v "$PWD/.onec-runtime/cache":/home/usr1cv8/.1cv8/1C/1cv8 \
  -e ONEC_RUNTIME_MODE=shell \
  -e ONEC_PROJECT_ROOT=/workspace/project \
  ghcr.io/mussolene/1c-developer:8.5.1.1343

docker exec -it 1c-dev onec-agent bootstrap
```

Лицензия не нужна для bootstrap, OACS memory, MCP config и context capsule. Для новых
локальных проектов OACS может создать `local_unlocked` key material без
passphrase. Для существующих passphrase-wrapped хранилищ передайте
`OACS_PASSPHRASE` или `ONEC_OACS_PASSPHRASE`, но не коммитьте их и не
печатайте в отчётах. Лицензия нужна только для запуска 1С runtime.

Для запуска 1С runtime после bootstrap есть два поддержанных пути:

- локальная ручная активация через `onec-license-store`;
- сетевой HASP через `nethasp.ini`.

Для сетевого HASP монтируйте `nethasp.ini` read-only в
`/opt/1cv8/conf/nethasp.ini:ro`; пример есть в README. Если используете helper
commands, задайте `NETHASP_INI_PATH` в ignored `.env` или shell. На старте
контейнер включает `UseHwLicenses=1` и синхронизирует mounted файл в
runtime-профили `root` и `usr1cv8`, поэтому сетевой HASP доступен и для VNC, и
для `vrunner`/`ibcmd` команд через `docker exec`.

## What Bootstrap Does

`onec-agent bootstrap` does not pull images, create containers, stop containers,
or publish ports. It only prepares the mounted project:

- initializes project-local OACS state under `.agent/oacs/`;
- writes `.agent/mcp/onec-context-mcp.json` for the external `1c_hbk_helper` / `onec-context-mcp` endpoint;
- builds `.agent/context-capsules/bootstrap-context-capsule.json` with a compact PAI `orientation_prompt`;
- writes `.agent/bootstrap-report.md`;
- writes `.agent/instructions/pai-agent-instructions.md`;
- writes `.agent/instructions/oacs-memory-call-loop.md`;
- writes `.agent/AGENTS.md` only when it does not already exist;
- writes `.agent/reports/onec-agent-doctor.txt`;
- writes `.agent/reports/oacs-bootstrap-context.json`;
- writes `.agent/context-capsules/cross-repo-findings-capsule.public.json`;
- writes `.agent/reports/cross-repo-findings-memories.public.json`;
- records references to the external MCP URL, registry, skills, and the agent orientation prompt.

Platform help, standards, snippets, and metadata lookup are provided by the
external MCP service. The image does not embed or build local context packs.

## Agent Loop

After bootstrap, agents use the same running container:

```bash
docker exec -it 1c-dev acs memory query --query "<task intent>" --scope project --json
docker exec -it 1c-dev acs context build --intent "<task intent>" --scope project --json
docker exec -it 1c-dev onec-agent context-mcp-config
docker exec -it 1c-dev acs run --label "<check label>" --scope project --json -- <check command>
docker exec -it 1c-dev acs resume --scope project --json
```

Run `acs context build` directly after querying project memory for substantial
repository work. Do not replace context build with a local heuristic.

`acs run` is the preferred path for command evidence. Use `acs tool
ingest-result` only for results that were produced outside the CLI. Persist only
verified reusable conclusions with direct `acs memory propose/commit/sharpen`.
Do not recreate the container for normal agent work. Keep it in `shell` runtime
and run 1C-dependent commands through `docker exec`, Compose transport commands,
or IDE tooling.
