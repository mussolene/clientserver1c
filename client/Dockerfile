FROM debian:bullseye-slim

ARG PLATFORM_VERSION=8.3.22.1851
ARG PLATFORM_DIST_NAME

ENV DEBIAN_FRONTEND noninteractive
ENV GOSU_VERSION 1.13
ENV PLATFORM_VERSION=${PLATFORM_VERSION}
ENV PLATFORM_DIST_NAME=${PLATFORM_DIST_NAME}
ENV COMPONENT_PLATFORM client_full
COPY .local/1c/client-platform/ /tmp/platform/
ENV DISPLAY=:0
ENV DISPLAY_WIDTH=1440
ENV DISPLAY_HEIGHT=900

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.8.0/s6-overlay-amd64.tar.gz /tmp/

RUN printf '%s\n' \
  "deb http://deb.debian.org/debian bullseye main contrib non-free" \
  "deb http://deb.debian.org/debian-security bullseye-security main contrib non-free" \
  "deb http://deb.debian.org/debian bullseye-updates main contrib non-free" \
  > /etc/apt/sources.list \
  && apt-get update \
  && apt-mark hold iptables \
  && env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  dbus-x11 \
  psmisc \
  xdg-utils \
  x11-xserver-utils \
  x11-utils \
  xvfb \
  && env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  xfce4 \
  xfce4-goodies \
  && sed -i 's%<property name="ThemeName" type="string" value="Xfce"/>%<property name="ThemeName" type="string" value="Raleigh"/>%' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  dirmngr \
  gnupg \
  && echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  ca-certificates \
  git \
  locales \
  ttf-mscorefonts-installer \
  libfontconfig1 \
  libgsf-1-114 \
  libglib2.0-0 \
  libgtk2.0-0 \
  libodbc1 \
  libtcmalloc-minimal4 \
  libmagickwand-6.q16-6 \
  at-spi2-core \
  procps \
  unzip \
  x11vnc \
  # Install libpng12-0 from xenial
  && printf '%s\n' 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99legacy-repos \
  && echo "deb [trusted=yes] http://security.ubuntu.com/ubuntu xenial-security main" > /etc/apt/sources.list.d/xenial-security.list \
  && apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  libpng12-0 \
  && rm -rf /etc/apt/sources.list.d/xenial-security.list \
  # Install libwebkitgtk from stretch
  && echo "deb [trusted=yes] http://archive.debian.org/debian stretch main contrib non-free" > /etc/apt/sources.list.d/stretch.list \
  && apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  libwebkitgtk-3.0-0 \
  && rm -rf /etc/apt/sources.list.d/stretch.list /etc/apt/apt.conf.d/99legacy-repos \
  && apt-get update \
  && rm -rf  \
  /var/lib/apt/lists/* \
  /var/cache/debconf \
  && localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8
ENV LANG ru_RU.UTF-8

# remove DST Root CA X3 cert if it exists
COPY artifacts/scripts/remove-dst-root-ca-x3.sh /remove-dst-root-ca-x3.sh
RUN chmod +x /remove-dst-root-ca-x3.sh \
  && /remove-dst-root-ca-x3.sh \
  && rm /remove-dst-root-ca-x3.sh

RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C / \
  && rm -rf /tmp/s6-overlay-amd64.tar.gz

COPY artifacts/client-vnc/rootfs/ /
COPY artifacts/ /tmp/build-artifacts/

RUN apt-get -qq update && apt-get -qq install --yes --no-install-recommends apt-utils ca-certificates wget locales iputils-ping sudo gnupg2 curl htop vim mc \
  && `#----- Install the dependencies -----` \
  && apt-get -qq install --yes --no-install-recommends fontconfig imagemagick \
  && `#----- Deal with ttf-mscorefonts-installer -----` \
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
    if [ -f "/tmp/platform/setup-full-${PLATFORM_VERSION}-x86_64.run" ]; then \
      archive_name="setup-full-${PLATFORM_VERSION}-x86_64.run"; \
    elif [ -f "/tmp/platform/all-clients-distr-${PLATFORM_VERSION}-x86_64.run" ]; then \
      archive_name="all-clients-distr-${PLATFORM_VERSION}-x86_64.run"; \
    elif [ -f "/tmp/platform/server64_with_all_clients_${version_underscored}.zip" ]; then \
      archive_name="server64_with_all_clients_${version_underscored}.zip"; \
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
      && if [ -f "/tmp/platform-unpacked/setup-full-${PLATFORM_VERSION}-x86_64.run" ]; then \
        chmod +x "/tmp/platform-unpacked/setup-full-${PLATFORM_VERSION}-x86_64.run" \
        && "/tmp/platform-unpacked/setup-full-${PLATFORM_VERSION}-x86_64.run" --mode unattended --enable-components "$COMPONENT_PLATFORM"; \
      else \
        apt-get -qq update \
        && apt-get -qq install --yes --no-install-recommends \
          /tmp/platform-unpacked/1c-enterprise-${PLATFORM_VERSION}-thin-client_*.deb \
          /tmp/platform-unpacked/1c-enterprise-${PLATFORM_VERSION}-thin-client-nls_*.deb; \
      fi \
      ;; \
    *) \
      tar -xzvf "/tmp/platform/${archive_name}" \
      && ./setup-full-$PLATFORM_VERSION-x86_64.run --mode unattended --enable-components $COMPONENT_PLATFORM \
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

EXPOSE 5900

ENTRYPOINT ["/init"]
