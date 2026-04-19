ARG PG_REPO_DIST=bullseye
FROM debian:${PG_REPO_DIST}-slim

ARG PG_MAJOR=17
ARG PG_REPO_DIST=bullseye

# Env section
ENV LANGUAGE=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV PG_MAJOR=${PG_MAJOR}
ENV PG_REPO_DIST=${PG_REPO_DIST}
ENV PATH=/opt/pgpro/1c-${PG_MAJOR}/bin:$PATH
ENV PGDATA=/var/lib/postgresql/data
ENV PGLOG=/var/log/postgresql

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dirmngr \
    gnupg \
    gosu \
    locales \
    procps \
    ssl-cert \
    wget \
  && rm -rf /var/lib/apt/lists/* \
  && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
  && locale-gen en_US.UTF-8 \
  && locale-gen ru_RU.UTF-8 \
  && locale-gen ru_RU.CP1251

RUN wget -qO- "http://repo.postgrespro.ru/1c/1c-${PG_MAJOR}/keys/GPG-KEY-POSTGRESPRO-COMBO" \
    | gpg --dearmor -o /usr/share/keyrings/postgrespro.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/postgrespro.gpg] http://repo.postgrespro.ru/1c/1c-${PG_MAJOR}/debian ${PG_REPO_DIST} main" \
    > /etc/apt/sources.list.d/postgrespro.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    "postgrespro-1c-${PG_MAJOR}-client" \
    "postgrespro-1c-${PG_MAJOR}-contrib" \
    "postgrespro-1c-${PG_MAJOR}-server" \
  && rm -rf /var/lib/apt/lists/*

RUN getent group postgres >/dev/null || groupadd -r postgres --gid=999 \
  && id -u postgres >/dev/null 2>&1 || useradd -r -g postgres --uid=999 postgres \
  && mkdir -p /docker-entrypoint-initdb.d /docker-entrypoint-init.d \
  && mkdir -p /var/run/postgresql /var/lib/postgresql /var/log/postgresql \
  && chown -R postgres /var/run/postgresql /var/lib/postgresql /var/log/postgresql

COPY pg/docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 5432
CMD ["postgres"]
