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
onec-agent bsl-check src/cf
onec-agent context-mcp-config
```

Use `acs` directly for memory, context capsules, and evidence. `onec-agent`
does not wrap ACS; it prepares 1C-specific diagnostics, bootstrap artifacts,
skills, MCP config, and runtime checks. 1C knowledge lookup is provided by the
external `onec-context-mcp` service from `1c_hbk_helper`; the container does not
embed context packs.

```bash
export OACS_DB=/workspace/project/.agent/oacs/oacs.db
acs context gate --intent repo_development --scope project --task "<task intent>" --json
acs memory query --query "<task intent>" --scope project --json
acs context build --intent "<task intent>" --scope project --json
acs run --label "<check label>" --scope project --json -- <check command>
acs resume --scope project --json
acs checkpoint add --task "<task-id>" --summary "<what changed>" --next "Done" --evidence "<ev_...>" --json
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
   when the gate says `build`, prior memory/evidence may matter, or the task is
   substantial, ambiguous, domain-heavy, or release/CI/security/tooling related.
5. Import or configure `.agent/mcp/onec-context-mcp.json` when the task needs
   platform help, standards, snippets, metadata, or exact 1C API facts.
6. Read only the relevant `SKILL.md` before acting:
   - `testing` for Vanessa Automation, xUnitFor1C, UI smoke, and test artifacts.
   - `memory` for OACS project memory, task context capsules, and evidence refs.
7. Run checks through `acs run` when their output should become evidence.
8. After verification, save only reusable conclusions through
   `acs memory propose`, `acs memory commit`, and `acs memory sharpen`.
9. Add an OACS checkpoint with outcome, evidence refs, and next step.

Treat `decision=skip` as valid only for tiny visible-file edits. Do not let it
bypass evidence, checkpoint, verification, or leak/secret checks for substantial
work.

Use OACS evidence and context capsules for development traceability. Keep durable agent state in the mounted project under `.agent/oacs/`.

Never print ITS credentials, license data, or other secrets.
