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
IMAGE_NAMESPACE ?=
OACS_VERSION ?=
ONEC_RUNTIME_MODE ?=

ifneq ($(IMAGE_NAMESPACE),)
export IMAGE_NAMESPACE
endif

COMPOSE_FILES := -f docker-compose.yml $(if $(filter native-arm,$(ONEC_PLATFORM_OVERRIDE)),-f docker-compose.onec-native-arm.yml)
env_var = $(if $($(1)),$(1)="$($(1))")
runtime_mode = $(if $(ONEC_RUNTIME_MODE),$(ONEC_RUNTIME_MODE),shell)

PLATFORM_ENV := $(foreach v,PLATFORM_VERSION PLATFORM_ARCH PLATFORM_DIST_NAME DOCKER_DEFAULT_PLATFORM,$(call env_var,$(v)))
IMAGE_ENV := $(foreach v,PLATFORM_VERSION PG_1C_VERSION IMAGE_NAMESPACE ONEC_WITH_PG,$(call env_var,$(v)))
RUNTIME_ENV := $(foreach v,DOCKER_DEFAULT_PLATFORM PG_MAJOR PG_1C_VERSION PG_REPO_DIST PLATFORM_VERSION PLATFORM_ARCH PLATFORM_DIST_NAME ONEC_PLATFORM_OVERRIDE OACS_VERSION,$(call env_var,$(v)))
BUILD_ENV := $(RUNTIME_ENV) $(call env_var,IMAGE_NAMESPACE)
AGENT_ENV := $(foreach v,PROJECT_PATH ONEC_PROJECT_PATH PLATFORM_VERSION PLATFORM_ARCH PLATFORM_DIST_NAME ONEC_PLATFORM_OVERRIDE OACS_VERSION,$(call env_var,$(v)))
AGENT_CMD_ENV := $(foreach v,PROJECT_PATH ONEC_PROJECT_PATH ONEC_PLATFORM_OVERRIDE,$(call env_var,$(v)))
CONFIG_ENV := $(BUILD_ENV) POSTGRES_PASSWORD="$(POSTGRES_PASSWORD)"

.PHONY: help env doctor first-start pull download prepare-platform build-common-base build-desktop-base build-onescript-builder build-onescript-base up up-file-db up-server build build-server-stack ui-smoke agent-up agent-exec agent-doctor agent-skills agent-skill agent-context agent-memory-query agent-memory-capture agent-bslls agent-bslls-format config down ps logs clean-platform clean

help:
	@printf '%s\n' \
	  'Common targets:' \
	  '  make env             - create .env from .env.example if missing' \
	  '  make doctor          - check local readiness and print next commands' \
	  '  make pull            - pull configured prebuilt developer image' \
	  '  make first-start     - create .env if needed, then start the license UI' \
	  '  make up              - use local/pulled developer image, start shell/agent-ready runtime' \
	  '  make up-file-db      - start 1c-dev in file DB mode after license activation' \
	  '  make ui-smoke        - run the tracked Vanessa UI smoke' \
	  '' \
	  'IDE-agent targets:' \
	  '  make agent-up PROJECT_PATH=$$PWD       - start 1c-dev with project mounted' \
	  '  make agent-doctor PROJECT_PATH=$$PWD   - check agent-ready runtime inside 1c-dev' \
	  '  make agent-exec CMD="..."             - run command in /workspace/project' \
	  '  make agent-context TASK="..."         - build OACS task context capsule' \
	  '  make agent-memory-query QUERY="..."   - query OACS project memory' \
	  '  make agent-memory-capture SUMMARY="..." - capture OACS project memory' \
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
	@$(MAKE) --no-print-directory up ONEC_RUNTIME_MODE=license-ui

pull:
	@env ENV_FILE="$(abspath $(ENV_FILE))" $(IMAGE_ENV) ./scripts/pull-images.sh

download:
	@env ENV_FILE="$(abspath $(ENV_FILE))" $(PLATFORM_ENV) ./scripts/download-platform.sh

prepare-platform:
	@env ENV_FILE="$(abspath $(ENV_FILE))" $(PLATFORM_ENV) ./scripts/prepare-platform.sh

build-common-base:
	@env ENV_FILE="$(abspath $(ENV_FILE))" $(call env_var,DOCKER_DEFAULT_PLATFORM) bash ./scripts/build-common-base.sh

