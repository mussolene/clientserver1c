ARG DESKTOP_BASE_IMAGE=mussolene/linux-desktop-base:bookworm
ARG ONESCRIPT_BASE_IMAGE=mussolene/linux-onescript:2.0.0
FROM ${ONESCRIPT_BASE_IMAGE} AS onescript_base
FROM ${DESKTOP_BASE_IMAGE}

ARG TARGETARCH
ARG PLATFORM_VERSION=8.3.22.1851
ARG PLATFORM_DIST_NAME
ARG VANESSA_ADD_VERSION=6.9.5
ARG VANESSA_RUNNER_VERSION=2.6.0

ENV PLATFORM_VERSION=${PLATFORM_VERSION}
ENV PLATFORM_DIST_NAME=${PLATFORM_DIST_NAME}
ENV COMPONENT_PLATFORM=client_full
ENV ONESCRIPT_ROOT=/opt/onescript
ENV PATH=/opt/onescript:/opt/onescript/bin:${PATH}
ENV OSCRIPT_CONFIG=lib.system=/opt/onescript/lib
ENV OPM_CONFIG=/opt/onescript/opm.cfg
ENV OSCRIPTBIN=/opt/onescript/bin
COPY artifacts/ /tmp/build-artifacts/
COPY scripts/download-platform-build.sh /usr/local/bin/download-platform-build.sh
COPY artifacts/client-vnc/rootfs/etc/services.d/onec/run /etc/services.d/onec/run
COPY --from=onescript_base /opt/onescript /opt/onescript
COPY --from=onescript_base /usr/local/bin/oscript /usr/local/bin/oscript
COPY --from=onescript_base /usr/local/bin/opm /usr/local/bin/opm

RUN --mount=type=cache,id=1c-platform-cache,target=/var/cache/1c-platform \
    --mount=type=secret,id=its_login \
    --mount=type=secret,id=its_password \
    chmod +x /usr/local/bin/download-platform-build.sh \
  && archive_path="$(PLATFORM_COMPONENT=client PLATFORM_VERSION="$PLATFORM_VERSION" PLATFORM_DIST_NAME="$PLATFORM_DIST_NAME" TARGETARCH="$TARGETARCH" PLATFORM_PACKAGE_ARCH="$TARGETARCH" /usr/local/bin/download-platform-build.sh)" \
  && cd /tmp \
  && case "$archive_path" in \
    *.run) \
      chmod +x "$archive_path" \
      && "$archive_path" --mode unattended --enable-components "$COMPONENT_PLATFORM" \
      ;; \
    *.zip) \
      mkdir -p /tmp/platform-unpacked \
      && unzip -q "$archive_path" -d /tmp/platform-unpacked \
      && installer="$(find /tmp/platform-unpacked -maxdepth 1 -name "setup-full-${PLATFORM_VERSION}-*.run" | head -n 1)" \
      && if [ -n "$installer" ]; then \
           chmod +x "$installer" \
           && "$installer" --mode unattended --enable-components "$COMPONENT_PLATFORM"; \
         else \
           rm -rf /var/lib/apt/lists/* \
           && apt-get -qq update -o APT::Sandbox::User=root -o Acquire::Retries=5 \
           && apt-get -qq install --yes --no-install-recommends -o APT::Sandbox::User=root \
             bash \
           && ln -sf /usr/bin/bash /bin/bash \
           && apt-get -qq install --yes --no-install-recommends -o APT::Sandbox::User=root \
             /tmp/platform-unpacked/*.deb; \
         fi \
      ;; \
    *) \
      tar -xzvf "$archive_path" \
      && installer="$(find . -maxdepth 1 -name "setup-full-${PLATFORM_VERSION}-*.run" | head -n 1)" \
      && chmod +x "$installer" \
      && "$installer" --mode unattended --enable-components "$COMPONENT_PLATFORM" \
      ;; \
    esac \
  && rm -rf /tmp/* 

# create symlink to current 1c:enterprise directory
COPY artifacts/scripts/createsymlink-current.sh /createsymlink-current.sh
RUN chmod +x /createsymlink-current.sh \
  && /createsymlink-current.sh \
  && rm /createsymlink-current.sh

RUN (opm install "add@${VANESSA_ADD_VERSION}" || opm install add) \
  && (opm install "vanessa-runner@${VANESSA_RUNNER_VERSION}" || opm install vanessa-runner) \
  && mkdir -p /opt/lib \
  && ln -sfn /opt/onescript/lib/add /opt/lib/add \
  && ln -sf /opt/onescript/bin/vrunner /usr/local/bin/vrunner \
  && ln -sf /opt/onescript/bin/runner /usr/local/bin/runner \
  && ln -sf /opt/onescript/bin/vanessa-runner /usr/local/bin/vanessa-runner \
  && command -v vrunner >/dev/null \
  && vrunner help >/dev/null

RUN if [ -f /tmp/build-artifacts/nethasp.ini ]; then \
    cp /tmp/build-artifacts/nethasp.ini /opt/1cv8/conf/nethasp.ini; \
  fi \
  && rm -rf /tmp/build-artifacts

EXPOSE 5900

ENTRYPOINT ["/init"]
