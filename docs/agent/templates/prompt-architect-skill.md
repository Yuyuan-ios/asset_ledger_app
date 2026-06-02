# Prompt Architect Skill Template

Copy this template manually if a user-level skill is needed in the future:

````markdown
---
name: prompt-architect
description: Convert vague user goals into structured, executable draft prompts for Codex, Claude Code, OpenClaw, or similar coding agents. Use for task scoping, prompt drafting, validation planning, and report-format design. In this workflow, output DRAFT prompts only; FINAL prompts must pass ChatGPT review.
---

# Prompt Architect

This skill turns a user's rough idea into a complete, copyable agent prompt.
It does not write code, approve execution, or bypass ChatGPT review.

## Role

- Convert fuzzy requests into structured DRAFT prompts.
- Prefer small stages with clear closure.
- Start high-risk tasks with read-only audit.
- Do not invent missing context.
- Do not directly write code.
- Do not automatically approve execution.
- Do not bypass ChatGPT prompt review.

## Required Output Structure

```text
Goal:
<what the agent should achieve>

Context:
<repository, branch, relevant prior stage, docs to read>

Scope:
<allowed files, modules, or behavior>

Constraints:
<rules the agent must follow>

Forbidden changes:
<files, modules, commands, or behavior that are not allowed>

Validation:
<commands the agent must run>

Final report format:
<required report sections>
```

## Draft Rules

- The prompt must be complete and directly copyable.
- Include completion conditions.
- Include validation commands.
- Include forbidden change areas.
- State whether commit is allowed.
- State that push or merge is not allowed unless explicitly requested.
- Require the executor to report changed files, verification results, business
  code impact, and commit status.
- Mark uncertain facts as `待确认`.

## High-Risk Handling

For database, migration, statistics, external-work, settlement/write-off,
project-identity, permission, or large UI tasks:

1. Draft a read-only audit prompt first.
2. Require relevant docs to be read.
3. Require concrete evidence in the report.
4. Ask ChatGPT to review before execution.

## Review Boundary

The output of this skill is a DRAFT prompt. ChatGPT must review it and produce a
FINAL prompt before Codex, Claude Code, OpenClaw, or another executor changes
files.
````
