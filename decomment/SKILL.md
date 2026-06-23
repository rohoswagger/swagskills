---
name: decomment
description: Aggressively strip comments from the current diff — remove most comments outright, keeping only the few that encode non-obvious technical context (workarounds, hard-won gotchas, constraints) a competent reader couldn't recover from the code itself. Use when asked to "clean up comments", "decomment the diff", "remove noisy comments", "strip the comments", or before opening a PR. Only touches lines the diff added or modified; never sweeps the whole repo.
---

# decomment — delete by default; a comment must earn its place

Most comments are noise. Good code says what it does; the reader can see that a
loop loops and a constant is a constant. A comment earns its place only when it
encodes something the code genuinely *can't* show — a non-obvious technical
rationale, a workaround with the reason it exists, an ordering constraint, a
trap that will bite the next person. Everything else goes.

So the default here is **delete**. Don't ask "is this comment harmful?" — ask
"would a competent reader lose real, non-recoverable information if this
vanished?" If the answer isn't a clear yes, cut it. This runs **on the diff
only**: pre-existing comments are someone else's call and out of scope.

## Scope: what "the diff" means

1. If there are uncommitted changes (`git status` not clean), the diff is
   `git diff HEAD` (staged + unstaged).
2. Otherwise it's the branch diff against the base:
   `git diff $(git merge-base HEAD <base>)...HEAD`. Resolve `<base>` from the
   environment if available (e.g. `sc worktree status --json` → `target_branch`
   under Superconductor), else the repo's default branch.
3. Only comment lines that appear as **added lines** (`+`) in that diff are
   candidates. A comment that merely moved (deleted and re-added unchanged
   elsewhere) is pre-existing — leave it.

If the user gave a narrower path, intersect with it.

## Delete vs keep

The keep list is short and the delete list is "almost everything else." When a
comment doesn't clearly match a keep category, it goes.

### Delete (the default)

1. **Code narration** — restates what the adjacent line does:
   `# increment counter`, `// loop over users`, `# call the helper`.
2. **Change narration** — talks about the edit, not the code: `# Added to fix
   the race`, `// Updated to use the new API`, `# Now we also handle null`,
   `# This change ensures...`. The commit message is where that belongs.
3. **Tombstones** — `# removed X`, `// previously this did Y`, `# moved to
   utils.py`. When a line of code is removed, no comment marks its grave; git
   history is the tombstone.
4. **Commented-out code** added in this diff. (In pre-existing lines it's out
   of scope here — that's the `cleanup` skill.)
5. **Restated-intent comments** — comments that paraphrase the code one level
   up: `# validate the input` over a validation call, `# build the request`,
   `# handle the error`. The function/variable names already say this.
6. **Labels on constants and config** — `# max retries`, `# timeout in seconds`
   above `MAX_RETRIES = 5` / `TIMEOUT_SECONDS = 30`. A well-named constant needs
   no comment; if it isn't well-named, rename it (note it in the report) rather
   than annotate it.
7. **Comments on obvious logic** — anything explaining a step a competent reader
   follows at a glance: early returns, guard clauses, simple mapping/filtering,
   standard idioms.
8. **Reviewer-directed justification** — `# this is safe because the lock is
   held` when the lock acquisition is right there and obvious. Only survives if
   the argument is genuinely non-local (see keep #1).
9. **Section banners** added in the diff (`# ===== helpers =====`).
10. **Docstrings that only restate the signature** — `"""Gets the user.
    Args: user_id: the user id."""` — *unless* lint or project convention
    requires a docstring there; then reduce it to one honest line.
11. **Placeholder TODOs** — `# TODO: improve this`. A TODO survives only if it
    names a concrete condition, ticket, or follow-up.

### Keep (the short list)

- **Non-obvious technical context** — the reason this skill exists. A workaround
  and *why* it's needed (ideally a link), an ordering constraint ("must run
  before X because Y"), a subtle invariant, an off-by-one or floating-point
  gotcha, a performance reason for an unusual approach, "the obvious way
  deadlocks / breaks on input Z." The test: a sharp engineer reading the code
  would be surprised or get it wrong without this. If yes, keep; if it merely
  restates or reassures, delete.
- **Lint/tooling directives**: `# noqa`, `# type: ignore`, `// eslint-disable`,
  `#[allow(...)]`, `@ts-expect-error`, pragmas, coverage markers.
- **Public API doc comments** (docstrings, JSDoc, rustdoc) — trim padding if
  bloated, but a documented public surface stays documented.
- **License/copyright headers** and file-level boilerplate the repo mandates.

Note what's gone: "match the surrounding comment density" is *not* a keep
reason. Be aggressive even in a heavily commented file — the bar is whether the
comment carries non-recoverable technical information, not whether its neighbors
have comments too.

When unsure, lean delete. The one exception: if a comment plausibly encodes a
real gotcha or workaround you can't confirm from the code in front of you, keep
it and flag it in the report — that specific case is where a wrong deletion is
costly. General "it might help someone" is not that case; cut it.

## Workflow

1. **Collect candidates.** Walk `git diff` output; for each file, extract added
   lines that are comments or docstrings (respect the language's syntax —
   strings that look like comments are not comments). Read enough surrounding
   code per candidate to judge it against the lists above; never classify from
   the diff hunk alone.
2. **Edit.** Remove the comment line(s) cleanly — including a now-empty line
   left behind, but preserving the file's blank-line conventions. For
   reduce-don't-delete cases (required docstrings), rewrite minimally.
3. **Verify.** The diff must still build: run formatter → linter on the touched
   files (some linters require docstrings — failures here mean restore/reduce).
   Run the test suite only if docstring removal could affect it (doctests).
4. **Report.** Per file: comments removed (count + a few representative
   examples), comments kept-but-borderline with one line on why. No commit
   unless the user asked — this usually runs on an unfinished branch.

## Hard rules

- Never modify a line the diff didn't add or change.
- Never delete a lint directive, even one that looks unnecessary — that's a
  separate, verifiable change.
- Never "improve" code while in there. Comments only; refactors are /simplify,
  dead code is /cleanup.
- Don't rewrite kept comments to your own style — the author's voice stays.
