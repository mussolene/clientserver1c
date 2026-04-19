# clientserver1c

Инфраструктурный репозиторий для локального стенда 1С в Docker.

Состав стенда:

1. `1c-client` - клиент 1С с VNC
2. `1c-server` - сервер 1С
3. `1c-pg` - PostgreSQL для 1С

Отдельно собирается shared base image:

1. `linux-desktop-base` - общий GUI-слой для клиента: Xfce, VNC, шрифты и системные зависимости

В клиентский образ также устанавливаются:

1. `OneScript`
2. `Vanessa ADD`
3. `vanessa-runner`

Поддерживаются сборки для `amd64` и `arm64` Linux, начиная с платформы `8.3.22`.

## Структура

- `client/` - Dockerfile клиентского контейнера
- `base/linux-desktop/` - Dockerfile общего desktop-base образа
- `server/` - Dockerfile серверного контейнера
- `pg/` - Dockerfile и entrypoint для PostgreSQL
- `artifacts/` - общие артефакты для сборки
- `artifacts/client-vnc/` - rootfs overlay для VNC-клиента
- `artifacts/config/` - конфиги, которые копируются в образы
- `artifacts/scripts/` - служебные скрипты сборки

## Что нужно подготовить локально

В репозиторий не коммитятся локальные бинарные артефакты и чувствительные настройки. Перед сборкой подготовьте:

1. локальный файл `.env` на основе `.env.example`

Архив платформы скачивается локально в скрытую папку `.local/1c/platform/` и не хранится в git.
Файл `artifacts/nethasp.ini` опционален: добавляйте его только если вашей схеме лицензирования он действительно нужен.

## Запуск

```bash
cp .env.example .env
make up
```

Если в `.env` нет `ITS_LOGIN` и `ITS_PASSWORD`, скрипт сам спросит их в CLI при первом скачивании и сохранит в локальный `.env`.

Если архив уже скачан или нужен только этап загрузки:

```bash
make download
make build
```

## Make targets

- `make env` - создать `.env` из `.env.example`, если файла еще нет
- `make download` - скачать архив платформы в `.local/1c/platform/`; при необходимости запросит ITS-логин и пароль
- `make prepare-platform` - подготовить локальные staging-каталоги `.local/1c/server-platform/` и `.local/1c/client-platform/` для Docker build
- `make build-desktop-base` - собрать shared image `linux-desktop-base` для клиента
- `make up` - скачать платформу при необходимости, при необходимости запросить ITS-логин и пароль, затем поднять стенд; принимает `PG_MAJOR`, `PG_REPO_DIST`, `PLATFORM_VERSION`, `PLATFORM_ARCH`, `DOCKER_DEFAULT_PLATFORM`, `ENABLE_USBIP_TOOLS`, `ONESCRIPT_VERSION`, `VANESSA_ADD_VERSION`, `VANESSA_RUNNER_VERSION`
- `make build` - собрать образы; принимает `PLATFORM_ARCH`, `DOCKER_DEFAULT_PLATFORM`, `ENABLE_USBIP_TOOLS`, `ONESCRIPT_VERSION`, `VANESSA_ADD_VERSION`, `VANESSA_RUNNER_VERSION`
- `make config` - проверить `docker compose config`
- `make down` - остановить стенд
- `make ps` - показать состояние контейнеров
- `make logs` - смотреть логи
- `make clean-platform` - удалить локальные кэши платформы и staging-каталоги

## Переменные `.env`

- `POSTGRES_PASSWORD` - пароль PostgreSQL для локального стенда
- `PG_MAJOR` - major-версия Postgres Pro 1C для контейнера БД; по умолчанию `17`
- `PG_REPO_DIST` - дистрибутивный codename репозитория Postgres Pro 1C; по умолчанию `bullseye`
- `PLATFORM_VERSION` - версия платформы 1С, которая будет скачиваться и использоваться при сборке
- `PLATFORM_ARCH` - архитектура дистрибутивов платформы 1С из ITS: `amd64` или `arm64`
- `DOCKER_DEFAULT_PLATFORM` - целевая Docker-платформа для cross-build/run; обычно пусто, для явного cross-build можно задать `linux/amd64` или `linux/arm64`
- `ENABLE_USBIP_TOOLS` - собирать ли USB/IP и `VirtualHere` helper в серверном образе; `auto` по умолчанию, на `arm64` автоматически отключается
- `DESKTOP_BASE_IMAGE` - имя shared desktop base image; по умолчанию `mussolene/linux-desktop-base`
- `DESKTOP_BASE_TAG` - тег shared desktop base image; по умолчанию `bullseye`
- `BASE_DEBIAN_DIST` - Debian codename для сборки shared desktop base image; по умолчанию `bullseye`
- `ONESCRIPT_VERSION` - версия `OneScript`, которая будет скачана в клиентский образ
- `VANESSA_ADD_VERSION` - версия пакета `add`, которая будет установлена через `opm`
- `VANESSA_RUNNER_VERSION` - версия пакета `vanessa-runner`, которая будет установлена через `opm`
- `ITS_LOGIN` и `ITS_PASSWORD` - учетка для `login.1c.ru` / `releases.1c.ru`; если не заданы, будут запрошены интерактивно и сохранены в `.env`

