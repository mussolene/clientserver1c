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
onec-agent --help
```

Host-side `make agent-*` targets остаются удобными wrappers для запуска этих команд через Docker Compose, но они не являются основной частью Portable Agent Infrastructure runtime.

## Запуск

Из репозитория 1С-проекта:

```bash
make -C /path/to/clientserver1c agent-up PROJECT_PATH="$PWD"
make -C /path/to/clientserver1c agent-doctor PROJECT_PATH="$PWD"
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

## OACS Memory/Context

OACS входит в Portable Agent Infrastructure image как обязательный слой.

State хранится в смонтированном проекте: `.agent/oacs/oacs.db`. Для shared/private проектов задавайте `OACS_PASSPHRASE` или `ONEC_OACS_PASSPHRASE` явно и не коммитьте `.agent/oacs/`.

OACS здесь state/governance backend, а не оркестратор. `onec-context` остаётся retrieval engine для platform help, ITS standards и project packs.

MCP import внутри контейнера:

```bash
onec-agent context-mcp-config > /tmp/onec-context-mcp.json
acs mcp import /tmp/onec-context-mcp.json
```

После import OACS видит `onec_status`, `onec_ensure`, `onec_resolve_packs`, `onec_query_kb`, `onec_query_code`, `onec_query_config` как governed tools.

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

## Закреплённые версии

Image закрепляет версии инструментов и skills через build variables из `.env`. Build/runtime детали и prebuilt packs описаны в [runtime-details.md](runtime-details.md).
