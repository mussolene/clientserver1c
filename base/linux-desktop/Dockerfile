ARG BASE_DEBIAN_DIST=bullseye
FROM debian:${BASE_DEBIAN_DIST}-slim

ARG BASE_DEBIAN_DIST=bullseye
ARG TARGETARCH
ARG GOSU_VERSION=1.13
ARG S6_OVERLAY_VERSION=1.21.8.0

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0
ENV DISPLAY_WIDTH=1440
ENV DISPLAY_HEIGHT=900
ENV LANG=ru_RU.UTF-8

RUN printf '%s\n' \
  "deb http://deb.debian.org/debian ${BASE_DEBIAN_DIST} main contrib non-free" \
  "deb http://deb.debian.org/debian-security ${BASE_DEBIAN_DIST}-security main contrib non-free" \
  "deb http://deb.debian.org/debian ${BASE_DEBIAN_DIST}-updates main contrib non-free" \
  > /etc/apt/sources.list \
  && apt-get update \
  && apt-mark hold iptables \
  && echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections \
  && env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    apt-utils \
    at-spi2-core \
    ca-certificates \
    cabextract \
    curl \
    dbus-x11 \
    dirmngr \
    evince \
    fontconfig \
    fonts-roboto \
    git \
    gnupg \
    htop \
    imagemagick \
    iputils-ping \
    libfontconfig1 \
    libglib2.0-0 \
    libglu1-mesa \
    libgsf-1-114 \
    libgtk2.0-0 \
    libicu67 \
    libmagickwand-6.q16-6 \
    libodbc1 \
    libtcmalloc-minimal4 \
    libwebkit2gtk-4.0-37 \
    locales \
    mc \
    policykit-1 \
    procps \
    psmisc \
    sudo \
    t1utils \
    ttf-mscorefonts-installer \
    unixodbc \
    unzip \
    vim \
    wget \
    x11-utils \
    x11-xserver-utils \
    x11vnc \
    xdg-utils \
    xfonts-utils \
    xfce4 \
    xfce4-goodies \
    xvfb \
    zenity \
  && sed -i 's%<property name="ThemeName" type="string" value="Xfce"/>%<property name="ThemeName" type="string" value="Raleigh"/>%' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
  && localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8 \
  && curl -fsSL \
    "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-$(case "${TARGETARCH:-$(dpkg --print-architecture)}" in amd64) echo amd64 ;; arm64) echo aarch64 ;; arm) echo arm ;; *) echo amd64 ;; esac).tar.gz" \
    -o /tmp/s6-overlay.tar.gz \
  && tar xzf /tmp/s6-overlay.tar.gz -C / \
  && rm -f /tmp/s6-overlay.tar.gz \
  && wget --quiet --output-document /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$(dpkg --print-architecture)" \
  && chmod +x /usr/local/bin/gosu \
  && gosu nobody true \
  && rm -rf /var/lib/apt/lists/* /var/cache/debconf

COPY artifacts/scripts/remove-dst-root-ca-x3.sh /remove-dst-root-ca-x3.sh
RUN chmod +x /remove-dst-root-ca-x3.sh \
  && /remove-dst-root-ca-x3.sh \
  && rm /remove-dst-root-ca-x3.sh

COPY artifacts/client-vnc/rootfs/ /

EXPOSE 5900

ENTRYPOINT ["/init"]
