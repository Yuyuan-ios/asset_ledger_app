# Prompt Rules

- Prompts must be complete and directly copyable.
- The default prompt baseline is `/Users/yu/Flutter_Projects/fleet_ledger_app`
  on branch `dev`.
- OpenClaw / MiniMax output is only a DRAFT prompt.
- Only ChatGPT-reviewed output can become the FINAL Codex prompt.
- Codex executes only FINAL prompts.
- Prefer small stages with clear closure.
- Include completion conditions.
- Include Goal, Context, Scope, Constraints, Forbidden changes, Validation, and
  Final report format.
- Include forbidden change areas.
- Include validation commands.
- Require the final report to list changed files, verification results, whether
  business code changed, and whether a commit was created.
- Start complex tasks with a read-only audit.
- High-risk tasks must cite the corresponding docs:
  - Migration: `docs/architecture/database-migration-rules.md`
  - Statistics: `docs/product/statistics.md`
  - External work: `docs/product/external-work.md`
  - Settlement/write-off: `docs/product/settlement-writeoff.md`
  - Project identity: `docs/product/project-identity.md`
- Do not ask Codex to modify code using chat memory alone.
- Do not let OpenClaw / MiniMax call Codex with an unreviewed prompt.
- Do not point to old audit worktrees unless the user explicitly requests them.
- Do not inject branch, commit, merge, or push requirements unless the user task
  explicitly asks for them.
- Mark uncertain product behavior as `待确认`.
