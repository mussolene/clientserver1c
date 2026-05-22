# 1C Agent Memory Skill

Use this skill when a 1C task benefits from project memory, task context capsules, or historical evidence captured through OACS.

## Model

- External `onec-context-mcp` remains the canonical retrieval surface for platform help, standards, snippets, and project metadata.
- OACS stores governed memory, `EvidenceRef` records, audit entries, and `ContextCapsule` metadata.
- Do not copy whole help pages, standards dumps, platform archives, ITS credentials, license data, or secrets into memory.
- Treat OACS memory as project-specific guidance. Treat external MCP lookup output as retrieval evidence only after it is captured through `acs run` or `acs tool ingest-result`.

## Workflow

Before a non-trivial project task, build OACS context directly:

```bash
acs memory query --query "short_task_intent" --scope project --json
acs context build --intent "short_task_intent" --scope project --json
```

Host transport command:

```bash
make -C /path/to/1c-develop agent-context PROJECT_PATH="$PWD" TASK="short_task_intent"
```

When the task needs a specific 1C help, standards, snippets, or metadata lookup,
use the external MCP config produced by bootstrap:

```bash
onec-agent context-mcp-config > /tmp/onec-context-mcp.json
acs mcp import /tmp/onec-context-mcp.json
```

The image does not embed local context packs. Start `1c_hbk_helper` /
`onec-context-mcp` outside this image and connect the MCP client to the URL in
the config, default `http://localhost:8050/mcp`.

Use `acs run` or `acs tool ingest-result` when an MCP result should become OACS
evidence, then promote durable conclusions explicitly with `acs memory`.

For agents that support MCP, register the external MCP endpoint with OACS:

```bash
onec-agent context-mcp-config > /tmp/onec-context-mcp.json
acs mcp import /tmp/onec-context-mcp.json
```

The imported MCP tools are governed OACS tools and can be called through `acs tool call --execute-mcp`.

Query project memory:

```bash
acs memory query --query "json writer" --scope project --json
acs context build --intent "json writer" --scope project --json
```

Run checks through ACS when their command output should be evidence:

```bash
acs run --label "bsl_check_json_writer" --scope project --json -- onec-agent bsl-check src/cf
acs resume --scope project --json
```

If you have a specific `ev_...` from a lookup, attach it:

```bash
candidate="$(acs memory propose --type procedure --depth 2 --scope project --text "Use ЗаписьJSON for sequential JSON writes." --json)"
memory_id="$(printf '%s' "$candidate" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"
acs memory commit "$memory_id" --json
acs memory sharpen "$memory_id" --evidence "ev_..." --json
```

## Policy

- Capture only durable project conclusions, decisions, procedures, and caveats.
- Keep OACS state in `.agent/oacs/`.
