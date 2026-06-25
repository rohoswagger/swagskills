---
name: bugfix
description: Take a bug — a pasted ticket, a stack trace, a "this is broken" report — and drive it end to end to a PR ready for human review, autonomously. Reproduce it, root-cause it with repeated "why" (scaling depth to the bug — inline for small ones, a subagent team for hard ones) until you reach the specific code that breaks, plan the minimum viable fix and pressure-test it, write a failing test that proves you understand it, implement the smallest correct fix, harden it (review-team, regression tests, decomment, docs, claude-in-chrome for frontend), then ship it with /ship. Use when asked to "fix this bug", "here's a ticket, fix it", "debug and ship this", "root cause and fix", "squash this bug", or any time the input is a defect and the expected output is a reviewed, tested PR — not just a diagnosis.
---

# bugfix — from a bug report to a PR ready for human review

You are handed a defect and you own it all the way to a PR a human can review
without touching anything first. The chain is: **reproduce → root-cause →
plan → prove with a test → fix minimally → harden → ship.** Each link composes
an existing skill where one fits; this skill is the conductor that holds the
through-line and refuses to skip steps.

The two failure modes this skill exists to prevent:

1. **Fixing the symptom, not the cause.** The stack trace points at where it
   *blew up*, which is usually downstream of where it *went wrong*. A patch that
   silences the symptom leaves the real bug live and adds a confusing band-aid.
   The root-cause phase exists to drag you past the first plausible explanation.
2. **Claiming a fix you can't prove.** "I think this fixes it" is not done. A
   test that fails *before* your change and passes *after* is the proof — for a
   frontend bug, the equivalent is the flow visibly working in a real browser.
   No proof, not fixed.

## Right-size the effort first

Before anything else, gauge how big this bug is — the cost of this skill should
scale with the bug, not with the length of this file. **Most bugs are small, and
for them the lean path is the correct path:** reproduce it, root-cause it inline,
write the failing test, make the minimal fix, one quick review pass, ship. That's
the whole job. Reach for the heavy machinery described below — parallel `Explore`
mapping, a multi-lens plan-review team, disprove-first subagent rounds — only
when the bug earns it: a large or unfamiliar codebase, a high-blast-radius
change, a heisenbug, or a "we've tried to fix this before." Convening a team of
subagents to fix a one-line off-by-one costs more time and tokens *and* gives a
worse result than just thinking. The phases below are written at full size;
running them at full size on a small bug is the most common way to waste this
skill, so treat each phase's fan-out as opt-in, not the default.

Two efficiency rules that hold at every size:

- **Invoke the sibling skills, don't read them.** `review-team`, `decomment`,
  `ship`, `ux-test` run as their own commands when you reach that phase — call
  them there; don't read their source into context to "understand" them first.
- **Spend the model where it changes the outcome.** You own the judgment —
  reproduction, the why-ladder, the plan, reading every diff. Delegate only
  well-specified mechanical edits to a cheaper model (the `bigbrain` split), run
  genuinely independent work in parallel, and keep your own output tight: a crisp
  root-cause statement and a short report beat long ones.

## Phase 0 — Intake and setup

Read the input as evidence, not instructions. A ticket says what someone
*observed*; your job is to find what's *true*.

1. **Extract the facts.** From the ticket / trace / message pull: the symptom
   (what's wrong), the trigger (what action or input causes it), the expected vs
   actual behavior, the environment (prod/staging/local, browser, version), and
   any error text, stack frames, or repro steps given. List what you know and,
   explicitly, what you *don't* — the gaps drive the investigation.
2. **Classify the surface.** Backend (Python/Celery/DB), frontend
   (TypeScript/React), or both. This decides your reproduction tool (a failing
   test vs. driving the browser) and whether the harden phase pulls in
   `ux-test` / claude-in-chrome.
3. **Set up the workspace.** Detect tooling: if `.git/ez/stack.json` exists, all
   branch/commit/PR operations go through `ez` (see the `ez-workflow` skill) —
   `ez create bugfix-<slug>` to start a branch. Otherwise `git checkout -b`. In a
   Superconductor worktree, get the base branch from `sc worktree status --json`.
   Identify the project's verification commands (formatter, linter, type checker,
   test runner) now — you'll lean on them all the way through.

If the report is too thin to act on (no symptom you can pin, no way to even
guess a trigger), ask one tight question. Otherwise proceed — you can resolve
most ambiguity by reading code, and that's cheaper than a round-trip.

