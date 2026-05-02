ARG DESKTOP_BASE_IMAGE=ghcr.io/mussolene/linux-desktop-base:bookworm
ARG ONESCRIPT_BASE_IMAGE=ghcr.io/mussolene/linux-onescript:2.0.0
FROM ${ONESCRIPT_BASE_IMAGE} AS onescript_base
FROM ${DESKTOP_BASE_IMAGE}

ARG TARGETARCH
ARG PLATFORM_VERSION=8.5.1.1302
ARG PLATFORM_DIST_NAME
ARG VANESSA_ADD_VERSION=6.8.0
ARG VANESSA_RUNNER_VERSION=2.6.0
ARG VANESSA_AUTOMATION_VERSION=1.2.043.1
ARG ONEC_VANESSA_SKILL_REF=58b8e8b4831f4f1457707b037c8a050f5cd32e86
ARG ONEC_CONTEXT_TOOLKIT_REF=6a1df34b06a7a71c65876298070cb13525896ee3
ARG BSLLS_VERSION=0.25.0
ARG OACS_VERSION=0.3.1a2

ENV PLATFORM_VERSION=${PLATFORM_VERSION}
ENV PLATFORM_DIST_NAME=${PLATFORM_DIST_NAME}
ENV ONESCRIPT_ROOT=/opt/onescript
ENV PATH=/opt/onec-agent/bin:/opt/onescript:/opt/onescript/bin:${PATH}
ENV OSCRIPT_CONFIG=lib.system=/opt/onescript/lib
ENV OPM_CONFIG=/opt/onescript/opm.cfg
ENV OSCRIPTBIN=/opt/onescript/bin
ENV OACS_VERSION=${OACS_VERSION}
COPY artifacts/ /tmp/build-artifacts/
COPY artifacts/client-vnc/rootfs/etc/services.d/onec/run /etc/services.d/onec/run
COPY --from=onescript_base /opt/onescript /opt/onescript
COPY --from=onescript_base /usr/local/bin/oscript /usr/local/bin/oscript
COPY --from=onescript_base /usr/local/bin/opm /usr/local/bin/opm

RUN apt-get update -o APT::Sandbox::User=root \
  && apt-get install --yes --no-install-recommends -o APT::Sandbox::User=root \
    git \
    imagemagick \
    iproute2 \
    iputils-ping \
    jq \
    openjdk-17-jre-headless \
    python3 \
    python3-pip \
    python3-venv \
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

RUN mkdir -p /opt/bslls \
  && curl -fsSL \
    "https://github.com/1c-syntax/bsl-language-server/releases/download/v${BSLLS_VERSION}/bsl-language-server-${BSLLS_VERSION}-exec.jar" \
    -o /opt/bslls/bsl-language-server.jar \
  && printf '%s\n' \
      '#!/usr/bin/env bash' \
      'set -euo pipefail' \
      'exec java ${BSLLS_JAVA_OPTS:--Xmx2g} -jar /opt/bslls/bsl-language-server.jar "$@"' \
    > /usr/local/bin/bsl-language-server \
  && chmod +x /usr/local/bin/bsl-language-server \
  && bsl-language-server --version >/dev/null

RUN python3 -m venv /opt/oacs \
  && /opt/oacs/bin/pip install --no-cache-dir --pre "oacs==${OACS_VERSION}" \
  && ln -sf /opt/oacs/bin/acs /usr/local/bin/acs \
  && acs --help >/dev/null \
  && command -v acs >/dev/null

COPY agent/ /opt/onec-agent/

RUN --mount=type=secret,id=its_login,required=false \
  --mount=type=secret,id=its_password,required=false \
  bash -euxo pipefail <<'EOF'
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
context_commit="$(clone_skill onec-context-toolkit https://github.com/mussolene/onec-context-toolkit "${ONEC_CONTEXT_TOOLKIT_REF}")"

context_root="$skills_root/onec-context-toolkit"
context_workspace=/opt/onec-agent/context-workspace
context_manifest="$context_workspace/.onec/workspace.manifest.json"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'exec /opt/onec-skills/onec-context-toolkit/bin/onec-context "$@"' \
  > /usr/local/bin/onec-context
chmod +x /usr/local/bin/onec-context "$context_root/bin/onec-context"

