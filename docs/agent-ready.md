# Работа IDE-агента

IDE-агент остаётся на host в Cursor, Codex, VS Code или другом редакторе. Проект тоже остаётся на host. Контейнер `1c-dev` даёт 1С runtime, инструменты тестирования, BSL-диагностику и закреплённый слой 1C skills.

## Модель работы

```text
IDE-агент на host
  редактирует файлы в открытом проекте
  вызывает container-side onec-agent CLI или helper-команды из 1c-develop

контейнер 1c-dev
  видит тот же проект как /workspace/project
  запускает 1С, OneScript, Vanessa, onec-hbk-bsl и 1C-specific проверки через onec-agent
  вызывает ACS/OACS напрямую через acs
```

Главный 1С-интерфейс Portable Agent Infrastructure находится внутри image:

```bash
onec-agent --help
```

Host-side `make agent-*` targets остаются transport-командами для Docker Compose,
но они не являются основной частью Portable Agent Infrastructure runtime.

Для первого запуска без mounted project используйте:

```bash
docker exec -it 1c-dev onec-agent quickstart
```

Эта команда не создаёт project-local OACS DB и не требует
`OACS_PASSPHRASE`. Она проверяет standalone runtime, регистрирует demo file DB и
оставляет пользователю рабочий VNC/1С контур. Project bootstrap ниже нужен
только после монтирования конкретного проекта в `/workspace/project`.

## Bootstrap

`onec-agent bootstrap` разделяет инструкции и runtime bootstrap. Команда выполняется внутри уже запущенного container-side PAI и не управляет Docker lifecycle.

```bash
docker exec -it 1c-dev onec-agent bootstrap
```

Bootstrap создает в смонтированном проекте:

- `.agent/oacs/oacs.db` - project-local OACS state.
- `.agent/mcp/onec-context-mcp.json` - MCP config для внешнего `1c_hbk_helper` / `onec-context-mcp`.
- `.agent/context-capsules/bootstrap-context-capsule.json` - минимальный capsule с `orientation_prompt`, MCP URL, registry и skills.
- `.agent/bootstrap-report.md` - короткий отчет и следующий шаг для агента.
- `.agent/instructions/pai-agent-instructions.md` - инструкции для IDE-агента.
- `.agent/instructions/oacs-memory-call-loop.md` - обязательный memory/context/evidence loop.
- `.agent/context-capsules/cross-repo-findings-capsule.public.json` - OACS-compatible ContextCapsule для обезличенных изысканий по контейнерному и тестовому workspace.
- `.agent/reports/cross-repo-findings-memories.public.json` - OACS MemoryRecord seed records, на которые ссылается cross-repo capsule.
- `.agent/reports/onec-agent-doctor.txt` - снимок readiness-check.
- `.agent/reports/oacs-bootstrap-context.json` - bootstrap context capsule.

Если `.agent/AGENTS.md` еще нет, bootstrap создаст IDE entrypoint. Если файл уже существует, bootstrap его не перезаписывает.

После bootstrap агент должен начинать каждую нетривиальную задачу с прямого
`acs memory query` и `acs context build`. Для 1С-фактов он использует внешний
MCP endpoint из `.agent/mcp/onec-context-mcp.json` и сохраняет в memory только
проверенные выводы через `acs memory propose`, `acs memory commit` и
`acs memory sharpen`.

ACS используется напрямую. `onec-agent` не является оберткой над ACS: он
добавляет diagnostics, skills, MCP config и runtime checks.

## Запуск Runtime

Из репозитория 1С-проекта:

```bash
make -C /path/to/1c-develop agent-up PROJECT_PATH="$PWD"
make -C /path/to/1c-develop agent-doctor PROJECT_PATH="$PWD"
```

Без helper-репозитория держите контейнер в `shell` runtime и выполняйте команды
через `docker exec`. Команды ACS ниже требуют mounted project и
`OACS_PASSPHRASE`. 1C knowledge lookup выполняется через внешний MCP service.

```bash
docker exec -it 1c-dev onec-agent doctor
docker exec -it 1c-dev acs memory query --query "task" --scope project --json
docker exec -it 1c-dev acs context build --intent "task" --scope project --json
docker exec -it 1c-dev onec-agent context-mcp-config
docker exec -it 1c-dev acs run --label "bsl_check" --scope project --json -- onec-agent bsl-check src/cf
docker exec -it 1c-dev acs resume --scope project --json
```

## Прочитать skills

```bash
make -C /path/to/1c-develop agent-skills PROJECT_PATH="$PWD"
make -C /path/to/1c-develop agent-skill PROJECT_PATH="$PWD" NAME=testing
make -C /path/to/1c-develop agent-skill PROJECT_PATH="$PWD" NAME=memory
make -C /path/to/1c-develop agent-skill PROJECT_PATH="$PWD" NAME=runtime
```

