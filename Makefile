SHELL := /bin/bash

ENV_FILE ?= .env
DOCKER_COMPOSE ?= docker compose
POSTGRES_PASSWORD ?= test-local
PG_MAJOR ?=
PG_1C_VERSION ?=
PG_REPO_DIST ?=
PLATFORM_VERSION ?=
PLATFORM_ARCH ?=
PLATFORM_DIST_NAME ?=
DOCKER_DEFAULT_PLATFORM ?=
ONEC_PLATFORM_OVERRIDE ?=

COMPOSE_FILES := -f docker-compose.yml $(if $(filter native-arm,$(ONEC_PLATFORM_OVERRIDE)),-f docker-compose.onec-native-arm.yml)

.PHONY: help env doctor first-start download prepare-platform build-common-base build-desktop-base build-onescript-builder build-onescript-base up up-file-db up-server build build-server-stack ui-smoke agent-up agent-exec agent-doctor agent-skills agent-skill agent-bslls agent-bslls-format config down ps logs clean-platform clean

help:
	@printf '%s\n' \
	  'Common targets:' \
	  '  make env             - create .env from .env.example if missing' \
	  '  make doctor          - check local readiness and print next commands' \
	  '  make first-start     - create .env if needed, then start the license UI' \
	  '  make up              - prepare platform, build missing image, start license UI' \
	  '  make up-file-db      - start 1c-dev in file DB mode after license activation' \
	  '  make ui-smoke        - run the tracked Vanessa UI smoke' \
	  '' \
	  'IDE-agent targets:' \
	  '  make agent-up PROJECT_PATH=$$PWD       - start 1c-dev with project mounted' \
	  '  make agent-doctor PROJECT_PATH=$$PWD   - check agent-ready runtime inside 1c-dev' \
	  '  make agent-exec CMD="..."             - run command in /workspace/project' \
	  '  make agent-bslls SRC_DIR=src/cf       - run BSL Language Server diagnostics' \
	  '  make agent-bslls-format SRC_DIR=src/cf - format BSL files' \
	  '' \
	  'Advanced targets:' \
	  '  make download        - download the 1C platform archive into .local/1c/platform' \
	  '  make prepare-platform - prepare local staging inputs in .local/1c/dev-platform' \
	  '  make build           - prepare platform and build only the developer image' \
	  '  make up-server       - start server mode with PostgreSQL 1C' \
	  '  make build-server-stack - build developer image plus PostgreSQL 1C' \
	  '  make build-common-base / build-desktop-base / build-onescript-*' \
	  '  make config          - validate docker compose config' \
	  '  make down / ps / logs / clean-platform / clean' \
	  '' \
	  'Examples:' \
	  '  make doctor' \
	  '  make first-start' \
	  '  make up-file-db' \
	  '  make agent-up PROJECT_PATH=/path/to/1c-project' \
	  '  make agent-bslls PROJECT_PATH=/path/to/1c-project SRC_DIR=src/cf' \
	  '' \
	  'See README.md and docs/ for advanced build and runtime options.'

env:
	@if [[ ! -f "$(ENV_FILE)" ]]; then \
	  cp .env.example "$(ENV_FILE)"; \
	  echo "Created $(ENV_FILE) from .env.example"; \
	else \
	  echo "$(ENV_FILE) already exists"; \
	fi

doctor:
	@env ENV_FILE="$(abspath $(ENV_FILE))" DOCTOR_STRICT="$(DOCTOR_STRICT)" bash ./scripts/doctor.sh

first-start: env
	@$(MAKE) --no-print-directory up

download:
	@env_args=(); \
	if [[ -n "$(PLATFORM_VERSION)" ]]; then env_args+=(PLATFORM_VERSION="$(PLATFORM_VERSION)"); fi; \
	if [[ -n "$(PLATFORM_ARCH)" ]]; then env_args+=(PLATFORM_ARCH="$(PLATFORM_ARCH)"); fi; \
	if [[ -n "$(PLATFORM_DIST_NAME)" ]]; then env_args+=(PLATFORM_DIST_NAME="$(PLATFORM_DIST_NAME)"); fi; \
	env ENV_FILE="$(abspath $(ENV_FILE))" "$${env_args[@]}" ./scripts/download-platform.sh