build-desktop-base:
	@env ENV_FILE="$(abspath $(ENV_FILE))" $(call env_var,DOCKER_DEFAULT_PLATFORM) bash ./scripts/build-desktop-base.sh

build-onescript-builder:
	@env ENV_FILE="$(abspath $(ENV_FILE))" $(call env_var,DOCKER_DEFAULT_PLATFORM) bash ./scripts/build-onescript-builder.sh

build-onescript-base:
	@env ENV_FILE="$(abspath $(ENV_FILE))" $(call env_var,DOCKER_DEFAULT_PLATFORM) bash ./scripts/build-onescript-base.sh

up:
	@env ENV_FILE="$(abspath $(ENV_FILE))" ONEC_RUNTIME_MODE="$(runtime_mode)" $(RUNTIME_ENV) ./scripts/up.sh

up-file-db:
	@env ENV_FILE="$(abspath $(ENV_FILE))" ONEC_RUNTIME_MODE=file-db $(RUNTIME_ENV) $(call env_var,ONEC_FILE_DB_PATH) ./scripts/up.sh

up-server:
	@env ENV_FILE="$(abspath $(ENV_FILE))" ONEC_RUNTIME_MODE=server ONEC_WITH_PG=1 $(RUNTIME_ENV) ./scripts/up.sh

build:
	@set -a; [[ ! -f "$(ENV_FILE)" ]] || . "$(ENV_FILE)"; set +a; \
	env ENV_FILE="$(abspath $(ENV_FILE))" $(BUILD_ENV) bash ./scripts/prepare-platform.sh; \
	env $(BUILD_ENV) $(DOCKER_COMPOSE) $(COMPOSE_FILES) --profile build build 1c-dev

build-server-stack:
	@set -a; [[ ! -f "$(ENV_FILE)" ]] || . "$(ENV_FILE)"; set +a; \
	env ENV_FILE="$(abspath $(ENV_FILE))" $(BUILD_ENV) bash ./scripts/prepare-platform.sh; \
	env $(BUILD_ENV) $(DOCKER_COMPOSE) $(COMPOSE_FILES) --profile build build 1c-pg 1c-dev

ui-smoke:
	@env $(foreach v,PLATFORM_VERSION IB_CONNECTION DB_USER DB_PWD,$(call env_var,$(v))) bash ./scripts/run-ui-smoke.sh

agent-up:
	@env ONEC_RUNTIME_MODE="$(runtime_mode)" $(AGENT_ENV) bash ./scripts/agent-up.sh

agent-exec:
	@env $(AGENT_CMD_ENV) $(call env_var,CMD) bash ./scripts/agent-exec.sh

agent-doctor:
	@env $(AGENT_CMD_ENV) bash ./scripts/agent-doctor.sh

agent-skills:
	@env $(AGENT_CMD_ENV) CMD='onec-agent registry' bash ./scripts/agent-exec.sh

agent-skill:
	@env $(AGENT_CMD_ENV) $(call env_var,NAME) bash ./scripts/agent-skill.sh

agent-context:
	@env $(AGENT_CMD_ENV) $(foreach v,TASK QUERY PACK LIMIT,$(call env_var,$(v))) bash ./scripts/agent-context.sh build

agent-memory-query:
	@env $(AGENT_CMD_ENV) $(call env_var,QUERY) bash ./scripts/agent-context.sh query

agent-memory-capture:
	@env $(AGENT_CMD_ENV) $(foreach v,SUMMARY TYPE DEPTH EVIDENCE,$(call env_var,$(v))) bash ./scripts/agent-context.sh capture

agent-bslls:
	@env $(AGENT_CMD_ENV) $(foreach v,SRC_DIR OUTPUT_DIR REPORTERS,$(call env_var,$(v))) bash ./scripts/agent-bslls.sh

agent-bslls-format:
	@env $(AGENT_CMD_ENV) $(call env_var,SRC_DIR) bash ./scripts/agent-bslls-format.sh

config:
	@set -a; [[ ! -f "$(ENV_FILE)" ]] || . "$(ENV_FILE)"; set +a; \
	env $(CONFIG_ENV) $(DOCKER_COMPOSE) $(COMPOSE_FILES) --profile build config

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
