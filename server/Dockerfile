FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive
ENV GOSU_VERSION 1.13
ENV PLATFORM_VERSION 8.3.22.1851
ENV SERVER_VERSION 8.3.22-1851
ENV PATH_PLATFORM_TAR server64_8_3_22_1851.tar.gz
ENV COMPONENT_PLATFORM server
COPY artifacts/$PATH_PLATFORM_TAR /tmp/

RUN apt-get -qq update && apt-get -qq install --yes --no-install-recommends apt-utils ca-certificates wget locales iputils-ping sudo gnupg2 curl htop vim mc libc-dev curl gcc bison flex make musl-dev libssl-dev bc libelf-dev usbutils \
  && `#----- Install the dependencies -----` \
  && apt-get -qq install --yes --no-install-recommends fontconfig imagemagick \
  && `#----- Deal with ttf-mscorefonts-installer -----` \
  && apt-get -qq install --yes --no-install-recommends xfonts-utils cabextract \
  && apt-get -qq install libgsf-1-114 ttf-mscorefonts-installer t1utils unixodbc \
  && wget --quiet --output-document /tmp/ttf-mscorefonts-installer_3.6_all.deb http://ftp.us.debian.org/debian/pool/contrib/m/msttcorefonts/ttf-mscorefonts-installer_3.6_all.deb \
  && dpkg --install /tmp/ttf-mscorefonts-installer_3.6_all.deb 2> /dev/null \
  && rm /tmp/ttf-mscorefonts-installer_3.6_all.deb \
  && `#----- Install gosu -----` \
  && wget --quiet --output-document /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
  && chmod +x /usr/local/bin/gosu \
  && gosu nobody true 

RUN localedef --inputfile ru_RU --force --charmap UTF-8 --alias-file /usr/share/locale/locale.alias ru_RU.UTF-8
ENV LANG ru_RU.utf8

RUN cd /tmp && tar -xzvf $PATH_PLATFORM_TAR \
  && ./setup-full-$PLATFORM_VERSION-x86_64.run --mode unattended --enable-components $COMPONENT_PLATFORM \
  && rm -rf /tmp/* \
  && mkdir --parent /var/log/1C /home/usr1cv8/.1cv8/1C/1cv8/conf \
  && chown --recursive usr1cv8:grp1cv8 /var/log/1C /home/usr1cv8

# create symlink to current 1c:enterprise directory
COPY artifacts/createsymlink-current.sh /createsymlink-current.sh
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

COPY server/docker-entrypoint.sh /
COPY artifacts/logcfg.xml /home/usr1cv8/.1cv8/1C/1cv8/conf
COPY artifacts/nethasp.ini /opt/1cv8/conf/nethasp.ini
COPY artifacts/nethasp.ini /home/usr1cv8/.1cv8/1C/1cv8/conf/nethasp.ini

EXPOSE 1540-1541 1560-1591 1545

CMD ["gosu", "usr1cv8", "/opt/1cv8/current/ragent", "-debug"]

