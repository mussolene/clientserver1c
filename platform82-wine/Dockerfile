ARG COMMON_BASE_IMAGE=ghcr.io/mussolene/linux-common-base:bookworm
FROM ${COMMON_BASE_IMAGE}

ARG PLATFORM_VERSION=8.2.19.130
ARG PLATFORM_ARCHIVE_NAME=windows.rar

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=ru_RU.UTF-8
ENV LANGUAGE=ru_RU:ru
ENV LC_ALL=ru_RU.UTF-8
ENV WINEDEBUG=-all
ENV WINEARCH=win32
ENV WINEPREFIX=/opt/wineprefix
ENV DISPLAY=:99
ENV ONEC82_VERSION=${PLATFORM_VERSION}
ENV ONEC82_HOME="/opt/wineprefix/drive_c/Program Files/1cv82/${PLATFORM_VERSION}"
ENV ONEC82_BIN="/opt/wineprefix/drive_c/Program Files/1cv82/${PLATFORM_VERSION}/bin/1cv8.exe"

RUN dpkg --add-architecture i386 \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get update -o APT::Sandbox::User=root -o Acquire::Retries=5 \
  && apt-get install -y -o APT::Sandbox::User=root --no-install-recommends \
    libarchive-tools \
    locales \
    wine \
    wine32 \
    wine64 \
    xauth \
    xvfb \
  && localedef -i ru_RU -c -f UTF-8 -A /usr/share/locale/locale.alias ru_RU.UTF-8 \
  && rm -rf /var/lib/apt/lists/* /var/cache/debconf

RUN --mount=type=bind,source=.local/1c/wine82-platform,target=/tmp/platform-staging,readonly \
  --mount=type=cache,target=/tmp/wine82-unpacked \
  bash -euxo pipefail <<'EOF'
archive_path="/tmp/platform-staging/${PLATFORM_ARCHIVE_NAME}"
unpack_dir=/tmp/wine82-unpacked
msi_path=

if [[ ! -f "$archive_path" ]]; then
  echo "Missing 1C 8.2 Windows archive: $archive_path" >&2
  echo "Prepare it on the host, for example:" >&2
  echo "  mkdir -p .local/1c/wine82-platform" >&2
  echo "  cp .local/1c/platform/windows.rar .local/1c/wine82-platform/windows.rar" >&2
  exit 1
fi

rm -rf "$unpack_dir"/*
mkdir -p "$unpack_dir"
bsdtar -xf "$archive_path" -C "$unpack_dir"

msi_path="$(find "$unpack_dir" -type f -iname '1CEnterprise 8.2.msi' | head -n 1)"
if [[ -z "$msi_path" ]]; then
  msi_path="$(find "$unpack_dir" -type f -iname '*.msi' | head -n 1)"
fi
if [[ -z "$msi_path" ]]; then
  echo "Could not find 1CEnterprise 8.2 MSI inside ${PLATFORM_ARCHIVE_NAME}" >&2
  find "$unpack_dir" -maxdepth 3 -type f | sort >&2
  exit 1
fi

xvfb-run -a wineboot --init
xvfb-run -a wine msiexec /i "$msi_path" /qn /norestart

for required_binary in 1cv8.exe 1cv8c.exe chdbfl.exe; do
  if ! find "$WINEPREFIX/drive_c" -type f -iname "$required_binary" | grep -q .; then
    echo "Required 1C 8.2 binary is missing after Wine install: $required_binary" >&2
    exit 1
  fi
done

mkdir -p \
  "$WINEPREFIX/drive_c/Program Files/1cv82/conf" \
  "$ONEC82_HOME/conf" \
  "$ONEC82_HOME/bin" \
  "$WINEPREFIX/drive_c/windows" \
  "$WINEPREFIX/drive_c/users/root/Application Data/1C/1cv82/conf"

rm -rf "$unpack_dir"/*
EOF

COPY platform82-wine/rootfs/ /

RUN chmod +x /usr/local/bin/onec82-check-config \
  && onec82-check-config --version

WORKDIR /workspace
ENTRYPOINT ["onec82-check-config"]
