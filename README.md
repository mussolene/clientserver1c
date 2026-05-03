# 1c-develop

`1c-develop` - переносимая Docker-среда для разработки, проверки и агентной работы с 1С-проектами.

Идея простая: пользователь скачивает готовый image, монтирует свой проект и сразу получает 1С runtime, VNC, OneScript, Vanessa, BSL Language Server, OACS и 1C-aware agent context без ручной сборки локального набора скриптов.

## Что внутри

- 1С:Предприятие `8.5.1.1302` в desktop/runtime контейнере.
- VNC/Xfce, доступный на `127.0.0.1:5900`.
- OneScript, Vanessa Runner, Vanessa Automation и `bsl-language-server`.
- `onec-agent` для 1C-specific операций: bootstrap, context, MCP config, BSLLS, skills.
- OACS/ACS как прямой слой памяти, evidence и context capsules.
- Prebuilt context packs: platform help, BSL developer guide, ITS standards и локальный metadata pack после bootstrap.
- Опциональный PostgreSQL 1C для server/client-server сценариев.

Изюминка проекта: контейнер не просто запускает 1С. Он подготавливает корректный контекст для IDE-агента: где искать справку, какие skills читать, как строить OACS capsule, куда писать evidence и как не терять проектные решения между итерациями.

## Быстрый старт

Запускайте из корня вашего 1С-проекта. Это минимальный путь: скачать image,
поднять PAI-контейнер, собрать agent context и продолжить работу через тот же
запущенный контейнер.

```bash
docker pull ghcr.io/mussolene/1c-developer:8.5.1.1302
export OACS_PASSPHRASE="<local-oacs-passphrase>"
mkdir -p .onec-runtime/data .onec-runtime/cache

docker run -d \
  --name 1c-dev \
  --platform linux/amd64 \
  -p 127.0.0.1:5900:5900 \
  -v onec-license-store:/var/1C/licenses \
  -v "$PWD":/workspace/project \
  -v "$PWD/.onec-runtime/data":/mnt/data \
  -v "$PWD/.onec-runtime/cache":/home/usr1cv8/.1cv8/1C/1cv8 \
  -e ONEC_RUNTIME_MODE=shell \
  -e ONEC_PROJECT_ROOT=/workspace/project \
  -e OACS_PASSPHRASE="$OACS_PASSPHRASE" \
  ghcr.io/mussolene/1c-developer:8.5.1.1302

docker exec -it 1c-dev onec-agent bootstrap
```

Ожидаемый TTM для нового проекта: скачать image, запустить контейнер и получить
`.agent/bootstrap-report.md` без локальной сборки. Лицензия 1С не нужна для
bootstrap, OACS memory и context lookup; она потребуется позже для запуска GUI,
`vrunner`, `ibcmd` и других runtime-команд 1С.

После bootstrap:

1. Откройте VNC: `localhost:5900`. В меню приложений и на рабочем столе будет штатный launcher 1С; файловая база из `ONEC_FILE_DB_PATH` будет добавлена в список баз 1С.
2. Дайте IDE-агенту прочитать `.agent/bootstrap-report.md`.
3. Держите контейнер запущенным и выполняйте дальнейшие команды через `docker exec`.

```bash
docker exec -it 1c-dev onec-agent doctor
docker exec -it 1c-dev acs memory query --query "текущая задача" --scope project --json
docker exec -it 1c-dev acs context build --intent "текущая задача" --scope project --json
docker exec -it 1c-dev onec-agent context --query "ЗаписьJSON" --pack platform --limit 5
docker exec -it 1c-dev acs run --label "readiness" --scope project --json -- onec-agent doctor
```

Bootstrap, ACS memory и context packs не требуют лицензии 1С. Лицензия нужна
только для запуска самого 1С runtime.

## Лицензирование

Поддерживаются два чистых пути:

- локальная ручная активация: используйте Docker volume `onec-license-store` (`/var/1C/licenses`) и не удаляйте его после активации;
- сетевой HASP: подготовьте `nethasp.ini` и смонтируйте его в контейнер.

По умолчанию контейнер включает поиск аппаратной лицензии 1С (`UseHwLicenses=1`)
для профилей `root` и `usr1cv8`. Это важно для VNC-сессии, `vrunner`,
`ibcmd`, `compileepf/decompileepf` и ручных команд через `docker exec`.

Запустить штатный UI для ручной активации:

