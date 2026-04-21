ARG DESKTOP_BASE_IMAGE=mussolene/linux-desktop-base:bookworm
ARG ONESCRIPT_BASE_IMAGE=mussolene/linux-onescript:2.0.0
FROM ${ONESCRIPT_BASE_IMAGE} AS onescript_base
FROM ${DESKTOP_BASE_IMAGE}

ARG TARGETARCH
ARG PLATFORM_VERSION=8.5.1.1302
ARG PLATFORM_DIST_NAME
ARG VANESSA_ADD_VERSION=6.9.5
ARG VANESSA_RUNNER_VERSION=2.6.0

ENV PLATFORM_VERSION=${PLATFORM_VERSION}
ENV PLATFORM_DIST_NAME=${PLATFORM_DIST_NAME}
ENV ONESCRIPT_ROOT=/opt/onescript
ENV PATH=/opt/onescript:/opt/onescript/bin:${PATH}
ENV OSCRIPT_CONFIG=lib.system=/opt/onescript/lib
ENV OPM_CONFIG=/opt/onescript/opm.cfg
ENV OSCRIPTBIN=/opt/onescript/bin
COPY artifacts/ /tmp/build-artifacts/
COPY artifacts/client-vnc/rootfs/etc/services.d/onec/run /etc/services.d/onec/run
COPY --from=onescript_base /opt/onescript /opt/onescript
COPY --from=onescript_base /usr/local/bin/oscript /usr/local/bin/oscript
COPY --from=onescript_base /usr/local/bin/opm /usr/local/bin/opm

RUN apt-get update -o APT::Sandbox::User=root \
  && apt-get install --yes --no-install-recommends -o APT::Sandbox::User=root \
    imagemagick \
    iproute2 \
    iputils-ping \
    xdotool \
  && rm -rf /var/lib/apt/lists/*

RUN --mount=type=bind,source=.local/1c/dev-platform,target=/tmp/platform-staging,readonly \
  --mount=type=cache,target=/tmp/platform-unpacked \
  --mount=type=cache,target=/tmp/platform-installer-tmp \
  bash -euxo pipefail <<'EOF'
staging_dir=/tmp/platform-staging
unpack_dir=/tmp/platform-unpacked
tmp_installer_dir=/tmp/platform-installer-tmp

mkdir -p "$unpack_dir" "$tmp_installer_dir"
rm -rf "$unpack_dir"/* "$tmp_installer_dir"/*
export TMPDIR="$tmp_installer_dir"

mapfile -t archives < <(find "$staging_dir" -maxdepth 1 -type f | sort)
if [[ "${#archives[@]}" -eq 0 ]]; then
  echo "No platform archives found in $staging_dir" >&2
  exit 1
fi

installer_path=""

for archive_path in "${archives[@]}"; do
  case "$archive_path" in
    */setup-full-*.run)
      copied_installer_path="$tmp_installer_dir/$(basename "$archive_path")"
      cp "$archive_path" "$copied_installer_path"
      installer_path="$copied_installer_path"
      ;;
    *.run)
      echo "Skipping non-installer run payload: $(basename "$archive_path")"
      ;;
    *.zip)
      archive_name="$(basename "$archive_path" .zip)"
      target_dir="$unpack_dir/$archive_name"
      mkdir -p "$target_dir"
      unzip -q "$archive_path" -d "$target_dir"
      ;;
    *.tar.gz)
      archive_name="$(basename "$archive_path" .tar.gz)"
      target_dir="$unpack_dir/$archive_name"
      mkdir -p "$target_dir"
      tar -xzf "$archive_path" -C "$target_dir"
      ;;
    *)
      echo "Unsupported platform archive: $archive_path" >&2
      exit 1
      ;;
  esac
done

deb_list="$(find "$unpack_dir" -type f \
  \( -name '*-common_*.deb' -o -name '*-common-nls_*.deb' -o -name '*-server_*.deb' -o -name '*-server-nls_*.deb' -o -name '*-client_*.deb' -o -name '*-client-nls_*.deb' \) \
  ! -name '*-thin-client_*.deb' \
  ! -name '*-thin-client-nls_*.deb' \
  ! -name '*-web-client_*.deb' \
  ! -name '*-web-client-nls_*.deb' \
  | sort)"