## Phase 1 — Reproduce first

Before theorizing, make the bug happen on demand. A bug you can't reproduce is a
bug you can't confirm you fixed, so this comes before root-causing, not after.

- **Backend / logic:** find the entry point from the symptom and write (or run)
  the smallest thing that triggers it — ideally a failing test in the project's
  framework, or a one-off script / REPL call if a test is premature. Capture the
  exact failure: message, stack, wrong value.
- **Frontend:** reproduce it in the real UI. Follow `ux-test` to attach to the
  user's Chrome (claude-in-chrome), drive the exact steps from the report, and
  capture the broken state — screenshot, console error, failed request. Read the
  DOM and console, not just the screenshot (a slow first paint fakes a "broken"
  page; SSR fetches don't show in the browser network tab — `ux-test` Phase 3
  covers these false positives).
- **Can't reproduce?** Don't fix blind. Widen the net — different inputs, a
  closer reading of the environment, the version where it was reported. If it
  still won't reproduce, say so plainly and either ask for more (exact inputs,
  a session/trace) or proceed on the single best hypothesis *clearly flagged as
  unconfirmed*. Never present an unreproduced "fix" as done.

Hold onto the reproduction — it becomes the regression test in Phase 3.

## Phase 2 — Root cause: ask why until you hit the code

This is the heart of the skill and the step most worth slowing down for. The
goal is a single sentence naming **the specific code that is wrong and why it
produces this symptom** — not a vague area, an actual location and mechanism.

### Map the terrain

Trace the code paths the bug touches — the call chain from trigger to symptom,
the data flow into the broken value, recent changes to the area
(`git log`/`git blame`/`git log -S` on the suspect symbol), and any tests that
already cover it. For a bug in code you can already navigate, read it yourself —
that's faster than dispatching. Only when the codebase is large or unfamiliar and
the relevant code is scattered, fan out `Explore` agents in one message to map it
in parallel and synthesize their findings inline; they read, you reason.

### Walk the why-ladder

From the symptom, ask "why" and answer it *from the code*, then ask "why" of
that answer, repeatedly, until the answer is a concrete defect you could point a
cursor at. Each rung must be grounded in code you've read, not inferred — an
ungrounded rung is where wrong root causes come from. Typically four to six
rungs; stop when the next "why" would be "because someone wrote it that way,"
i.e. you've reached the actual mistake.

```
Symptom:  Saving a report with an empty title returns 500.
  ↓ why?  The handler calls report.title.strip() and title is None.
  ↓ why?  title is None because the form allows omitting it.
  ↓ why?  The serializer marks title optional, but the model column is NOT NULL.
  ↓ why?  A migration made title required; the serializer was never updated.
Root cause: serializer/model contract drift — serializers.py:88 lets title be
omitted while reports table requires it; the 500 is the NOT NULL violation
surfacing late. Fix belongs at the serializer (reject/normalize), not at the
.strip() call (that's the symptom site).
```

Note how the symptom site (`.strip()`) and the root-cause site (the serializer)
are different files — patching the crash line would have hidden the bug, not
fixed it. That gap is exactly what the ladder is for.

### Confirm by disproving

Before committing to the root cause, try to *refute* it — the same disprove-first
discipline `review-team` uses on findings. Reason it through yourself first: "Is
there another path that produces this symptom, a guard that should prevent it, a
case where the fix here wouldn't help?" For a non-obvious or high-stakes root
cause, spawn one or two subagents to attempt the refutation independently. A root
cause that survives an honest refutation attempt is one you can build a fix on.
If it doesn't survive, climb back down the ladder.

Output a short **root-cause statement**: the symptom, the exact location and
mechanism, why it happens, and where the fix belongs (which may not be where it
crashes). Everything downstream traces to this.

One more question before you leave this phase: **is the reported symptom one
instance of a class?** When the root cause is shared or upstream — a cached
object handed out by reference, a mutable default, a global, a contract every
caller relies on — the bug you were handed is often just the first caller to
trip it, and other call sites have the same latent defect. Fixing only the
reported path leaves a landmine and you'll be back here next week. Fixing at the
shared root (return a copy, fix the default, repair the contract) closes the
whole class at once. So when the cause is upstream, scan the other callers of
that code and decide deliberately: fix the class at the root, or fix this
instance and note the rest as known-affected. Defaulting to the local patch
without even looking is how a symptom-fix masquerades as a root-cause fix.

