# clientserver1c

Инфраструктурный репозиторий для локального стенда 1С в Docker.

Состав стенда:

1. `1c-client` - клиент 1С с VNC
2. `1c-server` - сервер 1С
3. `1c-pg` - PostgreSQL для 1С

## Структура

- `client/` - Dockerfile клиентского контейнера
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
- `make up` - скачать платформу при необходимости, при необходимости запросить ITS-логин и пароль, затем поднять стенд; принимает `PG_MAJOR`, `PG_REPO_DIST`, `PLATFORM_VERSION`
- `make build` - собрать образы
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
- `ITS_LOGIN` и `ITS_PASSWORD` - учетка для `login.1c.ru` / `releases.1c.ru`; если не заданы, будут запрошены интерактивно и сохранены в `.env`

По умолчанию downloader пытается найти файл нужной версии на `releases.1c.ru`, скачать его в `.local/1c/platform/`, а затем Dockerfile берут архив уже оттуда. Учетные данные остаются только на хосте и не попадают в образ.

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

## Типовой сценарий

```bash
make env
make up
```

1. `make env` создаст `.env`, если его еще нет
2. `make up` при необходимости спросит ITS-логин и пароль, сохранит их в `.env`, скачает платформу и поднимет контейнеры

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

## Порты

- клиент VNC: `localhost:5900`
- сервер 1С: `1540-1541`, `1560-1691`, `1545`
- PostgreSQL: `5432`

## Замечания

- `docker-compose.yml` настроен для локального стенда, не для production
- пароль БД задается через `.env`, а не хранится в git
