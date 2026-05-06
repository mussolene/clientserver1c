ARG BASE_IMAGE=ghcr.io/mussolene/1c-developer:8.5.1.1302

FROM ${BASE_IMAGE}

ARG VIRTUALHERE_CLIENT_URL=https://www.virtualhere.com/sites/default/files/usbclient/vhclientx86_64

RUN apt-get update -o APT::Sandbox::User=root \
  && apt-get install --yes --no-install-recommends -o APT::Sandbox::User=root \
    kmod \
    usbutils \
  && rm -rf /var/lib/apt/lists/* \
  && curl -fsSL --retry 3 --show-error "$VIRTUALHERE_CLIENT_URL" -o /usr/local/bin/vhclientx86_64 \
  && chmod 0755 /usr/local/bin/vhclientx86_64 \
  && /usr/local/bin/vhclientx86_64 -h >/dev/null

COPY licensed/rootfs/ /

RUN chmod +x \
  /etc/cont-init.d/50-server-ibase \
  /etc/services.d/virtualhere/run \
  /etc/services.d/ras/run