if [[ -n "$deb_list" ]]; then
  rm -rf /var/lib/apt/lists/*
  apt-get -qq update -o APT::Sandbox::User=root -o Acquire::Retries=5
  apt-get -qq install --yes --no-install-recommends -o APT::Sandbox::User=root bash $deb_list
  rm -rf "$unpack_dir"/* "$tmp_installer_dir"/* /tmp/*.run /tmp/*.tar.gz /tmp/*.zip
  exit 0
fi

if [[ -z "$installer_path" ]]; then
  installer_path="$(find "$unpack_dir" -type f -name "setup-full-${PLATFORM_VERSION}-*.run" | head -n 1)"
fi

if [[ -z "$installer_path" ]]; then
  echo "Could not find 1C installer for version $PLATFORM_VERSION" >&2
  exit 1
fi

installer_name="$(basename "$installer_path")"
enable_components="client_full,server,ws,server_admin,config_storage_server,additional_admin_functions,integrity_monitoring,liberica_jre,ru"

chmod +x "$installer_path"
cd "$tmp_installer_dir"
"./$installer_name" \
  --mode unattended \
  --unattendedmodeui none \
  --enable-components "$enable_components"
find /opt/1cv8 -type d -name distr -prune -exec rm -rf {} +
rm -rf "$unpack_dir"/* "$tmp_installer_dir"/* /tmp/*.run /tmp/*.tar.gz /tmp/*.zip
EOF

# create symlink to current 1c:enterprise directory
COPY artifacts/scripts/createsymlink-current.sh /createsymlink-current.sh
RUN chmod +x /createsymlink-current.sh \
  && /createsymlink-current.sh \
  && rm /createsymlink-current.sh

RUN bash -euxo pipefail <<'EOF'
check_binary() {
  local binary_name="$1"
  local binary_path

  binary_path="$(find /opt/1cv8 -type f -name "$binary_name" | head -n 1)"
  if [[ -z "$binary_path" ]]; then
    echo "Required 1C binary is missing after install: $binary_name" >&2
    exit 1
  fi

  if ldd "$binary_path" | grep -q 'not found'; then
    echo "Installed 1C binary has unresolved shared libraries: $binary_path" >&2
    ldd "$binary_path" >&2
    exit 1
  fi
}

for required_binary in 1cv8 1cv8c ragent rmngr ras; do
  check_binary "$required_binary"
done

uiproxy_path="$(find /opt/1cv8 -type f -name 'uiproxywx.so' | head -n 1)"
if [[ -z "$uiproxy_path" ]]; then
  echo "Required 1C UI runtime library is missing after install: uiproxywx.so" >&2
  exit 1
fi
EOF

RUN (opm install "add@${VANESSA_ADD_VERSION}" || opm install add) \
  && (opm install "vanessa-runner@${VANESSA_RUNNER_VERSION}" || opm install vanessa-runner) \
  && mkdir -p /opt/lib \
  && ln -sfn /opt/onescript/lib/add /opt/lib/add \
  && ln -sf /opt/onescript/bin/vrunner /usr/local/bin/vrunner \
  && ln -sf /opt/onescript/bin/runner /usr/local/bin/runner \
  && ln -sf /opt/onescript/bin/vanessa-runner /usr/local/bin/vanessa-runner \
  && command -v vrunner >/dev/null \
  && vrunner help >/dev/null

RUN chmod +x /etc/services.d/onec/run \
  && if ! getent group grp1cv8 >/dev/null; then \
       groupadd -r grp1cv8; \
     fi \
  && mkdir -p /var/log/1C /var/1C/licenses /home/usr1cv8/.1cv8/1C/1cv8/conf \
  && if getent passwd usr1cv8 >/dev/null; then \
       chown --recursive usr1cv8:grp1cv8 /var/log/1C /home/usr1cv8; \
     fi \
  && chown root:grp1cv8 /var/1C/licenses \
  && chmod 775 /var/1C/licenses \
  && cp /tmp/build-artifacts/config/logcfg.xml /home/usr1cv8/.1cv8/1C/1cv8/conf/logcfg.xml \
  && if [ -f /tmp/build-artifacts/nethasp.ini ]; then \
       cp /tmp/build-artifacts/nethasp.ini /opt/1cv8/conf/nethasp.ini; \
       cp /tmp/build-artifacts/nethasp.ini /home/usr1cv8/.1cv8/1C/1cv8/conf/nethasp.ini; \
     fi \
  && rm -rf /tmp/build-artifacts

EXPOSE 5900 1540-1541 1560-1691 1545

ENTRYPOINT ["/init"]
