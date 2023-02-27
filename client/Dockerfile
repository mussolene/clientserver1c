FROM debian:bullseye-backports

ENV DEBIAN_FRONTEND noninteractive
ENV GOSU_VERSION 1.13
ENV PLATFORM_VERSION 8.3.23.1437
ENV SERVER_VERSION 8.3.23-1437
ENV PATH_PLATFORM_TAR server64_8_3_23_1437.tar.gz
ENV COMPONENT_PLATFORM client_full
COPY $PATH_PLATFORM_TAR /tmp/
ENV DISPLAY=:0
ENV DISPLAY_WIDTH=1440
ENV DISPLAY_HEIGHT=900

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.8.0/s6-overlay-amd64.tar.gz /tmp/

RUN apt-get update \
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
  && echo "deb http://http.debian.net/debian/ bullseye main contrib non-free" > /etc/apt/sources.list \
  && echo "deb http://http.debian.net/debian/ bullseye-backports main" >> /etc/apt/sources.list \
  && echo "deb http://http.debian.net/debian/ bullseye-proposed-updates main contrib non-free" >> /etc/apt/sources.list \
  && echo "deb http://security.debian.org/debian-security/ bullseye-security main contrib non-free" >> /etc/apt/sources.list \
  && echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections \
  && apt-get update \
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
  x11vnc \
  # Install libpng12-0 from xenial
  && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 40976EAF437D05B5 \
  && echo "deb http://security.ubuntu.com/ubuntu xenial-security main" > /etc/apt/sources.list.d/xenial-security.list \
  && apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  libpng12-0 \
  && rm -rf  /etc/apt/sources.list.d/xenial-security.list \
  && apt-get update \
  # Install libwebkitgtk from stretch
  && echo "deb http://deb.debian.org/debian/ stretch main contrib non-free" > /etc/apt/sources.list.d/stretch.list \
  && apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  libwebkitgtk-3.0-0 \
  && rm -rf  /etc/apt/sources.list.d/stretch.list \
  && apt-get update \
  && rm -rf  \
  /var/lib/apt/lists/* \
  /var/cache/debconf \
  && localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8
ENV LANG ru_RU.UTF-8

# remove DST Root CA X3 cert if it exists
COPY remove-dst-root-ca-x3.sh /remove-dst-root-ca-x3.sh
RUN chmod +x /remove-dst-root-ca-x3.sh \
  && /remove-dst-root-ca-x3.sh \
  && rm /remove-dst-root-ca-x3.sh

RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C / \
  && rm -rf /tmp/s6-overlay-amd64.tar.gz

COPY ./client-vnc/rootfs/ /

RUN apt-get -qq update && apt-get -qq install --yes --no-install-recommends apt-utils ca-certificates wget locales iputils-ping sudo gnupg2 curl htop vim mc \
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
  && rm -rf /tmp/* 

# create symlink to current 1c:enterprise directory
COPY createsymlink-current.sh /createsymlink-current.sh
RUN chmod +x /createsymlink-current.sh \
  && /createsymlink-current.sh \
  && rm /createsymlink-current.sh

COPY nethasp.ini /opt/1cv8/conf/nethasp.ini

EXPOSE 5900

ENTRYPOINT ["/init"]