По умолчанию downloader пытается найти файл нужной версии на `releases.1c.ru`, скачать его в `.local/1c/platform/`, а затем Dockerfile берут архив уже оттуда. Учетные данные остаются только на хосте и не попадают в образ.

Тяжелый GUI/VNC/font слой теперь вынесен в отдельный image `linux-desktop-base`, а `1c-client` собирается уже поверх него. Это позволяет не пересобирать Xfce, VNC, шрифты и системные зависимости при каждой смене версии платформы.

OneScript и пакеты BDD скачиваются уже на этапе `docker build` клиента. На `amd64` после сборки в контейнере доступны команды `oscript`, `opm` и `vrunner`, а сама `Vanessa ADD` лежит в `/opt/onescript/lib/add`. На `arm64` установка `OneScript` пока пропускается, потому что в upstream-релизе `OneScript 2.0.0` нет Linux `arm64`-артефакта.

## Версия сборки

Версию можно задать двумя способами:

1. Постоянно через `.env`:

```bash
PLATFORM_VERSION=8.3.24.1548
```

2. Разово в команде:

```bash
make up PLATFORM_VERSION=8.3.24.1548
```

## Архитектура сборки

По умолчанию репозиторий собирает `amd64`-вариант платформы. Для нативной `arm64`-сборки на ARM-хосте:

```bash
make build PLATFORM_ARCH=arm64
```

Для cross-build:

```bash
make build PLATFORM_ARCH=arm64 DOCKER_DEFAULT_PLATFORM=linux/arm64
```

Практический нюанс для `8.5.1.1150`: ITS отдает отдельные ARM-архивы `server.arm.deb64_8.5.1.1150.zip` и `client.arm.deb64_8.5.1.1150.zip`. В этом релизе клиентский ARM-архив содержит `thin-client` пакеты, поэтому ARM-клиент сейчас собирается из них, тогда как на `amd64` для `8.5.x` используется full client.

## Типовой сценарий

```bash
make env
make up
```

1. `make env` создаст `.env`, если его еще нет
2. `make up` при необходимости спросит ITS-логин и пароль, сохранит их в `.env`, соберет `linux-desktop-base`, скачает платформу и поднимет контейнеры

Если нужно отдельно прогреть только shared base image:

```bash
make build-desktop-base
```

## Версия PostgreSQL

По умолчанию контейнер БД собирается на `Postgres Pro 1C 17` через официальный репозиторий `repo.postgrespro.ru`. Для текущего стенда это выбранная верхняя рабочая версия по умолчанию; при необходимости ее можно понизить через переменные окружения.

Переопределить можно через `.env`:

```bash
PG_MAJOR=17
PG_REPO_DIST=bullseye
```

или разово:

```bash
make up PG_MAJOR=16
make build PG_MAJOR=17 PG_REPO_DIST=bullseye
```

## OneScript и BDD

По умолчанию `1c-client` собирается вместе с `OneScript`, `Vanessa ADD` и `vanessa-runner`. Переопределить версии можно через `.env`:

```bash
ONESCRIPT_VERSION=2.0.0
VANESSA_ADD_VERSION=6.9.5
VANESSA_RUNNER_VERSION=2.6.0
```

или разово:

```bash
make build ONESCRIPT_VERSION=2.0.0 VANESSA_ADD_VERSION=6.9.5 VANESSA_RUNNER_VERSION=2.6.0
```

После сборки в клиентском контейнере доступны:

- `oscript`
- `opm`
- `vrunner`

## Порты

- клиент VNC: `localhost:5900`
- сервер 1С: `1540-1541`, `1560-1691`, `1545`
- PostgreSQL: `5432`

## Замечания

- `docker-compose.yml` настроен для локального стенда, не для production
- пароль БД задается через `.env`, а не хранится в git
