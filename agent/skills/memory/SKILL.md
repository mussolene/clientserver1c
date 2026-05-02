# 1C Agent Memory Skill

Use this skill when a 1C task benefits from project memory, task context capsules, or historical evidence captured through OACS.

## Model

- `onec-context` remains the canonical retrieval engine for platform help, ITS standards, and project packs.
- OACS stores governed memory, `EvidenceRef` records, audit entries, and `ContextCapsule` metadata.
- Do not copy whole help pages, standards packs, platform archives, ITS credentials, license data, or secrets into memory.
- Treat OACS memory as project-specific guidance. Treat `onec-context` lookup output as canonical evidence.

## Workflow

Before a non-trivial 1C task, build context:

```bash
onec-agent context --task "short_task_intent"
```

Host transport command:

```bash
make -C /path/to/clientserver1c agent-context PROJECT_PATH="$PWD" TASK="short_task_intent"
```

When the task needs a specific 1C help or standards lookup, include a query:

```bash
onec-agent context --task "json_writer_question" --query "ЗаписьJSON" --pack platform --limit 5
```

Host transport command:

```bash
make -C /path/to/clientserver1c agent-context PROJECT_PATH="$PWD" TASK="json_writer_question" QUERY="ЗаписьJSON" PACK=platform LIMIT=5
```

This performs an external `onec-context` lookup, ingests the result as OACS `tool_result` evidence, and builds a context capsule. Promote durable conclusions to memory explicitly with `acs memory`.

For agents that support MCP, register the container MCP server with OACS from inside the container:

```bash
onec-agent context-mcp-config > /tmp/onec-context-mcp.json
acs mcp import /tmp/onec-context-mcp.json
```

The imported MCP tools are governed OACS tools and can be called through `acs tool call --execute-mcp`.

Query project memory:

```bash
acs memory query --query "json writer" --scope project --json
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
