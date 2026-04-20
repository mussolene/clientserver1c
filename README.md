# clientserver1c

Инфраструктурный репозиторий для локального стенда 1С в Docker.

Основные сервисы:

1. `1c-pg` - `PostgreSQL 1C`
2. `1c-server` - сервер 1С
3. `1c-client` - клиент 1С с VNC, `OneScript`, `opm`, `Vanessa ADD`, `vanessa-runner`

Поддерживаются сборки для `linux/amd64` и `linux/arm64`.

## Как устроена сборка

Основной сценарий теперь идет через `docker compose`, а не через ручной порядок shell-скриптов.

В `docker-compose.yml` описаны не только прикладные сервисы, но и build-only слои:

1. `linux-common-base` - общий системный слой
2. `linux-desktop-base` - GUI/VNC/Xfce слой для клиента
3. `linux-onescript-builder` - промежуточный build-слой для сборки `OneScript` из исходников
4. `linux-onescript` - runtime-слой с готовыми `oscript` и `opm`
5. `1c-pg`
6. `1c-server`
7. `1c-client`

Порядок сборки определяется самим `compose` через `additional_contexts: service:...`.

## Структура

- `base/linux-common/` - Dockerfile общего base-слоя
- `base/linux-desktop/` - Dockerfile desktop-слоя
- `base/linux-onescript-builder/` - Dockerfile builder-слоя `OneScript`
- `base/linux-onescript/` - Dockerfile runtime-слоя `OneScript`
- `pg/` - Dockerfile и helper-скрипты для `PostgreSQL 1C`
- `server/` - Dockerfile серверного контейнера 1С
- `client/` - Dockerfile клиентского контейнера 1С
- `scripts/` - вспомогательные shell-скрипты
- `artifacts/` - overlay, конфиги и вспомогательные файлы для сборки

## Что нужно подготовить

```bash
cp .env.example .env
```

Минимально нужно задать:

- `POSTGRES_PASSWORD`
- `PLATFORM_VERSION`

Для build-time скачивания с ITS нужны:

- `ITS_LOGIN`
- `ITS_PASSWORD`

Если `make build` или `make up` запускаются локально из интерактивного терминала и ITS-учетка не задана, скрипт сам спросит логин/пароль и сохранит их в `.env`.

В CI интерактивного prompt нет: там `ITS_LOGIN` и `ITS_PASSWORD` должны быть заданы заранее.

## Основной запуск

```bash
make up
```

Эта команда:

1. проверяет `.env`
2. при локальном запуске при необходимости запрашивает ITS-учетку
3. запускает `docker compose --profile build build 1c-pg 1c-server 1c-client`
4. затем делает `docker compose up`

Если нужен только build:

```bash
make build
```

Если нужен только просмотр итогового конфига:

```bash
make config
```

## Make targets

- `make env` - создать `.env` из `.env.example`, если его еще нет
- `make up` - основной сценарий: собрать всю цепочку через `compose` и поднять стенд
- `make build` - собрать всю цепочку через `compose`, не запуская контейнеры
- `make config` - проверить итоговый `docker compose config`
- `make down` - остановить стенд
- `make ps` - показать состояние контейнеров
- `make logs` - смотреть логи

Низкоуровневые/вспомогательные цели:

- `make build-common-base`
- `make build-desktop-base`
- `make build-onescript-builder`
- `make build-onescript-base`

Offline/helper цели:

- `make download` - скачать архив платформы в `.local/1c/platform/`
- `make prepare-platform` - подготовить локальные staging-каталоги `.local/1c/server-platform/` и `.local/1c/client-platform/`
- `make clean-platform` - очистить локальные кэши платформы

Основной online-flow не требует `make download` или `make prepare-platform`.

## Build-time скачивание

### Платформа 1С

`1c-server` и `1c-client` скачивают дистрибутивы платформы прямо во время `docker build` через ITS secrets.

Используется [scripts/download-platform-build.sh](/Users/maxon/git/me/clientserver1c/scripts/download-platform-build.sh:1):

- логин на `login.1c.ru`
- поиск релиза на `releases.1c.ru`
- выбор архива по `PLATFORM_VERSION`, `PLATFORM_ARCH`, `TARGETARCH`
- кэширование через BuildKit cache `id=1c-platform-cache`

Архив не коммитится в git и не остается в финальном образе.

### PostgreSQL 1C

`1c-pg` тоже скачивает пакет во время `docker build` через ITS secrets.