onec-context doctor --workspace-init --hbk-base /opt/1cv8
test -x "$context_root/.venv/bin/onec-context-mcp"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'exec /opt/onec-skills/onec-context-toolkit/.venv/bin/onec-context-mcp "$@"' \
  > /usr/local/bin/onec-context-mcp
chmod +x /usr/local/bin/onec-context-mcp
onec-context init \
  --workspace-root "$context_workspace" \
  --source-path "$context_workspace" \
  --profile base \
  --hbk-base /opt/1cv8 \
  --platform "${PLATFORM_VERSION}" \
  --with-standards \
  --fetch-its-standards
context_platform_pack="$(onec-context resolve-packs \
  --workspace-root "$context_workspace" \
  --role platform \
  --path-only)"
context_standards_pack="$(onec-context resolve-packs \
  --workspace-root "$context_workspace" \
  --role standards \
  --path-only)"
context_standards_manifest="$context_workspace/.onec/manifests/standards.its-v8std.kb.manifest.json"
test -f "$context_manifest"
test -f "$context_platform_pack"
test -f "$context_standards_pack"
test -f "$context_standards_manifest"

jq -n \
  --arg vanessa_ref "${ONEC_VANESSA_SKILL_REF}" \
  --arg vanessa_commit "$vanessa_commit" \
  --arg context_ref "${ONEC_CONTEXT_TOOLKIT_REF}" \
  --arg context_commit "$context_commit" \
  --arg bslls_version "${BSLLS_VERSION}" \
  --arg context_workspace "$context_workspace" \
  --arg context_manifest "$context_manifest" \
  --arg context_platform_pack "$context_platform_pack" \
  --arg context_standards_pack "$context_standards_pack" \
  --arg context_standards_manifest "$context_standards_manifest" \
  '{
    skills_root: "/opt/onec-skills",
    project_root: "/workspace/project",
    tools: {
      "bsl-language-server": {
        version: $bslls_version,
        command: "bsl-language-server",
        jar: "/opt/bslls/bsl-language-server.jar"
      },
      "onec-agent": {
        command: "onec-agent",
        description: "Self-contained container-side 1C agent CLI"
      },
      "onec-context": {
        command: "onec-context",
        mcp_command: "onec-agent-context-mcp",
        workspace: $context_workspace,
        manifest: $context_manifest
      },
      "oacs": {
        enabled: true,
        version: env.OACS_VERSION,
        command: "acs",
        wrapper: "/opt/onec-agent/bin/onec-agent-context",
        default_db: "/workspace/project/.agent/oacs/oacs.db"
      }
    },
    packs: {
      platform: $context_platform_pack,
      standards: $context_standards_pack
    },
    manifests: {
      standards: $context_standards_manifest
    },
    skills: {
      "onec-vanessa-skill": {
        source: "https://github.com/mussolene/onec-vanessa-skill",
        ref: $vanessa_ref,
        commit: $vanessa_commit,
        entrypoint: "/opt/onec-skills/onec-vanessa-skill/skill/core/SKILL.md"
      },
      "onec-context-toolkit": {
        source: "https://github.com/mussolene/onec-context-toolkit",
        ref: $context_ref,
        commit: $context_commit,
        entrypoint: "/opt/onec-skills/onec-context-toolkit/skill/SKILL.md"
      },
      "onec-agent-memory": {
        source: "local",
        ref: env.OACS_VERSION,
        commit: env.OACS_VERSION,
        entrypoint: "/opt/onec-agent/skills/memory/SKILL.md"
      }
    }
  }' > /opt/onec-agent/registry.json

chmod +x /opt/onec-agent/bin/*
ln -sf /opt/onec-agent/bin/* /usr/local/bin/
command -v onec-agent-doctor >/dev/null
command -v onec-agent-skill >/dev/null
command -v onec-agent-bslls >/dev/null
command -v onec-agent-bootstrap >/dev/null
command -v onec-agent >/dev/null
command -v onec-context >/dev/null
command -v onec-context-mcp >/dev/null
command -v onec-agent-context-mcp >/dev/null
ONEC_PROJECT_ROOT=/tmp onec-agent-doctor >/dev/null
onec-agent-skill list >/dev/null
onec-agent bootstrap --help >/dev/null
onec-agent --help >/dev/null
onec-context-mcp --help >/dev/null
onec-agent-context-mcp --help >/dev/null
EOF

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

EXPOSE 5900 1540-1541 1560-1691 1545

ENTRYPOINT ["/init"]