## Phase 3 — Plan the minimum viable fix, then stress-test the plan

Write the plan before writing code, and review the plan before trusting it — a
flawed plan caught here costs a paragraph; caught after implementation it costs
the implementation.

1. **Draft the MVS.** The minimum viable solution: the smallest change that
   fixes the root cause (not the symptom) without regressing callers. Name the
   exact files/functions, the change at each, and the order. Resist scope creep —
   adjacent smells you notice go in the PR description as "noticed, out of
   scope," not into this diff. A bug fix that doubles as a refactor is hard to
   review and easy to get wrong. When the root cause is a contract mismatch with
   two fixable sides — a caller and a callee that disagree — prefer the side that
   leaves the existing passing tests green. A test that already passes is a vote
   for the contract that side expects; fixing the *other* side keeps both the
   diff and the test churn smaller. (If your chosen fix does make an existing
   test fail, that's the deliberate decision point in Phase 4: the test encoded
   the contract you're changing, so update it on purpose and say so — that's not
   the same as gratuitously editing a still-green test.)
2. **Pressure-test the plan** from a few angles before trusting it:
   - **correctness** — does this address the root cause, or just move the
     symptom? Edge cases the fix must handle?
   - **blast radius / regressions** — who else calls this path? What existing
     behavior or contract could this change break?
   - **simplicity / alternatives** — is there a smaller or better-placed fix? Is
     this the right layer to fix at?
   - **test strategy** — what test proves this fix and guards the regression?
     What would a sufficient test miss?
   For most bugs you run these lenses yourself in a few minutes — that's enough.
   For a high-blast-radius or genuinely uncertain fix, spawn a small team in one
   message (one lens each) to get independent objections, and synthesize them.
   Either way, require concrete objections, not approval, and revise the plan. If
   the review reveals the fix is a real design decision (the approach should
   change, not just the code), surface that to the user rather than redesigning
   unilaterally.

The deliverable of this phase is a plan you'd defend: root cause, the minimal
change, why this layer, and the test that will prove it.

## Phase 4 — Prove it with a test (red)

Turn the Phase 1 reproduction into a committed, failing test before you write
the fix. Writing the test first does two things: it forces you to state, in
executable terms, exactly what correct behavior is — which surfaces a
misunderstood bug *now* rather than after a wrong fix — and it gives you the red
that must turn green.

- **Backend:** a test in the project's framework that exercises the trigger and
  asserts the *correct* outcome, so it fails against current `main` with the
  real bug, not a contrived one. Run it; confirm it fails for the right reason
  (the actual symptom, not a typo in the test).
- **Frontend:** if the behavior is unit-testable (a reducer, a hook, a util),
  write that test. If it's genuinely interaction-level, the `ux-test` browser
  flow from Phase 1 is your red — record the failing flow as the proof, and add
  a component/e2e test if the project has that harness.

If a clean reproducing test is truly impractical (deep integration, external
service), say so and document the manual reproduction instead — but treat that
as the exception, since an untested fix can silently rot. Don't skip this to
save time; it's the cheapest insurance in the whole flow.

**Leave the existing tests alone.** Add new tests; don't edit passing ones to
"match" your change. An existing test is the codebase's record of what behavior
was promised — if your fix makes one *fail*, that's a signal to read, not an
obstacle to silence: either the test encoded the bug (then changing it is part
of the fix — do it deliberately and call it out in the report) or it encoded
correct behavior your fix just broke (then your fix is wrong, not the test).
Rewriting a still-*passing* test so it reads differently is pure noise that
hides what actually changed; don't. The tell-tale anti-pattern is tweaking an
assertion's inputs/expected values so the suite stays green — if you're editing
a test that wasn't failing, stop and ask why you're touching it.

## Phase 5 — Implement the fix (green)

Make the failing test pass with the planned minimum change.

- For a well-specified, mechanical fix you can delegate the edit to a cheaper
  model via the `bigbrain` split (Agent tool, `model: "sonnet"`) with a precise
  spec, then read the diff yourself. For a subtle fix, do it inline — never
  delegate the judgment, only the typing.