prepare-platform:
	@env_args=(); \
	if [[ -n "$(PLATFORM_VERSION)" ]]; then env_args+=(PLATFORM_VERSION="$(PLATFORM_VERSION)"); fi; \
	if [[ -n "$(PLATFORM_ARCH)" ]]; then env_args+=(PLATFORM_ARCH="$(PLATFORM_ARCH)"); fi; \
	if [[ -n "$(DOCKER_DEFAULT_PLATFORM)" ]]; then env_args+=(DOCKER_DEFAULT_PLATFORM="$(DOCKER_DEFAULT_PLATFORM)"); fi; \
	if [[ -n "$(PLATFORM_DIST_NAME)" ]]; then env_args+=(PLATFORM_DIST_NAME="$(PLATFORM_DIST_NAME)"); fi; \
	env ENV_FILE="$(abspath $(ENV_FILE))" "$${env_args[@]}" ./scripts/prepare-platform.sh

build-common-base:
	@env_args=(); \
	if [[ -n "$(DOCKER_DEFAULT_PLATFORM)" ]]; then env_args+=(DOCKER_DEFAULT_PLATFORM="$(DOCKER_DEFAULT_PLATFORM)"); fi; \
	env ENV_FILE="$(abspath $(ENV_FILE))" "$${env_args[@]}" bash ./scripts/build-common-base.sh

build-desktop-base:
	@env_args=(); \
	if [[ -n "$(DOCKER_DEFAULT_PLATFORM)" ]]; then env_args+=(DOCKER_DEFAULT_PLATFORM="$(DOCKER_DEFAULT_PLATFORM)"); fi; \
	env ENV_FILE="$(abspath $(ENV_FILE))" "$${env_args[@]}" bash ./scripts/build-desktop-base.sh

build-onescript-builder:
	@env_args=(); \
	if [[ -n "$(DOCKER_DEFAULT_PLATFORM)" ]]; then env_args+=(DOCKER_DEFAULT_PLATFORM="$(DOCKER_DEFAULT_PLATFORM)"); fi; \
	env ENV_FILE="$(abspath $(ENV_FILE))" "$${env_args[@]}" bash ./scripts/build-onescript-builder.sh

build-onescript-base:
	@env_args=(); \
	if [[ -n "$(DOCKER_DEFAULT_PLATFORM)" ]]; then env_args+=(DOCKER_DEFAULT_PLATFORM="$(DOCKER_DEFAULT_PLATFORM)"); fi; \
	env ENV_FILE="$(abspath $(ENV_FILE))" "$${env_args[@]}" bash ./scripts/build-onescript-base.sh

up:
	@env_args=(); \
	if [[ -n "$(DOCKER_DEFAULT_PLATFORM)" ]]; then env_args+=(DOCKER_DEFAULT_PLATFORM="$(DOCKER_DEFAULT_PLATFORM)"); fi; \
	if [[ -n "$(PG_MAJOR)" ]]; then env_args+=(PG_MAJOR="$(PG_MAJOR)"); fi; \
	if [[ -n "$(PG_1C_VERSION)" ]]; then env_args+=(PG_1C_VERSION="$(PG_1C_VERSION)"); fi; \
	if [[ -n "$(PG_REPO_DIST)" ]]; then env_args+=(PG_REPO_DIST="$(PG_REPO_DIST)"); fi; \
	if [[ -n "$(PLATFORM_VERSION)" ]]; then env_args+=(PLATFORM_VERSION="$(PLATFORM_VERSION)"); fi; \
	if [[ -n "$(PLATFORM_ARCH)" ]]; then env_args+=(PLATFORM_ARCH="$(PLATFORM_ARCH)"); fi; \
	if [[ -n "$(PLATFORM_DIST_NAME)" ]]; then env_args+=(PLATFORM_DIST_NAME="$(PLATFORM_DIST_NAME)"); fi; \
	if [[ -n "$(ONEC_PLATFORM_OVERRIDE)" ]]; then env_args+=(ONEC_PLATFORM_OVERRIDE="$(ONEC_PLATFORM_OVERRIDE)"); fi; \
	env ENV_FILE="$(abspath $(ENV_FILE))" "$${env_args[@]}" ./scripts/up.sh