Используется [pg/download-postgresql-1c.sh](/Users/maxon/git/me/clientserver1c/pg/download-postgresql-1c.sh:1):

- логин на `login.1c.ru`
- поиск релиза в `AddCompPostgre`
- выбор пакета под нужный дистрибутив и архитектуру
- установка `.deb` сразу в image

Архив также не хранится в репозитории и не остается в финальном image.

## Переменные `.env`

- `POSTGRES_PASSWORD` - пароль PostgreSQL
- `PG_MAJOR` - major-ветка PostgreSQL, по умолчанию `17`
- `PG_1C_VERSION` - версия `PostgreSQL 1C`, по умолчанию `17.7-1.1C`
- `PG_REPO_DIST` - целевой дистрибутив пакета `PostgreSQL 1C`, по умолчанию `bookworm`
- `PLATFORM_VERSION` - версия платформы 1С
- `PLATFORM_ARCH` - `amd64` или `arm64`
- `DOCKER_DEFAULT_PLATFORM` - платформа Docker для явного cross-build, например `linux/amd64` или `linux/arm64`
- `ITS_LOGIN`, `ITS_PASSWORD` - учетные данные ITS

Внутренние версии слоев и toolchain не вынесены в `.env`: они закреплены в Dockerfile, `docker-compose.yml` и CI workflow как внутренняя часть репозитория.

## Архитектура

По умолчанию:

```bash
PLATFORM_ARCH=amd64
```

Для нативной ARM-сборки:

```bash
make build PLATFORM_ARCH=arm64
```

Для явного cross-build:

```bash
make build PLATFORM_ARCH=arm64 DOCKER_DEFAULT_PLATFORM=linux/arm64
make build PLATFORM_ARCH=amd64 DOCKER_DEFAULT_PLATFORM=linux/amd64
```

## OneScript и Vanessa

`OneScript` собирается из исходников в `linux-onescript-builder`, затем переносится в `linux-onescript`, а пакеты:

- `add`
- `vanessa-runner`

ставятся уже в `1c-client` штатно через:

```bash
opm install add
opm install vanessa-runner
```

После сборки в клиентском контейнере доступны:

- `oscript`
- `opm`
- `vrunner`

## GitHub CI

Для публикации образов в `ghcr.io` и `docker.io` в репозитории используется workflow [docker-publish.yml](/Users/maxon/git/me/clientserver1c/.github/workflows/docker-publish.yml:1).

Что нужно подготовить в GitHub:

1. В `Settings -> Secrets and variables -> Actions -> Repository secrets`:
   - `ITS_LOGIN`
   - `ITS_PASSWORD`
   - `DOCKERHUB_TOKEN`
2. В `Settings -> Secrets and variables -> Actions -> Repository variables`:
   - `DOCKERHUB_USERNAME`
   - опционально `DOCKERHUB_NAMESPACE`, если namespace в Docker Hub отличается от `DOCKERHUB_USERNAME`
   - опционально `GHCR_NAMESPACE`, если namespace в GHCR должен отличаться от `github.repository_owner`
3. В Docker Hub:
   - создать access token с правом `Write`
   - создать нужные репозитории или namespace, если у вас это не делается автоматически
4. В GitHub Packages / GHCR:
   - после первого publish при необходимости выставить package visibility
   - если package живет с granular permissions отдельно от репозитория, проверить `Manage Actions access`
5. В `Settings -> Actions`:
   - разрешить запуск workflow
   - если в организации действует restrictive policy, разрешить используемые official actions `actions/*` и `docker/*`

Практический нюанс:

- workflow публикует multi-arch образы для `linux/amd64` и `linux/arm64`
- для внутренних зависимостей цепочки он использует GHCR как промежуточный registry через commit tag `build-<sha>`
- для `1c-client`, `1c-server` и `postgresql` публикуется дополнительный composite tag вида `platform-<PLATFORM_VERSION>-pg-<PG_1C_VERSION>`
- publish запускается на `push` в `main` / `master`, на `v*` tags и вручную через `workflow_dispatch`

## Порты

- `1c-client` VNC: `5900`
- `1c-server`: `1540-1541`, `1560-1691`, `1545`
- `1c-pg`: `5432`

## Замечания

- `artifacts/nethasp.ini` опционален
- `.env` и `.local/` не коммитятся
- `docker-compose.yml` настроен под локальный стенд, не под production