```bash
docker exec -d -u usr1cv8 -e DISPLAY=:0 1c-dev /opt/1cv8/current/1cv8c
```

Пример для сетевого HASP:

```bash
chmod 644 ./nethasp.ini
docker run -d \
  --name 1c-dev \
  --platform linux/amd64 \
  -p 127.0.0.1:5900:5900 \
  -v "$PWD":/workspace/project \
  -v "$PWD/.onec-runtime/data":/mnt/data \
  -v "$PWD/.onec-runtime/cache":/home/usr1cv8/.1cv8/1C/1cv8 \
  -v "$PWD/nethasp.ini":/opt/1cv8/conf/nethasp.ini:ro \
  -e ONEC_RUNTIME_MODE=shell \
  -e ONEC_PROJECT_ROOT=/workspace/project \
  -e OACS_PASSPHRASE="$OACS_PASSPHRASE" \
  ghcr.io/mussolene/1c-developer:8.5.1.1302
```

Файл `nethasp.ini` не коммитьте. Достаточно смонтировать его в
`/opt/1cv8/conf/nethasp.ini`; при старте контейнер синхронизирует этот файл в
профили `root` и `usr1cv8`, чтобы одинаково работали GUI, `vrunner`, `ibcmd` и
другие runtime-команды.

Если используете helper-команды из этого репозитория, задайте только локальный
путь к файлу:

```bash
export NETHASP_INI_PATH=/absolute/path/to/nethasp.ini
make -C /path/to/1c-develop agent-up PROJECT_PATH="$PWD"
```

`NETHASP_INI_PATH` можно положить в локальный `.env`, но сам `nethasp.ini`, его
содержимое и данные лицензии не должны попадать в git, OACS memory или
context capsule.

## Работа с агентом

Агент остается в Cursor, Codex, VS Code или другом IDE на host. Контейнер дает runtime и проверенные 1C facts.

`onec-agent bootstrap` создает в смонтированном проекте:

- `.agent/oacs/` с project-local ACS state;
- `.agent/bootstrap-report.md` и инструкции для IDE-агента;
- `.agent/context-capsules/`, `.agent/mcp/` и `.agent/reports/` с context/evidence артефактами.

Если `.agent/AGENTS.md` еще нет, bootstrap создаст IDE entrypoint. Если файл уже существует, bootstrap его не перезаписывает.
Полный список bootstrap-артефактов: [bootstrap.md](bootstrap.md).

Правило работы:

- память и evidence пишутся напрямую через `acs`;
- `onec-agent` используется только как 1C adapter для context, MCP, diagnostics и runtime checks;
- контейнер не пересоздается для каждой задачи.

Подробнее: [docs/agent-ready.md](docs/agent-ready.md).

## Через Make

Если вы работаете из clone этого репозитория, доступны transport-команды:

| Команда | Назначение |
| --- | --- |
| `make env` | создать `.env` из `.env.example`, если его еще нет |
| `make doctor` | проверить Docker, image, staging, license volume и agent mode |
| `make pull` | скачать настроенный developer image |
| `make first-start` | запустить optional local license UI |
| `make up` | поднять shell/agent-ready runtime для самого 1c-develop workspace |
| `make up-file-db` | запустить file DB mode после настройки лицензирования |
| `make up-server` | запустить server mode вместе с PostgreSQL 1C |
| `make ui-smoke` | прогнать минимальный Vanessa UI smoke |
| `make xunit-smoke` | прогнать xUnit smoke по EPF |
| `make agent-context` | transport-helper для context-команд внутри контейнера |
| `make agent-bslls` | запустить BSL Language Server diagnostics |
| `make agent-epf-roundtrip` | разобрать и собрать EPF внутри mounted проекта |

Пример из 1С-проекта:

```bash
make -C /path/to/1c-develop agent-up PROJECT_PATH="$PWD"
make -C /path/to/1c-develop agent-doctor PROJECT_PATH="$PWD"
make -C /path/to/1c-develop agent-context PROJECT_PATH="$PWD" TASK="текущая задача"
make -C /path/to/1c-develop agent-context PROJECT_PATH="$PWD" TASK="метаданные" QUERY="Заявки" PACK=metadata LIMIT=5
make -C /path/to/1c-develop agent-epf-roundtrip PROJECT_PATH="$PWD" EPF_PATH=tests/xunit/epf/Test.epf
```

