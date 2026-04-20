# syntax=docker/dockerfile:1.7
ARG PG_MAJOR=17
ARG COMMON_BASE_IMAGE=mussolene/linux-common-base:bookworm
FROM postgres:${PG_MAJOR}-bookworm AS postgres-upstream

FROM ${COMMON_BASE_IMAGE}

ARG PG_MAJOR=17
ARG PG_REPO_DIST=bookworm
ARG PG_1C_VERSION=17.7-1.1C
ARG TARGETARCH

ENV LANGUAGE=ru_RU.UTF-8
ENV LC_ALL=ru_RU.UTF-8
ENV LANG=ru_RU.UTF-8
ENV PG_MAJOR=${PG_MAJOR}
ENV PG_REPO_DIST=${PG_REPO_DIST}
ENV PG_1C_VERSION=${PG_1C_VERSION}
ENV PGDATA=/var/lib/postgresql/data
ENV PGLOG=/var/log/postgresql
ENV PATH=/usr/lib/postgresql/${PG_MAJOR}/bin:$PATH

COPY --from=postgres-upstream /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY --from=postgres-upstream /usr/local/bin/docker-ensure-initdb.sh /usr/local/bin/docker-ensure-initdb.sh
COPY --from=postgres-upstream /usr/local/bin/docker-enforce-initdb.sh /usr/local/bin/docker-enforce-initdb.sh
COPY --from=postgres-upstream /usr/local/bin/gosu /usr/local/bin/gosu
COPY pg/download-postgresql-1c.sh /usr/local/bin/download-postgresql-1c.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-ensure-initdb.sh /usr/local/bin/docker-enforce-initdb.sh /usr/local/bin/gosu /usr/local/bin/download-postgresql-1c.sh \
  && mkdir -p /docker-entrypoint-initdb.d "$PGLOG" /var/run/postgresql \
  && chmod 03775 /var/run/postgresql

RUN --mount=type=secret,id=its_login,required=true \
    --mount=type=secret,id=its_password,required=true \
    export DEBIAN_FRONTEND=noninteractive; \
    rm -rf /var/lib/apt/lists/* \
    && mkdir -p /etc/postgresql-common \
    && echo 'create_main_cluster = false' > /etc/postgresql-common/createcluster.conf \
    && apt-get update -o APT::Sandbox::User=root -o Acquire::Retries=5 \
    && apt-get install -y -o APT::Sandbox::User=root --no-install-recommends \
      bzip2 \
      ssl-cert \
      tzdata \
    && PG_DOWNLOAD_DIR=/tmp/pg1c /usr/local/bin/download-postgresql-1c.sh \
    && apt-get install -y -o APT::Sandbox::User=root -o Dpkg::Options::=--force-confold --no-install-recommends /tmp/pg1c/*.deb \
    && rm -rf /tmp/pg1c /var/lib/apt/lists/* \
    && printf '%s\n' 'ru_RU.UTF-8 UTF-8' 'ru_RU.CP1251 CP1251' > /etc/locale.gen \
    && locale-gen \
    && find "/usr/lib/postgresql/${PG_MAJOR}/bin" -maxdepth 1 -type f -executable -exec ln -sf {} /usr/local/bin/ \; \
    && mkdir -p "$PGDATA" \
    && chown -R postgres:postgres "$PGLOG" "$PGDATA" /var/run/postgresql

VOLUME ["/var/lib/postgresql/data"]

EXPOSE 5432

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]
