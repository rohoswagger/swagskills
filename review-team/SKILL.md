---
name: review-team
description: Review a PR or diff with a team of specialist subagents, each owning one aspect (correctness, security, tests, performance, API/contract, readability), run in parallel and synthesized into one deduped, severity-ranked report — then fix the confirmed critical/high/medium issues. Use when asked to "review this PR with a team", "do a thorough/multi-angle review and fix what you find", "get a bunch of agents to review", "deep review before I merge", or any review where breadth and parallel specialist coverage matter more than a single quick pass. It reports findings and applies the fixes, but does not open PRs or drive CI (use /ship for the full pipeline).
---

# review-team — parallel specialist review, one synthesized report

A single reviewer reading a diff top-to-bottom finds the obvious things and
misses the ones that need a specific lens. A security mindset and a
test-coverage mindset notice different problems on the same line. This skill
runs several specialists in parallel — each looking at the *whole* diff through
*one* lens — then synthesizes, dedupes, and validates their findings into a
report, and fixes the confirmed critical/high/medium issues it found.

It produces both a report and a changeset, but stops short of opening a PR or
driving CI — that keeps the loop tight (review and harden the working tree)
without taking the outward-facing actions. For the full
review→fix→PR→bots→CI→notify pipeline, that's `/ship`.

## What this is for vs. the alternatives

- **`/code-review`** — one fast pass over the diff, optionally fixes/comments.
  Reach for it on small or routine changes.
- **review-team (this)** — many specialists in parallel for breadth on a
  larger or higher-stakes change, then applies the fixes. No PR/CI.
- **`/ship`** — uses a review like this as one phase, then fixes, opens the PR,
  triages the bots, and drives CI green.

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
  comments that lie, structure that will be hard to change. Also enforce the
  code-quality house rules below.