up-file-db:
	@env_args=(ONEC_RUNTIME_MODE=file-db); \
	if [[ -n "$(ONEC_FILE_DB_PATH)" ]]; then env_args+=(ONEC_FILE_DB_PATH="$(ONEC_FILE_DB_PATH)"); fi; \
	if [[ -n "$(DOCKER_DEFAULT_PLATFORM)" ]]; then env_args+=(DOCKER_DEFAULT_PLATFORM="$(DOCKER_DEFAULT_PLATFORM)"); fi; \
	if [[ -n "$(PG_MAJOR)" ]]; then env_args+=(PG_MAJOR="$(PG_MAJOR)"); fi; \
	if [[ -n "$(PG_1C_VERSION)" ]]; then env_args+=(PG_1C_VERSION="$(PG_1C_VERSION)"); fi; \
	if [[ -n "$(PG_REPO_DIST)" ]]; then env_args+=(PG_REPO_DIST="$(PG_REPO_DIST)"); fi; \
	if [[ -n "$(PLATFORM_VERSION)" ]]; then env_args+=(PLATFORM_VERSION="$(PLATFORM_VERSION)"); fi; \
	if [[ -n "$(PLATFORM_ARCH)" ]]; then env_args+=(PLATFORM_ARCH="$(PLATFORM_ARCH)"); fi; \
	if [[ -n "$(PLATFORM_DIST_NAME)" ]]; then env_args+=(PLATFORM_DIST_NAME="$(PLATFORM_DIST_NAME)"); fi; \
	if [[ -n "$(ONEC_PLATFORM_OVERRIDE)" ]]; then env_args+=(ONEC_PLATFORM_OVERRIDE="$(ONEC_PLATFORM_OVERRIDE)"); fi; \
	env ENV_FILE="$(abspath $(ENV_FILE))" "$${env_args[@]}" ./scripts/up.sh

up-server:
	@env_args=(ONEC_RUNTIME_MODE=server ONEC_WITH_PG=1); \
	if [[ -n "$(DOCKER_DEFAULT_PLATFORM)" ]]; then env_args+=(DOCKER_DEFAULT_PLATFORM="$(DOCKER_DEFAULT_PLATFORM)"); fi; \
	if [[ -n "$(PG_MAJOR)" ]]; then env_args+=(PG_MAJOR="$(PG_MAJOR)"); fi; \
	if [[ -n "$(PG_1C_VERSION)" ]]; then env_args+=(PG_1C_VERSION="$(PG_1C_VERSION)"); fi; \
	if [[ -n "$(PG_REPO_DIST)" ]]; then env_args+=(PG_REPO_DIST="$(PG_REPO_DIST)"); fi; \
	if [[ -n "$(PLATFORM_VERSION)" ]]; then env_args+=(PLATFORM_VERSION="$(PLATFORM_VERSION)"); fi; \
	if [[ -n "$(PLATFORM_ARCH)" ]]; then env_args+=(PLATFORM_ARCH="$(PLATFORM_ARCH)"); fi; \
	if [[ -n "$(PLATFORM_DIST_NAME)" ]]; then env_args+=(PLATFORM_DIST_NAME="$(PLATFORM_DIST_NAME)"); fi; \
	if [[ -n "$(ONEC_PLATFORM_OVERRIDE)" ]]; then env_args+=(ONEC_PLATFORM_OVERRIDE="$(ONEC_PLATFORM_OVERRIDE)"); fi; \
	env ENV_FILE="$(abspath $(ENV_FILE))" "$${env_args[@]}" ./scripts/up.sh

