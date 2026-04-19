ARG COMMON_BASE_DIST=jammy
FROM ubuntu:${COMMON_BASE_DIST}

ARG COMMON_BASE_DIST=jammy

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=ru_RU.UTF-8

RUN printf '%s\n' \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get update -o Acquire::Retries=5 \
  && echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections \
  && apt-get install -y --no-install-recommends \
    apt-utils \
    ca-certificates \
    cabextract \
    curl \
    dirmngr \
    fontconfig \
    gosu \
    gnupg \
    htop \
    imagemagick \
    iputils-ping \
    libgsf-1-114 \
    locales \
    mc \
    procps \
    sudo \
    t1utils \
    ttf-mscorefonts-installer \
    unixodbc \
    unzip \
    vim \
    wget \
    xfonts-utils \
  && localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8 \
  && gosu nobody true \
  && rm -rf /var/lib/apt/lists/* /var/cache/debconf

COPY artifacts/scripts/remove-dst-root-ca-x3.sh /remove-dst-root-ca-x3.sh
RUN chmod +x /remove-dst-root-ca-x3.sh \
  && /remove-dst-root-ca-x3.sh \
  && rm /remove-dst-root-ca-x3.sh
