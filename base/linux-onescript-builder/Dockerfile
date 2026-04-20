ARG ONESCRIPT_SDK_IMAGE=mcr.microsoft.com/dotnet/sdk:8.0
FROM ${ONESCRIPT_SDK_IMAGE}

ARG TARGETARCH
ARG ONESCRIPT_VERSION=2.0.0
ARG ONESCRIPT_GIT_URL=https://github.com/EvilBeaver/OneScript.git

ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV DOTNET_NOLOGO=1

RUN rm -rf /var/lib/apt/lists/* \
  && apt-get update -o APT::Sandbox::User=root -o Acquire::Retries=5 \
  && apt-get install -y -o APT::Sandbox::User=root --no-install-recommends \
    ca-certificates \
    git \
  && rm -rf /var/lib/apt/lists/* \
  && echo "Cloning OneScript sources v${ONESCRIPT_VERSION}" \
  && git clone --branch "v${ONESCRIPT_VERSION}" --depth 1 "$ONESCRIPT_GIT_URL" /tmp/OneScript

RUN case "$TARGETARCH" in \
      amd64) rid='linux-x64' ;; \
      arm64) rid='linux-arm64' ;; \
      *) echo "Unsupported TARGETARCH for OneScript builder: $TARGETARCH" >&2; exit 1 ;; \
    esac \
  && echo "Restoring OneScript projects for $rid" \
  && cd /tmp/OneScript \
  && dotnet restore src/oscript/oscript.csproj --verbosity minimal

RUN case "$TARGETARCH" in \
      amd64) rid='linux-x64' ;; \
      arm64) rid='linux-arm64' ;; \
      *) echo "Unsupported TARGETARCH for OneScript builder: $TARGETARCH" >&2; exit 1 ;; \
    esac \
  && echo "Publishing OneScript runtime for $rid" \
  && cd /tmp/OneScript \
  && dotnet publish src/oscript/oscript.csproj \
       -c Release \
       -r "$rid" \
       --self-contained \
       --verbosity minimal \
       -o /opt/onescript \
  && chmod +x /opt/onescript/oscript

RUN echo "Preparing OPM runtime and core packages" \
  && cd /tmp/OneScript \
  && mkdir -p /opt/onescript/lib /opt/onescript/bin /opt/onescript/lib/tmp \
  && cp install/package-loader.os /opt/onescript/lib/package-loader.os \
  && /opt/onescript/oscript install/unicode-zipper.os unpack install/opm.ospx /opt/onescript/lib/tmp \
  && /opt/onescript/oscript install/unicode-zipper.os unpack /opt/onescript/lib/tmp/content.zip /opt/onescript/lib/opm \
  && rm -rf /opt/onescript/lib/tmp \
  && printf '%s\n' \
       '#!/bin/sh' \
       'export OSCRIPT_CONFIG="${OSCRIPT_CONFIG:-lib.system=/opt/onescript/lib}"' \
       'exec /opt/onescript/oscript /opt/onescript/lib/opm/src/cmd/opm.os "$@"' \
     > /opt/onescript/bin/opm \
  && chmod +x /opt/onescript/bin/opm \
  && OSCRIPT_CONFIG='lib.system=/opt/onescript/lib' /opt/onescript/bin/opm install -d /opt/onescript/lib asserts logos fs tempfiles cli \
  && case "$TARGETARCH" in \
       amd64) rid='linux-x64' ;; \
       arm64) rid='linux-arm64' ;; \
       *) echo "Unsupported TARGETARCH for OneScript builder: $TARGETARCH" >&2; exit 1 ;; \
     esac \
  && printf 'onescript_version=%s\nruntime_id=%s\n' "$ONESCRIPT_VERSION" "$rid" > /opt/onescript/BUILDINFO \
  && /opt/onescript/oscript --version >/dev/null \
  && /opt/onescript/bin/opm version >/dev/null \
  && rm -rf /tmp/OneScript /root/.nuget /var/lib/apt/lists/*
