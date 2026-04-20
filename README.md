# clientserver1c

Локальный Docker-стенд для 1С с одним developer-контейнером платформы. `PostgreSQL 1C` остаётся опциональным сервисом только для server/client-server сценариев.

Основные сервисы:

1. `1c-pg` - PostgreSQL 1C
2. `1c-dev` - один контейнер 1С со всем стеком: GUI/VNC, OneScript, Vanessa tooling, клиентские и серверные бинарники 1С

## Основная идея

Штатный flow теперь такой:

1. Первый запуск: developer-контейнер стартует в режиме `license-ui`
2. Через VNC вручную проходится получение лицензии
3. Лицензия сохраняется в общем `/var/1C/licenses`
4. После этого тот же образ можно запускать:
   - в режиме `file-db` для обычной работы с файловой ИБ
   - в режиме `server` для запуска серверного процесса тем же образом

Отдельного контейнера `1c-server` в локальном supported flow больше нет.

## Структура

- `base/linux-common/` - общий base image
- `base/linux-desktop/` - GUI/VNC/Xfce base image
- `base/linux-onescript-builder/` - build image для OneScript
- `base/linux-onescript/` - runtime image с OneScript
- `client/` - Dockerfile developer-контейнера 1С
- `pg/` - Dockerfile и helper-скрипты для PostgreSQL 1C
- `scripts/` - локальные build/run helper-скрипты
- `artifacts/` - overlay, конфиги и runtime helper-скрипты

## Подготовка

```bash
cp .env.example .env
```

Минимально нужно задать:

- `PLATFORM_VERSION`

Для подготовки архивов платформы с ITS нужны:

- `ITS_LOGIN`
- `ITS_PASSWORD`

Если локально запускать `make build`, `make up`, `make up-file-db`, `make up-server` или `make build-server-stack` из интерактивного терминала, недостающие `ITS_LOGIN` / `ITS_PASSWORD` будут запрошены и сохранены в `.env`.

## Основные команды

```bash
make up
```

Готовит staging платформы, при отсутствии локального image собирает нужные сервисы и поднимает:

- `1c-dev` в режиме `license-ui`

Это базовый первый запуск, когда нужно вручную получить лицензию через VNC.

После того как лицензия уже есть:

```bash
make up-file-db
```

Поднимает тот же стек, но `1c-dev` стартует сразу в режиме `file-db`. Если developer-image уже собран, повторный запуск не уходит в лишнюю полную пересборку.

Если нужно поднять серверный процесс тем же образом:

```bash
make up-server
```

Этот сценарий дополнительно поднимает:

- `1c-pg`
- `1c-dev` в режиме `server`

Полезные команды:

- `make build` - только developer-образ
- `make build-server-stack` - developer-образ плюс `1c-pg`
- `make config` - проверить итоговый `docker compose config`
- `make down` - остановить стенд
- `make ps` - список контейнеров
- `make logs` - логи `1c-pg` и `1c-dev`
- `make clean-platform` - очистить локальный cache/staging платформы

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

Пакеты ставятся в процессе сборки образа.

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
