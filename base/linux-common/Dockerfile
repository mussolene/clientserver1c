ARG COMMON_BASE_DIST=bookworm
FROM debian:${COMMON_BASE_DIST}-slim

ARG COMMON_BASE_DIST=bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=ru_RU.UTF-8

RUN printf '%s\n' \
  && rm -rf /var/lib/apt/lists/* \
  && if [ -f /etc/apt/sources.list.d/debian.sources ]; then \
       sed -i 's/^Components: main$/Components: main contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources; \
     fi \
  && apt-get update -o APT::Sandbox::User=root -o Acquire::Retries=5 \
  && echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections \
  && apt-get install -y -o APT::Sandbox::User=root --no-install-recommends \
    bash \
    cabextract \
    ca-certificates \
    curl \
    fontconfig \
    gosu \
    libgsf-1-114 \
    locales \
    procps \
    t1utils \
    ttf-mscorefonts-installer \
    unixodbc \
    unzip \
    xfonts-utils \
  && localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8 \
  && gosu nobody true \
  && rm -rf /var/lib/apt/lists/* /var/cache/debconf

COPY artifacts/scripts/remove-dst-root-ca-x3.sh /remove-dst-root-ca-x3.sh
RUN chmod +x /remove-dst-root-ca-x3.sh \
  && /remove-dst-root-ca-x3.sh \
  && rm /remove-dst-root-ca-x3.sh
