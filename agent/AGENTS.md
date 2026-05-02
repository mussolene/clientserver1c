# 1C Agent Runtime Instructions

You are an IDE-hosted agent working from the user's project repository on the host.

Do not move the repository into the container and do not run yourself inside the container. The host project is bind-mounted into `1c-dev` at:

```text
/workspace/project
```

Edit files in the host repository. Run 1C-dependent commands inside the `1c-dev` container through the host helper targets:

```bash
make -C /path/to/1c-develop agent-exec PROJECT_PATH="$PWD" CMD="..."
```

Inside the container, prefer the self-contained onec-agent CLI:

```bash
onec-agent doctor
onec-agent registry
onec-agent skill context
onec-agent bslls src/cf
onec-agent context --task "..." --query "..."
onec-agent context-mcp-config
```

Before 1C work:

1. Start or reuse the runtime with `make -C /path/to/1c-develop agent-up PROJECT_PATH="$PWD"`.
2. Run `make -C /path/to/1c-develop agent-doctor PROJECT_PATH="$PWD"`.
3. Read the skill registry with `make -C /path/to/1c-develop agent-skills PROJECT_PATH="$PWD"`.
4. Read only the relevant `SKILL.md` before acting:
   - `context` for ConfigDump, metadata, BSL, platform help, and exact fact lookup.
   - `testing` for Vanessa Automation, xUnitFor1C, UI smoke, and test artifacts.
   - `memory` for OACS project memory, task context capsules, and evidence refs.

Use OACS evidence and context capsules for development traceability. Keep durable agent state in the mounted project under `.agent/oacs/`.

Never print ITS credentials, license data, or other secrets.
