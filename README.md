# 1c-develop

`1c-develop` - переносимая Docker-среда для разработки, проверки и агентной работы с 1С-проектами.

Идея простая: пользователь скачивает готовый image, монтирует свой проект и сразу получает 1С runtime, VNC, OneScript, Vanessa, BSL Language Server, OACS и 1C-aware agent context без ручной сборки локального набора скриптов.

## Что внутри

- 1С:Предприятие `8.5.1.1302` в desktop/runtime контейнере.
- VNC/Xfce, доступный на `127.0.0.1:5900`.
- OneScript, Vanessa Runner, Vanessa Automation и `bsl-language-server`.
- `onec-agent` для 1C-specific операций: bootstrap, context, MCP config, BSLLS, skills.
- OACS/ACS как прямой слой памяти, evidence и context capsules.
- Prebuilt context packs: platform help, ITS standards и локальный metadata pack после bootstrap.
- Опциональный PostgreSQL 1C для server/client-server сценариев.

Изюминка проекта: контейнер не просто запускает 1С. Он подготавливает корректный контекст для IDE-агента: где искать справку, какие skills читать, как строить OACS capsule, куда писать evidence и как не терять проектные решения между итерациями.

## Быстрый старт

Запускайте из корня вашего 1С-проекта.

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

После bootstrap:

1. Откройте VNC: `localhost:5900`.
2. Дайте IDE-агенту прочитать `.agent/bootstrap-report.md` и `.agent/instructions/pai-agent-instructions.md`.
3. Держите контейнер запущенным и выполняйте дальнейшие команды через `docker exec`.

```bash
docker exec -it 1c-dev onec-agent doctor
docker exec -it 1c-dev acs memory query --query "текущая задача" --scope project --json
docker exec -it 1c-dev onec-agent context --task "текущая задача" --query "ЗаписьJSON" --pack platform --limit 5
```

Bootstrap не требует лицензии 1С. Лицензия нужна только для запуска самого 1С runtime.

## Лицензирование

Поддерживаются два чистых пути:

- локальная ручная активация: используйте Docker volume `onec-license-store` (`/var/1C/licenses`) и не удаляйте его после активации;
- сетевой HASP: подготовьте `nethasp.ini` и смонтируйте его в контейнер.

Запустить штатный UI для ручной активации:

```bash
docker exec -d 1c-dev /opt/1cv8/current/1cv8c
```

Пример для сетевого HASP:

```bash
docker cp ./nethasp.ini 1c-dev:/opt/1cv8/conf/nethasp.ini
docker cp ./nethasp.ini 1c-dev:/home/usr1cv8/.1cv8/1C/1cv8/conf/nethasp.ini
```

## Работа с агентом

Агент остается в Cursor, Codex, VS Code или другом IDE на host. Контейнер дает runtime и проверенные 1C facts.

`onec-agent bootstrap` создает в смонтированном проекте:

- `.agent/oacs/oacs.db`
- `.agent/mcp/onec-context-mcp.json`
- `.agent/context-capsules/bootstrap-context-capsule.json`
- `.agent/bootstrap-report.md`
- `.agent/instructions/pai-agent-instructions.md`
- `.agent/instructions/oacs-memory-call-loop.md`
- `.agent/reports/onec-agent-doctor.txt`
- `.agent/reports/oacs-bootstrap-context.json`
- `.agent/reports/oacs-standards-context.json`

Если `.agent/AGENTS.md` еще нет, bootstrap создаст IDE entrypoint. Если файл уже существует, bootstrap его не перезаписывает.

Правило работы:

- память и evidence пишутся напрямую через `acs`;
- `onec-agent` используется только как 1C adapter для context, MCP, diagnostics и runtime checks;
- контейнер не пересоздается для каждой задачи.

Подробнее: [docs/agent-ready.md](docs/agent-ready.md).

## Через Make

Если вы работаете из clone этого репозитория, доступны transport-команды:

| Команда | Назначение |
| --- | --- |
| `make env` | создать `.env` из `.env.example`, если его еще нет |
| `make doctor` | проверить Docker, image, staging, license volume и agent mode |
| `make pull` | скачать настроенный developer image |
| `make first-start` | запустить optional local license UI |
| `make up` | поднять shell/agent-ready runtime |
| `make up-file-db` | запустить file DB mode после настройки лицензирования |
| `make up-server` | запустить server mode вместе с PostgreSQL 1C |
| `make ui-smoke` | прогнать минимальный Vanessa UI smoke |
| `make agent-context` | собрать OACS task context capsule |
| `make agent-bslls` | запустить BSL Language Server diagnostics |

Пример из 1С-проекта:

```bash
make -C /path/to/1c-develop agent-up PROJECT_PATH="$PWD"
make -C /path/to/1c-develop agent-doctor PROJECT_PATH="$PWD"
make -C /path/to/1c-develop agent-context PROJECT_PATH="$PWD" TASK="текущая задача"
```

## Runtime

Обычный `make up` поднимает shell/agent-ready контейнер без окна добавления базы. VNC поднимается по умолчанию и доступен только на localhost.

Порты:

- `127.0.0.1:5900` - VNC;
- `5432` - PostgreSQL 1C, только если поднят `make up-server`.

Server ports 1C наружу по умолчанию не публикуются. Для локальной разработки и file DB они не нужны.

Runtime modes, platform staging, volumes, architecture и prebuilt context packs описаны в [docs/runtime-details.md](docs/runtime-details.md).

## UI smoke

В репозитории есть минимальный Vanessa smoke для связки `TestManager -> TestClient`.

```bash
make ui-smoke
```

Runner: [`scripts/run-ui-smoke.sh`](scripts/run-ui-smoke.sh). Артефакты сохраняются в `./volumes/1c-dev/data/workspace/artifacts`.

## Локальная сборка

Для pull-based onboarding сборка не нужна: достаточно скачать image и выполнить `onec-agent bootstrap`.

Если готового image нет или вы меняете Dockerfile:

```bash
make env
make build
```

Для локальной сборки с ITS нужны `ITS_LOGIN` и `ITS_PASSWORD`. Если они пустые, build targets запросят их один раз и сохранят в `.env`. Не коммитьте `.env`.

По умолчанию compose и helper-скрипты используют `IMAGE_NAMESPACE=ghcr.io/mussolene`. Для private registry задайте свой namespace в `.env`.

## Структура

- `client/` - developer image с 1С runtime и agent-ready слоем.
- `base/` - базовые Linux/Desktop/OneScript images.
- `pg/` - PostgreSQL 1C image.
- `agent/` - container-side `onec-agent`, registry и local OACS skill.
- `scripts/` - host transport commands и build/run helpers.
- `artifacts/` - runtime overlay, VNC services, configs и smoke assets.
- `docs/` - подробности по runtime, OACS workflow и agent-ready режиму.

## CI publish

Workflow [`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml) публикует:

- `linux-common-base`
- `linux-desktop-base`
- `linux-onescript-builder`
- `linux-onescript`
- `postgresql`
- `1c-developer`

Publish запускается вручную через `workflow_dispatch` или по git-тегам `v*`.

## Важно

- `.env`, `.agent/`, `.local/`, `.onec-runtime/` и локальные volume-данные не коммитятся.
- `nethasp.ini`, license data, ITS credentials и OACS DB не должны попадать в git или OACS memory.
- Проект сейчас поддерживает 1С platform runtime в `linux/amd64` mode.
- Compose настроен под локальную разработку, не под production.
