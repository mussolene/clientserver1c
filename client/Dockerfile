ARG DESKTOP_BASE_IMAGE=mussolene/linux-desktop-base
ARG DESKTOP_BASE_TAG=bullseye
FROM ${DESKTOP_BASE_IMAGE}:${DESKTOP_BASE_TAG}

ARG TARGETARCH
ARG PLATFORM_VERSION=8.3.22.1851
ARG PLATFORM_DIST_NAME
ARG ONESCRIPT_VERSION=2.0.0
ARG VANESSA_ADD_VERSION=6.9.5
ARG VANESSA_RUNNER_VERSION=2.6.0

ENV PLATFORM_VERSION=${PLATFORM_VERSION}
ENV PLATFORM_DIST_NAME=${PLATFORM_DIST_NAME}
ENV ONESCRIPT_VERSION=${ONESCRIPT_VERSION}
ENV VANESSA_ADD_VERSION=${VANESSA_ADD_VERSION}
ENV VANESSA_RUNNER_VERSION=${VANESSA_RUNNER_VERSION}
ENV COMPONENT_PLATFORM client_full
COPY .local/1c/client-platform/ /tmp/platform/
COPY artifacts/ /tmp/build-artifacts/

RUN archive_name="${PLATFORM_DIST_NAME}" \
  && if [ -z "$archive_name" ]; then \
    version_underscored="$(printf '%s' "$PLATFORM_VERSION" | tr '.' '_')"; \
    installer_path="$(find /tmp/platform -maxdepth 1 -name "setup-full-${PLATFORM_VERSION}-*.run" | head -n 1)"; \
    alt_installer_path="$(find /tmp/platform -maxdepth 1 -name "all-clients-distr-${PLATFORM_VERSION}-*.run" | head -n 1)"; \
    if [ -n "$installer_path" ]; then \
      archive_name="$(basename "$installer_path")"; \
    elif [ -n "$alt_installer_path" ]; then \
      archive_name="$(basename "$alt_installer_path")"; \
    elif [ -f "/tmp/platform/server64_with_all_clients_${version_underscored}.zip" ]; then \
      archive_name="server64_with_all_clients_${version_underscored}.zip"; \
    elif [ -f "/tmp/platform/client.arm.deb64_${PLATFORM_VERSION}.zip" ]; then \
      archive_name="client.arm.deb64_${PLATFORM_VERSION}.zip"; \
    elif [ -f "/tmp/platform/thin.client.arm.deb64_${PLATFORM_VERSION}.zip" ]; then \
      archive_name="thin.client.arm.deb64_${PLATFORM_VERSION}.zip"; \
    elif [ -f "/tmp/platform/server64_with_clients_${version_underscored}.zip" ]; then \
      archive_name="server64_with_clients_${version_underscored}.zip"; \
    elif [ -f "/tmp/platform/client_${version_underscored}.deb64.zip" ]; then \
      archive_name="client_${version_underscored}.deb64.zip"; \
    elif [ -f "/tmp/platform/thin.client_${version_underscored}.deb64.zip" ]; then \
      archive_name="thin.client_${version_underscored}.deb64.zip"; \
    else \
      archive_name="server64_${version_underscored}.tar.gz"; \
    fi; \
  fi \
  && test -f "/tmp/platform/${archive_name}" \
  && cd /tmp \
  && case "$archive_name" in \
    *.run) \
      chmod +x "/tmp/platform/${archive_name}" \
      && "/tmp/platform/${archive_name}" --mode unattended --enable-components "$COMPONENT_PLATFORM" \
      ;; \
    *.zip) \
      mkdir -p /tmp/platform-unpacked \
      && unzip -q "/tmp/platform/${archive_name}" -d /tmp/platform-unpacked \
      && installer="$(find /tmp/platform-unpacked -maxdepth 1 -name "setup-full-${PLATFORM_VERSION}-*.run" | head -n 1)" \
      && if [ -n "$installer" ]; then \
           chmod +x "$installer" \
           && "$installer" --mode unattended --enable-components "$COMPONENT_PLATFORM"; \
         else \
           apt-get -qq update \
           && apt-get -qq install --yes --no-install-recommends \
             /tmp/platform-unpacked/*.deb; \
         fi \
      ;; \
    *) \
      tar -xzvf "/tmp/platform/${archive_name}" \
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

RUN if [ -f /tmp/build-artifacts/nethasp.ini ]; then \
    cp /tmp/build-artifacts/nethasp.ini /opt/1cv8/conf/nethasp.ini; \
  fi \
  && rm -rf /tmp/build-artifacts

ENV ONESCRIPT_ROOT=/opt/onescript
ENV PATH=/opt/onescript/bin:${PATH}

RUN mkdir -p "$ONESCRIPT_ROOT" \
  && arch="$(dpkg --print-architecture)" \
  && if [ "$arch" = "amd64" ]; then \
       curl -fsSL -o /tmp/onescript.zip \
         "https://github.com/EvilBeaver/OneScript/releases/download/v${ONESCRIPT_VERSION}/OneScript-${ONESCRIPT_VERSION}-linux-x64.zip"; \
       unzip -q /tmp/onescript.zip -d "$ONESCRIPT_ROOT"; \
       chmod +x "$ONESCRIPT_ROOT/bin/oscript" "$ONESCRIPT_ROOT/bin/opm"; \
       ln -sf "$ONESCRIPT_ROOT/bin/oscript" /usr/local/bin/oscript; \
       ln -sf "$ONESCRIPT_ROOT/bin/opm" /usr/local/bin/opm; \
       oscript --version; \
       opm --version; \
       opm install "add@${VANESSA_ADD_VERSION}"; \
       opm install "vanessa-runner@${VANESSA_RUNNER_VERSION}"; \
       test -f "$ONESCRIPT_ROOT/lib/add/packagedef"; \
       command -v vrunner >/dev/null; \
     else \
       echo "Skipping OneScript install on $arch: upstream v${ONESCRIPT_VERSION} release has no Linux $arch artifact."; \
     fi \
  && rm -f /tmp/onescript.zip

EXPOSE 5900

ENTRYPOINT ["/init"]
