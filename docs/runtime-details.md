# Runtime-детали

Репозиторий даёт один основной developer-контейнер:

- `1c-dev`: платформа 1С, GUI/VNC, OneScript, Vanessa tooling, BSL diagnostics и agent-ready skills layer с предсобранными platform help и standards packs.
- `1c-pg`: опциональный PostgreSQL 1C для server/client-server сценариев.

## Runtime modes

`ONEC_RUNTIME_MODE` управляет запуском:

- `shell`: default. Держит контейнер в idle-режиме для ручных или agent-driven команд.
- `license-ui`: первый запуск для ручной активации лицензии через VNC.
- `file-db`: запускает `1cv8 ENTERPRISE /F <path>`.
- `server`: запускает `ragent`.

## Volumes

- `./volumes/1c-dev/data:/mnt/data`
- `./volumes/1c-dev/cache:/root/.1cv8/1C/1cv8/`
- `onec-license-store:/var/1C/licenses`

Не удаляйте `onec-license-store` после активации лицензии.

## Platform Staging

Платформа 1С готовится на host до Docker build:

```bash
make prepare-platform
```

Staging directory: `.local/1c/dev-platform`. Она намеренно ignored by git.

Runtime targets используют готовый image:

- если настроенный image есть локально, он используется как есть;
- если image отсутствует, scripts пробуют `docker pull`;
- если image нельзя скачать или он не agent-ready, команда падает с явной подсказкой `make build`.

Local platform staging запускается только в явных build-командах:

```bash
make prepare-platform
make build
```

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
OACS_VERSION=0.3.1a2
```

Skills закреплены по commit SHA. Обновляйте эти значения только при осознанном refresh agent-ready слоя.
OACS является обязательным agent-layer dependency для Portable Agent Infrastructure memory/context/evidence.

## Agent Context Packs

Во время сборки `1c-dev` `onec-context` создаёт workspace `/opt/onec-agent/context-workspace`:

- platform help pack строится из HBK под `/opt/1cv8`;
- standards pack строится из ITS `v8std` в SQLite/FTS `.db.zst`;
- пути записываются в `/opt/onec-agent/registry.json`.

Project-specific packs (`metadata`, `code`, `full`) строятся отдельно из смонтированного `/workspace/project`. OACS хранит memory, evidence refs, audit и context capsules вокруг найденных фактов, но не заменяет сами packs.
