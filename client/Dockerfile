ARG DESKTOP_BASE_IMAGE=ghcr.io/mussolene/linux-desktop-base:bookworm
ARG ONESCRIPT_VERSION=2.0.1
ARG ONESCRIPT_DOWNLOAD_URL

FROM ${DESKTOP_BASE_IMAGE}

ARG TARGETARCH
ARG ONESCRIPT_VERSION
ARG ONESCRIPT_DOWNLOAD_URL
ARG PLATFORM_VERSION=8.5.1.1343
ARG PLATFORM_DIST_NAME
ARG VANESSA_ADD_VERSION=6.8.0
ARG VANESSA_RUNNER_VERSION=2.6.0
ARG VANESSA_AUTOMATION_VERSION=1.2.043.1
ARG ONEC_VANESSA_SKILL_REF=58b8e8b4831f4f1457707b037c8a050f5cd32e86
ARG ONEC_HBK_BSL_VERSION=0.7.41
ARG OACS_VERSION=1.0.14

ENV PLATFORM_VERSION=${PLATFORM_VERSION}
ENV PLATFORM_DIST_NAME=${PLATFORM_DIST_NAME}
ENV ONESCRIPT_ROOT=/opt/onescript
ENV PATH=/opt/onec-agent/bin:/opt/onescript:/opt/onescript/bin:${PATH}
ENV OSCRIPT_CONFIG=lib.system=/opt/onescript/lib
ENV OPM_CONFIG=/opt/onescript/opm.cfg
ENV OSCRIPTBIN=/opt/onescript/bin
ENV OACS_DB=/workspace/project/.agent/oacs/oacs.db