Для сетевого HASP добавьте к `agent-up` `NETHASP_INI_PATH=/absolute/path/to/nethasp.ini`.

## Runtime

Обычный `make up` поднимает shell/agent-ready контейнер без окна добавления базы.
VNC поднимается по умолчанию и доступен только на localhost. 1С installer ставит
штатный launcher и иконки через компонент `desktop_icons`; при старте контейнер
копирует этот launcher на рабочий стол и готовит `ibases.v8i` для пользователя
`usr1cv8`. Имя и путь базы задаются через `ONEC_FILE_DB_NAME` и
`ONEC_FILE_DB_PATH`.

После ручного создания или восстановления файловой базы обновите список баз без перезапуска контейнера:

```bash
docker exec -it 1c-dev onec-agent ibase add --name "SmallBusiness30" --path /mnt/ib/sb30 --home /home/usr1cv8 --owner usr1cv8:grp1cv8
```

Порты:

- `127.0.0.1:5900` - VNC;
- `5432` - PostgreSQL 1C, только если поднят `make up-server`.

Server ports 1C наружу по умолчанию не публикуются. Для локальной разработки и file DB они не нужны.

Runtime modes, platform staging, volumes, architecture и prebuilt context packs описаны в [docs/runtime-details.md](docs/runtime-details.md).

## Проверки

Быстрая проверка agent-ready слоя:

```bash
docker exec -it 1c-dev onec-agent doctor
docker exec -it 1c-dev acs run --label "readiness" --scope project --json -- onec-agent doctor
docker exec -it 1c-dev acs resume --scope project --json
```

В репозитории есть минимальный Vanessa smoke для связки `TestManager -> TestClient`.

```bash
make ui-smoke
```

Runner: [`scripts/run-ui-smoke.sh`](scripts/run-ui-smoke.sh). Артефакты сохраняются в `./volumes/1c-dev/data/workspace/artifacts`.

Для xUnit smoke:

```bash
make xunit-smoke
```

Runner: [`scripts/run-xunit-smoke.sh`](scripts/run-xunit-smoke.sh). Скрипт пишет `status.txt` даже при ошибках раннера/таймаутах и сохраняет process snapshot в `artifacts/xunit/processes.txt`.

Для проверки, что контейнер умеет разобрать и собрать существующую обработку
проекта:

```bash
make agent-epf-roundtrip PROJECT_PATH=/path/to/1c-project EPF_PATH=tests/xunit/epf/Test.epf
```

Runner: [`scripts/agent-epf-roundtrip.sh`](scripts/agent-epf-roundtrip.sh). Он
использует mounted project в `/workspace/project`, вызывает
`vrunner decompileepf` и `vrunner compileepf`, затем оставляет результат в
`.agent/runtime/epf-roundtrip/<имя-epf>/`.

## Локальная сборка

Для pull-based onboarding сборка не нужна: достаточно скачать image и выполнить `onec-agent bootstrap`.

Если готового image нет или вы меняете Dockerfile:

```bash
make env
make build
```

Для локальной сборки с ITS нужны `ITS_LOGIN` и `ITS_PASSWORD`. Если они пустые, build targets запросят их один раз и сохранят в `.env`. Не коммитьте `.env`.

По умолчанию compose и helper-скрипты используют `IMAGE_NAMESPACE=ghcr.io/mussolene`. Для private registry задайте свой namespace в `.env`.

## Структура

- `client/` - developer image с 1С runtime, OneScript zip install и agent-ready слоем.
- `base/` - базовые Linux/Desktop images.
- `pg/` - PostgreSQL 1C image.
- `agent/` - container-side `onec-agent`, registry и local OACS skill.
- `scripts/` - host transport commands и build/run helpers.
- `artifacts/` - runtime overlay, VNC services, configs и smoke assets.
- `docs/` - подробности по runtime, OACS workflow и agent-ready режиму.

## CI publish

Workflow [`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml) публикует:

- `linux-common-base`
- `linux-desktop-base`
- `postgresql`
- `1c-developer`

Publish запускается вручную через `workflow_dispatch` или по git-тегам `v*`.

## Важно

- `.env`, `.agent/`, `.local/`, `.onec-runtime/` и локальные volume-данные не коммитятся.
- `nethasp.ini`, license data, ITS credentials и OACS DB не должны попадать в git или OACS memory.
- Проект сейчас поддерживает 1С platform runtime в `linux/amd64` mode.
- Compose настроен под локальную разработку, не под production.
