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

.PHONY: help env download prepare-platform build-common-base build-desktop-base build-onescript-builder build-onescript-base up up-file-db up-server build build-server-stack ui-smoke agent-up agent-exec agent-doctor agent-skills agent-skill agent-bslls agent-bslls-format config down ps logs clean-platform clean

help:
	@printf '%s\n' \
	  'Targets:' \
	  '  make env             - create .env from .env.example if missing' \
	  '  make download        - optional: download the 1C platform archive into .local/1c/platform for local cache/offline work' \
	  '  make prepare-platform - optional: prepare local staging inputs in .local/1c/dev-platform' \
	  '  make build-common-base - build only the shared common base image' \
	  '  make build-desktop-base - build only the shared desktop GUI base image' \
	  '  make build-onescript-builder - build only the intermediate OneScript source-build image' \
	  '  make build-onescript-base - build only the reusable OneScript runtime image' \
	  '  make up              - prepare staged platform archives, build missing images if needed, and start the first-run license UI' \
	  '  make up-file-db      - start the developer container directly in file-db mode, building missing images if needed' \
	  '  make up-server       - start the developer container in server mode together with PostgreSQL 1C, building missing images if needed' \
	  '  make build           - prepare staged platform archives and build only the developer image' \
	  '  make build-server-stack - prepare staged platform archives and build developer image plus PostgreSQL 1C' \
	  '  make ui-smoke        - start 1c-dev in shell mode and run the tracked Vanessa smoke against the file DB' \
	  '  make agent-up PROJECT_PATH=$$PWD - start 1c-dev with a host project mounted at /workspace/project' \
	  '  make agent-exec CMD="..."       - run a command in /workspace/project inside 1c-dev' \
	  '  make agent-doctor               - check agent-ready runtime and skills inside 1c-dev' \
	  '  make agent-skills               - print the container skill registry' \
	  '  make agent-skill NAME=context   - print one skill entrypoint from the container' \
	  '  make agent-bslls SRC_DIR=src/cf - run BSL Language Server diagnostics in the mounted project' \
	  '  make agent-bslls-format SRC_DIR=src/cf - format BSL files in the mounted project' \
	  '  make config          - validate docker compose config' \
	  '  make down            - stop containers' \
	  '  make ps              - show container status' \
	  '  make logs            - follow logs' \
	  '  make clean-platform  - remove local platform caches and staging directories' \
	  '  make clean           - remove local platform caches and stop the stack' \
	  '' \
	  'Examples:' \
	  '  make config PG_MAJOR=17 PG_1C_VERSION=17.7-1.1C PG_REPO_DIST=bookworm' \
	  '  make up PG_MAJOR=17 PG_1C_VERSION=17.7-1.1C' \
	  '  make up-file-db' \
	  '  make build-common-base' \
	  '  make build-desktop-base' \
	  '  make build-onescript-builder' \
	  '  make build-onescript-base' \
	  '  make build PLATFORM_ARCH=arm64 DOCKER_DEFAULT_PLATFORM=linux/arm64' \
	  '  make build ONEC_PLATFORM_OVERRIDE=native-arm PLATFORM_ARCH=arm64' \
	  '  make build PLATFORM_ARCH=amd64 DOCKER_DEFAULT_PLATFORM=linux/amd64' \
	  '  make up PLATFORM_VERSION=8.3.24.1548' \
	  '  make download PLATFORM_VERSION=8.3.25.1374' \
	  '  make agent-up PROJECT_PATH=/path/to/1c-project' \
	  '  make agent-exec PROJECT_PATH=/path/to/1c-project CMD="oscript --version"'

env:
	@if [[ ! -f "$(ENV_FILE)" ]]; then \
	  cp .env.example "$(ENV_FILE)"; \
	  echo "Created $(ENV_FILE) from .env.example"; \
	else \
	  echo "$(ENV_FILE) already exists"; \
	fi

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