**Code-quality house rules** (give these to the readability lens verbatim —
they're deliberate style choices, not generic advice):

- **Escape hatches need a *proven* reason.** `cast()`, `# type: ignore`,
  `as any`, `@ts-expect-error`, `# noqa` — each asserts the checker is wrong.
  Don't just flag one: **delete it, run the type checker, and report what
  happened.** Every cast lands in one of two buckets, and the checker tells you
  which:
  - *Removable* — the cast is propping up a redundant branch or a loose local
    annotation. Fix the types instead: narrow with `isinstance`, annotate the
    variable, correct the upstream return type, or convert once at the edge
    (`dict(x)`). Report the replacement.
  - *Load-bearing* — a third-party signature wants a `TypedDict`, a Protocol, or
    an invariant generic, and nothing spelled `dict[str, Any]` (or `Mapping`) is
    assignable to it. Then the cast *is* the boundary marker and should stay.
    Report the checker error and name the vendor type, so the next reviewer
    doesn't re-litigate it.

  A reviewer who says "remove the cast" without having run the checker is
  guessing, and the author burns a round trip disproving them. Two casts on
  adjacent lines routinely fall in different buckets — judge each one.
- **No dataclasses.** New structured types should be Pydantic models (validation,
  serialization, consistency with the rest of the codebase), not
  `@dataclass`. Flag any new dataclass the diff introduces.
- **Inline single-use helpers.** A private function called from exactly one
  place is usually indirection, not abstraction — the reader has to jump to it
  and back for no reuse payoff. Inline it unless it earns its name: it isolates
  something genuinely separable (a hairy algorithm, an I/O boundary) or exists
  to be tested directly. The same applies to single-use constants, wrapper
  classes, and one-line lambdas assigned to names.
- **No speculative abstraction.** Interfaces with one implementation, config
  knobs nothing sets, generic parameters instantiated one way — YAGNI. Build
  the abstraction when the second use case arrives.
- **Comments must be true, or gone.** A confident, stale comment is worse than
  no comment: it misdirects whoever debugs the area next, and they'll trust it
  over the code. Flag any comment the diff renders false, any comment that
  narrates the change ("now also handles X") instead of explaining a non-obvious
  *why*, and any comment asserting scope ("only X does Y") that the reader can't
  verify locally — those rot silently and are the expensive kind.
- **Unsupported input must fail loudly.** Quietly dropping a field or degrading
  to a default — an unmappable enum becoming `auto`, an unknown key swallowed by
  a permissive schema, a requested constraint ignored — produces a *plausible
  wrong answer* with nothing downstream able to detect it. That's strictly worse
  than an error. Prefer an explicit raise/4xx, and flag any silent fallback the
  caller can't observe.
- **Error paths preserve invariants.** If the happy path opens, locks,
  registers, or emits a start-event, then every `except` and early return must
  close it. Read the success path and each failure path side by side and look for
  the asymmetry — this is where half of all streaming/resource bugs live.
- **Identity is minted once.** A helper that generates an id, uuid, or timestamp
  must not be called twice for the same logical entity; the second call silently
  yields a different value. Watch for a builder invoked once while streaming and
  again for the terminal payload — the two disagree and clients can't correlate
  them.

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
   tests. Run these in parallel; only **confirmed** findings survive at full
   severity. `needs-author-call` items are reported but not auto-fixed. Validate
   mediums too — they get fixed, so they need the same proof — but a quick look
   from you suffices rather than a dedicated validator. Lows don't need it.

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
covers it. **Any snippet you hand over must actually compile and typecheck** —
apply it and run the checker before it goes in the report. A plausible-looking
replacement that the checker rejects wastes the author's time and costs the
review its credibility; prose beats a broken snippet. The "what looked good" and "coverage" sections matter: they tell the
reader how much of the diff was actually examined and where the review is
silent, so an empty section doesn't get misread as a clean bill of health.

Present the report before you start fixing, so the user can see the full
picture and the fixes are traceable back to specific findings.

## Step 6 — Fix the confirmed issues

Fix every **confirmed** critical, high, and medium finding. Leave alone:

- **Lows / nits** — report them; fixing them balloons the diff for little gain.
- **`needs-author-call` items** — these didn't survive validation cleanly, so a
  fix would be a guess. Leave them in the report for the author to decide.
- Anything whose fix is a genuine design decision, not a mechanical correction
  (e.g. "this whole approach should change"). Flag it; don't unilaterally
  redesign. When unsure whether something is mechanical or a design call, treat
  it as a design call and leave it.

How to fix well:

- Make the **smallest correct change** per finding. This phase is hardening the
  existing change, not refactoring it — a sprawling fix is harder to review and
  more likely to introduce its own bugs.
- Fix in dependency order, and re-check that a later fix doesn't undo an earlier
  one.
- After fixing, run the project's verification suite — formatter, linter, type
  checker, and the tests covering the touched code (e.g. on Onyx: `ruff format`
  + `ruff check`, `mypy`/`tsc`, `eslint`, `pytest`/jest on the affected paths).
  A fix that breaks the build isn't a fix.
- If a fix is non-obvious or spans several files, you can dispatch it to a
  subagent with a precise spec, then read the resulting diff yourself — don't
  trust "done" without looking.

Then update the report: mark each finding **fixed** (with a one-line note on
what changed) or **left** (with why). The final state should be: confirmed
criticals/highs/mediums fixed in the working tree and verified, everything else
documented for the human. Don't commit, push, or open a PR — leave the working
tree staged-and-ready so the user (or `/ship`) takes it from there.

## Principles

- **Fix only what you proved.** Apply fixes for confirmed critical/high/medium
  findings; never fix a `needs-author-call` item or a design decision. The
  deliverable is a hardened working tree plus a report — not a PR. Opening the
  PR and driving CI is `/ship`.
- **A false positive is worse than a miss** — doubly so now that findings get
  fixed, because a fix for a non-bug introduces a real one. The disprove-first
  validation round is what makes auto-fixing safe; don't skip it to save time.
- **Smallest correct fix.** This phase hardens the change; it doesn't refactor
  it. Re-verify after fixing — a fix that breaks the build isn't a fix.
- **Review the diff, not the repo.** Flag what the change introduces;
  pre-existing issues and lint-catchable nits are out of scope and just noise.
- **Match the team to the diff.** Skip lenses with nothing to examine; add
  domain lenses when the change needs them. Don't convene a team for a typo fix.
- **Severity is about consequence, not surprise.** "Could in principle" is not
  critical; "drops writes under normal load" is.
