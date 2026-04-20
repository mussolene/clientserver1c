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

.PHONY: help env download prepare-platform build-common-base build-desktop-base build-onescript-builder build-onescript-base up build config down ps logs clean-platform clean

help:
	@printf '%s\n' \
	  'Targets:' \
	  '  make env             - create .env from .env.example if missing' \
	  '  make download        - optional: download the 1C platform archive into .local/1c/platform for local cache/offline work' \
	  '  make prepare-platform - optional: prepare local staging inputs in .local/1c/server-platform and .local/1c/client-platform' \
	  '  make build-common-base - build only the shared common base image' \
	  '  make build-desktop-base - build only the shared desktop GUI base image' \
	  '  make build-onescript-builder - build only the intermediate OneScript source-build image' \
	  '  make build-onescript-base - build only the reusable OneScript runtime image' \
	  '  make up              - build the full compose dependency graph and start the stack; platform and PostgreSQL are downloaded during docker build via ITS secrets' \
	  '  make build           - build the full compose dependency graph' \
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
	  '  make build-common-base' \
	  '  make build-desktop-base' \
	  '  make build-onescript-builder' \
	  '  make build-onescript-base' \
	  '  make build PLATFORM_ARCH=arm64 DOCKER_DEFAULT_PLATFORM=linux/arm64' \
	  '  make build PLATFORM_ARCH=amd64 DOCKER_DEFAULT_PLATFORM=linux/amd64' \
	  '  make up PLATFORM_VERSION=8.3.24.1548' \
	  '  make download PLATFORM_VERSION=8.3.25.1374'

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
	env ENV_FILE="$(abspath $(ENV_FILE))" "$${env_args[@]}" bash ./scripts/ensure-its-env.sh; \
	env "$${env_args[@]}" $(DOCKER_COMPOSE) --profile build build 1c-pg 1c-server 1c-client

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
	env "$${env_args[@]}" $(DOCKER_COMPOSE) config

down:
	@$(DOCKER_COMPOSE) down

ps:
	@$(DOCKER_COMPOSE) ps

logs:
	@$(DOCKER_COMPOSE) logs -f

clean-platform:
	@rm -rf .local/1c/platform
	@rm -rf .local/1c/server-platform
	@rm -rf .local/1c/client-platform
	@echo 'Removed .local/1c platform caches'

clean: clean-platform
	@$(DOCKER_COMPOSE) down
