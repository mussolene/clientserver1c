## OACS Repo Workflow

For substantial features, refactors, bug fixes, release work, and documentation
changes in this repository, use OACS as the durable project memory, context, and
evidence surface.

Required sequence:

1. State the task scope and explicit acceptance criteria (`AC1`, `AC2`, ...)
   before implementation.
2. Export repo-local ACS state before using ACS:
   `export OACS_DB="$PWD/.agent/oacs/oacs.db" OACS_PASSPHRASE="<local-passphrase>"`.
3. Query durable memory first, then build fresh context:
   `acs memory query --query "<task intent>" --scope project --json` and
   `acs context build --intent "<task intent>" --scope project --json`.
4. Treat command outputs, Docker checks, OACS/MCP results, and runtime checks as
   evidence with `acs tool ingest-result ...`.
5. If evidence should become durable project knowledge, distill it into memory
   with `acs memory propose`, `acs memory commit`, and `acs memory sharpen`.
6. Run a fresh check against the current repository state and rerun
   the relevant checks.
7. Before every commit, check staged changes and unpushed history for
   non-project information and sensitive data: no local host paths, `.env`,
   OACS DB files, `nethasp.ini` contents, credentials, tokens, license data,
   platform archives, local volumes, or unrelated artifacts.
8. If checks do not pass, explain the problem, apply the smallest safe fix, and
   rerun the checks.
9. Close each completed work iteration with a focused commit after checks pass.

Hard rules:

- Do not claim completion unless every acceptance criterion is `PASS`.
- Current code and current command results are the source of truth, not prior
  chat claims.
- Fixes should be the smallest defensible diff.
- OACS is not the runtime orchestrator. It records memory, context, and evidence
  around commands executed by the agent through normal shell/Docker/git tools.
- In this repository, use `acs` directly for repo work. Use `onec-agent` only
  for container/product behavior that needs the built image or 1C runtime.
- Keep secrets out of OACS: no ITS credentials, license data, `nethasp.ini`
  contents, platform archives, full help dumps, or local host paths.
- Do not leave a completed iteration as uncommitted work. Commit after the
  verification and leak checks for that iteration pass.
- Keep this root `AGENTS.md` lean. Put expanded guidance in docs instead of
  adding parallel workflow files.

See `docs/oacs-development.md` for the repository-specific command loop.
