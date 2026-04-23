# clientserver1c

Повторяемая локальная среда для 1С-разработки и тестирования в Docker.

Главный контейнер `1c-dev` содержит платформу 1С, GUI/VNC, OneScript, Vanessa tooling, BSL Language Server и слой 1C skills для IDE-агентов. Во время сборки слоя skills он предсобирает platform help pack из установленной HBK платформы и standards pack в локальном SQLite/FTS формате. `PostgreSQL 1C` подключается только когда нужен server/client-server сценарий.

## Быстрый старт

```bash
docker login ghcr.io
make env
make pull
make doctor
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

Из репозитория 1С-проекта:

```bash
make -C /path/to/clientserver1c agent-up PROJECT_PATH="$PWD"
make -C /path/to/clientserver1c agent-doctor PROJECT_PATH="$PWD"
```

Частые проверки:

```bash
make -C /path/to/clientserver1c agent-bslls PROJECT_PATH="$PWD" SRC_DIR=src/cf
make -C /path/to/clientserver1c agent-bslls-format PROJECT_PATH="$PWD" SRC_DIR=src/cf
make -C /path/to/clientserver1c agent-exec PROJECT_PATH="$PWD" CMD="oscript --version"
```

Подробнее: [docs/agent-ready.md](docs/agent-ready.md).

## Основные команды

| Команда | Назначение |
| --- | --- |
| `make env` | создать `.env` из `.env.example`, если его ещё нет |
| `make doctor` | показать готовность host, Docker, staging, image, license volume и agent mode |
| `make pull` | скачать настроенный готовый developer image из registry |
| `make first-start` | создать `.env`, затем запустить первый license UI старт |
| `make up` | использовать локальный/pulled image, собрать только если image недоступен |
| `make up-file-db` | запустить `1c-dev` в файловом режиме после активации лицензии |
| `make ui-smoke` | прогнать минимальный Vanessa UI smoke |
| `make up-server` | запустить server mode вместе с PostgreSQL 1C |

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

Минимально нужен `PLATFORM_VERSION` в `.env`. Если platform archive ещё не подготовлен, `make up`/`make first-start` запустит host-side staging.

Для скачивания платформы с ITS нужны:

- `ITS_LOGIN`
- `ITS_PASSWORD`

Если они пустые, интерактивные targets запросят их один раз и сохранят в `.env`. Не коммитьте `.env`.

Если готовый image уже есть локально или доступен в registry, `make up`/`make first-start` не скачивает платформу и не собирает образ. Host-side staging запускается только как fallback для локальной сборки, когда image нельзя использовать или скачать.

## Образы и private registry

По умолчанию compose и helper-скрипты используют опубликованные GHCR images:

```env
IMAGE_NAMESPACE=ghcr.io/mussolene
```

Для своего private registry задайте namespace в `.env`:

```env
IMAGE_NAMESPACE=ghcr.io/acme
```

Тогда `1c-dev` будет использовать `ghcr.io/acme/1c-developer:<PLATFORM_VERSION>`, а base/PostgreSQL images - тот же namespace. Это позволяет публиковать готовые образы в закрытый registry и не менять compose-файлы в fork/company setup.

Для Docker Hub явно задайте:

```env
IMAGE_NAMESPACE=mussolene
```

Минимальный pull-based onboarding:

```bash
docker login ghcr.io
make env
make pull
make first-start
```

Для IDE-агента:

```bash
make -C /path/to/clientserver1c pull
make -C /path/to/clientserver1c agent-up PROJECT_PATH="$PWD"
```

## Runtime modes

Режим контейнера задаётся через `ONEC_RUNTIME_MODE`.

Поддерживаются:

- `license-ui` - default. Запуск штатного GUI/launcher для ручной активации лицензии
- `file-db` - запуск `1cv8 ENTERPRISE /F <path>`
- `server` - запуск `ragent`
- `shell` - idle-режим для ручного входа в контейнер

Дополнительные переменные:

- `ONEC_FILE_DB_PATH` - путь к файловой ИБ в режиме `file-db`, по умолчанию `/mnt/data/testdb`
- `ONEC_DISABLE_UNSAFE_ACTION_PROTECTION` - значение для `DisableUnsafeActionProtection` в `conf.cfg`, по умолчанию `.*` для developer-стенда
- `SRV1CV8_PORT`, `SRV1CV8_REGPORT`, `SRV1CV8_RANGE`, `SRV1CV8_DEBUG` - параметры server-mode

## Платформа 1С

Платформа не скачивается внутри `docker build` developer-образа.

Используется [`scripts/prepare-platform.sh`](scripts/prepare-platform.sh), который:

- логинится на ITS
- скачивает архив платформы в `.local/1c/platform/`
- готовит единый staging-каталог `.local/1c/dev-platform/`

Это host-side стадия, которая запускается перед `make build`, `make up`, `make up-file-db`, `make up-server`, `make build-server-stack` и `make prepare-platform`.

Для `amd64` исходный архив `server64_with_all_clients_<version>.zip` хранится в `.local/1c/platform/`, а в `.local/1c/dev-platform/` staging-скрипт раскладывает уже нужные installer-файлы `setup-full-...run` и `all-clients-distr-...run`.

Для `arm64` в `.local/1c/dev-platform/` раскладываются отдельные server/client zip-архивы `server.arm.deb64_<version>.zip` и `client.arm.deb64_<version>.zip` (или `thin.client.arm.deb64_<version>.zip`), а developer-image при сборке ставит и серверные, и клиентские пакеты из этого staging-каталога.

## Лицензия

Лицензия хранится в общем named volume:

```text
/var/1C/licenses
```

Именно этот volume переживает пересоздание контейнера и может быть подключён к другим копиям того же developer-образа.

Первый supported flow намеренно ручной:

1. `make up`
2. подключение к `localhost:5900`
3. ручной ввод учётных данных в штатном окне лицензирования 1С

## Volumes

Compose использует:

- `./volumes/1c-dev/data:/mnt/data`
- `./volumes/1c-dev/cache:/root/.1cv8/1C/1cv8/`
- `onec-license-store:/var/1C/licenses`

При старте `1c-dev` runtime-скрипт прописывает `DisableUnsafeActionProtection` в `conf.cfg` по Linux-путям платформы:

- `/opt/1cv8/current/conf/conf.cfg`
- `/opt/1cv8/conf/conf.cfg`
- `/root/.1cv8/1C/1cv8/conf/conf.cfg`

Это нужно для запуска Vanessa/external EPF без модального предупреждения безопасности внутри developer-контейнера.

## Порты

- `127.0.0.1:5900` - VNC только на localhost
- `5432` - PostgreSQL 1C, если поднят `make up-server`

Серверные порты 1С по умолчанию наружу не публикуются. Для первого запуска и `file-db` они не нужны, а сам `server`-mode остаётся доступен тем же образом внутри docker-сети или через отдельный runtime-override, если позже понадобится host exposure.

## Архитектура и платформы

По умолчанию 1С-сервисы собираются как `linux/amd64`.

На ARM-хосте default flow остаётся таким:

- базовые слои можно собирать multi-arch
- `1c-pg` может остаться нативным
- `1c-dev` обычно идёт как `linux/amd64`

Если нужно попробовать native ARM:

```bash
make build ONEC_PLATFORM_OVERRIDE=native-arm PLATFORM_ARCH=arm64
make up ONEC_PLATFORM_OVERRIDE=native-arm PLATFORM_ARCH=arm64
```

## OneScript и Vanessa

Внутри `1c-dev` доступны:

- `oscript`
- `opm`
- `vrunner`
- `vanessa-runner`
- `vanessa-automation`
- `python3`
- `bsl-language-server`

Пакеты ставятся в процессе сборки образа.

## Agent-ready режим

`1c-dev` содержит слой 1C skills и helper tools для IDE-агентов. Быстрый путь есть в начале README, подробности лежат в [docs/agent-ready.md](docs/agent-ready.md).

Agent-ready слой также содержит `onec-context` и контейнерный workspace `/opt/onec-agent/context-workspace` с prebuilt packs. Platform help pack строится во время Docker build из HBK, установленной вместе с платформой в `/opt/1cv8`. Standards pack строится в тот же SQLite/FTS `.db.zst` формат из ITS `v8std`; доступ к публичным страницам работает без логина, а `ITS_LOGIN`/`ITS_PASSWORD` secrets используются только если доступны.

## UI smoke через Vanessa

В репозитории есть воспроизводимый минимальный smoke для `TestManager -> TestClient`:

- feature: `artifacts/tests/ui/smoke/open-test-client.feature`
- `VAParams`: `artifacts/config/va-file-db-smoke.json`
- runner: `scripts/run-ui-smoke.sh`

Запуск:

```bash
make ui-smoke
```

По умолчанию runner:

- пересоздаёт `1c-dev` в `ONEC_RUNTIME_MODE=shell`
- копирует tracked feature и `VAParams` в `./volumes/1c-dev/data/workspace`
- очищает старые артефакты
- запускает `vrunner vanessa` против `/F/mnt/data/testdb`
- в начале прогона снимает типовые стартовые модальные окна вроде `Рекомендуется обновить версию конфигурации`, которые блокируют подключение `TestClient`

Артефакты сохраняются в `./volumes/1c-dev/data/workspace/artifacts`.

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