build:
	@env_args=(); \
	if [[ -f "$(ENV_FILE)" ]]; then set -a; . "$(ENV_FILE)"; set +a; fi; \
	if [[ -n "$(DOCKER_DEFAULT_PLATFORM)" ]]; then env_args+=(DOCKER_DEFAULT_PLATFORM="$(DOCKER_DEFAULT_PLATFORM)"); fi; \
	if [[ -n "$(PG_MAJOR)" ]]; then env_args+=(PG_MAJOR="$(PG_MAJOR)"); fi; \
	if [[ -n "$(PG_1C_VERSION)" ]]; then env_args+=(PG_1C_VERSION="$(PG_1C_VERSION)"); fi; \
	if [[ -n "$(PG_REPO_DIST)" ]]; then env_args+=(PG_REPO_DIST="$(PG_REPO_DIST)"); fi; \
	if [[ -n "$(PLATFORM_VERSION)" ]]; then env_args+=(PLATFORM_VERSION="$(PLATFORM_VERSION)"); fi; \
	if [[ -n "$(PLATFORM_ARCH)" ]]; then env_args+=(PLATFORM_ARCH="$(PLATFORM_ARCH)"); fi; \
	if [[ -n "$(PLATFORM_DIST_NAME)" ]]; then env_args+=(PLATFORM_DIST_NAME="$(PLATFORM_DIST_NAME)"); fi; \
	if [[ -n "$(ONEC_PLATFORM_OVERRIDE)" ]]; then env_args+=(ONEC_PLATFORM_OVERRIDE="$(ONEC_PLATFORM_OVERRIDE)"); fi; \
	env ENV_FILE="$(abspath $(ENV_FILE))" "$${env_args[@]}" bash ./scripts/prepare-platform.sh; \
	env "$${env_args[@]}" $(DOCKER_COMPOSE) $(COMPOSE_FILES) --profile build build 1c-dev

build-server-stack:
	@env_args=(); \
	if [[ -f "$(ENV_FILE)" ]]; then set -a; . "$(ENV_FILE)"; set +a; fi; \
	if [[ -n "$(DOCKER_DEFAULT_PLATFORM)" ]]; then env_args+=(DOCKER_DEFAULT_PLATFORM="$(DOCKER_DEFAULT_PLATFORM)"); fi; \
	if [[ -n "$(PG_MAJOR)" ]]; then env_args+=(PG_MAJOR="$(PG_MAJOR)"); fi; \
	if [[ -n "$(PG_1C_VERSION)" ]]; then env_args+=(PG_1C_VERSION="$(PG_1C_VERSION)"); fi; \
	if [[ -n "$(PG_REPO_DIST)" ]]; then env_args+=(PG_REPO_DIST="$(PG_REPO_DIST)"); fi; \
	if [[ -n "$(PLATFORM_VERSION)" ]]; then env_args+=(PLATFORM_VERSION="$(PLATFORM_VERSION)"); fi; \
	if [[ -n "$(PLATFORM_ARCH)" ]]; then env_args+=(PLATFORM_ARCH="$(PLATFORM_ARCH)"); fi; \
	if [[ -n "$(PLATFORM_DIST_NAME)" ]]; then env_args+=(PLATFORM_DIST_NAME="$(PLATFORM_DIST_NAME)"); fi; \
	if [[ -n "$(ONEC_PLATFORM_OVERRIDE)" ]]; then env_args+=(ONEC_PLATFORM_OVERRIDE="$(ONEC_PLATFORM_OVERRIDE)"); fi; \
	env ENV_FILE="$(abspath $(ENV_FILE))" "$${env_args[@]}" bash ./scripts/prepare-platform.sh; \
	env "$${env_args[@]}" $(DOCKER_COMPOSE) $(COMPOSE_FILES) --profile build build 1c-pg 1c-dev

ui-smoke:
	@env_args=(); \
	if [[ -n "$(PLATFORM_VERSION)" ]]; then env_args+=(PLATFORM_VERSION="$(PLATFORM_VERSION)"); fi; \
	if [[ -n "$(IB_CONNECTION)" ]]; then env_args+=(IB_CONNECTION="$(IB_CONNECTION)"); fi; \
	if [[ -n "$(DB_USER)" ]]; then env_args+=(DB_USER="$(DB_USER)"); fi; \
	if [[ -n "$(DB_PWD)" ]]; then env_args+=(DB_PWD="$(DB_PWD)"); fi; \
	env "$${env_args[@]}" bash ./scripts/run-ui-smoke.sh

