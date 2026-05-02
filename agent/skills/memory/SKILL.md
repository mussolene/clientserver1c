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

Host wrapper equivalent:

```bash
make -C /path/to/clientserver1c agent-context PROJECT_PATH="$PWD" TASK="short_task_intent"
```

When the task needs a specific 1C help or standards lookup, include a query:

```bash
onec-agent context --task "json_writer_question" --query "ЗаписьJSON" --pack platform --limit 5
```

Host wrapper equivalent:

```bash
make -C /path/to/clientserver1c agent-context PROJECT_PATH="$PWD" TASK="json_writer_question" QUERY="ЗаписьJSON" PACK=platform LIMIT=5
```

This performs an external `onec-context` lookup, ingests the result as OACS `tool_result` evidence, links that evidence to a project memory, and builds a context capsule.

For agents that support MCP, register the container MCP server with OACS from inside the container:

```bash
onec-agent context-mcp-config > /tmp/onec-context-mcp.json
acs mcp import /tmp/onec-context-mcp.json
```

The imported MCP tools are governed OACS tools and can be called through `acs tool call --execute-mcp`.

Query project memory:

```bash
onec-agent memory-query --query "json writer"
onec-agent memory-capture --summary "Use file-db runtime before UI smoke in this project."
```

Host wrapper equivalent:

```bash
make -C /path/to/clientserver1c agent-memory-query PROJECT_PATH="$PWD" QUERY="json writer"
make -C /path/to/clientserver1c agent-memory-capture PROJECT_PATH="$PWD" SUMMARY="Use file-db runtime before UI smoke in this project."
```

If you have a specific `ev_...` from a lookup, attach it:

```bash
onec-agent memory-capture --summary "Use ЗаписьJSON for sequential JSON writes." --evidence "ev_..."
```

Host wrapper equivalent:

```bash
make -C /path/to/clientserver1c agent-memory-capture PROJECT_PATH="$PWD" SUMMARY="Use ЗаписьJSON for sequential JSON writes." EVIDENCE="ev_..."
```

## Policy

- Capture only durable project conclusions, decisions, procedures, and caveats.
- Keep OACS state in `.agent/oacs/`.
