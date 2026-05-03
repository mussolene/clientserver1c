# Работа IDE-агента

IDE-агент остаётся на host в Cursor, Codex, VS Code или другом редакторе. Проект тоже остаётся на host. Контейнер `1c-dev` даёт 1С runtime, инструменты тестирования, BSL-диагностику и закреплённый слой 1C skills.

## Модель работы

```text
IDE-агент на host
  редактирует файлы в открытом проекте
  вызывает container-side onec-agent CLI или helper-команды из 1c-develop

контейнер 1c-dev
  видит тот же проект как /workspace/project
  запускает 1С, OneScript, Vanessa, BSLLS и 1C-specific проверки через onec-agent
  вызывает ACS/OACS напрямую через acs
```

Главный 1С-интерфейс Portable Agent Infrastructure находится внутри image:

```bash
onec-agent --help
```

Host-side `make agent-*` targets остаются transport-командами для Docker Compose,
но они не являются основной частью Portable Agent Infrastructure runtime.

## Bootstrap

`onec-agent bootstrap` разделяет инструкции и runtime bootstrap. Команда выполняется внутри уже запущенного container-side PAI и не управляет Docker lifecycle.

```bash
docker exec -it 1c-dev sh -lc 'test -n "$OACS_PASSPHRASE" && onec-agent bootstrap'
```

Bootstrap создает в смонтированном проекте:

- `.agent/oacs/oacs.db` - project-local OACS state.
- `.agent/mcp/onec-context-mcp.json` - MCP config для context tools.
- `.agent/context-capsules/bootstrap-context-capsule.json` - минимальный capsule со ссылками на help, BSL developer guide, standards packs, metadata scan, registry и skills.
- `.agent/bootstrap-report.md` - короткий отчет и следующий шаг для агента.
- `.agent/instructions/pai-agent-instructions.md` - инструкции для IDE-агента.
- `.agent/instructions/oacs-memory-call-loop.md` - обязательный memory/context/evidence loop.
- `.agent/context-capsules/cross-repo-findings-capsule.public.json` - OACS-compatible ContextCapsule для обезличенных изысканий по контейнерному и тестовому workspace.
- `.agent/reports/cross-repo-findings-memories.public.json` - OACS MemoryRecord seed records, на которые ссылается cross-repo capsule.
- `.agent/reports/onec-agent-doctor.txt` - снимок readiness-check.
- `.agent/reports/oacs-bootstrap-context.json` - bootstrap context capsule.
- `.agent/reports/oacs-standards-context.json` - standards context capsule.
- `.agent/reports/oacs-bsl-dev-context.json` - developer guide context capsule.
- `.agent/reports/onec-context-metadata-ensure.log` - результат подготовки metadata pack.

Если `.agent/AGENTS.md` еще нет, bootstrap создаст IDE entrypoint. Если файл уже существует, bootstrap его не перезаписывает.

После bootstrap агент должен начинать каждую нетривиальную задачу с прямого
`acs memory query` и `acs context build`. Затем он делает точечные
`onec-agent context` lookup для 1С-фактов и сохраняет в memory только
проверенные выводы через `acs memory propose`, `acs memory commit` и
`acs memory sharpen`.

ACS используется напрямую. `onec-agent` не является оберткой над ACS: он
добавляет 1С context retrieval, diagnostics, skills и runtime checks.

## Запуск Runtime

Из репозитория 1С-проекта:

```bash
make -C /path/to/1c-develop agent-up PROJECT_PATH="$PWD"
make -C /path/to/1c-develop agent-doctor PROJECT_PATH="$PWD"
```

Без helper-репозитория держите контейнер в `shell` runtime и выполняйте команды через `docker exec`:

```bash
docker exec -it 1c-dev onec-agent doctor
docker exec -it 1c-dev acs memory query --query "task" --scope project --json
docker exec -it 1c-dev acs context build --intent "task" --scope project --json
docker exec -it 1c-dev onec-agent context --task "task" --query "ЗаписьJSON" --pack platform --limit 5
docker exec -it 1c-dev onec-agent context --task "task" --query "Фоновые задания" --pack bsl-dev --limit 5
docker exec -it 1c-dev acs run --label "bslls_check" --scope project --json -- onec-agent bslls src/cf
docker exec -it 1c-dev acs resume --scope project --json
```

## Прочитать skills

```bash
make -C /path/to/1c-develop agent-skills PROJECT_PATH="$PWD"
make -C /path/to/1c-develop agent-skill PROJECT_PATH="$PWD" NAME=context
make -C /path/to/1c-develop agent-skill PROJECT_PATH="$PWD" NAME=testing
make -C /path/to/1c-develop agent-skill PROJECT_PATH="$PWD" NAME=memory
```

Используйте `context` перед изменением метаданных или BSL, когда нужны точные факты. Используйте `testing` для Vanessa/xUnit/UI проверок. Используйте `memory` для OACS project memory, task context capsule и evidence refs.