Используйте внешний MCP для точных фактов по платформе, стандартам, snippets и
metadata. Используйте `testing` для Vanessa/xUnit/UI проверок. Используйте
`memory` для OACS project memory, task context capsule и evidence refs.
Используйте `runtime` как Codex/OACS loop для компактной работы через OACS без
повторной передачи всего контекста.

## Выполнить команду в контейнере

```bash
make -C /path/to/1c-develop agent-exec PROJECT_PATH="$PWD" CMD="oscript -version"
```

## BSL-диагностика и форматирование

```bash
make -C /path/to/1c-develop agent-bsl-check PROJECT_PATH="$PWD" SRC_DIR=src/cf
make -C /path/to/1c-develop agent-bsl-format PROJECT_PATH="$PWD" SRC_DIR=src/cf
```

Эквивалент внутри Portable Agent Infrastructure container:

```bash
onec-agent bsl-check src/cf
onec-agent bsl-format src/cf
```

`agent-bsl-check` пишет JSON в `.agent/bsl/onec-hbk-bsl.json` и печатает короткую сводку. Для фильтрации правил передайте `SELECT=BSL001,BSL011` или `IGNORE=BSL012`.
`agent-bsl-format` меняет файлы проекта. После запуска агент должен показать diff.

## EPF Round-Trip

Для проверяемой обработки, которая уже лежит в mounted проекте:

```bash
make -C /path/to/1c-develop agent-epf-roundtrip PROJECT_PATH="$PWD" EPF_PATH=tests/xunit/epf/Test.epf
```

Команда выполняет `vrunner decompileepf` и `vrunner compileepf` внутри того же
контейнера, где смонтирован проект. Результат и лог остаются в
`.agent/runtime/epf-roundtrip/<имя-epf>/`. Это smoke-level проверка инструмента,
а не доказательство корректности бизнес-логики обработки.

## OACS Memory/Context

OACS входит в Portable Agent Infrastructure image как обязательный слой.

State хранится в смонтированном проекте: `.agent/oacs/oacs.db`. Новые local
stores могут использовать `local_unlocked` key material без passphrase. Для
существующих passphrase-wrapped хранилищ задавайте `OACS_PASSPHRASE` или
`ONEC_OACS_PASSPHRASE` явно. Не коммитьте `.agent/oacs/`, `.oacs`, OACS DB,
`key.json`, `unlocked.key`, passphrases и private agent state.

OACS здесь state/governance backend, а не оркестратор. `onec-context-mcp`
остаётся внешним retrieval service для platform help, standards, snippets и
metadata.

Минимальный memory call loop после bootstrap:

```bash
export OACS_DB=/workspace/project/.agent/oacs/oacs.db
acs memory query --query "<task intent>" --scope project --json
acs context build --intent "<task intent>" --scope project --json
acs run --label "<check label>" --scope project --json -- <check command>
acs resume --scope project --json
```

Для команд используйте `acs run`: он выполняет команду и сохраняет `tool_result`
evidence. `acs resume` показывает последние command evidence, checkpoints,
memory и context capsules после сжатия контекста или возврата к задаче.
`acs tool ingest-result` оставляйте для результатов, полученных вне CLI.
Запускайте `acs context build` напрямую после `acs memory query` для
substantial repository work. Не заменяйте context build локальной эвристикой.
Durable memory пишите через `acs memory propose/commit/sharpen` только после
проверки факта. Не сохраняйте в OACS ITS credentials, license data, platform
archives, полные help dumps или другие секреты.

Для лицензирования через сетевой HASP агенту можно передавать только локальный
путь `NETHASP_INI_PATH=/absolute/path/to/nethasp.ini`. Сам файл, его содержимое,
адреса/параметры лицензирования и копии из рабочих контейнеров не записывайте в
OACS memory, reports или context capsules.

## Advanced OACS Tools

MCP import внутри контейнера нужен только когда агент умеет вызывать governed
MCP tools через ACS. Для первого запуска достаточно прямых `acs` команд и
внешнего MCP endpoint.

```bash
onec-agent context-mcp-config > /tmp/onec-context-mcp.json
acs mcp import /tmp/onec-context-mcp.json
```

После import OACS видит tools внешнего `onec-context-mcp` как governed tools.

`make agent-context` является transport-helper поверх `docker exec`, а не
отдельным workflow:

```bash
make -C /path/to/1c-develop agent-context PROJECT_PATH="$PWD" TASK="oacs_context_question"
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
- local agent skills: `/opt/onec-agent/skills`

## Закреплённые версии

Image закрепляет версии инструментов и skills через build variables из `.env`. Build/runtime детали и MCP-контракт описаны в [runtime-details.md](runtime-details.md).
