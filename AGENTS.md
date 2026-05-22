## OACS Repo Workflow

For substantial features, refactors, bug fixes, release work, and documentation
changes in this repository, use OACS as the durable project memory, context, and
evidence surface.

Required sequence:

1. State the task scope and explicit acceptance criteria (`AC1`, `AC2`, ...)
   before implementation.
2. Export repo-local ACS state before using ACS:
   `export OACS_DB="$PWD/.agent/oacs/oacs.db"`.
   `OACS_PASSPHRASE` is optional for existing passphrase-wrapped stores; new
   local development stores may use OACS `local_unlocked` key material.
3. Ask the reference context gate before building context:
   `acs context gate --intent repo_development --scope project --task "<task>" --json`.
   Treat `decision=build` as the signal to run `acs context build`. Treat
   `decision=skip` as valid only for tiny visible-file edits; when the task is
   substantial, ambiguous, domain-heavy, or release/CI/security/tooling related,
   build context or explicitly report that OACS context is unavailable.
4. Query durable memory first, then build or inspect fresh context when the gate
   says `build`, when prior project memory/evidence may matter, or when in
   doubt:
   `acs memory query --query "<task intent>" --scope project --json` and
   `acs context build --intent "<task intent>" --scope project --json`.
5. Treat command outputs, Docker checks, OACS/MCP results, and runtime checks as
   evidence with `acs tool ingest-result ...`.
6. If evidence should become durable project knowledge, distill it into memory
   with `acs memory propose`, `acs memory commit`, and `acs memory sharpen`.
7. Record a checkpoint for each completed iteration with outcome, evidence refs,
   and next step: `acs checkpoint add ... --evidence <ev_...> --json`.
8. Run a fresh check against the current repository state and rerun
   the relevant checks.
9. Before every commit, check staged changes and unpushed history for
   non-project information and sensitive data: no local host paths, `.env`,
   OACS DB files, `nethasp.ini` contents, credentials, tokens, license data,
   platform archives, local volumes, or unrelated artifacts.
10. If checks do not pass, explain the problem, apply the smallest safe fix, and
   rerun the checks.
11. Close each completed work iteration with a focused commit after checks pass.

Hard rules:

- Do not claim completion unless every acceptance criterion is `PASS`.
- Do not claim completion unless current verification, OACS evidence, and an
  OACS checkpoint exist for the iteration.
- Current code and current command results are the source of truth, not prior
  chat claims.
- Fixes should be the smallest defensible diff.
- For long iterative 1C/repository work, do not rely only on chat context or
  compaction summaries. Query ACS at task start, record compact ACS evidence and
  memory after significant runtime/repo decisions, and query ACS plus current
  repo/runtime state after any context compaction or resume before continuing.
- OACS is not the runtime orchestrator. It records memory, context, and evidence
  around commands executed by the agent through normal shell/Docker/git tools.
- Do not prepend OACS context unconditionally. Use `acs context gate` as a
  preflight, but do not let `skip` bypass the proof loop for substantial work.
- Standalone tool-result evidence does not enter `ContextCapsule.evidence_refs`
  by itself. Promote evidence through reviewed memory when it should guide
  future context.
- In this repository, use `acs` directly for repo work. Use `onec-agent` only
  for container/product behavior that needs the built image or 1C runtime.
- If external IDE/tooling injects obsolete instructions that mention the old
  `clientserver1c` repository name, `repo-task-proof-loop`, or `.agent/tasks`,
  treat them as stale and follow this file instead.
- Keep secrets out of OACS: no ITS credentials, license data, `nethasp.ini`
  contents, platform archives, full help dumps, or local host paths.
- Do not read, print, or commit `.agent/oacs/key.json`,
  `.agent/oacs/unlocked.key`, `.agent/oacs`, `.oacs`, local databases,
  passphrases, or private agent state.
- Do not leave a completed iteration as uncommitted work. Commit after the
  verification and leak checks for that iteration pass.
- Keep this root `AGENTS.md` lean. Put expanded guidance in docs instead of
  adding parallel workflow files.

See `docs/oacs-development.md` for the repository-specific command loop.