## Выполнить команду в контейнере

```bash
make -C /path/to/1c-develop agent-exec PROJECT_PATH="$PWD" CMD="oscript --version"
```

## BSL-диагностика и форматирование

```bash
make -C /path/to/1c-develop agent-bslls PROJECT_PATH="$PWD" SRC_DIR=src/cf
make -C /path/to/1c-develop agent-bslls-format PROJECT_PATH="$PWD" SRC_DIR=src/cf
```

Эквивалент внутри Portable Agent Infrastructure container:

```bash
onec-agent bslls src/cf
onec-agent bslls-format src/cf
```

`agent-bslls` пишет полный JSON в `.agent/bslls/bsl-json.json` и печатает короткую сводку. Если нужен полный console reporter, передайте `REPORTERS=json,console`.
`agent-bslls-format` меняет файлы проекта. После запуска агент должен показать diff.

## OACS Memory/Context

OACS входит в Portable Agent Infrastructure image как обязательный слой.

State хранится в смонтированном проекте: `.agent/oacs/oacs.db`. Для shared/private проектов задавайте `OACS_PASSPHRASE` или `ONEC_OACS_PASSPHRASE` явно и не коммитьте `.agent/oacs/`.

OACS здесь state/governance backend, а не оркестратор. `onec-context` остаётся retrieval engine для platform help, BSL developer guide, ITS standards и project packs.

Минимальный memory call loop после bootstrap:

```bash
export OACS_DB=/workspace/project/.agent/oacs/oacs.db
acs memory query --query "<task intent>" --scope project --json
acs context build --intent "<task intent>" --scope project --json
onec-agent context --task "<task intent>" --query "<точный термин 1С>" --pack platform --limit 5
acs run --label "<check label>" --scope project --json -- <check command>
acs resume --scope project --json
```

Для команд используйте `acs run`: он выполняет команду и сохраняет `tool_result`
evidence. `acs resume` показывает последние command evidence, checkpoints,
memory и context capsules после сжатия контекста или возврата к задаче.
`acs tool ingest-result` оставляйте для результатов, полученных вне CLI.
Durable memory пишите через `acs memory propose/commit/sharpen` только после
проверки факта. Не сохраняйте в OACS ITS credentials, license data, platform
archives, полные help packs или другие секреты.

## Advanced OACS Tools

MCP import внутри контейнера нужен только когда агент умеет вызывать governed
MCP tools через ACS. Для первого запуска достаточно прямых `acs` команд и
точечных `onec-agent context` lookup.

```bash
onec-agent context-mcp-config > /tmp/onec-context-mcp.json
acs mcp import /tmp/onec-context-mcp.json
```

После import OACS видит `onec_status`, `onec_ensure`, `onec_resolve_packs`,
`onec_query_kb`, `onec_query_code`, `onec_query_config` как governed tools.

`make agent-context` является transport-helper поверх `docker exec`, а не
отдельным workflow:

```bash
make -C /path/to/1c-develop agent-context PROJECT_PATH="$PWD" TASK="answer_1c_platform_question"
make -C /path/to/1c-develop agent-context PROJECT_PATH="$PWD" TASK="json_writer_question" QUERY="ЗаписьJSON" PACK=platform LIMIT=5
make -C /path/to/1c-develop agent-context PROJECT_PATH="$PWD" TASK="metadata_question" QUERY="Заявки" PACK=metadata LIMIT=5
```

Прочитать и записать project memory напрямую через ACS:

```bash
docker exec -it 1c-dev acs memory query --query "json writer" --scope project --json
docker exec -it 1c-dev acs context build --intent "json writer" --scope project --json
docker exec -it 1c-dev sh -lc '
candidate_json=$(acs memory propose --type procedure --depth 2 --scope project --text "Use file-db runtime before UI smoke in this project." --json)
memory_id=$(printf "%s" "$candidate_json" | python3 -c "import json,sys; print(json.load(sys.stdin)[\"id\"])")
acs memory commit "$memory_id" --json
'
```

Agent Workflow UX:

```bash
acs loop explain --json
acs loop run --request "<task intent>" --scope project --json
```

`acs loop run` строит memory-call oriented context/prompt. Он не заменяет
фактическую работу агента с файлами и runtime, но помогает восстановить
контекст задачи и явно увидеть, какие memory calls были выполнены.

## Пути в контейнере

- проект: `/workspace/project`
- инструкции для агента: `/opt/onec-agent/AGENTS.md`
- registry skills: `/opt/onec-agent/registry.json`
- skill repositories: `/opt/onec-skills`
- prebuilt context workspace: `/opt/onec-agent/context-workspace`

## Закреплённые версии

Image закрепляет версии инструментов и skills через build variables из `.env`. Build/runtime детали и prebuilt packs описаны в [runtime-details.md](runtime-details.md).
