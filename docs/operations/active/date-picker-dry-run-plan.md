# Date Picker Dry Run Plan

## Purpose

This document is a sample long-goal dry run plan for a future "date picker"
task. It does not request code changes and does not authorize implementation.

## Why Date Picker Is A Good Dry Run

- It is a realistic feature-shaped request.
- It can be split into audit, proposal, implementation, tests, and polish.
- It demonstrates that long goals must be planned before implementation.
- It has UI and state risk without requiring DB schema changes by default.

## Why It Should Start With Readonly Audit

The repository may already contain date inputs, date formatting rules, date
state handling, or target-page conventions. The first stage must inspect current
code and docs before suggesting implementation. It must not modify files.

## Example Staged Plan

- Stage 0: readonly audit current date input, date formatting, target pages,
  related state, and existing tests. No code changes.
- Stage 1: proposal for date picker entry point, interaction, scope, forbidden
  changes, and validation. No code changes.
- Stage 2: smallest UI date picker implementation in the approved target
  surface. No business storage or DB schema changes.
- Stage 3: connect approved target page state. No DB schema changes.
- Stage 4: add widget or unit tests for the approved behavior.
- Stage 5: polish, regression validation, and final report.

## What Must Be Confirmed Before Implementation

- Target page or workflow.
- Whether the date picker is for a new record, edit flow, filter, report, or
  another use case.
- Required date format and locale behavior.
- Whether existing product rules constrain selectable dates.
- Whether state changes are UI-only or affect persisted data.
- Validation commands for the selected scope.

## What Should Stop Automation

- The first audit finds conflicting existing date behavior.
- The feature would require DB schema changes.
- The feature affects financial, statistics, external work, settlement, or data
  recovery behavior.
- ChatGPT does not produce a clear `FINAL_STAGE_PLAN` or `FINAL_CODEX_PROMPT`.
- Codex validation fails.
- Scope expands beyond the approved stage.
- The user sends `/stop`.

## Recommended First Telegram Command

/draft 规划“日期选择功能”的多阶段实现。第一阶段必须是只读审计，不改代码；后续每阶段都必须经 Telegram approve，测试通过也不能自动执行下一阶段。

