---
name: ux-test
description: Drive the user's real Chrome as an agent and UX-test a just-built feature end to end — derive the user flows a real person would take, click through those exact flows in the live browser, report what's broken or awkward, then fix it in code and re-test until every flow works as intended. Use when asked to "UX test this", "click through the new feature", "test the UX in my browser", "drive the browser and make sure this works", "dogfood this feature", or any request to exercise a built feature through the actual UI (not unit tests) and harden it until it behaves.
---

# ux-test — drive the browser, find the rough edges, fix them, re-test

You are a user, not a unit test. The feature was just built; your job is to
*use* it the way a real person would — open the page, click the thing, fill the
form, watch what happens — and judge whether the experience is actually good.
Then close the loop: anything broken or awkward, you fix in the code and run the
flow again, until every flow you defined passes cleanly.

This is exercise-through-the-real-UI, not assertion-writing. If the user wanted
Playwright specs, that's a different task. Here the deliverable is a feature that
demonstrably works when a human drives it, plus a report of what you found and
fixed getting there.

## Operating assumptions (read these first)

- **Everything is already authenticated.** You're attaching to the user's real,
  logged-in Chrome. Never try to log in, never look for a login form, never
  treat an auth wall as part of the flow. If you somehow land on a sign-in page,
  that's a wrong-URL or wrong-tab problem — fix your navigation, don't fill
  credentials.
- **You are an agent acting as the user.** Reads are free (screenshots, DOM,
  console, network). Actions that mutate real state — sending a message,
  submitting a payment, deleting something, changing account settings — are
  fair game *only* on throwaway/test data or local/staging environments. On
  anything resembling production, get explicit go-ahead for that specific
  mutating action before you click it.
- **It's the user's browser.** New tab for your testing; never hijack, reload,
  or close a tab you didn't open; close the tabs you do open when finished.

## Phase 0 — Connect to the browser

You need a tool that *drives* the UI (clicks, types, navigates, screenshots).
Two clients can do it, and **they connect by different transports — don't
conflate them:**

1. **`mcp__claude-in-chrome__*`** — the extension-based client, the user's real
   browser. **Primary tool for this skill**: it clicks and types as the user in
   their actual session. It rides the Chrome extension, **not** CDP — so it does
   *not* open port 9222, and `connect-chrome`'s `cdp-status.sh` probe will report
   `off` even when claude-in-chrome is working fine. The only test that matters
   for this client is: **are the `mcp__claude-in-chrome__*` tools registered in
   your session?** If they are, you're connected — just start using them. If
   they aren't, the user enables it on their side (the `/chrome` command / the
   extension); a green CDP probe is irrelevant here.
2. **`mcp__chrome-devtools__*`** — the CDP-based client (this is the one
   `connect-chrome` and `cdp-status.sh` are about). Also the real browser; has
   click/fill/navigate plus richer console/network/screenshot. Good as the
   driver, and good *alongside* claude-in-chrome for reading console errors and
   failed requests while you click. Needs port 9222 up — follow `connect-chrome`
   to attach it.

