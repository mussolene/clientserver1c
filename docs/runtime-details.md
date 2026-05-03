# Runtime-детали

Репозиторий даёт один основной developer-контейнер:

- `1c-dev`: платформа 1С, GUI/VNC, OneScript, Vanessa tooling, BSL diagnostics и agent-ready skills layer с предсобранными platform help, BSL developer guide и standards packs.
- `1c-pg`: опциональный PostgreSQL 1C для server/client-server сценариев.

## Runtime modes

`ONEC_RUNTIME_MODE` управляет запуском:

- `shell`: default. Держит контейнер в idle-режиме для ручных или agent-driven команд.
- `license-ui`: первый запуск для ручной активации лицензии через VNC.
- `file-db`: запускает `1cv8 ENTERPRISE /F <path>`.
- `server`: запускает `ragent`.

Во время сборки контейнера 1С installer запускается с компонентом
`desktop_icons`, поэтому меню приложений и icon theme наполняются штатными
launcher/icon файлами 1С. На каждом старте контейнер копирует штатный
`1cestart` launcher на VNC desktop и готовит список баз 1С `ibases.v8i` для
профиля `usr1cv8`. По умолчанию список баз указывает на
`ONEC_FILE_DB_PATH=/mnt/data/testdb`; отображаемое имя задается через
`ONEC_FILE_DB_NAME`.

Если база создана или восстановлена уже после старта контейнера, обновите
список баз вручную:

```bash
onec-agent ibase add --name "SmallBusiness30" --path /mnt/ib/sb30 --home /home/usr1cv8 --owner usr1cv8:grp1cv8
```

## Volumes

- `./volumes/1c-dev/data:/mnt/data`
- `./volumes/1c-dev/cache:/home/usr1cv8/.1cv8/1C/1cv8/`
- `onec-license-store:/var/1C/licenses` для локальной ручной активации

Bootstrap, OACS memory и context packs не требуют активированной лицензии. Для запуска 1С runtime используйте один из двух путей:

- локальная ручная активация через `license-ui` и volume `onec-license-store`; не удаляйте этот volume после активации;
- сетевой HASP через `nethasp.ini`, смонтированный read-only в `/opt/1cv8/conf/nethasp.ini`.

Контейнер на каждом старте включает `UseHwLicenses=1` в
`~/.1C/1cestart/1cestart.cfg` для `root` и `usr1cv8`. Если найден
`nethasp.ini`, контейнер синхронизирует его в системные и пользовательские
runtime-пути 1С. Это закрывает два сценария: GUI/VNC работает от `usr1cv8`, а
agent-driven команды вроде `vrunner`, `ibcmd`, `compileepf` и `decompileepf`
часто запускаются от `root`.

`nethasp.ini` должен быть читаемым внутри контейнера (`chmod 644` на host-файле
при bind mount). GUI-режимы контейнера запускают 1С от `usr1cv8`, поэтому
ручные команды через `docker exec` для конфигуратора, загрузки `.cfe` или
запуска файловой базы обычно выполняйте в том же профиле:

```bash
docker exec -u usr1cv8 -e DISPLAY=:0 1c-dev \
  /opt/1cv8/current/1cv8 DESIGNER /F /mnt/data/testdb /N Администратор
```

Для host helper-команд используйте локальный путь, а не содержимое файла:

```bash
NETHASP_INI_PATH=/absolute/path/to/nethasp.ini \
  make agent-up PROJECT_PATH=/path/to/1c-project
```

Helper создаёт локальный ignored Compose override и монтирует файл read-only в
`/opt/1cv8/conf/nethasp.ini`; startup-скрипт контейнера дальше синхронизирует
его в runtime-профили. В OACS допустимо фиксировать только факт и результат
проверки доступности лицензирования, но не содержимое `nethasp.ini`.

## Platform Staging

Платформа 1С готовится на host до Docker build:

```bash
make prepare-platform
```

Staging directory: `.local/1c/dev-platform`. Она намеренно ignored by git.

Runtime targets используют готовый image:

- если настроенный image есть локально, он используется как есть;
- если image отсутствует, scripts скачивают настроенный опубликованный image;
- если image нельзя скачать или он не agent-ready, команда падает с явной подсказкой `make build`.

Local platform staging запускается только в явных build-командах:

```bash
make prepare-platform
make build
```

## Build Layer Order

Сборка намеренно идёт только для `linux/amd64`. ARM/arm64 сейчас не является
поддержанным target, потому что платформа 1С, desktop runtime и внешние
инструменты проверяются в amd64-контуре.

Слои должны оставаться в таком порядке:

