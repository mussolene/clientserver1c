# Работа IDE-агента

IDE-агент остаётся на host в Cursor, Codex, VS Code или другом редакторе. Проект тоже остаётся на host. Контейнер `1c-dev` даёт 1С runtime, инструменты тестирования, BSL-диагностику и закреплённый слой 1C skills.

## Модель работы

```text
IDE-агент на host
  редактирует файлы в открытом проекте
  вызывает helper-команды из clientserver1c

контейнер 1c-dev
  видит тот же проект как /workspace/project
  запускает 1С, OneScript, Vanessa, BSLLS и skill-guided проверки
```

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
make -C /path/to/clientserver1c agent-skill PROJECT_PATH="$PWD" NAME=proof-loop
```

Используйте `context` перед изменением метаданных или BSL, когда нужны точные факты. Используйте `testing` для Vanessa/xUnit/UI проверок. Используйте `proof-loop` для нетривиальных изменений со spec, evidence, verification и fix-loop.

## Выполнить команду в контейнере

```bash
make -C /path/to/clientserver1c agent-exec PROJECT_PATH="$PWD" CMD="oscript --version"
```

## BSL-диагностика и форматирование

```bash
make -C /path/to/clientserver1c agent-bslls PROJECT_PATH="$PWD" SRC_DIR=src/cf
make -C /path/to/clientserver1c agent-bslls-format PROJECT_PATH="$PWD" SRC_DIR=src/cf
```

`agent-bslls-format` меняет файлы проекта. После запуска агент должен показать diff.

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

## Закреплённые версии

Image закрепляет версии инструментов и skills через build variables из `.env`. Не меняйте их без необходимости: так сборка остаётся повторяемой.
