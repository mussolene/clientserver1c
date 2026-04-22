ARG COMMON_BASE_IMAGE=ghcr.io/mussolene/linux-common-base:bookworm
FROM ${COMMON_BASE_IMAGE}

ARG TARGETARCH
ARG S6_OVERLAY_VERSION=1.21.8.0

ENV DISPLAY=:0
ENV DISPLAY_WIDTH=1440
ENV DISPLAY_HEIGHT=900

RUN rm -rf /var/lib/apt/lists/* \
  && apt-get update -o APT::Sandbox::User=root -o Acquire::Retries=5 \
  && apt-mark hold iptables \
  && env DEBIAN_FRONTEND=noninteractive apt-get install -y -o APT::Sandbox::User=root --no-install-recommends \
    at-spi2-core \
    dbus-x11 \
    fonts-roboto \
    libfontconfig1 \
    libglib2.0-0 \
    libglu1-mesa \
    libgtk2.0-0 \
    libicu72 \
    libmagickwand-6.q16-6 \
    libtcmalloc-minimal4 \
    libwebkit2gtk-4.0-37 \
    policykit-1 \
    x11-utils \
    x11-xserver-utils \
    x11vnc \
    xdg-utils \
    xfce4 \
    xfce4-goodies \
    xvfb \
  && sed -i 's%<property name="ThemeName" type="string" value="Xfce"/>%<property name="ThemeName" type="string" value="Raleigh"/>%' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
  && curl -fsSL \
    "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-$(case "${TARGETARCH:-$(dpkg --print-architecture)}" in amd64) echo amd64 ;; arm64) echo aarch64 ;; arm) echo arm ;; *) echo amd64 ;; esac).tar.gz" \
    -o /tmp/s6-overlay.tar.gz \
    && tar xzf /tmp/s6-overlay.tar.gz -C / \
  && ln -sf /usr/bin/bash /bin/bash \
  && ln -sf /usr/bin/dash /bin/sh \
  && rm -f /tmp/s6-overlay.tar.gz \
  && rm -rf /var/lib/apt/lists/* /var/cache/debconf

COPY artifacts/client-vnc/rootfs/ /

EXPOSE 5900

ENTRYPOINT ["/init"]
