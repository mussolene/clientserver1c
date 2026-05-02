# 1c-develop

Повторяемая локальная среда для 1С-разработки и тестирования в Docker.

Главный контейнер `1c-dev` содержит платформу 1С, GUI/VNC, OneScript, Vanessa tooling, BSL Language Server и agent-ready слой для IDE-агентов. `PostgreSQL 1C` подключается только когда нужен server/client-server сценарий.

## Быстрый старт

Минимальный путь без clone helper-репозитория:

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

После этого:

1. Откройте VNC: `localhost:5900`.
2. Дайте агенту инструкцию читать `.agent/bootstrap-report.md` и `.agent/instructions/pai-agent-instructions.md`.
3. Для всех дальнейших команд используйте работающий контейнер:

```bash
docker exec -it 1c-dev onec-agent doctor
docker exec -it 1c-dev acs memory query --query "текущая задача" --scope project --json
docker exec -it 1c-dev onec-agent context --task "текущая задача" --query "ЗаписьJSON" --pack platform --limit 5
```

Контейнер не нужно пересоздавать для обычной работы агента. Он остается в `shell` runtime, а 1С-зависимые команды запускаются через `docker exec`.

Если нужна ручная активация лицензии, откройте штатный UI внутри уже запущенного контейнера и подключитесь к VNC:

```bash
docker exec -d 1c-dev /opt/1cv8/current/1cv8c
```

Лицензирование опционально для bootstrap и agent context. Для запуска 1С runtime есть два пути:

- локальная ручная активация: используйте Docker volume `onec-license-store` (`/var/1C/licenses`) и не удаляйте его после активации;
- сетевой HASP: подготовьте `nethasp.ini` и смонтируйте его в контейнер, локальная активация тогда не нужна.

Пример для сетевого HASP:

```bash
docker cp ./nethasp.ini 1c-dev:/opt/1cv8/conf/nethasp.ini
docker cp ./nethasp.ini 1c-dev:/home/usr1cv8/.1cv8/1C/1cv8/conf/nethasp.ini
```

Helper-репозиторий дает те же сценарии через Make:

```bash
make env
make pull
make up
make agent-context PROJECT_PATH="$PWD" TASK="текущая задача"
```

## Работа из IDE с агентом

Агент остаётся в Cursor/Codex/VS Code на host, а текущий проект монтируется в `1c-dev` как `/workspace/project`.

Portable Agent Infrastructure интерфейс находится внутри самого image. Host-side `make agent-*` targets являются только transport-командами для Docker Compose и не заменяют container-side CLI.

Bootstrap создает project-local артефакты для агента:

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

Минимальная проверка без постоянного контейнера:

```bash
docker pull ghcr.io/mussolene/1c-developer:<PLATFORM_VERSION>
docker run --rm -it \
  --entrypoint onec-agent \
  -v "$PWD":/workspace/project \
  -e ONEC_PROJECT_ROOT=/workspace/project \
  -e OACS_PASSPHRASE="$OACS_PASSPHRASE" \
  ghcr.io/mussolene/1c-developer:<PLATFORM_VERSION> \
  bootstrap
```

Из репозитория 1С-проекта:

```bash
make -C /path/to/1c-develop agent-up PROJECT_PATH="$PWD"
make -C /path/to/1c-develop agent-doctor PROJECT_PATH="$PWD"
```

Частые проверки, OACS/MCP, memory policy и детали agent workflow: [docs/agent-ready.md](docs/agent-ready.md).

## Основные команды

| Команда | Назначение |
| --- | --- |
| `make env` | создать `.env` из `.env.example`, если его ещё нет |
| `make doctor` | показать готовность host, Docker, staging, image, optional local license volume и agent mode |
| `make pull` | скачать настроенный готовый developer image из registry |
| `make first-start` | создать `.env`, затем запустить optional local license UI старт |
| `make up` | запустить локальный или заранее скачанный developer image в shell/agent-ready режиме |
| `make up-file-db` | запустить `1c-dev` в файловом режиме после настройки лицензирования |
| `make ui-smoke` | прогнать минимальный Vanessa UI smoke |
| `make up-server` | запустить server mode вместе с PostgreSQL 1C |
| `make agent-context` | собрать OACS task context capsule |

