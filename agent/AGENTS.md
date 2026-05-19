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
onec-agent context --query "ЗаписьJSON" --pack platform --limit 5
onec-agent context --query "Заявки" --pack metadata --limit 5
onec-agent context-mcp-config
```

Use `acs` directly for memory, context capsules, and evidence. `onec-agent`
does not wrap ACS; it only prepares 1C-specific context and runtime checks.

```bash
export OACS_DB=/workspace/project/.agent/oacs/oacs.db
acs context gate --intent repo_development --scope project --task "<task intent>" --json
acs memory query --query "<task intent>" --scope project --json
acs context build --intent "<task intent>" --scope project --json
acs run --label "<check label>" --scope project --json -- <check command>
acs resume --scope project --json
```

`OACS_PASSPHRASE` is optional and only needed for existing passphrase-wrapped
stores. New local development stores may use OACS `local_unlocked` key
material. Do not read, print, or commit `.agent/oacs/key.json`,
`.agent/oacs/unlocked.key`, databases, passphrases, or private agent state.

Before 1C work:

1. Start or reuse the runtime with `make -C /path/to/1c-develop agent-up PROJECT_PATH="$PWD"`.
2. Run `make -C /path/to/1c-develop agent-doctor PROJECT_PATH="$PWD"`.
3. Read the skill registry with `make -C /path/to/1c-develop agent-skills PROJECT_PATH="$PWD"`.
4. Ask `acs context gate`, query ACS memory, and build a fresh context capsule
   only when the gate or prior memory/evidence says context matters.
5. Read only the relevant `SKILL.md` before acting:
   - `context` for ConfigDump, metadata, BSL, platform help, and exact fact lookup.
   - `testing` for Vanessa Automation, xUnitFor1C, UI smoke, and test artifacts.
   - `memory` for OACS project memory, task context capsules, and evidence refs.
6. Run checks through `acs run` when their output should become evidence.
7. After verification, save only reusable conclusions through
   `acs memory propose`, `acs memory commit`, and `acs memory sharpen`.

Use OACS evidence and context capsules for development traceability. Keep durable agent state in the mounted project under `.agent/oacs/`.

Never print ITS credentials, license data, or other secrets.
