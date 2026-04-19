# clientserver1c

Инфраструктурный репозиторий для локального стенда 1С в Docker.

Состав стенда:

1. `1c-client` - клиент 1С с VNC
2. `1c-server` - сервер 1С
3. `1c-pg` - PostgreSQL для 1С

Отдельно собираются shared base image:

1. `linux-common-base` - общий системный слой для сервера и клиента
2. `linux-desktop-base` - GUI-слой для клиента поверх `linux-common-base`: Xfce, VNC и desktop-зависимости
3. `linux-onescript-builder` - промежуточный build-слой, который скачивает исходники OneScript, собирает `oscript` и раскладывает `opm`
4. `linux-onescript` - reusable runtime-слой с готовыми `OneScript` и `opm`

В клиентский образ также переносятся:

1. `OneScript`
2. `OPM`
3. `Vanessa ADD`
4. `vanessa-runner`

Поддерживаются сборки для `amd64` и `arm64` Linux, начиная с платформы `8.3.22`.

## Структура

- `client/` - Dockerfile клиентского контейнера
- `base/linux-common/` - Dockerfile общего common-base образа
- `base/linux-desktop/` - Dockerfile общего desktop-base образа
- `base/linux-onescript-builder/` - Dockerfile промежуточного builder-образа для сборки OneScript из исходников
- `base/linux-onescript/` - Dockerfile общего onescript-base образа
- `server/` - Dockerfile серверного контейнера
- `pg/` - Dockerfile PostgreSQL
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
- `make build-common-base` - собрать shared image `linux-common-base` для сервера и клиента
- `make build-desktop-base` - собрать shared image `linux-desktop-base` для клиента
- `make build-onescript-builder` - собрать промежуточный image `linux-onescript-builder`, который скачивает исходники OneScript, собирает `oscript` и раскладывает `opm`
- `make build-onescript-base` - собрать shared image `linux-onescript`
- `make up` - скачать платформу при необходимости, при необходимости запросить ITS-логин и пароль, затем поднять стенд; принимает `PG_MAJOR`, `PG_REPO_DIST`, `PLATFORM_VERSION`, `PLATFORM_ARCH`, `DOCKER_DEFAULT_PLATFORM`, `ENABLE_USBIP_TOOLS`, `ONESCRIPT_VERSION`
- `make build` - собрать образы; принимает `PLATFORM_ARCH`, `DOCKER_DEFAULT_PLATFORM`, `ENABLE_USBIP_TOOLS`, `ONESCRIPT_VERSION`
- `make config` - проверить `docker compose config`
- `make down` - остановить стенд
- `make ps` - показать состояние контейнеров
- `make logs` - смотреть логи
- `make clean-platform` - удалить локальные кэши платформы и staging-каталоги

## Переменные `.env`

