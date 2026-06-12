---
name: bigbrain
description: Orchestrate hard thinking on a powerful model (Fable/Opus) while shelling out implementation to smaller models (Sonnet). Use when asked to "bigbrain" a task, or for any large piece of work where planning/exploration deserves the big model but the edits themselves are well-specified enough for a cheaper one.
---

# bigbrain — think big, implement small

The session's main loop (you, presumably Fable or Opus) is the expensive resource.
Spend it on judgment: exploration, architecture, planning, task decomposition, and
review. Spend Sonnet on execution: making the edits you already decided on.

## The split

**Big model (inline, this session):**
- Exploring the codebase and building the mental model (fan out `Explore` agents for breadth, but synthesize inline)
- Writing the plan: what changes, where, why, in what order
- Decomposing the plan into self-contained implementation tasks
- Reviewing every diff a subagent produces
- All architectural and ambiguity-resolving decisions

**Small model (Agent tool, `model: "sonnet"`):**
- Executing one well-specified implementation task at a time
- Running the verification command for its own task

Never delegate a decision. If a task requires judgment you haven't already
exercised, the spec isn't done — finish thinking before dispatching.

## Workflow

### 1. Think (inline)
Explore until you could write the diff yourself. Write the plan. For multi-step
work, decompose into tasks that are:
- **Independent** where possible (so they can run in parallel)
- **Self-contained**: a subagent has no conversation context — everything it
  needs goes in the prompt
- **Decision-free**: the approach is fully specified; only mechanical judgment remains

### 2. Dispatch (Agent tool, sonnet)
Spawn one agent per task with `model: "sonnet"`. Independent tasks go in a single
message so they run concurrently; use `isolation: "worktree"` only if parallel
agents would mutate the same files.

Every task prompt follows this template:

```
## Context
<what this codebase/area is, what the overall change is, why>

## Task
<the exact change: files, functions, approach — be prescriptive, not aspirational>

## Constraints
<project rules that apply: error handling patterns, import style, typing, etc.>

## Verification
Run: <exact command>. It must pass before you finish.

## Report
Return: files changed, a summary of the diff, verification output. If anything
in the spec is ambiguous or turns out to be wrong, STOP and report the conflict
instead of improvising.
```

### 3. Review (inline)
Read every diff yourself (`git diff`) — do not trust the subagent's summary.
Re-run verification yourself. For fixes, use `SendMessage` to the same agent
(it keeps its context) rather than spawning a fresh one. If a subagent reports
ambiguity, decide inline and send the decision back.

### 4. Integrate (inline)
Final pass with the big model: cross-task consistency, the overall diff reads
like one author wrote it, full test suite, commit.

## Scale variants

- **1–2 tasks**: plain Agent calls, review between them.
- **Many independent tasks** (migrations, sweeps): use the Workflow tool with
  `agent(prompt, {model: 'sonnet'})` per item, and a big-model review stage —
  but only if the user has opted into multi-agent orchestration.
- **Trivial mechanical task, no real thinking**: skip this skill; just do it.

## Anti-patterns

- Dispatching before the plan is finished ("the agent will figure it out" — it won't, well)
- Vague specs that outsource design to Sonnet
- Accepting "done, tests pass" without reading the diff
- Respawning a fresh agent for a follow-up fix instead of SendMessage
- Using this for small tasks where orchestration overhead exceeds the work
