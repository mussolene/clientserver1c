FROM debian:stretch-slim

RUN echo -e "nameserver 1.1.1.1\nnameserver 8.8.4.4" | tee -a /etc/resolv.conf

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
RUN apt-get update && apt-get install -y locales locales-all && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
	&& locale-gen en_US.UTF-8 \
	&& locale-gen ru_RU.UTF-8 \
	&& locale-gen ru_RU.CP1251 
#        && update-locale LANG=ru_RU \
#        && dpkg-reconfigure locales 

# Env section
ENV GOSU_VERSION 1.7
ENV LANGUAGE en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

# explicitly set user/group IDs
RUN groupadd -r postgres --gid=999 && useradd -r -g postgres --uid=999 postgres

# grab gosu for easy step-down from root
RUN set -x \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates wget gnupg dirmngr lsb-release \
	&& rm -rf /var/lib/apt/lists/* \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc"


RUN apt-get -qq update \
	&& apt-get -qq install --yes --no-install-recommends ca-certificates wget locales curl libicu57 libxml2 procps ssl-cert libxslt1.1\
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* \
	&& wget --quiet -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true \
	&& apt-get purge -y --auto-remove

RUN mkdir /docker-entrypoint-initdb.d

RUN mkdir /docker-entrypoint-init.d

# Version env
ENV PG_MAJOR 14
ENV PG_MINOR 7

# Install pgpro
#RUN echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/postgrespro.list \
#	&& apt-get update \
#	&& apt-get install -y postgrespro-std-$PG_MAJOR \
#	&& rm -rf /var/lib/apt/lists/*

RUN mkdir postgres && cd postgres && wget -O  postgrespro-1c-$PG_MAJOR-server.deb http://repo.postgrespro.ru/pg1c-$PG_MAJOR/debian/pool/main/p/postgrespro-1c-$PG_MAJOR/postgrespro-1c-$PG_MAJOR-server_$PG_MAJOR.$PG_MINOR-1.stretch_amd64.deb \
	&& wget -O  postgrespro-1c-$PG_MAJOR-libs.deb http://repo.postgrespro.ru/pg1c-$PG_MAJOR/debian/pool/main/p/postgrespro-1c-$PG_MAJOR/postgrespro-1c-$PG_MAJOR-libs_$PG_MAJOR.$PG_MINOR-1.stretch_amd64.deb \
	&& wget -O  postgrespro-1c-$PG_MAJOR-client.deb http://repo.postgrespro.ru/pg1c-$PG_MAJOR/debian/pool/main/p/postgrespro-1c-$PG_MAJOR/postgrespro-1c-$PG_MAJOR-client_$PG_MAJOR.$PG_MINOR-1.stretch_amd64.deb \
	&& wget -O  postgrespro-1c-$PG_MAJOR-contrib.deb http://repo.postgrespro.ru/pg1c-$PG_MAJOR/debian/pool/main/p/postgrespro-1c-$PG_MAJOR/postgrespro-1c-$PG_MAJOR-contrib_$PG_MAJOR.$PG_MINOR-1.stretch_amd64.deb \
	&& dpkg -i *.deb


RUN mkdir -p /var/run/postgresql && chown -R postgres /var/run/postgresql && chown -R postgres /var/lib/postgresql

ENV PATH /opt/pgpro/1c-$PG_MAJOR/bin:$PATH
ENV PGDATA /var/lib/postgresql/data
ENV PGLOG /var/log/postgresql

COPY pg/docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 5432
CMD ["postgres"]
