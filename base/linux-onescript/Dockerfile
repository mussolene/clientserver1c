ARG ONESCRIPT_BUILD_IMAGE=mussolene/linux-onescript-builder
ARG ONESCRIPT_BUILD_TAG=2.0.0
ARG ONESCRIPT_BASE_DIST=jammy

FROM ${ONESCRIPT_BUILD_IMAGE}:${ONESCRIPT_BUILD_TAG} AS onescript_build
FROM ubuntu:${ONESCRIPT_BASE_DIST}

ARG ONESCRIPT_BASE_DIST=jammy

ENV DEBIAN_FRONTEND=noninteractive
ENV ONESCRIPT_ROOT=/opt/onescript
ENV PATH=/opt/onescript:/opt/onescript/bin:${PATH}
ENV OSCRIPT_CONFIG=lib.system=/opt/onescript/lib

RUN rm -rf /var/lib/apt/lists/* \
  && apt-get update -o Acquire::Retries=5 \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    libicu70 \
  && mkdir -p "$ONESCRIPT_ROOT/bin" \
  && rm -rf /var/lib/apt/lists/*

COPY --from=onescript_build /opt/onescript/ /opt/onescript/

RUN ln -sf /opt/onescript/oscript /opt/onescript/bin/oscript \
  && printf '%s\n' \
       '#!/bin/sh' \
       'if [ -x /opt/onescript/oscript ]; then exec /opt/onescript/oscript "$@"; fi' \
       'echo "OneScript runtime files are missing in this image." >&2' \
       'exit 1' \
     > /usr/local/bin/oscript \
  && printf '%s\n' \
       '#!/bin/sh' \
       'if [ -x /opt/onescript/bin/opm ]; then exec /opt/onescript/bin/opm "$@"; fi' \
       'echo "OPM files are missing in this image." >&2' \
       'exit 1' \
     > /usr/local/bin/opm \
  && chmod +x /usr/local/bin/oscript /usr/local/bin/opm \
  && oscript --version >/dev/null \
  && opm version >/dev/null
