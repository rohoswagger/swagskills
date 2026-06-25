---
name: ship
description: Take the current branch from "code written" to "ready for human review" autonomously — multi-agent code review, fix critical/high issues, open the PR, reply to and resolve AI reviewer comments (Greptile, Cubic), drive CI green (retrying flaky tests, fixing real failures), then notify the user. Use when asked to "ship this", "ship the PR", "get this ready for review", "open a PR and babysit it", "drive this to green", or any request to handle the whole review-PR-CI pipeline end to end.
---

# ship — drive a branch to "ready for human review"

You own the full pipeline: review → fix → PR → AI-comment triage → CI → notify.
The user is walking away; the deliverable is a PR a human can review without
touching anything first. Don't stop halfway and report status — keep driving
until the PR is green and reviewed-by-bots, or you hit a blocker only the user
can resolve.

## Phase 0 — Preflight

1. Confirm there are changes to ship: commits ahead of the base branch and/or
   uncommitted work. Nothing to ship → say so and stop.
2. Detect tooling: if `.git/ez/stack.json` exists, ALL branch/commit/push/PR
   operations go through `ez` (see the ez-workflow skill) — `ez commit`,
   `ez push --title ... --body ...`, never raw `git commit`/`gh pr create`.
   Otherwise use git + `gh`.
3. Determine the base branch (in Superconductor worktrees:
   `sc worktree status --json` → `target_branch`; otherwise repo default).
4. Identify the project's local verification commands (formatter, linter,
   type checker, test suite) — you'll run these after every fix batch.
5. If on the default branch with uncommitted work, create a branch first
   (`ez create` or `git checkout -b`).

## Phase 1 — Multi-agent review

Spawn a review team in parallel (one message, multiple Agent calls), each with
a distinct lens so they don't all find the same things:

- **correctness** — logic bugs, edge cases, error handling, race conditions
- **security** — injection, authz gaps, secrets, unsafe deserialization
- **tests** — untested new behavior, tests that don't assert what they claim
- **regressions** — does the diff break existing callers/contracts/behavior?

Give each agent the full diff context (base branch, changed files) and require
structured findings: file:line, severity (critical/high/medium/low), what's
wrong, why it matters, suggested fix. Reviewers see only the diff and repo —
they have no conversation context, so put everything in the prompt.

Then dedupe and **verify before fixing**: for each critical/high finding, check
it yourself against the code. Review agents produce plausible false positives;
fixing a non-bug introduces real ones. Downgrade or drop anything that doesn't
hold up.

## Phase 2 — Fix critical and high

Fix every verified critical and high finding. Mediums and lows: don't fix —
list them in the PR description under "Known minor items" so the human reviewer
sees them with context. (Fixing everything balloons the diff and the timeline;
the bar here is "safe to review", not "perfect".)

After fixing: run the local verification suite from Phase 0. If a fix is
non-obvious or touches design, prefer the smallest correct change — this phase
is hardening, not refactoring.

## Phase 3 — Open the PR

- ez repos: `git add` any new files, `ez commit -am "..."`, then
  `ez push --title "..." --body "..."` (or `ez submit` for a stack).
  Never `gh pr create` after `ez push` — the PR already exists.
- Plain repos: commit, push, `gh pr create`.

PR body: what changed and why, how it was verified, the "Known minor items"
list from Phase 2. Mark ready (not draft) — the AI reviewers and CI need it.

Capture the PR number and URL; everything downstream uses them.

## Phase 4 — AI reviewer comments (Greptile, Cubic)

These bots usually post within ~2–5 minutes of the PR opening or a new push.
Poll for their comments:

```bash
gh pr view <n> --json reviews,comments
gh api repos/{owner}/{repo}/pulls/<n>/comments   # inline review comments
```

Match authors case-insensitively on `greptile` and `cubic` (e.g.
`greptile-apps[bot]`, `cubic-dev-ai[bot]`). Poll every ~2 minutes; if neither
bot has posted after ~10 minutes, assume they're not installed on this repo and
move on — don't wait forever for reviewers that may not exist.

Triage each comment on the merits, not on deference. Every bot comment gets a
**reply, then a resolve** once it's actually handled — don't leave addressed
threads open for the human to wade through:

- **Real issue in this PR's scope** → fix it, include in the next commit. Once
  the fix is pushed, reply with what you did and the commit sha, then resolve
  the thread.
