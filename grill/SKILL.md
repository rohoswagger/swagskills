---
name: grill
description: Interrogate the user about a new feature, product change, UX change, or infrastructure decision BEFORE any design or implementation work begins — extract the context in their head so the implementation isn't confidently wrong. Use this whenever the user invokes /grill, starts describing a new task or feature to build, says "grill me", "pick my brain", "let me give you context", or hands over a feature request that has any open product/design/architecture decisions. This is meant to be the FIRST skill invoked on any new piece of work. Do not use for bug fixes or tasks where the desired behavior is already fully specified.
---

# Grill

The user is about to hand you a task they've been thinking about for days. They have a rich mental model — who it's for, what it must not break, what they already rejected, what "done" looks like — and the task description contains maybe 10% of it. If you implement from that 10%, you will build something plausible and wrong. Your job here is to extract the other 90% by interviewing them like a skeptical senior engineer in a design review: sharp, specific, grounded in the actual codebase.

The measure of success: after the grilling, you (or any agent reading the conversation) could make the same judgment calls the user would make. Not "you have a spec" — specs go stale the moment implementation hits a surprise. You want their *decision function*.

## Step 0: Is this grillable?

If the task is a bug fix, a fully-specified mechanical change ("rename X to Y everywhere"), or a task where there are genuinely no open decisions — say so and skip the grilling. One sentence: "This looks fully specified — no grilling needed. Proceeding." Don't perform an interview for its own sake.

If the user invoked this with no task description at all, ask one opener: "What are we building?" and wait. Everything else comes after you know the topic.

## Step 1: Scout the codebase (fast, before asking anything)

Spend a few minutes exploring the code relevant to the task before writing a single question. Use the Explore agent (or direct search for small scopes) to find:

- The current behavior in the area being changed — what exists today that this touches, replaces, or extends
- Adjacent precedent — has this codebase solved a similar problem before? (e.g., if the task adds a new notification type, how do existing notifications work?)
- Constraint surfaces — feature flags, permissions/roles, tenancy, API versioning, migration patterns, anything that suggests "changes here have a blast radius"
- Anything ambiguous or surprising — places where the task description and the code seem to disagree

This matters because grounded questions are an order of magnitude better than generic ones. "Should this be configurable?" is a waste of the user's time. "Right now `ChatSession` hardcodes the retention window to 30 days in `session_config.py` — is the new archival feature replacing that, or layering on top?" forces a real decision out of their head. The scout is also how you catch the cases where the user's mental model of the code is out of date — surfacing "the code actually does X, not Y" during the interview saves a doomed implementation.

Keep the scout to ~5 minutes of effort. You're gathering ammunition for questions, not writing a design doc.

## Step 2: Round 1 — the 5–10 core questions

Ask 5–10 questions in one batch. Number them. Every question must pass this bar: **the answer changes what you would build.** If you can predict the answer, or any answer leads to the same implementation, cut the question.

Delivery: use AskUserQuestion for questions where you can enumerate the realistic options (it's faster for the user to tap than type, and the "Other" escape hatch is always there) — max 4 per call, so batch the enumerable ones together. Ask the open-ended ones as plain numbered text in the same turn. Don't force open-ended questions into fake multiple choice.

Cover whichever of these dimensions actually have open decisions for this task — not all of them, and not in this order. The task determines the mix; a UX change weights heavily toward the first four, an infra change toward the last four.

1. **The user and the moment** — Who hits this, and what were they doing right before? What triggers it? "All users" is almost never the real answer; get to the specific persona and entry point.
2. **The job to be done** — What does the user accomplish with this that they can't today? What's the workaround they're currently suffering through? The workaround usually reveals the real requirement.
3. **Success and failure** — How will the user (your user, the one grilling you) know this worked? A metric, a demo moment, a complaint that stops? And what's the failure mode they're most afraid of?
4. **Scope edges** — What is explicitly OUT? What's the v1/v2 line? Users usually have a crisp mental cut line they haven't written down anywhere.
5. **Rejected alternatives** — What approaches did they already consider and discard, and why? This is the highest-density question in the set: every rejected alternative carries a hidden constraint. If they say "we thought about doing it client-side but no" — the *why* behind that "no" will shape ten of your implementation decisions.
6. **Interaction with existing behavior** — For each thing your scout found that this touches: replace, extend, or coexist? Migration story for existing data/users? Feature-flagged or straight to everyone?
7. **Hard constraints** — Deadlines, compliance, perf budgets, API stability promises, "the CEO wants it to look like X", dependencies on other teams' work. The stuff that's obvious to them and invisible to you.
8. **Taste and precedent** — Is there a product (or an existing screen/endpoint in this codebase) they want this to feel like? "Like Linear's command palette" transmits more design intent than three paragraphs.

Ground as many questions as possible in the scout: quote the actual file, the actual current behavior, the actual precedent. Present the batch, then stop and wait. Do not start designing, do not hedge with "meanwhile I'll assume…".

## Step 3: Round 2 (and maybe 3) — drill the gaps

Read the answers like a reviewer, not a stenographer. Then follow up on:

- **Contradictions** — answer 3 says "ship fast, flag it", answer 7 says "must handle the enterprise tenant migration". Name the tension explicitly and make them pick.
- **Suspiciously easy answers** — "just make it like the existing one" → the existing one does A, B, and C; which of those carry over? Vague answers are where wrong implementations are born.
- **New territory an answer opened** — they mention a stakeholder, system, or constraint you didn't know about → one or two questions to map it.
- **The unasked question** — after reading their answers, ask yourself: "if I built this and it came out wrong, what would the wrongness most likely be?" If that risk isn't covered yet, ask about it now.

Round 2 should be 2–5 questions, tightly targeted. If round 2 answers open something big, do a round 3; otherwise stop. Two rounds is the norm. Do not pad — the user's patience is the budget, and a question that doesn't change the build spends it for nothing.

## Step 4: Play it back

Summarize everything extracted, in-conversation (no file unless asked). Structure it as:

- **What we're building** — 2–3 sentences, in your words (not theirs — restating in your own words is the check that you actually understood)
- **Who it's for and the moment it serves**
- **Decisions made** — each open question that got closed, with the chosen answer
- **Explicitly out of scope**
- **Constraints and landmines** — hard requirements, rejected alternatives and their whys, blast-radius notes from the scout
- **Open items** — anything the user deferred or answered with "use your judgment", so the license to judge is explicit and bounded

End with: "Anything wrong or missing?" — and give them a beat to correct it before anyone starts building. A wrong playback caught here costs one message; caught in code review it costs the whole implementation.

## What not to do

- Don't ask questions answerable from the code — that's what the scout was for. Asking the user something you could have grepped burns trust in the whole interview.
- Don't ask compound questions ("What's the scope, and also who's it for, and when's it due?"). One decision per question.
- Don't accept your own assumptions as answers. If you catch yourself writing "presumably they want…", that's a question, not a fact.
- Don't start implementing, planning, or writing design docs mid-interview. The grilling is the deliverable of this skill; the playback is its output. What happens after is a new task with a well-fed agent.
