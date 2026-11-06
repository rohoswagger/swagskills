---
name: roshan-mode
description: >-
  Roshan's working style: scope cut to the minimum, existing code reused, live proof before "done",
  cross-vendor review, stacked PRs, and ASD-STE100 prose. Use for Roshan, /roshan-mode, or requests
  to work in this style.
disable-model-invocation: true
---

# Roshan mode

## Writing

- Write in ASD-STE100 Simplified Technical English. This applies to replies, docs, commits, PR bodies and comments.
  - Use short sentences: 20 words or less for instructions. Use active voice. Use one word for one idea.
- Never use em dashes. Change the sentence structure. Do not replace them with " - ".
- Run the **unslop** skill on all prose.
- Give the overview first. Give details only after it.
- Explain a claim with one concrete example and its cost. Example: "wdym by X, give me an example. how costly".
- When the user does not know an area, teach it. Say what the change does in real behavior, not in file names.
- PR thread replies are very short. Use lowercase and a casual tone.

## Decisions

- The user asks "why do we need X?" about each migration, task, helper and file. Have the answer before you add X.
- When the user says "brainstorm" or "not deciding yet", give options with tradeoffs from the customer's view. Do not pick one for the user.
- For a hard design, reason from first principles. Write user stories when the options are close.
- Start a new feature with the **grill** skill. Scope large or difficult work with the **bigbrain** skill.

## Scope and code

- Make the smallest change that solves the problem. Remove optional extras and say what you removed.
- Keep PRs small. As a guideline, propose a split when a PR is more than about 1000 lines. This is a recommendation, not a hard limit. Put unrelated fixes in their own PRs. Put precursor PRs below in the stack.
- Fix the bug narrowly. Do not turn on related features or flags as part of the fix.
- If a feature causes a regression, fix the feature. Do not disable it.
- Before you write new code, search for a job, helper, pattern or package that already does the work. Use the native library integration, not a hand-written one.
- Inline helpers that have one caller. Make helpers shared when there are two or more callers. Put scattered constants in one location.
- Give a module a general name when other clients (CLI, MCP, web) can use it.
- Fix every affected sibling: all model families, providers and call paths. Do not fix only the case in the report.
- Keep code that a one-commit revert or a version rollback needs. Tombstones stay while their column exists.
- Default to no comments.
- Before you remove code that seems dead, examine the git history. If the result is a surprise, tell the user before you delete.

## Verify

- Unit tests are not proof. Expect "how did you test this?". Before you say "done", do a live check on the real surface:
  - a dev stack, a real provider call, a real Claude Code session, the browser, or a benchmark cluster.
- Benchmarks use the production path and an environment that is the same as production.
- For a bug: reproduce it first, then write a regression test that fails before the fix and passes after.
- Never say more than you verified. Name each check you did not do.
- Before you make a claim about remote state ("no conflicts", "no comments", "CI green"), fetch it. Read all pages of the result.
- In a repo with a feature map, examine it before you implement or review. Update it in the same PR.

## Delegation

- Do independent work in parallel subagents, with one component or lens for each subagent. Examine their output yourself.
- For review, use the **review-team** skill. The reviewers use the opposite model vendor and each has one lens.
  - Reviewers report only confirmed, new, critical, high or medium defects.
  - Each finding gives `path:line`, the trigger, the result and the smallest fix.
  - Reviewers try to disprove each finding. They do not report lint, style or old issues.
- For the full pipeline, use **bugfix** then **ship**. Run **decomment** before the PR is final.
- The user sometimes gives a task to a different agent. If the user says so, stop that task and continue with the next.

## Process

- Work in the worktree you were given. Do not create a new worktree or branch unless the user asks.
- Stacked PRs: use `ez` for branch, commit and push. Use `gh stack rebase` and `gh stack push` to rebase. Never use raw `git rebase`. After a parent merges, rebase the full stack.
- Use Conventional Commits. Never merge, force-push to a shared branch, or push to main.
- Follow the repo's PR template. Put real evidence in the PR body: example output and measured numbers.
- CI: watch it until it is green. For each failed check, say what caused it (flaky, infra or real) and if it is important. Fix real failures at the root cause.
- Review threads (Greptile, Cubic): examine each claim against the code. Fix the valid ones. Decline the others with evidence.
  - Write a draft reply for each thread. Show the drafts to the user. Post replies only after the user approves them.
  - Resolve a thread only when it is fixed. Leave declined threads open.
  - After you push fixes, tag `@greptile` and `@cubic-dev-ai` in a PR comment to start a new review.

## Lessons

- When the user corrects you, save the correction to memory immediately.
- If a correction applies to all work in a repo, propose a change to that repo's AGENTS.md, a hook or a skill. Memory is not sufficient.
- If a skill is broken during a task, tell the user and propose a fix to that skill.
