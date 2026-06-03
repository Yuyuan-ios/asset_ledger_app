# ChatGPT Prompt Review Gateway

## Definition

Prompt Review Gateway is the safety boundary between task orchestration and
execution. OpenClaw / MiniMax prepares a draft package, ChatGPT reviews and
repairs that draft, and Codex executes only the final reviewed prompt.

## Why Draft Only

The user's OpenClaw backend brain is MiniMax. In this workflow, OpenClaw /
MiniMax is responsible for reading context, coordinating work, drafting prompts,
summarizing reports, and suggesting next stages. It is not the final prompt
reviewer and must not directly hand an unreviewed prompt to Codex.

ChatGPT is the final prompt reviewer because it must check missing context,
oversized scope, insufficient validation, unauthorized changes, and product-rule
misreadings before Codex modifies the repository.

## ChatGPT Review Checklist

1. Is the task goal clear?
2. Did the draft read the correct docs?
3. Are key product rules missing?
4. Is the task scope too large?
5. Are forbidden change areas explicit?
6. Are validation commands included?
7. Is the final report format specified?
8. Could the prompt accidentally modify business code?
9. Could the prompt accidentally modify DB schema or migrations?
10. Could it touch high-risk UI, copywriting, statistics, external work,
    settlement, write-off, or project identity behavior?
11. Does the prompt clearly say whether commit is allowed?
12. Is OpenClaw / MiniMax making too many implementation decisions by itself?
13. Is OpenClaw / MiniMax incorrectly treating DRAFT as FINAL?
14. Does the prompt incorrectly point to the old audit worktree?
15. Does the prompt misuse `/approve` as push, merge, release, or publish?
16. Does the FINAL prompt include Goal, Context, Scope, Constraints, Forbidden
    changes, Validation, and Final report format?

## Must Reject And Rewrite

Reject the draft when any of these are true:

- The goal is ambiguous.
- Required docs are missing or wrong.
- The scope combines unrelated stages.
- Forbidden changes are missing.
- Validation is absent or too weak for the risk.
- The draft asks Codex to rely on memory instead of repository docs.
- The draft allows business, UI, DB, migration, product-rule, or test changes
  that were not requested.
- OpenClaw / MiniMax is trying to approve, execute, push, merge, or bypass
  ChatGPT review.
- The prompt points to `/Users/yu/Flutter_Projects/worktrees/fleet_ledger_audit`
  without explicit user instruction.
- The prompt treats Telegram `/approve` as push, merge, release, or publishing.

## May Output Final Prompt

ChatGPT may output a `FINAL_CODEX_PROMPT` when:

- The goal and scope are clear.
- Relevant docs are named.
- Forbidden changes are explicit.
- Validation commands match the task risk.
- The report format is complete.
- Commit, push, merge, and branch behavior are unambiguous.
- Any uncertain product detail is marked `待确认`.
- Default baseline is `/Users/yu/Flutter_Projects/fleet_ledger_app` on `dev`
  unless the user explicitly requests another path.

## DRAFT_PROMPT_PACKAGE Format

```text
DRAFT_PROMPT_PACKAGE

Task:
<任务名>

Task type:
<readonly-audit | implementation | ui-polish | migration-change | merge-review | report-review | next-stage-planning>

Source request:
<用户原始请求>

Relevant docs read:
- <doc path>
- <doc path>

Assumptions:
- <假设 1>
- <假设 2>

Risks:
- <风险 1>
- <风险 2>

Draft Codex prompt:
<OpenClaw / MiniMax 生成的 Codex prompt 草稿>

Questions for ChatGPT reviewer:
- <需要 ChatGPT 判断的问题>
```

## FINAL_CODEX_PROMPT Format

```text
FINAL_CODEX_PROMPT

Reviewer verdict:
<approved_after_revision | rejected_needs_rewrite>

Changes made by ChatGPT:
- <修改点 1>
- <修改点 2>

Final Codex prompt:
<最终可交给 Codex 的完整 prompt>
```

The final Codex prompt must include Goal, Context, Scope, Constraints,
Forbidden changes, Validation, and Final report format.
