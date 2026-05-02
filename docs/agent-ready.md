# Работа IDE-агента

IDE-агент остаётся на host в Cursor, Codex, VS Code или другом редакторе. Проект тоже остаётся на host. Контейнер `1c-dev` даёт 1С runtime, инструменты тестирования, BSL-диагностику и закреплённый слой 1C skills.

## Модель работы

```text
IDE-агент на host
  редактирует файлы в открытом проекте
  вызывает container-side onec-agent CLI или helper-команды из clientserver1c

контейнер 1c-dev
  видит тот же проект как /workspace/project
  запускает 1С, OneScript, Vanessa, BSLLS, OACS helpers и skill-guided проверки через onec-agent
```

Главный интерфейс Portable Agent Infrastructure находится внутри image:

```bash
onec-agent doctor
onec-agent registry
onec-agent skill context
onec-agent bslls src/cf
onec-agent context --task "json_writer_question" --query "ЗаписьJSON" --pack platform
onec-agent context-mcp-config
```

Host-side `make agent-*` targets остаются удобными wrappers для запуска этих команд через Docker Compose, но они не являются основной частью Portable Agent Infrastructure runtime.

## Запуск

Из репозитория 1С-проекта:

```bash
make -C /path/to/clientserver1c agent-up PROJECT_PATH="$PWD"
make -C /path/to/clientserver1c agent-doctor PROJECT_PATH="$PWD"
```

Если helper-репозиторий не нужен, можно использовать скачанный image напрямую:

```bash
docker run --rm -it \
  -v "$PWD":/workspace/project \
  -e ONEC_PROJECT_ROOT=/workspace/project \
  ghcr.io/mussolene/1c-developer:<PLATFORM_VERSION> \
  onec-agent doctor
```

## Прочитать skills

```bash
make -C /path/to/clientserver1c agent-skills PROJECT_PATH="$PWD"
make -C /path/to/clientserver1c agent-skill PROJECT_PATH="$PWD" NAME=context
make -C /path/to/clientserver1c agent-skill PROJECT_PATH="$PWD" NAME=testing
make -C /path/to/clientserver1c agent-skill PROJECT_PATH="$PWD" NAME=memory
```

Используйте `context` перед изменением метаданных или BSL, когда нужны точные факты. Используйте `testing` для Vanessa/xUnit/UI проверок. Используйте `memory` для OACS project memory, task context capsule и evidence refs.

## Выполнить команду в контейнере

```bash
make -C /path/to/clientserver1c agent-exec PROJECT_PATH="$PWD" CMD="oscript --version"
```

## BSL-диагностика и форматирование

```bash
make -C /path/to/clientserver1c agent-bslls PROJECT_PATH="$PWD" SRC_DIR=src/cf
make -C /path/to/clientserver1c agent-bslls-format PROJECT_PATH="$PWD" SRC_DIR=src/cf
```

Эквивалент внутри Portable Agent Infrastructure container:

```bash
onec-agent bslls src/cf
onec-agent bslls-format src/cf
```

`agent-bslls-format` меняет файлы проекта. После запуска агент должен показать diff.

## OACS memory/context слой

OACS входит в Portable Agent Infrastructure image как обязательный слой.

```bash
make -C /path/to/clientserver1c agent-up PROJECT_PATH="$PWD"
```

OACS state хранится в смонтированном проекте:

```text
.agent/oacs/oacs.db
```

Для локального dev wrapper использует default passphrase `clientserver1c-local-oacs`, если не задан `OACS_PASSPHRASE` или `ONEC_OACS_PASSPHRASE`. Для shared/private проектов задавайте passphrase явно через environment и не коммитьте `.agent/oacs/`.

Слой использует OACS как state/governance backend, а не как оркестратор. `onec-context` остаётся canonical retrieval engine для platform help, ITS standards и project packs. Wrapper записывает результаты lookup как OACS `tool_result` evidence и связывает их с project memory перед сборкой context capsule.

Свежий `onec-context-toolkit` также включает stdio MCP server `onec-context-mcp`. В контейнере OACS регистрирует wrapper `onec-agent-context-mcp`, чтобы default workspace указывал на предсобранную справку и standards pack. Для регистрации в OACS:

```bash
onec-agent context-mcp-config > /tmp/onec-context-mcp.json
acs mcp import /tmp/onec-context-mcp.json
```

После import OACS видит MCP tools (`onec_status`, `onec_ensure`, `onec_resolve_packs`, `onec_query_kb`, `onec_query_code`, `onec_query_config`) как governed tools. Их можно вызывать внутри контейнера через `acs tool call <tool> --execute-mcp --payload ...`.

Собрать task context:

```bash
make -C /path/to/clientserver1c agent-context PROJECT_PATH="$PWD" TASK="answer_1c_platform_question"
```

Собрать context с lookup в справке:

```bash
make -C /path/to/clientserver1c agent-context PROJECT_PATH="$PWD" TASK="json_writer_question" QUERY="ЗаписьJSON" PACK=platform LIMIT=5
```

Прочитать и записать project memory:

```bash
make -C /path/to/clientserver1c agent-memory-query PROJECT_PATH="$PWD" QUERY="json writer"
make -C /path/to/clientserver1c agent-memory-capture PROJECT_PATH="$PWD" SUMMARY="Use file-db runtime before UI smoke in this project."
```

Не сохраняйте в OACS ITS credentials, license data, platform archives, полные help packs или другие секреты.

## Пути в контейнере

- проект: `/workspace/project`
- инструкции для агента: `/opt/onec-agent/AGENTS.md`
- registry skills: `/opt/onec-agent/registry.json`
- skill repositories: `/opt/onec-skills`
- prebuilt context workspace: `/opt/onec-agent/context-workspace`

## Prebuilt context packs

Во время сборки `1c-dev` после установки платформы и клонирования skills запускается `onec-context init` для контейнерного workspace `/opt/onec-agent/context-workspace`. Он собирает platform help pack из HBK под `/opt/1cv8` для версии `PLATFORM_VERSION`; путь к pack записывается в `/opt/onec-agent/registry.json`.

Следом `onec-context init --with-standards --fetch-its-standards` из установленного `onec-context-toolkit` скачивает ITS `v8std` и собирает standards pack в тот же SQLite/FTS `.db.zst` формат. Публичный ITS `v8std` crawler работает без логина; BuildKit secrets `its_login` и `its_password` доступны контейнерной сборке, если позже понадобятся закрытые страницы.

Project-specific packs (`metadata`, `code`, `full`) строятся отдельно из смонтированного `/workspace/project`, потому что зависят от конкретной конфигурации.
OACS не заменяет эти packs: он хранит только project memory, evidence refs, audit и context capsules вокруг найденных фактов.

## Закреплённые версии

Image закрепляет версии инструментов и skills через build variables из `.env`. Не меняйте их без необходимости: так сборка остаётся повторяемой.
