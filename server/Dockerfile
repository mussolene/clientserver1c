FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive
ENV GOSU_VERSION 1.13
ENV PLATFORM_VERSION 8.3.23.1437
ENV SERVER_VERSION 8.3.23-1437
ENV PATH_PLATFORM_TAR server64_8_3_23_1437.tar.gz
ENV COMPONENT_PLATFORM client_full,server,ws
COPY $PATH_PLATFORM_TAR /tmp/

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
  && rm -rf /tmp/* \
  && mkdir --parent /var/log/1C /home/usr1cv8/.1cv8/1C/1cv8/conf \
  && chown --recursive usr1cv8:grp1cv8 /var/log/1C /home/usr1cv8

# create symlink to current 1c:enterprise directory
COPY createsymlink-current.sh /createsymlink-current.sh
RUN chmod +x /createsymlink-current.sh \
  && /createsymlink-current.sh \
  && rm /createsymlink-current.sh

COPY docker-entrypoint.sh /
COPY logcfg.xml /home/usr1cv8/.1cv8/1C/1cv8/conf

EXPOSE 1540-1541 1560-1591

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["ragent"]