1. `linux-common-base`: общие системные пакеты, locale, fonts, certificates.
2. `linux-desktop-base`: Xfce/VNC/s6 поверх common base.
3. `linux-onescript-builder`: сборка OneScript runtime.
4. `linux-onescript`: runtime OneScript/OPM поверх common base.
5. `postgresql`: опциональный PostgreSQL 1C, не влияет на developer image.
6. `1c-developer`: платформа 1С, Vanessa, BSLLS, OACS, skills и context packs
   поверх desktop base плюс onescript runtime.

Правило зависимости: platform archives, skills, OACS и context packs живут
только в `1c-developer`; базовые Linux/Desktop/OneScript слои не должны знать о
1С platform staging, OACS DB, project `.agent/`, `nethasp.ini` или mounted
workspace. Это держит rebuild scope узким: смена справки/skills/OACS не должна
пересобирать desktop/common base, а смена PostgreSQL 1C не должна пересобирать
developer image.

## Image namespace

Compose и helper-скрипты читают `IMAGE_NAMESPACE`.

Default:

```env
IMAGE_NAMESPACE=ghcr.io/mussolene
```

Для своего private registry:

```env
IMAGE_NAMESPACE=ghcr.io/acme
```

Для Docker Hub:

```env
IMAGE_NAMESPACE=mussolene
```

Имена образов остаются стабильными: `1c-developer`, `linux-common-base`, `linux-desktop-base`, `linux-onescript-builder`, `linux-onescript`, `postgresql`.

## Advanced build pins

`.env.example` содержит pinned версии для повторяемой сборки:

```env
VANESSA_ADD_VERSION=6.8.0
VANESSA_RUNNER_VERSION=2.6.0
VANESSA_AUTOMATION_VERSION=1.2.043.1
BSLLS_VERSION=0.25.0
OACS_VERSION=1.0.0
BSL_DEV_DOCS_REPO=https://github.com/mussolene/BSL_8.5.1_dev_docs
BSL_DEV_DOCS_REF=5feac5e9b9237d4bc134a517834a740157be2809
```

Skills закреплены по commit SHA. Обновляйте эти значения только при осознанном refresh agent-ready слоя.
BSL developer guide закреплен по commit SHA нашего fork и собирается в image как immutable KB pack.
OACS является обязательным agent-layer dependency для Portable Agent Infrastructure memory/context/evidence.

## Environment Contract

Основной контракт переменных живёт в `.env.example`; локальные значения держите
в ignored `.env`.

Runtime/onboarding:

- `PLATFORM_VERSION`: версия platform/image tag.
- `PLATFORM_ARCH=amd64` и `DOCKER_DEFAULT_PLATFORM=linux/amd64`: единственный
  поддержанный target.
- `ONEC_RUNTIME_MODE`: `shell`, `license-ui`, `file-db` или `server`.
- `ONEC_FILE_DB_PATH`, `ONEC_FILE_DB_NAME`: файловая база и имя в `ibases.v8i`.
- `ONEC_PROJECT_PATH` или `PROJECT_PATH`: host project для `agent-*` helpers.
- `OACS_PASSPHRASE`: локальный passphrase для project OACS DB.
- `NETHASP_INI_PATH`: локальный путь к ignored `nethasp.ini`.

Build pins:

- `VANESSA_ADD_VERSION`, `VANESSA_RUNNER_VERSION`,
  `VANESSA_AUTOMATION_VERSION`.
- `BSLLS_VERSION`, `OACS_VERSION`.
- `ONEC_VANESSA_SKILL_REF`, `ONEC_CONTEXT_TOOLKIT_REF`.
- `BSL_DEV_DOCS_REPO`, `BSL_DEV_DOCS_REF`.

Secrets:

- `ITS_LOGIN`, `ITS_PASSWORD` нужны только для явного скачивания/build.
- `POSTGRES_PASSWORD` нужен только при `server`/PostgreSQL mode.
- `nethasp.ini`, ITS credentials, license data, `.agent/oacs/oacs.db`,
  platform archives и local volumes не попадают в git, OACS memory или context
  capsules.

## Agent Context Packs

Во время сборки `1c-dev` `onec-context` создаёт workspace `/opt/onec-agent/context-workspace`:

- platform help pack строится из HBK под `/opt/1cv8`;
- BSL developer guide pack строится из pinned GitHub fork в SQLite/FTS `.db.zst`;
- standards pack строится из ITS `v8std` в SQLite/FTS `.db.zst`;
- пути записываются в `/opt/onec-agent/registry.json`.

Project-specific packs (`metadata`, `code`, `full`) строятся отдельно из смонтированного `/workspace/project`. Bootstrap строит только metadata pack и не пересобирает platform help, потому что platform/standards/BSL developer packs уже лежат в image. OACS хранит memory, evidence refs, audit и context capsules вокруг найденных фактов, но не заменяет сами packs.