agent-up:
	@env_args=(ONEC_RUNTIME_MODE=$${ONEC_RUNTIME_MODE:-shell}); \
	if [[ -n "$(PROJECT_PATH)" ]]; then env_args+=(PROJECT_PATH="$(PROJECT_PATH)"); fi; \
	if [[ -n "$(ONEC_PROJECT_PATH)" ]]; then env_args+=(ONEC_PROJECT_PATH="$(ONEC_PROJECT_PATH)"); fi; \
	if [[ -n "$(PLATFORM_VERSION)" ]]; then env_args+=(PLATFORM_VERSION="$(PLATFORM_VERSION)"); fi; \
	if [[ -n "$(PLATFORM_ARCH)" ]]; then env_args+=(PLATFORM_ARCH="$(PLATFORM_ARCH)"); fi; \
	if [[ -n "$(PLATFORM_DIST_NAME)" ]]; then env_args+=(PLATFORM_DIST_NAME="$(PLATFORM_DIST_NAME)"); fi; \
	if [[ -n "$(ONEC_PLATFORM_OVERRIDE)" ]]; then env_args+=(ONEC_PLATFORM_OVERRIDE="$(ONEC_PLATFORM_OVERRIDE)"); fi; \
	env "$${env_args[@]}" bash ./scripts/agent-up.sh

agent-exec:
	@env_args=(); \
	if [[ -n "$(PROJECT_PATH)" ]]; then env_args+=(PROJECT_PATH="$(PROJECT_PATH)"); fi; \
	if [[ -n "$(ONEC_PROJECT_PATH)" ]]; then env_args+=(ONEC_PROJECT_PATH="$(ONEC_PROJECT_PATH)"); fi; \
	if [[ -n "$(ONEC_PLATFORM_OVERRIDE)" ]]; then env_args+=(ONEC_PLATFORM_OVERRIDE="$(ONEC_PLATFORM_OVERRIDE)"); fi; \
	if [[ -n "$(CMD)" ]]; then env_args+=(CMD="$(CMD)"); fi; \
	env "$${env_args[@]}" bash ./scripts/agent-exec.sh

agent-doctor:
	@env_args=(); \
	if [[ -n "$(PROJECT_PATH)" ]]; then env_args+=(PROJECT_PATH="$(PROJECT_PATH)"); fi; \
	if [[ -n "$(ONEC_PROJECT_PATH)" ]]; then env_args+=(ONEC_PROJECT_PATH="$(ONEC_PROJECT_PATH)"); fi; \
	if [[ -n "$(ONEC_PLATFORM_OVERRIDE)" ]]; then env_args+=(ONEC_PLATFORM_OVERRIDE="$(ONEC_PLATFORM_OVERRIDE)"); fi; \
	env "$${env_args[@]}" bash ./scripts/agent-doctor.sh

agent-skills:
	@env_args=(CMD='cat /opt/onec-agent/registry.json'); \
	if [[ -n "$(PROJECT_PATH)" ]]; then env_args+=(PROJECT_PATH="$(PROJECT_PATH)"); fi; \
	if [[ -n "$(ONEC_PROJECT_PATH)" ]]; then env_args+=(ONEC_PROJECT_PATH="$(ONEC_PROJECT_PATH)"); fi; \
	if [[ -n "$(ONEC_PLATFORM_OVERRIDE)" ]]; then env_args+=(ONEC_PLATFORM_OVERRIDE="$(ONEC_PLATFORM_OVERRIDE)"); fi; \
	env "$${env_args[@]}" bash ./scripts/agent-exec.sh

agent-skill:
	@env_args=(); \
	if [[ -n "$(PROJECT_PATH)" ]]; then env_args+=(PROJECT_PATH="$(PROJECT_PATH)"); fi; \
	if [[ -n "$(ONEC_PROJECT_PATH)" ]]; then env_args+=(ONEC_PROJECT_PATH="$(ONEC_PROJECT_PATH)"); fi; \
	if [[ -n "$(ONEC_PLATFORM_OVERRIDE)" ]]; then env_args+=(ONEC_PLATFORM_OVERRIDE="$(ONEC_PLATFORM_OVERRIDE)"); fi; \
	if [[ -n "$(NAME)" ]]; then env_args+=(NAME="$(NAME)"); fi; \
	env "$${env_args[@]}" bash ./scripts/agent-skill.sh