Расширенные детали runtime: [docs/runtime-details.md](docs/runtime-details.md).

## Структура

- `base/linux-common/` - общий base image
- `base/linux-desktop/` - GUI/VNC/Xfce base image
- `base/linux-onescript-builder/` - build image для OneScript
- `base/linux-onescript/` - runtime image с OneScript
- `client/` - Dockerfile developer-контейнера 1С
- `pg/` - Dockerfile и helper-скрипты для PostgreSQL 1C
- `scripts/` - локальные build/run helper-скрипты
- `artifacts/` - overlay, конфиги и runtime helper-скрипты

## Первый запуск и credentials

Для pull-based onboarding достаточно скачать image, запустить `shell` runtime и выполнить `onec-agent bootstrap` внутри контейнера. `make up`/`make first-start` не собирают image скрыто: если готового image нет локально или в registry, выполните явный `make build`.

Для локальной сборки с ITS нужны `ITS_LOGIN` и `ITS_PASSWORD`. Если они пустые, build targets запросят их один раз и сохранят в `.env`. Не коммитьте `.env`.

## Образы и private registry

По умолчанию compose и helper-скрипты используют опубликованные GHCR images. Для своего registry задайте `IMAGE_NAMESPACE` в `.env`:

Примеры:

- `IMAGE_NAMESPACE=ghcr.io/mussolene` - default GHCR
- `IMAGE_NAMESPACE=ghcr.io/acme` - private GHCR namespace
- `IMAGE_NAMESPACE=mussolene` - Docker Hub

## Runtime

Bootstrap и agent/OACS context не требуют активированной лицензии. Лицензия нужна только для запуска 1С runtime.

Поддерживаются два пути:

- локальная ручная активация: named volume `onec-license-store` хранит `/var/1C/licenses`; первый license flow запускается через `make first-start` или `docker exec -d 1c-dev /opt/1cv8/current/1cv8c`;
- сетевой HASP: положите `nethasp.ini` в `/opt/1cv8/conf/nethasp.ini` и `/home/usr1cv8/.1cv8/1C/1cv8/conf/nethasp.ini`.

Обычный `make up` поднимает shell/agent-ready контейнер без окна добавления базы.

Runtime modes, platform staging, volumes, architecture and prebuilt context packs: [docs/runtime-details.md](docs/runtime-details.md).

## Порты

- `127.0.0.1:5900` - VNC только на localhost
- `5432` - PostgreSQL 1C, если поднят `make up-server`

Серверные порты 1С по умолчанию наружу не публикуются. Для первого запуска и `file-db` они не нужны, а сам `server`-mode остаётся доступен тем же образом внутри docker-сети или через отдельный runtime-override, если позже понадобится host exposure.

## OneScript и Vanessa

Внутри `1c-dev` доступны:

- `oscript`
- `opm`
- `vrunner`
- `vanessa-runner`
- `vanessa-automation`
- `vanessa-automation-single`
- `python3`
- `bsl-language-server`

Пакеты ставятся в процессе сборки образа.

## Agent-ready режим

`1c-dev` содержит `onec-agent`, OACS, skills, `onec-context`, BSLLS и prebuilt context packs. Быстрый путь есть выше, подробности: [docs/agent-ready.md](docs/agent-ready.md) и [docs/runtime-details.md](docs/runtime-details.md).

## UI smoke через Vanessa

В репозитории есть воспроизводимый минимальный smoke для `TestManager -> TestClient`:

Runner: [`scripts/run-ui-smoke.sh`](scripts/run-ui-smoke.sh). Артефакты сохраняются в `./volumes/1c-dev/data/workspace/artifacts`.

## CI publish

Workflow [`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml) публикует:

- `linux-common-base`
- `linux-desktop-base`
- `linux-onescript-builder`
- `linux-onescript`
- `postgresql`
- `1c-developer`

Publish запускается вручную через `workflow_dispatch` или по git-тегам `v*`.

Отдельный publish `1c-server` больше не используется.

## Замечания

- `.env`, `.local/` и локальные volume-данные не коммитятся
- compose настроен под локальную разработку, не под production
