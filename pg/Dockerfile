ARG PG_REPO_DIST=bookworm
ARG PG_MAJOR=17
FROM postgres:${PG_MAJOR}-${PG_REPO_DIST}

ARG PG_MAJOR=17
ARG PG_REPO_DIST=bookworm

ENV LANGUAGE=ru_RU.UTF-8
ENV LC_ALL=ru_RU.UTF-8
ENV LANG=ru_RU.UTF-8
ENV PG_MAJOR=${PG_MAJOR}
ENV PG_REPO_DIST=${PG_REPO_DIST}
ENV PGLOG=/var/log/postgresql

RUN rm -rf /var/lib/apt/lists/* \
  && apt-get update -o Acquire::Retries=5 \
  && apt-get install -y --no-install-recommends \
    locales \
    procps \
  && rm -rf /var/lib/apt/lists/* \
  && locale-gen ru_RU.UTF-8 \
  && locale-gen ru_RU.CP1251 \
  && mkdir -p "$PGLOG" \
  && chown -R postgres:postgres "$PGLOG"

EXPOSE 5432