agent-bslls:
	@env_args=(); \
	if [[ -n "$(PROJECT_PATH)" ]]; then env_args+=(PROJECT_PATH="$(PROJECT_PATH)"); fi; \
	if [[ -n "$(ONEC_PROJECT_PATH)" ]]; then env_args+=(ONEC_PROJECT_PATH="$(ONEC_PROJECT_PATH)"); fi; \
	if [[ -n "$(ONEC_PLATFORM_OVERRIDE)" ]]; then env_args+=(ONEC_PLATFORM_OVERRIDE="$(ONEC_PLATFORM_OVERRIDE)"); fi; \
	if [[ -n "$(SRC_DIR)" ]]; then env_args+=(SRC_DIR="$(SRC_DIR)"); fi; \
	if [[ -n "$(OUTPUT_DIR)" ]]; then env_args+=(OUTPUT_DIR="$(OUTPUT_DIR)"); fi; \
	if [[ -n "$(REPORTERS)" ]]; then env_args+=(REPORTERS="$(REPORTERS)"); fi; \
	env "$${env_args[@]}" bash ./scripts/agent-bslls.sh

agent-bslls-format:
	@env_args=(); \
	if [[ -n "$(PROJECT_PATH)" ]]; then env_args+=(PROJECT_PATH="$(PROJECT_PATH)"); fi; \
	if [[ -n "$(ONEC_PROJECT_PATH)" ]]; then env_args+=(ONEC_PROJECT_PATH="$(ONEC_PROJECT_PATH)"); fi; \
	if [[ -n "$(ONEC_PLATFORM_OVERRIDE)" ]]; then env_args+=(ONEC_PLATFORM_OVERRIDE="$(ONEC_PLATFORM_OVERRIDE)"); fi; \
	if [[ -n "$(SRC_DIR)" ]]; then env_args+=(SRC_DIR="$(SRC_DIR)"); fi; \
	env "$${env_args[@]}" bash ./scripts/agent-bslls-format.sh

config:
	@env_args=(POSTGRES_PASSWORD="$(POSTGRES_PASSWORD)"); \
	if [[ -f "$(ENV_FILE)" ]]; then set -a; . "$(ENV_FILE)"; set +a; fi; \
	if [[ -n "$(DOCKER_DEFAULT_PLATFORM)" ]]; then env_args+=(DOCKER_DEFAULT_PLATFORM="$(DOCKER_DEFAULT_PLATFORM)"); fi; \
	if [[ -n "$(PG_MAJOR)" ]]; then env_args+=(PG_MAJOR="$(PG_MAJOR)"); fi; \
	if [[ -n "$(PG_1C_VERSION)" ]]; then env_args+=(PG_1C_VERSION="$(PG_1C_VERSION)"); fi; \
	if [[ -n "$(PG_REPO_DIST)" ]]; then env_args+=(PG_REPO_DIST="$(PG_REPO_DIST)"); fi; \
	if [[ -n "$(PLATFORM_VERSION)" ]]; then env_args+=(PLATFORM_VERSION="$(PLATFORM_VERSION)"); fi; \
	if [[ -n "$(PLATFORM_ARCH)" ]]; then env_args+=(PLATFORM_ARCH="$(PLATFORM_ARCH)"); fi; \
	if [[ -n "$(PLATFORM_DIST_NAME)" ]]; then env_args+=(PLATFORM_DIST_NAME="$(PLATFORM_DIST_NAME)"); fi; \
	if [[ -n "$(ONEC_PLATFORM_OVERRIDE)" ]]; then env_args+=(ONEC_PLATFORM_OVERRIDE="$(ONEC_PLATFORM_OVERRIDE)"); fi; \
	env "$${env_args[@]}" $(DOCKER_COMPOSE) $(COMPOSE_FILES) --profile build config

down:
	@$(DOCKER_COMPOSE) $(COMPOSE_FILES) --profile build down

ps:
	@$(DOCKER_COMPOSE) $(COMPOSE_FILES) --profile build ps

logs:
	@$(DOCKER_COMPOSE) $(COMPOSE_FILES) --profile build logs -f 1c-pg 1c-dev

clean-platform:
	@rm -rf .local/1c/platform
	@rm -rf .local/1c/dev-platform
	@echo 'Removed .local/1c platform caches'

clean: clean-platform
	@$(DOCKER_COMPOSE) $(COMPOSE_FILES) --profile build down
