---
name: review-team
description: Review a PR or diff with a team of specialist subagents, each owning one aspect (correctness, security, tests, performance, API/contract, readability), run in parallel and synthesized into one deduped, severity-ranked report with verified findings. Use when asked to "review this PR with a team", "do a thorough/multi-angle review", "get a bunch of agents to review", "deep review before I merge", or any review where breadth and parallel specialist coverage matter more than a single quick pass. Review-only — it reports findings, it does not fix them or open PRs (use /ship for the full pipeline).
---

# review-team — parallel specialist review, one synthesized report

A single reviewer reading a diff top-to-bottom finds the obvious things and
misses the ones that need a specific lens. A security mindset and a
test-coverage mindset notice different problems on the same line. This skill
runs several specialists in parallel — each looking at the *whole* diff through
*one* lens — then synthesizes, dedupes, and verifies their findings into a
report a human can act on.

The output is a review, not a changeset. It does not edit code or open PRs —
that keeps it safe to run on anything and fast to read. For the full
review→fix→PR→CI pipeline, that's `/ship`.

## What this is for vs. the alternatives

- **`/code-review`** — one fast pass over the diff, optionally fixes/comments.
  Reach for it on small or routine changes.
- **review-team (this)** — many specialists in parallel for breadth on a
  larger or higher-stakes change. Report only.
- **`/ship`** — uses a review like this as one phase, then fixes and ships.

If the diff is tiny, don't convene a team — a single pass is faster and the
overhead isn't worth it. Say so and fall back to `/code-review`.

## Step 1 — Establish the diff

Figure out exactly what's under review before spawning anyone; reviewers with
the wrong scope waste the whole run.

- A PR number/URL → `gh pr diff <n>`, and `gh pr view <n>` for title/intent.
- The current branch → diff against its base. In an ez-stack repo
  (`.git/ez/stack.json` exists) the base is the branch's parent, not the trunk —
  `ez log --json` / `ez status --json` gives the parent so you review only this
  branch's slice of the stack, not the whole stack. Otherwise use
  `git merge-base` with the default branch (never a blind `HEAD~1`).
- Uncommitted work → `git diff` (and `--staged`).

Capture: the full diff, the list of changed files, and the stated intent of the
change. Skim it yourself first so you can write good reviewer prompts and
recognize nonsense findings later.

This complements Greptile and Cubic (the AI bots already on the PR) rather than
repeating them — the team goes deeper and synthesizes, where the bots fire
line-level comments. Don't burn a lens re-deriving something a bot already
posted; check the existing PR comments first if reviewing an open PR.

## Step 2 — Pick the lenses

Default team (spawn the ones that apply to this diff — don't run a security
specialist on a docs-only change):

- **correctness** — logic errors, edge cases, off-by-one, null/none handling,
  error paths, concurrency/races, incorrect assumptions about inputs.
- **security** — injection, authz/authn gaps, secrets in code, unsafe
  deserialization, SSRF, path traversal, missing validation on trust
  boundaries.
- **tests** — new behavior with no test, tests that assert the wrong thing or
  can't fail, missing edge/regression coverage, flaky patterns.
- **regressions & contracts** — does the diff break existing callers, public
  APIs, serialized formats, DB schemas, or documented behavior?
- **performance** — N+1 queries, accidental quadratic loops, unbounded memory,
  blocking I/O on hot paths, missing pagination/indexes.
- **readability & maintainability** — naming, dead code, duplicated logic,
  comments that lie, structure that will be hard to change.

Add domain lenses when the diff calls for them (migrations, accessibility,
i18n, concurrency, infra/IaC). Match the team to the change — more lenses isn't
better if half of them have nothing to look at.

**Onyx-specific lenses.** This is an Onyx codebase (Python + Celery + DB,
TypeScript/React frontend). When the diff touches these areas, spawn a lens and
point it at the matching project skill so it reviews against the house rules,
not generic best practice:

- Celery tasks changed → a **task-correctness** lens guided by the
  `celery-tasks` skill (idempotency, retries, serialization, queue routing).
- DB reads/writes changed → a **data-access** lens guided by the
  `interacting-with-db` skill (session handling, transactions, N+1).
- Concurrent/parallel code → a **concurrency** lens guided by the
  `using-concurrency` skill.
- Frontend changed → a **frontend-style** lens guided by the
  `writing-frontend-style` skill (in addition to correctness/a11y).

Tell those subagents to read the named skill first; that's where the
project-specific failure modes live.

## Step 3 — Dispatch the team (parallel)

Spawn all chosen lenses in a single message so they run concurrently. Each
subagent has no conversation context, so each prompt is self-contained:

