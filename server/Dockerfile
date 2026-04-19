ARG COMMON_BASE_IMAGE=mussolene/linux-common-base
ARG COMMON_BASE_TAG=jammy
FROM ${COMMON_BASE_IMAGE}:${COMMON_BASE_TAG}

ARG TARGETARCH
ARG PLATFORM_VERSION=8.3.22.1851
ARG PLATFORM_DIST_NAME
ARG ENABLE_USBIP_TOOLS=0

ENV PLATFORM_VERSION=${PLATFORM_VERSION}
ENV PLATFORM_DIST_NAME=${PLATFORM_DIST_NAME}
ENV ENABLE_USBIP_TOOLS=${ENABLE_USBIP_TOOLS}
ENV COMPONENT_PLATFORM=server
COPY .local/1c/server-platform/ /tmp/platform/
COPY artifacts/ /tmp/build-artifacts/

RUN rm -rf /var/lib/apt/lists/* \
  && apt-get -qq update -o Acquire::Retries=5 \
  && apt-get -qq install --yes --no-install-recommends \
    bc \
    bison \
    flex \
    gcc \
    libelf-dev \
    libc-dev \
    libssl-dev \
    make \
    musl-dev \
    usbutils \
  && rm -rf /var/lib/apt/lists/*

RUN archive_name="${PLATFORM_DIST_NAME}" \
  && if [ -z "$archive_name" ]; then \
    version_underscored="$(printf '%s' "$PLATFORM_VERSION" | tr '.' '_')"; \
    if [ -f "/tmp/platform/server.arm.deb64_${PLATFORM_VERSION}.zip" ]; then \
      archive_name="server.arm.deb64_${PLATFORM_VERSION}.zip"; \
    elif [ -f "/tmp/platform/server64_${version_underscored}.zip" ]; then \
      archive_name="server64_${version_underscored}.zip"; \
    elif [ -f "/tmp/platform/deb64_${version_underscored}.zip" ]; then \
      archive_name="deb64_${version_underscored}.zip"; \
    else \
      archive_name="server64_${version_underscored}.tar.gz"; \
    fi; \
  fi \
  && test -f "/tmp/platform/${archive_name}" \
  && cd /tmp \
  && case "$archive_name" in \
    *.zip) \
      mkdir -p /tmp/platform-unpacked \
      && unzip -q "/tmp/platform/${archive_name}" -d /tmp/platform-unpacked \
      && rm -rf /var/lib/apt/lists/* \
      && apt-get -qq update -o Acquire::Retries=5 \
      && apt-get -qq install --yes --no-install-recommends \
        /tmp/platform-unpacked/*.deb \
      ;; \
    *) \
      tar -xzvf "/tmp/platform/${archive_name}" \
      && installer="$(find . -maxdepth 1 -name "setup-full-${PLATFORM_VERSION}-*.run" | head -n 1)" \
      && chmod +x "$installer" \
      && "$installer" --mode unattended --enable-components $COMPONENT_PLATFORM \
      ;; \
    esac \
  && rm -rf /tmp/* \
  && mkdir --parent /var/log/1C /home/usr1cv8/.1cv8/1C/1cv8/conf \
  && chown --recursive usr1cv8:grp1cv8 /var/log/1C /home/usr1cv8

# create symlink to current 1c:enterprise directory
COPY artifacts/scripts/createsymlink-current.sh /createsymlink-current.sh
RUN chmod +x /createsymlink-current.sh \
  && /createsymlink-current.sh \
  && rm /createsymlink-current.sh

RUN arch="$(dpkg --print-architecture)" \
  && usbip_mode="$ENABLE_USBIP_TOOLS" \
  && if [ "$usbip_mode" = "auto" ]; then \
       usbip_mode="0"; \
     fi \
  && if [ "$usbip_mode" = "1" ]; then \
       mkdir /tmp/vhclient \
       && cd /tmp/vhclient \
       && curl https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-5.10.102.tar.gz -o kernel.tar.gz \
       && tar -xzf kernel.tar.gz --strip-components=1 \
       && make defconfig \
       && ([ ! -f /proc/1/root/proc/config.gz ] || zcat /proc/1/root/proc/config.gz > .config) \
       && printf '%s\n' 'CONFIG_USBIP_CORE=m' 'CONFIG_USBIP_VHCI_HCD=m' 'CONFIG_USBIP_VHCI_HC_PORTS=8' 'CONFIG_USBIP_VHCI_NR_HCS=1' >> .config \
       && yes "" | make oldconfig modules_prepare \
       && make M=drivers/usb/usbip \
       && mkdir -p /dist \
       && cd drivers/usb/usbip \
       && cp usbip-core.ko vhci-hcd.ko /dist \
       && printf '%s\n' '[General]' 'AutoFind=0' > /dist/.vhui \
       && curl -fsSL https://www.virtualhere.com/sites/default/files/usbclient/vhclientx86_64 -o /dist/vhclientx86_64 \
       && chmod +x /dist/vhclientx86_64; \
     else \
       echo "Skipping USB/IP helper build on $arch"; \
     fi

COPY artifacts/config/logcfg.xml /home/usr1cv8/.1cv8/1C/1cv8/conf
RUN if [ -f /tmp/build-artifacts/nethasp.ini ]; then \
    cp /tmp/build-artifacts/nethasp.ini /opt/1cv8/conf/nethasp.ini; \
    cp /tmp/build-artifacts/nethasp.ini /home/usr1cv8/.1cv8/1C/1cv8/conf/nethasp.ini; \
  fi \
  && rm -rf /tmp/build-artifacts

EXPOSE 1540-1541 1560-1691 1545

CMD ["gosu", "usr1cv8", "/opt/1cv8/current/ragent", "-debug"]
