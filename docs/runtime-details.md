# Runtime-детали

Репозиторий даёт один основной developer-контейнер:

- `1c-dev`: платформа 1С, GUI/VNC, OneScript, Vanessa tooling, BSL diagnostics и agent-ready skills layer.
- `1c-pg`: опциональный PostgreSQL 1C для server/client-server сценариев.

## Runtime modes

`ONEC_RUNTIME_MODE` управляет запуском:

- `license-ui`: первый запуск для ручной активации лицензии через VNC.
- `file-db`: запускает `1cv8 ENTERPRISE /F <path>`.
- `server`: запускает `ragent`.
- `shell`: держит контейнер в idle-режиме для ручных или agent-driven команд.

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

## Advanced build pins

`.env.example` содержит pinned версии для повторяемой сборки:

```env
VANESSA_ADD_VERSION=6.9.5
VANESSA_RUNNER_VERSION=2.6.0
VANESSA_AUTOMATION_VERSION=1.2.043.1
BSLLS_VERSION=0.25.0
```

Skills закреплены по commit SHA. Обновляйте эти значения только при осознанном refresh agent-ready слоя.