- **Real but out of scope** (pre-existing, adjacent code) → reply noting it's
  pre-existing and out of this PR's scope, then resolve; don't expand the PR.
- **Wrong or noise** → reply with a one-line reason it doesn't apply, then
  resolve. Never contort correct code to appease a bot.

Reply in-thread and resolve via the API (resolving an inline thread needs a
GraphQL mutation — there's no plain `gh` verb for it):

```bash
# reply in-thread to an inline review comment
gh api repos/{owner}/{repo}/pulls/<n>/comments \
  -f body="Fixed in <sha> — <one line>." -F in_reply_to=<comment_id>

# list review threads with their node IDs + resolution state
gh api graphql -f query='
  query($owner:String!,$repo:String!,$num:Int!){
    repository(owner:$owner,name:$repo){ pullRequest(number:$num){
      reviewThreads(first:100){ nodes{
        id isResolved
        comments(first:1){ nodes{ author{login} body url } } } } } } }' \
  -F owner={owner} -F repo={repo} -F num=<n>

# resolve a thread once its comment is addressed
gh api graphql -f query='
  mutation($id:ID!){ resolveReviewThread(input:{threadId:$id}){ thread{ isResolved } } }' \
  -F id=<threadId>
```

Only resolve a thread you've replied to and genuinely handled — fix pushed, or
declined with a stated reason. **Leave a thread unresolved when it's a real open
disagreement you're escalating to the human** (see the cap below) so they see it
sitting there; resolving it would bury the one thread that needs their eyes.

After pushing fixes, the bots re-review the new commit — loop back and triage
the new round. **Cap at 3 rounds**: if a bot keeps objecting after three
fix-respond cycles, you're in a disagreement loop, not a convergence — reply
once stating you're leaving it for the human, leave that thread unresolved, and
note it in the final report.

Never resolve, reply to, or dismiss comments from human reviewers; this phase
touches bot threads only.

## Phase 5 — Drive CI green

Watch checks with a background command so you're re-invoked when they settle:

```bash
gh pr checks <n> --watch   # run_in_background
```

When a check fails, read the actual logs (`gh run view <run-id> --log-failed`)
before deciding anything — classify from evidence, not from the check name:

- **Caused by this PR** (failure touches changed code/tests, reproduces
  locally) → fix it, run the local suite, commit, push, watch again.
- **Flaky** (unrelated to the diff, passes locally, timeout/network/race
  signature, or known-flaky) → `gh run rerun <run-id> --failed`. **Max 2
  reruns per check** — a third failure is not flake, treat it as real or
  escalate.
- **Infrastructure** (runner died, quota, broken on base branch too) → rerun
  once; if it persists, it's a blocker to report, not something to fix here.

Track the same test failing across your own fix attempts: if your fix for a
failure fails again, stop pattern-matching and debug it properly. **Three
failed fix attempts on the same check** → stop, leave the branch in its best
state, and escalate to the user with the logs.

New pushes restart Phase 4 (bots re-review) and Phase 5 (CI re-runs) — that's
expected; keep cycling until both are quiet and green.

## Phase 6 — Notify

Done means: critical/high findings fixed, bot comments addressed or answered,
CI fully green. Send the user a proactive message (SendUserMessage with
status "proactive"; also PushNotification if that tool is available):

- PR title + URL
- Review: N findings fixed (by severity), N minor items left for the reviewer
- Bot comments: N fixed, N replied-to/declined (with one-line reasons), all
  addressed threads resolved; N left unresolved for the human (with why)
- CI: green, with N flaky reruns if any
- Anything escalated or left open, stated plainly

If you stopped on a blocker instead, say exactly where the pipeline stopped,
what you tried, and what you need — the user should be able to act from the
message alone without re-deriving your state.

## Hard rules

- Never force-push, never rewrite published history.
- Resolve bot threads only after addressing them (fix pushed, or declined with
  a reason) — and never touch, reply to, or resolve human review comments or
  merge the PR. "ready for human review" is the finish line, not "merged".
- Every fix goes through the local verification suite before pushing; pushing
  a guess at CI wastes a full cycle and spams the bots.
- Caps are real: 3 bot-review rounds, 2 flake reruns per check, 3 fix attempts
  per failing check. When a cap hits, escalate with evidence — grinding past
  it hides real problems.
- Report faithfully: a skipped step, a red check you couldn't fix, a bot
  thread you declined — all of it goes in the final message.
