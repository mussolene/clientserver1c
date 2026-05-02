# clientserver1c

Повторяемая локальная среда для 1С-разработки и тестирования в Docker.

Главный контейнер `1c-dev` содержит платформу 1С, GUI/VNC, OneScript, Vanessa tooling, BSL Language Server и agent-ready слой для IDE-агентов. `PostgreSQL 1C` подключается только когда нужен server/client-server сценарий.

## Быстрый старт

```bash
docker login ghcr.io
make env
make pull
make first-start
```

Дальше:

1. Подключитесь к VNC: `localhost:5900`.
2. Активируйте лицензию 1С вручную.
3. После активации запускайте обычный файловый режим:

```bash
make up-file-db
```

4. Когда runtime готов, проверьте smoke:

```bash
make ui-smoke
```

Лицензия хранится в Docker volume `onec-license-store`. Не удаляйте этот volume после активации.

## Работа из IDE с агентом

Агент остаётся в Cursor/Codex/VS Code на host, а текущий проект монтируется в `1c-dev` как `/workspace/project`.

Portable Agent Infrastructure интерфейс находится внутри самого image. Host-side `make agent-*` targets являются только удобными transport wrappers вокруг контейнерного CLI `onec-agent`.

Минимальный pull-only запуск без clone helper-репозитория:

```bash
docker pull ghcr.io/mussolene/1c-developer:<PLATFORM_VERSION>
docker run --rm -it \
  -v "$PWD":/workspace/project \
  -e ONEC_PROJECT_ROOT=/workspace/project \
  ghcr.io/mussolene/1c-developer:<PLATFORM_VERSION> \
  onec-agent doctor
```

Из репозитория 1С-проекта:

```bash
make -C /path/to/clientserver1c agent-up PROJECT_PATH="$PWD"
make -C /path/to/clientserver1c agent-doctor PROJECT_PATH="$PWD"
```

Частые проверки, OACS/MCP, memory policy и детали agent workflow: [docs/agent-ready.md](docs/agent-ready.md).

## Основные команды

| Команда | Назначение |
| --- | --- |
| `make env` | создать `.env` из `.env.example`, если его ещё нет |
| `make doctor` | показать готовность host, Docker, staging, image, license volume и agent mode |
| `make pull` | скачать настроенный готовый developer image из registry |
| `make first-start` | создать `.env`, затем запустить первый license UI старт |
| `make up` | запустить локальный или заранее скачанный developer image в shell/agent-ready режиме |
| `make up-file-db` | запустить `1c-dev` в файловом режиме после активации лицензии |
| `make ui-smoke` | прогнать минимальный Vanessa UI smoke |
| `make up-server` | запустить server mode вместе с PostgreSQL 1C |
| `make agent-context` | собрать OACS task context capsule |
| `make agent-memory-query` | найти OACS project memory |
| `make agent-memory-capture` | записать проверенный OACS project memory вывод |

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

Для pull-based onboarding достаточно `.env` с `PLATFORM_VERSION`, затем `make pull` и `make first-start`. `make up`/`make first-start` не собирают image скрыто: если готового image нет локально или в registry, выполните явный `make build`.

Для локальной сборки с ITS нужны `ITS_LOGIN` и `ITS_PASSWORD`. Если они пустые, build targets запросят их один раз и сохранят в `.env`. Не коммитьте `.env`.

## Образы и private registry

По умолчанию compose и helper-скрипты используют опубликованные GHCR images. Для своего registry задайте `IMAGE_NAMESPACE` в `.env`:

Примеры:

- `IMAGE_NAMESPACE=ghcr.io/mussolene` - default GHCR
- `IMAGE_NAMESPACE=ghcr.io/acme` - private GHCR namespace
- `IMAGE_NAMESPACE=mussolene` - Docker Hub

## Runtime

Лицензия хранится в named volume `onec-license-store` (`/var/1C/licenses` внутри контейнера). Первый license flow намеренно ручной: `make first-start`, VNC `localhost:5900`, штатное окно лицензирования 1С. Обычный `make up` после этого поднимает shell/agent-ready контейнер без окна добавления базы.

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

- `artifacts/nethasp.ini` опционален
- `.env`, `.local/` и локальные volume-данные не коммитятся
- compose настроен под локальную разработку, не под production
