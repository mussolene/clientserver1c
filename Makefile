SHELL := /bin/bash

ENV_FILE ?= .env
DOCKER_COMPOSE ?= docker compose
POSTGRES_PASSWORD ?= test-local
PG_MAJOR ?=
PG_REPO_DIST ?=
PLATFORM_VERSION ?=
PLATFORM_DIST_NAME ?=

.PHONY: help env download prepare-platform up build config down ps logs clean-platform clean

help:
	@printf '%s\n' \
	  'Targets:' \
	  '  make env             - create .env from .env.example if missing' \
	  '  make download        - download the 1C platform archive into .local/1c/platform; prompts ITS creds if needed' \
	  '  make prepare-platform - prepare staged platform inputs for Docker builds' \
	  '  make up              - download platform if needed, prompt ITS creds if needed, and start the stack; supports PG_MAJOR/PG_REPO_DIST overrides' \
	  '  make build           - build images' \
	  '  make config          - validate docker compose config' \
	  '  make down            - stop containers' \
	  '  make ps              - show container status' \
	  '  make logs            - follow logs' \
	  '  make clean-platform  - remove local platform caches and staging directories' \
	  '  make clean           - remove local platform caches and stop the stack' \
	  '' \
	  'Examples:' \
	  '  make config PG_MAJOR=17 PG_REPO_DIST=bullseye' \
	  '  make up PG_MAJOR=16' \
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
	if [[ -n "$(PLATFORM_DIST_NAME)" ]]; then env_args+=(PLATFORM_DIST_NAME="$(PLATFORM_DIST_NAME)"); fi; \
	env ENV_FILE="$(abspath $(ENV_FILE))" "$${env_args[@]}" ./scripts/download-platform.sh

prepare-platform:
	@env_args=(); \
	if [[ -n "$(PLATFORM_VERSION)" ]]; then env_args+=(PLATFORM_VERSION="$(PLATFORM_VERSION)"); fi; \
	if [[ -n "$(PLATFORM_DIST_NAME)" ]]; then env_args+=(PLATFORM_DIST_NAME="$(PLATFORM_DIST_NAME)"); fi; \
	env ENV_FILE="$(abspath $(ENV_FILE))" "$${env_args[@]}" ./scripts/prepare-platform.sh

up:
	@env_args=(); \
	if [[ -n "$(PG_MAJOR)" ]]; then env_args+=(PG_MAJOR="$(PG_MAJOR)"); fi; \
	if [[ -n "$(PG_REPO_DIST)" ]]; then env_args+=(PG_REPO_DIST="$(PG_REPO_DIST)"); fi; \
	if [[ -n "$(PLATFORM_VERSION)" ]]; then env_args+=(PLATFORM_VERSION="$(PLATFORM_VERSION)"); fi; \
	if [[ -n "$(PLATFORM_DIST_NAME)" ]]; then env_args+=(PLATFORM_DIST_NAME="$(PLATFORM_DIST_NAME)"); fi; \
	env ENV_FILE="$(abspath $(ENV_FILE))" "$${env_args[@]}" ./scripts/up.sh

build:
	@env_args=(); \
	if [[ -n "$(PG_MAJOR)" ]]; then env_args+=(PG_MAJOR="$(PG_MAJOR)"); fi; \
	if [[ -n "$(PG_REPO_DIST)" ]]; then env_args+=(PG_REPO_DIST="$(PG_REPO_DIST)"); fi; \
	if [[ -n "$(PLATFORM_VERSION)" ]]; then env_args+=(PLATFORM_VERSION="$(PLATFORM_VERSION)"); fi; \
	if [[ -n "$(PLATFORM_DIST_NAME)" ]]; then env_args+=(PLATFORM_DIST_NAME="$(PLATFORM_DIST_NAME)"); fi; \
	env ENV_FILE="$(abspath $(ENV_FILE))" "$${env_args[@]}" ./scripts/prepare-platform.sh; \
	env "$${env_args[@]}" $(DOCKER_COMPOSE) build

config:
	@env_args=(POSTGRES_PASSWORD="$(POSTGRES_PASSWORD)"); \
	if [[ -n "$(PG_MAJOR)" ]]; then env_args+=(PG_MAJOR="$(PG_MAJOR)"); fi; \
	if [[ -n "$(PG_REPO_DIST)" ]]; then env_args+=(PG_REPO_DIST="$(PG_REPO_DIST)"); fi; \
	if [[ -n "$(PLATFORM_VERSION)" ]]; then env_args+=(PLATFORM_VERSION="$(PLATFORM_VERSION)"); fi; \
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