- `POSTGRES_PASSWORD` - пароль PostgreSQL для локального стенда
- `PG_MAJOR` - major-версия PostgreSQL для контейнера БД; по умолчанию `17`
- `PG_REPO_DIST` - тег базового официального образа `postgres`; по умолчанию `bookworm`
- `PLATFORM_VERSION` - версия платформы 1С, которая будет скачиваться и использоваться при сборке
- `PLATFORM_ARCH` - архитектура дистрибутивов платформы 1С из ITS: `amd64` или `arm64`
- `DOCKER_DEFAULT_PLATFORM` - целевая Docker-платформа для cross-build/run; обычно пусто, для явного cross-build можно задать `linux/amd64` или `linux/arm64`
- `ENABLE_USBIP_TOOLS` - собирать ли USB/IP и `VirtualHere` helper в серверном образе; по умолчанию `0`, включайте только явно при необходимости
- `COMMON_BASE_IMAGE` - имя shared common base image; по умолчанию `mussolene/linux-common-base`
- `COMMON_BASE_TAG` - тег shared common base image; по умолчанию `jammy`
- `COMMON_BASE_DIST` - базовый Ubuntu tag для сборки shared common base image; по умолчанию `jammy`
- `DESKTOP_BASE_IMAGE` - имя shared desktop base image; по умолчанию `mussolene/linux-desktop-base`
- `DESKTOP_BASE_TAG` - тег shared desktop base image; по умолчанию `jammy`
- `ONESCRIPT_BASE_IMAGE` - имя shared onescript base image; по умолчанию `mussolene/linux-onescript`
- `ONESCRIPT_BASE_TAG` - тег shared onescript base image; по умолчанию `2.0.0`
- `ONESCRIPT_BASE_DIST` - базовый Ubuntu tag для сборки shared onescript base image; по умолчанию `jammy`
- `ONESCRIPT_BUILD_IMAGE` - имя промежуточного build image для сборки OneScript из исходников; по умолчанию `mussolene/linux-onescript-builder`
- `ONESCRIPT_BUILD_TAG` - тег промежуточного build image; по умолчанию `2.0.0`
- `ONESCRIPT_SDK_IMAGE` - базовый SDK image для containerized сборки OneScript; по умолчанию `mcr.microsoft.com/dotnet/sdk:8.0`
- `ONESCRIPT_VERSION` - версия `OneScript`, чей git tag `v<version>` будет скачан и собран в builder-слое
- `VANESSA_ADD_VERSION` - версия пакета `add`, устанавливаемого через `opm`; по умолчанию `6.9.5`
- `VANESSA_RUNNER_VERSION` - версия пакета `vanessa-runner`, устанавливаемого через `opm`; по умолчанию `2.6.0`
- `ITS_LOGIN` и `ITS_PASSWORD` - учетка для `login.1c.ru` / `releases.1c.ru`; если не заданы, будут запрошены интерактивно и сохранены в `.env`

По умолчанию downloader пытается найти файл нужной версии на `releases.1c.ru`, скачать его в `.local/1c/platform/`, а затем Dockerfile берут архив уже оттуда. Учетные данные остаются только на хосте и не попадают в образ.

Общие системные зависимости вынесены в `linux-common-base`, тяжелый GUI/VNC слой вынесен в `linux-desktop-base`, а `OneScript` вынесен в связку `linux-onescript-builder` -> `linux-onescript`.

Итоговая иерархия такая:

1. `linux-common-base`
2. `linux-desktop-base` = `linux-common-base` + GUI
3. `1c-server` = `linux-common-base` + серверная платформа 1С
4. `1c-client` = `linux-desktop-base` + `linux-onescript` + клиентская платформа 1С + `Vanessa`

Это позволяет отдельно кэшировать общий системный слой, отдельно GUI-слой и отдельно containerized сборку OneScript из исходников.

OneScript собирается уже на этапе `docker build` промежуточного `linux-onescript-builder`. Там повторяется upstream-like packaging: раскладывается `opm` и подтягиваются базовые системные пакеты OneScript. Пакеты `add` и `vanessa-runner` затем ставятся уже в `1c-client` штатно через `opm install`.

Штатный upstream packaging у OneScript не содержит `linux-arm64`, но прямой containerized `dotnet publish` по `src/oscript/oscript.csproj` для `linux-arm64` работает. Поэтому `arm64`-вариант здесь собирается именно из исходников в builder-слое, а не через upstream ZIP.

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
2. `make up` при необходимости спросит ITS-логин и пароль, сохранит их в `.env`, соберет `linux-common-base`, `linux-desktop-base`, `linux-onescript-builder` и `linux-onescript`, скачает платформу и поднимет контейнеры

Если нужно отдельно прогреть только shared base image:

```bash
make build-common-base
make build-desktop-base
make build-onescript-builder
make build-onescript-base
```

## Версия PostgreSQL

По умолчанию контейнер БД собирается на официальном образе `postgres:17-bookworm`. Это наиболее переносимый вариант для локальной сборки на разных хостах и архитектурах; major-версию и distro tag при необходимости можно переопределить через переменные окружения.

Переопределить можно через `.env`:

```bash
PG_MAJOR=17
PG_REPO_DIST=bookworm
```

или разово:

```bash
make up PG_MAJOR=16
make build PG_MAJOR=17 PG_REPO_DIST=bookworm
```

## OneScript

По умолчанию `1c-client` собирается вместе с `OneScript`. Переопределить версию можно через `.env`:

```bash
ONESCRIPT_VERSION=2.0.0
```

или разово:

```bash
make build ONESCRIPT_VERSION=2.0.0
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
