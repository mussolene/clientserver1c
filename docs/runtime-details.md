# Runtime-детали

Репозиторий даёт один основной developer-контейнер:

- `1c-dev`: платформа 1С, GUI/VNC/RDP, OneScript, Vanessa tooling, BSL diagnostics, OACS/ACS и agent-ready skills layer. Knowledge retrieval подключается через внешний `1c_hbk_helper` / `onec-context-mcp`.
- `1c-pg`: опциональный PostgreSQL 1C для server/client-server сценариев.

## Runtime modes

`ONEC_RUNTIME_MODE` управляет запуском:

- `shell`: default. Держит контейнер в idle-режиме для ручных или agent-driven команд.
- `license-ui`: первый запуск для ручной активации лицензии через VNC.
- `file-db`: запускает `1cv8 ENTERPRISE /F <path>`.
- `server`: запускает `ragent`.

Desktop transport поднимается сразу в двух стандартных вариантах:

- TigerVNC `Xvnc` на `127.0.0.1:5900` как основной X/VNC server для desktop `:0`.
- xrdp на `127.0.0.1:3389`; по умолчанию login `usr1cv8` / `1cdev`,
  переопределяется через `ONEC_RDP_USER` и `ONEC_RDP_PASSWORD`.

Во время сборки контейнера 1С installer запускается с компонентом
`desktop_icons`, поэтому меню приложений и icon theme наполняются штатными
launcher/icon файлами 1С. На каждом старте контейнер копирует штатный
`1cestart` launcher на VNC desktop и готовит список баз 1С `ibases.v8i` для
профиля `usr1cv8`. По умолчанию список баз указывает на
`ONEC_FILE_DB_PATH=/mnt/data/testdb`; отображаемое имя задается через
`ONEC_FILE_DB_NAME`.

Для pull-only запуска без project mount используйте container-side команду:

```bash
onec-agent quickstart
```

Она проверяет VNC и инструменты, регистрирует demo file DB в `ibases.v8i`,
пытается создать её через `ibcmd`, если доступна лицензия, и печатает следующие
команды. Project-local OACS memory она не создаёт; для этого нужен
`onec-agent bootstrap` со смонтированным проектом.

Если база создана или восстановлена уже после старта контейнера, обновите
список баз вручную:

```bash
onec-agent ibase add --name "SmallBusiness30" --path /mnt/ib/sb30 --home /home/usr1cv8 --owner usr1cv8:grp1cv8
```

## Volumes

- `./volumes/1c-dev/data:/mnt/data`
- `./volumes/1c-dev/cache:/home/usr1cv8/.1cv8/1C/1cv8/`
- `onec-license-store:/var/1C/licenses` для локальной ручной активации

Standalone quickstart, bootstrap и OACS memory не требуют
активированной лицензии. Для запуска 1С runtime используйте один из двух путей:

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
3. `postgresql`: опциональный PostgreSQL 1C, не влияет на developer image.
4. `1c-developer`: desktop base плюс платформа 1С, downloaded OneScript zip,
   Vanessa, onec-hbk-bsl, OACS и local skills.

Правило зависимости: platform archives, OneScript, skills и OACS
живут только в `1c-developer`; базовые Linux/Desktop слои не должны знать о 1С
platform staging, OACS DB, project `.agent/`, `nethasp.ini` или mounted
workspace. Это держит rebuild scope понятным: смена skills/OACS не
пересобирает desktop/common base, а смена PostgreSQL 1C не пересобирает
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

Имена образов остаются стабильными: `1c-developer`, `linux-common-base`, `linux-desktop-base`, `postgresql`.

## Advanced build pins

`.env.example` содержит pinned версии для повторяемой сборки:

```env
VANESSA_ADD_VERSION=6.8.0
VANESSA_RUNNER_VERSION=2.6.0
VANESSA_AUTOMATION_VERSION=1.2.043.1
ONESCRIPT_VERSION=2.0.1
ONEC_HBK_BSL_VERSION=0.7.41
OACS_VERSION=1.0.14
```

Skills закреплены по commit SHA. Обновляйте эти значения только при осознанном refresh agent-ready слоя.
OACS является обязательным agent-layer dependency для Portable Agent Infrastructure memory/context/evidence. Image также включает local `codex-oacs-runtime` skill как компактный Codex/OACS workflow layer.

## Environment Contract

Основной контракт переменных живёт в `.env.example`; локальные значения держите
в ignored `.env`.

Runtime/onboarding:

- `PLATFORM_VERSION`: версия platform/image tag.
- `PLATFORM_ARCH=amd64` и `DOCKER_DEFAULT_PLATFORM=linux/amd64`: единственный
  поддержанный target.
- `ONEC_RUNTIME_MODE`: `shell`, `license-ui`, `file-db` или `server`.
- `ONEC_RDP_USER`, `ONEC_RDP_PASSWORD`: локальный RDP login для `xrdp` backend.
- `ONEC_FILE_DB_PATH`, `ONEC_FILE_DB_NAME`: файловая база и имя в `ibases.v8i`.
- `ONEC_PROJECT_PATH` или `PROJECT_PATH`: host project для `agent-*` helpers.
- `OACS_PASSPHRASE`: локальный passphrase для project OACS DB; standalone
  quickstart без project mount его не требует.
- `NETHASP_INI_PATH`: локальный путь к ignored `nethasp.ini`.

Build pins:

- `VANESSA_ADD_VERSION`, `VANESSA_RUNNER_VERSION`,
  `VANESSA_AUTOMATION_VERSION`.
- `ONEC_HBK_BSL_VERSION`, `OACS_VERSION`.
- `ONEC_VANESSA_SKILL_REF`.
- `ONEC_CONTEXT_MCP_URL`: URL внешнего `onec-context-mcp` для generated MCP config.

Secrets:

- `POSTGRES_PASSWORD` нужен только при `server`/PostgreSQL mode.
- `nethasp.ini`, license data, `.agent/oacs/oacs.db`,
  platform archives и local volumes не попадают в git, OACS memory или context
  capsules.

## Agent Context MCP

`1c-dev` больше не собирает и не хранит embedded context packs. Во время build
image не скачивает ITS standards, не клонирует BSL developer docs и не создаёт
SQLite/FTS packs. Для platform help, standards, snippets и metadata используйте
внешний `1c_hbk_helper` / `onec-context-mcp`.

Bootstrap записывает MCP config в `.agent/mcp/onec-context-mcp.json`.
По умолчанию URL равен `http://localhost:8050/mcp`; переопределите его через
`ONEC_CONTEXT_MCP_URL`, если MCP endpoint доступен по другому адресу. OACS
хранит memory, evidence refs, audit и context capsules вокруг найденных фактов,
но не заменяет сам retrieval service.

Registry также содержит local skills `/opt/onec-agent/skills/memory` и
`/opt/onec-agent/skills/codex_oacs_runtime`. Первый описывает прямой ACS memory
loop, второй задаёт компактный Codex/OACS runtime loop для repo work,
checkpoint/evidence и явно запрошенной multi-agent координации.