**Confirm a driver is actually live before going further** — don't design flows
against a browser you can't drive. Check that one client's tools are present and
take a throwaway screenshot to prove the connection responds. If neither client
is registered, say so plainly and have the user connect one (claude-in-chrome
via the extension, or chrome-devtools via `connect-chrome`'s setup) — this skill
cannot run without a live browser client, and a fabricated "test" is worse than
reporting the blocker.

## Phase 1 — Pin down what's under test

Before designing flows, know exactly what feature you're testing and where it
lives:

- **What changed.** Look at the branch diff (`git diff` against the base) for the
  frontend surface that's new or modified — components, routes, pages, the
  interaction that was built. The conversation usually names the feature; the
  diff tells you its actual shape and entry points.
- **Where it runs.** Find the live entry point: the local dev server URL (check
  if one's already running; the `run` skill knows how to launch this project's
  app if not), a staging URL, or wherever the user points you. Confirm the
  feature is actually deployed/running at that URL before testing — testing a
  stale build wastes the whole loop.
- **What "works as intended" means.** Pull the intent from the conversation, the
  PR/commit description, or ask one tight question if it's genuinely ambiguous.
  You can't judge UX against a spec you don't have.

## Phase 2 — Derive the user flows

This is the thinking step — do it before you touch the browser. Enumerate the
distinct paths a real user would take through this feature, named and ordered.
Cover, as the feature warrants:

- **The happy path** — the primary thing the feature exists to let someone do,
  start to finish.
- **Realistic variations** — the other legitimate ways through it (different
  entry points, optional fields, alternate selections, back/cancel, editing
  after creating).
- **Edge & error cases a user actually hits** — empty input, too-long input,
  invalid values, double-clicks, navigating away mid-action, refreshing,
  network hiccups. Not exhaustive fuzzing — the mistakes real people make.

Write the flows out explicitly as a numbered list, each with concrete steps and
the **expected outcome** at the end ("after clicking Save, the row appears in the
list and a success toast shows"). These exact flows are your test plan — you'll
run them as written and report against them, so they have to be specific enough
to execute and to judge pass/fail. Present this list before driving, so the work
is traceable.

## Phase 3 — Run each flow in the browser

Execute the flows you defined, one at a time, as written. For each step:

1. **Locate, then act** — screenshot or snapshot the page *first* to see what's
   actually there and find the target element, then click / type / navigate on
   the real element (these tools act on what's currently rendered, so don't click
   blind). If the element you expect isn't there, that itself is a finding.
2. **Wait for it to settle, then observe** — let the action complete (navigation,
   network request, animation) before judging; something mid-load is not "broken."
   Then screenshot the result, read the console for errors/warnings, and check the
   network panel for failed requests (4xx/5xx) the action triggered.
3. **Judge against the expected outcome** — did the right thing happen, and did
   it happen *well*? You're grading UX, not just "did it crash":
   - **Broken**: errors, dead buttons, wrong navigation, data not saved, blank
     states, infinite spinners, console exceptions, failed requests.
   - **Awkward**: no feedback after an action, confusing or missing labels,
     layout breaking, jarring jumps, slow loads with no indicator, a dead-end
     with no way back, validation that fires at the wrong time or says nothing
     useful, a flow that takes more clicks than it should.

**Before calling something broken, cross-check the screenshot against the DOM**
(read the accessibility tree / page text). The two can disagree: a loading
skeleton or a not-yet-painted screenshot routinely hides content that's actually
present in the DOM — so a "stuck skeleton" screenshot is often just a slow first
paint, not a dead page. And **"no request in the browser network panel" is not
proof the page didn't fetch** — server-rendered pages (React Server Components,
SSR) fetch *server-side*, so those calls never show up in the browser's network
tab; the page can be loading data fine with an empty browser-side network list.
Confirm a stuck/empty state in the DOM, after a real wait, before treating it as
a bug — these two false positives are the easiest way to "fix" something that was
never broken.

Record each flow as **pass / broken / awkward** with the specific evidence
(screenshot, console line, the step where it went wrong). Don't stop the whole
run at the first problem — finish the flow if you safely can, note everything,
then move on; a single pass surfaces more than a halt-on-first-error sweep.

## Phase 4 — Report findings

Before fixing, lay out what you found so the picture is visible and the fixes
trace back to it:

```
# UX test: <feature>

**Flows run:** N · **Pass:** N · **Broken:** N · **Awkward:** N
Environment: <url> · Driver: <claude-in-chrome | chrome-devtools>

## Flow 1: <name> — PASS | BROKEN | AWKWARD
Steps: <what you did>
Expected: <outcome> · Actual: <what happened>
Evidence: <screenshot ref / console line / failed request>
Findings: <broken/awkward items, each concrete>

## Flow 2: ...
```

Lead with the count line so the headline is immediate. Each finding names the
exact step and the evidence — "clicking Save did nothing; console: `TypeError:
cannot read 'id' of undefined` at CreateForm.tsx:42; no network request fired"
beats "save is broken."

## Phase 5 — Fix, then re-test (the loop)

For each **broken** finding, and **awkward** findings worth fixing:

1. **Find the cause in code** — trace from the symptom (console error, failed
   request, the component the diff touched) to the actual defect. Don't
   pattern-match a fix onto the symptom.
2. **Make the smallest correct change.** This is hardening the built feature,
   not redesigning it. A genuine design decision ("this whole flow should work
   differently") isn't yours to make unilaterally — flag it for the user instead
   of rebuilding.
3. **Rebuild / let it hot-reload**, confirm the new code is actually live at the
   test URL (a stale bundle is the #1 way to "fix" something and see no change).
4. **Re-run the exact flow that failed**, plus any flow the fix could have
   affected — fixes cause regressions, so don't just check the one thing.

Loop until every defined flow passes. **Caps so the loop terminates:**

- **3 fix attempts per flow.** If the same flow still fails after three real
  attempts, stop grinding — you're likely misdiagnosing. Leave it in its best
  state and escalate with what you tried and the evidence.
- A fix that needs a product/design decision, or infrastructure you can't change
  (a flaky backend, a missing service) → report it, don't fake a fix around it.

Re-verify after the last fix that the whole flow set still passes — a late fix
can quietly break an early flow.

## Phase 6 — Final report

Close with: each flow's final state (pass, or left-broken with why), what you
fixed (finding → root cause → change, one line each), what you left for the user
(design calls, out-of-scope issues, anything escalated), and the residual UX
notes worth knowing even if you didn't fix them. If a flow involved a mutating
action you skipped for lack of go-ahead, say so — a flow you didn't fully run
isn't a flow that passed.

## Hard rules

- **Never authenticate.** Everything is already logged in; an auth wall means
  you navigated wrong, not that you should sign in.
- **Test the exact flows you defined.** Improvising new clicks is fine for
  exploration, but judge pass/fail against the written flows so the report is
  honest about coverage.
- **Mutations need a clean environment or explicit consent.** Real
  send/pay/delete/settings actions only on test data or local/staging, or with
  the user's go-ahead for that specific action.
- **Confirm the build is live before believing a fix.** Re-test against actually-
  reloaded code; a stale bundle fakes both failures and successes.
- **Smallest correct fix; flag design calls.** Harden the feature, don't redesign
  it out from under the user.
- **Caps are real** — 3 fix attempts per flow, then escalate with evidence. A
  loop with no exit is worse than an honest "this one's still broken, here's why."
- **Report faithfully** — a skipped flow, a finding you couldn't fix, an awkward
  edge you left: all of it goes in the report, not just the wins.
