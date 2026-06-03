# Codex Report Checklist

Use this checklist to review a Codex execution report before deciding whether
the task is complete or should enter another review stage.

- Did the report list the real repository path?
- Did it list branch, HEAD, and dirty status?
- Did it confirm the dev baseline path / branch / HEAD / status?
- Did it list modified and newly added files?
- Did it state whether business code was changed, or describe the business-code
  scope if it was changed?
- Did it list validation commands and results?
- Did it state that it did not push?
- Did it state whether it committed and include the commit hash when applicable?
- Did it state that the FINAL prompt came from ChatGPT review?
- Did it avoid using the old audit worktree unless explicitly requested?
- Did it avoid treating `/approve` as push, merge, release, or publishing?
- Did it confirm Telegram approval before Codex execution when the task came
  through mobile GUI automation?
- Can OpenClaw summarize the report safely for Telegram?
- Did it stop instead of continuing if GUI automation state was uncertain?
- For long goals, did Codex execute only one stage?
- Did the report state whether next is recommended without executing next?
- Did the report include the current stage scope, forbidden changes, validation
  result, and stop conditions?
- If tests failed, did the report stop and ask for retry, revise, or stop
  instead of widening scope?
- Are there residual untracked files?
- Did any command fail?
- Did the implementation exceed the allowed scope?
- Are there product rules requiring human confirmation?
- Does this need a next stage?
- Does this need ChatGPT secondary review?
