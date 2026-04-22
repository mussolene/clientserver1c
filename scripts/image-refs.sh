#!/usr/bin/env bash
set -euo pipefail

image_namespace="${IMAGE_NAMESPACE:-ghcr.io/mussolene}"
platform_version="${PLATFORM_VERSION:-8.5.1.1302}"
pg_1c_version="${PG_1C_VERSION:-17.7-1.1C}"

ONEC_DEV_IMAGE="${image_namespace}/1c-developer:${platform_version}"
ONEC_PG_IMAGE="${image_namespace}/postgresql:${pg_1c_version}"

export ONEC_DEV_IMAGE ONEC_PG_IMAGE