RUN apt-get update -o APT::Sandbox::User=root \
  && apt-get install --yes --no-install-recommends -o APT::Sandbox::User=root \
    ca-certificates \
    curl \
    libarchive-tools \
    libicu72 \
  && rm -rf /var/lib/apt/lists/* \
  && onescript_url="${ONESCRIPT_DOWNLOAD_URL:-https://github.com/EvilBeaver/OneScript/releases/download/v${ONESCRIPT_VERSION}/OneScript-${ONESCRIPT_VERSION}-linux-x64.zip}" \
  && mkdir -p /opt/onescript /tmp/onescript \
  && curl -fsSL --retry 3 --show-error "$onescript_url" -o /tmp/onescript/onescript.zip \
  && LANG=C.UTF-8 LC_ALL=C.UTF-8 bsdtar -xf /tmp/onescript/onescript.zip -C /opt/onescript \
  && chmod +x /opt/onescript/bin/oscript /opt/onescript/bin/opm \
  && ln -sf /opt/onescript/bin/oscript /opt/onescript/oscript \
  && printf '%s\n' \
       '[default]' \
       'СервераПакетов = ОсновнойСерверПакетов, ЗапаснойСерверПакетов' \
       '' \
       '[ОсновнойСерверПакетов]' \
       'URL = https://hub.oscript.io' \
       '' \
       '[ЗапаснойСерверПакетов]' \
       'URL = https://hub.oscript.ru' \
     > /opt/onescript/opm.cfg \
  && printf '%s\n' \
       '#!/bin/sh' \
       'if [ -x /opt/onescript/bin/oscript ]; then exec /opt/onescript/bin/oscript "$@"; fi' \
       'echo "OneScript runtime files are missing in this image." >&2' \
       'exit 1' \
     > /usr/local/bin/oscript \
  && printf '%s\n' \
       '#!/bin/sh' \
       'if [ -x /opt/onescript/bin/opm ]; then exec /opt/onescript/bin/opm "$@"; fi' \
       'echo "OPM files are missing in this image." >&2' \
       'exit 1' \
     > /usr/local/bin/opm \
  && chmod +x /usr/local/bin/oscript /usr/local/bin/opm \
  && oscript -version >/dev/null \
  && opm version >/dev/null \
  && rm -rf /tmp/onescript

RUN apt-get update -o APT::Sandbox::User=root \
  && apt-get install --yes --no-install-recommends -o APT::Sandbox::User=root \
    git \
    imagemagick \
    iproute2 \
    iputils-ping \
    jq \
    ripgrep \
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
enable_components="client_full,desktop_icons,server,ws,server_admin,additional_admin_functions,ru"

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

RUN opm install "add@${VANESSA_ADD_VERSION}" \
  && opm install "vanessa-runner@${VANESSA_RUNNER_VERSION}" \
  && opm install "vanessa-automation@${VANESSA_AUTOMATION_VERSION}" \
  && opm install "vanessa-automation-single@${VANESSA_AUTOMATION_VERSION}" \
  && mkdir -p /opt/lib \
  && ln -sfn /opt/onescript/lib/add /opt/lib/add \
  && ln -sf /opt/onescript/bin/vrunner /usr/local/bin/vrunner \
  && ln -sf /opt/onescript/bin/runner /usr/local/bin/runner \
  && ln -sf /opt/onescript/bin/vanessa-runner /usr/local/bin/vanessa-runner \
  && command -v vrunner >/dev/null \
  && vrunner help >/dev/null

ENV ONEC_HBK_BSL_VERSION=${ONEC_HBK_BSL_VERSION}
RUN python3 -m venv /opt/onec-hbk-bsl \
  && /opt/onec-hbk-bsl/bin/pip install --no-cache-dir "onec-hbk-bsl==${ONEC_HBK_BSL_VERSION}" \
  && ln -sf /opt/onec-hbk-bsl/bin/onec-hbk-bsl /usr/local/bin/onec-hbk-bsl \
  && onec-hbk-bsl --version >/dev/null \
  && onec-hbk-bsl --list-rules >/dev/null

ENV OACS_VERSION=${OACS_VERSION}
RUN python3 -m venv /opt/oacs \
  && /opt/oacs/bin/pip install --no-cache-dir "oacs==${OACS_VERSION}" \
  && ln -sf /opt/oacs/bin/acs /usr/local/bin/acs \
  && test "$(acs --version)" = "acs ${OACS_VERSION}" \
  && acs --help >/dev/null \
  && command -v acs >/dev/null

COPY agent/ /opt/onec-agent/

RUN bash -euxo pipefail <<'EOF'
skills_root=/opt/onec-skills
mkdir -p "$skills_root"

clone_skill() {
  local name="$1"
  local url="$2"
  local ref="$3"
  local target="$skills_root/$name"

  rm -rf "$target"
  git init -q "$target"
  git -C "$target" remote add origin "$url"
  git -C "$target" fetch --depth 1 origin "$ref" || git -C "$target" fetch origin "$ref"
  git -C "$target" checkout --quiet --detach FETCH_HEAD
  git -C "$target" rev-parse HEAD
}

vanessa_commit="$(clone_skill onec-vanessa-skill https://github.com/mussolene/onec-vanessa-skill "${ONEC_VANESSA_SKILL_REF}")"

jq -n \
  --arg vanessa_ref "${ONEC_VANESSA_SKILL_REF}" \
  --arg vanessa_commit "$vanessa_commit" \
  --arg hbk_bsl_version "${ONEC_HBK_BSL_VERSION}" \
  --arg context_mcp_url "http://localhost:8050/mcp" \
  '{
    skills_root: "/opt/onec-skills",
    project_root: "/workspace/project",
    tools: {
      "onec-hbk-bsl": {
        version: $hbk_bsl_version,
        command: "onec-hbk-bsl",
        description: "Python BSL diagnostics, formatter, LSP and MCP server"
      },
      "onec-agent": {
        command: "onec-agent",
        description: "Self-contained container-side 1C agent CLI"
      },
      "onec-context-mcp": {
        mode: "external",
        url: $context_mcp_url,
        config_command: "onec-agent context-mcp-config",
        description: "External 1C Context MCP service, typically provided by 1c_hbk_helper"
      },
      "oacs": {
        enabled: true,
        version: env.OACS_VERSION,
        source: "https://github.com/mussolene/open-agent-context",
        ref: env.OACS_VERSION,
        command: "acs",
        context_adapter: "/opt/onec-agent/bin/onec-agent-context",
        default_db: "/workspace/project/.agent/oacs/oacs.db"
      }
    },
    packs: {},
    manifests: {},
    skills: {
      "onec-vanessa-skill": {
        source: "https://github.com/mussolene/onec-vanessa-skill",
        ref: $vanessa_ref,
        commit: $vanessa_commit,
        entrypoint: "/opt/onec-skills/onec-vanessa-skill/skill/core/SKILL.md"
      },
      "oacs-memory": {
        source: "local",
        ref: env.OACS_VERSION,
        commit: env.OACS_VERSION,
        entrypoint: "/opt/onec-agent/skills/memory/SKILL.md"
      },
      "codex-oacs-runtime": {
        source: "local",
        ref: env.OACS_VERSION,
        commit: env.OACS_VERSION,
        entrypoint: "/opt/onec-agent/skills/codex_oacs_runtime/SKILL.md",
        descriptor: "/opt/onec-agent/skills/codex_oacs_runtime/skill.json",
        action_command: "/opt/onec-agent/bin/onec-agent-oacs-runtime"
      }
    }
  }' > /opt/onec-agent/registry.json

find /opt/onec-agent/bin -maxdepth 1 -type f -exec chmod +x {} +
find /opt/onec-agent/bin -maxdepth 1 -type f -exec ln -sf {} /usr/local/bin/ \;
command -v onec-agent-doctor >/dev/null
command -v onec-agent-quickstart >/dev/null
command -v onec-agent-skill >/dev/null
command -v onec-agent-bsl >/dev/null
command -v onec-agent-bootstrap >/dev/null
command -v onec-agent-ibase >/dev/null
command -v onec-agent >/dev/null
command -v onec-agent-context-mcp >/dev/null
command -v onec-agent-oacs-runtime >/dev/null
test -f /opt/onec-agent/skills/codex_oacs_runtime/SKILL.md
test -f /opt/onec-agent/skills/codex_oacs_runtime/skill.json
test -f /opt/onec-agent/skills/codex_oacs_runtime/scripts/repo_memory.py
ONEC_PROJECT_ROOT=/tmp onec-agent-doctor >/dev/null
ONEC_QUICKSTART_CREATE_DB=0 ONEC_QUICKSTART_LAUNCH_GUI=0 onec-agent-quickstart >/dev/null
onec-agent-skill list >/dev/null
onec-agent-skill runtime >/dev/null
onec-agent bootstrap --help >/dev/null
onec-agent ibase --help >/dev/null
onec-agent --help >/dev/null
onec-agent context-mcp-config >/dev/null
rm -rf \
  "$skills_root/onec-vanessa-skill/.git" \
  /root/.cache/pip
EOF

COPY artifacts/client-vnc/rootfs/etc/services.d/onec/run /etc/services.d/onec/run
COPY artifacts/config/logcfg.xml /tmp/build-artifacts/config/logcfg.xml

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
  && rm -rf /tmp/build-artifacts

EXPOSE 5900 3389 1540-1541 1560-1691 1545

ENTRYPOINT ["/init"]
