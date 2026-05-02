# OACS Repo Workflow

This repository uses OACS directly through `acs` for project memory, context,
and evidence during repository work. Container runtime commands are product
surfaces; they are not required for ordinary repository development of this
infrastructure repo.

## Setup

Use repo-local ignored OACS state:

```bash
export OACS_DB="$PWD/.agent/oacs/oacs.db"
export OACS_PASSPHRASE="<local-passphrase>"

acs init --json
acs key init --passphrase "$OACS_PASSPHRASE" --json
```

Do not commit `.agent/`, `.env`, local volumes, license data, or platform
archives.

## Task Loop

For each non-trivial repository task:

```bash
export OACS_DB="$PWD/.agent/oacs/oacs.db"
export OACS_PASSPHRASE="<local-passphrase>"

acs context build --intent "<task intent>" --scope project --json
```

Run the actual work with normal tools: shell, `git`, `docker`, `make`, and
focused scripts.

Record canonical command output as evidence when it matters for the task:

```bash
acs tool ingest-result \
  --tool-id repo_check \
  --tool-name "Repository check" \
  --tool-type external \
  --scope project \
  --input '{"command":"make doctor"}' \
  --output '{"status":"pass","summary":"make doctor passed"}' \
  --source-uri "repo://checks/make-doctor" \
  --status completed \
  --json
```

Inspect evidence when needed:

```bash
acs evidence list --kind tool_result --json
acs evidence inspect "<ev_...>" --json
```

Promote only durable, verified conclusions to memory:

```bash
candidate="$(acs memory propose \
  --type procedure \
  --depth 2 \
  --scope project \
  --text "<verified reusable conclusion>" \
  --json)"

memory_id="$(printf '%s' "$candidate" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"
acs memory commit "$memory_id" --json
acs memory sharpen "$memory_id" --evidence "<ev_...>" --json
```

## Policy

- Use `acs` for repo memory, context capsules, and evidence references.
- Use shell, Docker, Make, and git for execution.
- Do not route repository development through container runtime commands.
- Do not store local paths, credentials, license data, `nethasp.ini` contents,
  platform archives, or complete platform help content in OACS.
- Keep `.agent/` ignored. OACS state, capsules, and local reports are runtime
  artifacts.
