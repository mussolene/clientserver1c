ARG COMMON_BASE_IMAGE=mussolene/linux-common-base:bookworm
FROM ${COMMON_BASE_IMAGE}

ARG TARGETARCH
ARG PLATFORM_VERSION=8.3.22.1851
ARG PLATFORM_DIST_NAME

ENV PLATFORM_VERSION=${PLATFORM_VERSION}
ENV PLATFORM_DIST_NAME=${PLATFORM_DIST_NAME}
ENV COMPONENT_PLATFORM=server
COPY artifacts/ /tmp/build-artifacts/
COPY scripts/download-platform-build.sh /usr/local/bin/download-platform-build.sh

RUN --mount=type=cache,id=1c-platform-cache,target=/var/cache/1c-platform \
    --mount=type=secret,id=its_login \
    --mount=type=secret,id=its_password \
    chmod +x /usr/local/bin/download-platform-build.sh \
  && archive_path="$(PLATFORM_COMPONENT=server PLATFORM_VERSION="$PLATFORM_VERSION" PLATFORM_DIST_NAME="$PLATFORM_DIST_NAME" TARGETARCH="$TARGETARCH" /usr/local/bin/download-platform-build.sh)" \
  && cd /tmp \
  && case "$archive_path" in \
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
             /tmp/platform-unpacked/*.deb; \
         fi \
      ;; \
    *) \
      tar -xzvf "$archive_path" \
      && installer="$(find . -maxdepth 1 -name "setup-full-${PLATFORM_VERSION}-*.run" | head -n 1)" \
      && chmod +x "$installer" \
      && "$installer" --mode unattended --enable-components $COMPONENT_PLATFORM \
      ;; \
    esac \
  && rm -rf /tmp/* \
  && mkdir --parent /var/log/1C /home/usr1cv8/.1cv8/1C/1cv8/conf \
  && chown --recursive usr1cv8:grp1cv8 /var/log/1C /home/usr1cv8

COPY artifacts/scripts/createsymlink-current.sh /createsymlink-current.sh
RUN chmod +x /createsymlink-current.sh \
  && /createsymlink-current.sh \
  && rm /createsymlink-current.sh

COPY artifacts/config/logcfg.xml /home/usr1cv8/.1cv8/1C/1cv8/conf
RUN if [ -f /tmp/build-artifacts/nethasp.ini ]; then \
    cp /tmp/build-artifacts/nethasp.ini /opt/1cv8/conf/nethasp.ini; \
    cp /tmp/build-artifacts/nethasp.ini /home/usr1cv8/.1cv8/1C/1cv8/conf/nethasp.ini; \
  fi \
  && rm -rf /tmp/build-artifacts

EXPOSE 1540-1541 1560-1691 1545

CMD ["gosu", "usr1cv8", "/opt/1cv8/current/ragent", "-debug"]
