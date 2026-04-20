ARG ONESCRIPT_BUILD_IMAGE=mussolene/linux-onescript-builder:2.0.0
ARG COMMON_BASE_IMAGE=mussolene/linux-common-base:bookworm

FROM ${ONESCRIPT_BUILD_IMAGE} AS onescript_build
FROM ${COMMON_BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive
ENV ONESCRIPT_ROOT=/opt/onescript
ENV PATH=/opt/onescript:/opt/onescript/bin:${PATH}
ENV OSCRIPT_CONFIG=lib.system=/opt/onescript/lib
ENV OPM_CONFIG=/opt/onescript/opm.cfg

RUN rm -rf /var/lib/apt/lists/* \
  && apt-get update -o APT::Sandbox::User=root -o Acquire::Retries=5 \
  && apt-get install -y -o APT::Sandbox::User=root --no-install-recommends \
    libicu72 \
  && mkdir -p "$ONESCRIPT_ROOT/bin" \
  && rm -rf /var/lib/apt/lists/*

COPY --from=onescript_build /opt/onescript/ /opt/onescript/

RUN ln -sf /opt/onescript/oscript /opt/onescript/bin/oscript \
  && printf '%s\n' \
       '[default]' \
       'СервераПакетов = ОсновнойСерверПакетов, ЗапаснойСерверПакетов' \
       '' \
       '[ОсновнойСерверПакетов]' \
       'URL = https://hub.oscript.io' \
       '' \
       '[ЗапаснойСерверПакетов]' \
       'URL = https://hub.oscript.ru' \
     > /opt/onescript/opm.cfg \
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
