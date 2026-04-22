# 1C Agent Runtime Instructions

You are an IDE-hosted agent working from the user's project repository on the host.

Do not move the repository into the container and do not run yourself inside the container. The host project is bind-mounted into `1c-dev` at:

```text
/workspace/project
```

Edit files in the host repository. Run 1C-dependent commands inside the `1c-dev` container through the host helper targets:

```bash
make -C /path/to/clientserver1c agent-exec CMD="..."
```

Before 1C work:

1. Start or reuse the runtime with `make -C /path/to/clientserver1c agent-up PROJECT_PATH="$PWD"`.
2. Run `make -C /path/to/clientserver1c agent-doctor`.
3. Read the skill registry with `make -C /path/to/clientserver1c agent-skills`.
4. Read only the relevant `SKILL.md` before acting:
   - `context` for ConfigDump, metadata, BSL, platform help, and exact fact lookup.
   - `testing` for Vanessa Automation, xUnitFor1C, UI smoke, and test artifacts.
   - `proof-loop` for non-trivial 1C changes requiring spec, evidence, verification, and fix loops.

Keep task artifacts in the mounted project under `.agent/tasks/<TASK_ID>/` unless the project has stricter local guidance.

Never print ITS credentials, license data, or other secrets.
