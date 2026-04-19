FROM ubuntu:20.04

ARG PLATFORM_VERSION=8.3.22.1851
ARG PLATFORM_DIST_NAME

ENV DEBIAN_FRONTEND noninteractive
ENV GOSU_VERSION 1.13
ENV PLATFORM_VERSION=${PLATFORM_VERSION}
ENV PLATFORM_DIST_NAME=${PLATFORM_DIST_NAME}
ENV COMPONENT_PLATFORM server
COPY .local/1c/server-platform/ /tmp/platform/
COPY artifacts/ /tmp/build-artifacts/

RUN apt-get -qq update && apt-get -qq install --yes --no-install-recommends apt-utils ca-certificates wget locales iputils-ping sudo gnupg2 curl htop vim mc libc-dev curl gcc bison flex make musl-dev libssl-dev bc libelf-dev usbutils unzip \
  && `#----- Install the dependencies -----` \
  && apt-get -qq install --yes --no-install-recommends fontconfig imagemagick \
  && `#----- Deal with ttf-mscorefonts-installer -----` \
  && echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections \
  && apt-get -qq install --yes --no-install-recommends xfonts-utils cabextract \
  && apt-get -qq install libgsf-1-114 ttf-mscorefonts-installer t1utils unixodbc \
  && `#----- Install gosu -----` \
  && wget --quiet --output-document /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
  && chmod +x /usr/local/bin/gosu \
  && gosu nobody true 

RUN localedef --inputfile ru_RU --force --charmap UTF-8 --alias-file /usr/share/locale/locale.alias ru_RU.UTF-8
ENV LANG ru_RU.utf8

RUN archive_name="${PLATFORM_DIST_NAME}" \
  && if [ -z "$archive_name" ]; then \
    version_underscored="$(printf '%s' "$PLATFORM_VERSION" | tr '.' '_')"; \
    if [ -f "/tmp/platform/server64_${version_underscored}.zip" ]; then \
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
      && apt-get -qq update \
      && apt-get -qq install --yes --no-install-recommends \
        /tmp/platform-unpacked/1c-enterprise-${PLATFORM_VERSION}-common_*.deb \
        /tmp/platform-unpacked/1c-enterprise-${PLATFORM_VERSION}-common-nls_*.deb \
        /tmp/platform-unpacked/1c-enterprise-${PLATFORM_VERSION}-server_*.deb \
        /tmp/platform-unpacked/1c-enterprise-${PLATFORM_VERSION}-server-nls_*.deb \
        /tmp/platform-unpacked/1c-enterprise-${PLATFORM_VERSION}-ws_*.deb \
        /tmp/platform-unpacked/1c-enterprise-${PLATFORM_VERSION}-ws-nls_*.deb \
        /tmp/platform-unpacked/1c-enterprise-${PLATFORM_VERSION}-crs_*.deb \
      ;; \
    *) \
      tar -xzvf "/tmp/platform/${archive_name}" \
      && ./setup-full-$PLATFORM_VERSION-x86_64.run --mode unattended --enable-components $COMPONENT_PLATFORM \
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

RUN mkdir /tmp/vhclient \
  && cd /tmp/vhclient \
  && curl https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-5.10.102.tar.gz -o kernel.tar.gz \
  && tar -xzf kernel.tar.gz --strip-components=1 \
  && make defconfig \
  && ([ ! -f /proc/1/root/proc/config.gz ] || zcat /proc/1/root/proc/config.gz > .config) \
  && printf '%s\n' 'CONFIG_USBIP_CORE=m' 'CONFIG_USBIP_VHCI_HCD=m' 'CONFIG_USBIP_VHCI_HC_PORTS=8' 'CONFIG_USBIP_VHCI_NR_HCS=1' >> .config \
  && make oldconfig modules_prepare \
  && make M=drivers/usb/usbip \
  && mkdir -p /dist \
  && cd drivers/usb/usbip \
  && cp usbip-core.ko vhci-hcd.ko /dist \
  && echo -e '[General]\nAutoFind=0\n' > /dist/.vhui \
  && curl -fsSL https://www.virtualhere.com/sites/default/files/usbclient/vhclientx86_64 -o /dist/vhclientx86_64 \
  && chmod +x /dist/vhclientx86_64

COPY artifacts/config/logcfg.xml /home/usr1cv8/.1cv8/1C/1cv8/conf
RUN if [ -f /tmp/build-artifacts/nethasp.ini ]; then \
    cp /tmp/build-artifacts/nethasp.ini /opt/1cv8/conf/nethasp.ini; \
    cp /tmp/build-artifacts/nethasp.ini /home/usr1cv8/.1cv8/1C/1cv8/conf/nethasp.ini; \
  fi \
  && rm -rf /tmp/build-artifacts

EXPOSE 1540-1541 1560-1691 1545

CMD ["gosu", "usr1cv8", "/opt/1cv8/current/ragent", "-debug"]