```
You are reviewing a PR through the <LENS> lens only. Ignore issues outside
your lens — other reviewers cover those.

## The change
Intent: <one-line PR intent>
Changed files: <list>
Diff:
<full diff, or the slice relevant to this lens for very large diffs>

## Your job
Find <LENS>-specific problems *in the code this diff introduces or changes*.
For each, report:
- file:line
- severity: critical | high | medium | low
- what's wrong (concrete, not "consider reviewing X")
- why it matters (the actual consequence)
- suggested fix (one line)

## Do NOT flag
- pre-existing issues the diff didn't introduce (review the change, not the repo)
- things that look like bugs but are actually correct on a closer read
- pedantic nits a senior engineer wouldn't raise in review
- anything a linter/formatter/type-checker already catches
- issues deliberately silenced in-code (lint-ignore, type-ignore with a reason)

Only report real issues you can point to in the diff. If the change is clean
through your lens, say so and report nothing. Do not invent findings to look
thorough — a false positive costs more than a miss here.
```

Use a structured-output schema if the harness supports it, so synthesis doesn't
hinge on parsing prose. For very large diffs, give each specialist only the
files relevant to its lens rather than the whole thing — dumping unrelated
context in raises false positives rather than lowering them.

## Step 4 — Dedupe, then validate by disproving (this is the real work)

The team's raw output is noisy: duplicates across lenses, disagreements, and
plausible-but-wrong findings. Turning it into something trustworthy is where
the quality comes from — a report full of false positives trains the reader to
ignore the whole thing, which is worse than no review.

1. **Dedupe first** — collapse the same issue reported by multiple lenses into
   one entry, keeping the clearest explanation and noting it was
   multiply-flagged (that's a strong signal it's real). Resolve contradictions:
   if two lenses disagree, you'll let the validation round settle it.

2. **Validate by disproving (a second fan-out).** This is the single
   highest-value step. For each surviving critical/high candidate, spawn a
   *validator* subagent whose job is to **refute** the finding, not confirm it:

   ```
   A reviewer claims this is a <severity> issue:
   <finding: file:line, claim, why-it-matters>

   Here is the actual code and its surrounding context: <code>

   Try to DISPROVE this. Is it actually a bug, or is the code correct on a
   closer read (handled elsewhere, guarded upstream, can't occur given the
   types/callers)? Default to "not a real issue" unless you can show concretely
   that it triggers. Return: verdict (confirmed | refuted | needs-author-call),
   the evidence, and a corrected severity if the reviewer over/under-rated it.
   ```

   Asking agents to disprove rather than "double-check" is what kills confident
   hallucinations — a confirm-prompt rubber-stamps, a refute-prompt actually
   tests. Run these in parallel; only **confirmed** findings go in the report at
   full severity. `needs-author-call` items are reported but labeled as such.
   Mediums/lows don't need their own validator — a quick look from you is enough.

3. **Rank** survivors by severity, and within severity by blast radius.

## Step 5 — The report

Output this structure:

```
# Review: <PR title / branch>

**Verdict:** <Ready to merge | Merge after addressing criticals/highs | Needs rework>
<one or two sentences of overall read>

## Critical
- `path:line` — <what + why> · *fix:* <suggestion> · [confirmed | needs-author-call] · (quick-win | heavy-lift)

## High
...

## Medium
...

## Low / nits
<terse list — these shouldn't dominate the reader's attention>

## What looked good
<brief — genuine strengths and what the team found clean. This calibrates trust
and tells the author what not to second-guess.>

## Coverage
Lenses run: <list>. Anything intentionally skipped and why.
```

Lead with the verdict — the reader wants the headline first. Keep mediums and
lows compact so they don't bury the criticals. The effort hint (quick-win vs
heavy-lift) lets you decide what to fix now vs. defer. For a small fix
(roughly under six lines) include the exact replacement in the *fix:* note; for
a structural or multi-location fix, describe it rather than pretending a snippet
covers it. The "what looked good" and "coverage" sections matter: they tell the
reader how much of the diff was actually examined and where the review is
silent, so an empty section doesn't get misread as a clean bill of health.

## Principles

- **Report, don't fix.** The deliverable is findings. If the user wants the
  fixes applied and the PR driven to green, that's `/ship`.
- **A false positive is worse than a miss.** An unreliable report gets ignored
  entirely. The disprove-first validation round is what earns the report's
  trust — don't skip it to save time.
- **Review the diff, not the repo.** Flag what the change introduces;
  pre-existing issues and lint-catchable nits are out of scope and just noise.
- **Match the team to the diff.** Skip lenses with nothing to examine; add
  domain lenses when the change needs them. Don't convene a team for a typo fix.
- **Severity is about consequence, not surprise.** "Could in principle" is not
  critical; "drops writes under normal load" is.