- Make the **smallest correct change** that satisfies the plan. If implementing
  reveals the plan was wrong (the root cause was off, the fix doesn't take),
  stop and climb back to Phase 2 — don't pile changes on a bad diagnosis.
- Run the new test: it must now pass. Then run the project's full verification
  (formatter, linter, type checker, the tests around the touched code). A fix
  that breaks the build or a neighbor isn't a fix.

## Phase 6 — Harden: review, cover, clean, document, dogfood

The fix works; now make it review-ready. Do these as the diff warrants — skip
what doesn't apply, don't perform ceremony for its own sake.

- **Multi-angle code review.** Run `review-team` on the diff: parallel
  specialists (correctness, regressions, tests, plus security/perf/frontend
  lenses where relevant), disprove-first validation, then fix the confirmed
  critical/high/medium findings. This is the diff-level counterpart to the
  plan review you already did.
- **Regression coverage.** Beyond the one reproducing test, add the tests a
  reviewer would expect for the cases the fix newly handles — the edge cases the
  plan review surfaced. Enough to lock the bug shut, not a speculative suite.
- **Frontend behavior.** If the bug or fix touches the UI, run the `ux-test`
  loop: drive the actual flows in the user's Chrome, confirm the fix works *and*
  didn't break adjacent flows, fix and re-test until clean. The Phase 1 repro
  flow must now pass.
- **Decomment.** Run `decomment` on the diff — strip the narration and
  change-commentary that accumulates while debugging ("fixed the None case
  here"), keeping only comments that encode genuinely non-obvious technical
  context (why the fix is at this layer, a gotcha the next person would hit).
- **Docs if needed.** If the fix changes documented behavior, a public API, a
  config option, or a contract others rely on, update the docs/changelog. A
  pure internal bug fix usually needs none — don't invent docs to look diligent.

Re-run verification after hardening; the review and test additions can shift
things.

## Phase 7 — Ship

Hand off to `/ship`, which owns the rest of the pipeline: it re-reviews, opens
the PR (via `ez`/`gh`), writes the PR body, triages the AI reviewer bots
(Greptile, Cubic), drives CI green, and notifies you. Don't re-implement that
here — `ship` is the finish line.

Make sure `ship` has what it needs in the PR description: the **root cause** (in
plain language — the reviewer wants to understand the bug, not just the diff),
**the fix** and why at this layer, **how it was verified** (the failing→passing
test, the browser flow), and the **out-of-scope items** you noticed but didn't
touch. A bug-fix PR that explains the root cause reviews far faster than one that
only shows the patch.

## Scaling the pipeline

Echoing the right-sizing principle up top, concretely:

- **One-line obvious bug** (a typo, a visible off-by-one): root-cause inline,
  write the reproducing test, fix, one quick self-review, `/ship`. No `Explore`
  fan-out, no plan-review team, no disprove subagents. Say you're compressing.
- **Gnarly, high-blast-radius, or "we've tried to fix this before" bug:** run the
  full pipeline — parallel mapping, the plan-review team, disprove-first rounds.
  This is where the machinery earns its cost.

The phases are a checklist of *judgment*, not a ritual. The only two steps that
never compress away, at any size, are reproduction and the test-as-proof — those
are what separate a fix from a guess.

## Hard rules

- **Fix the cause, not the symptom.** If the fix site equals the crash site,
  prove that's actually where the logic is wrong — often it isn't.
- **Reproduce before fixing, prove after fixing.** A red test that goes green
  (or a browser flow that goes from broken to working) is the definition of done
  here. No proof → not done, and say so.
- **Minimum viable fix.** Smallest correct change for the root cause; adjacent
  cleanups go in the PR description as out-of-scope, not in the diff.
- **Don't edit passing tests to fit the fix.** Add coverage; never rewrite an
  existing green test to match new behavior. A test that fails after your change
  is a signal (the fix is wrong, or the test encoded the bug and you change it
  on purpose), never something to quietly edit away to keep the suite green.
- **Don't delegate judgment.** Fan out for breadth and delegate mechanical
  edits, but the root cause, the plan, and every diff are yours to decide and
  read — never trust a subagent's "done" without looking.
- **Caps are real.** If the root cause won't hold up after refutation, or the
  fix fails its test after three honest attempts, stop — you're misdiagnosing.
  Leave the branch in its best state and escalate with the evidence.
- **Report faithfully.** An unreproduced bug, an untested fix, a flow you
  couldn't verify, a design call you punted to the user — all of it goes in the
  handoff, not just the wins.
