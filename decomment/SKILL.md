---
name: decomment
description: Ruthlessly strip comments from the current diff — delete nearly all of them, keeping only machine-read directives and the rare comment encoding a gotcha that would make a competent reader write a bug without it. Use when asked to "clean up comments", "decomment the diff", "remove noisy comments", "strip the comments", or before opening a PR. Only touches lines the diff added or modified; never sweeps the whole repo.
---

# decomment — delete by default; a comment must earn its place

We should rarely need code comments at all. Good code says what it does; the
reader can see that a loop loops and a constant is a constant, and the names
carry the intent. The right number of comments in a typical diff is close to
zero. A comment earns its place only when the code genuinely *can't* show
something and getting it wrong is costly — a workaround and why it exists
(ideally a link), an ordering constraint, a subtle invariant, a trap that makes
the obvious approach a bug. Everything else goes.

So the default here is **delete**. Don't ask "is this comment harmful?" — ask
"would a competent reader write a bug, or undo a deliberate choice, without
this?" If the answer isn't a clear yes, cut it. This runs **on the diff only**:
pre-existing comments are someone else's call and out of scope.

**Multi-line comments are the most suspect of all.** A paragraph above a
function is almost never carrying non-recoverable technical context — it's
narration, design exposition, or reassurance. Treat any block comment as
delete-on-sight unless every line of it clears the keep bar; in practice that
means cut the whole block, or reduce it to the single line that actually
matters.

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
   the argument is genuinely non-local and its absence would cause a bug (see
   keep: "a gotcha that turns into a bug without it").
9. **Section banners** added in the diff (`# ===== helpers =====`).
10. **Docstrings that only restate the signature** — `"""Gets the user.
    Args: user_id: the user id."""` — *unless* lint or project convention
    requires a docstring there; then reduce it to one honest line.
11. **Placeholder TODOs** — `# TODO: improve this`. A TODO survives only if it
    names a concrete condition, ticket, or follow-up.

### Keep (rare — and most diffs will have nothing here)

- **Machine-read directives** — `# noqa`, `# type: ignore`, `// eslint-disable`,
  `#[allow(...)]`, `@ts-expect-error`, pragmas, coverage markers, and
  license/copyright headers the repo mandates. These aren't comments for humans;
  they change tooling behavior. Keep verbatim.
- **A gotcha that turns into a bug without it** — and *only* that. The bar is
  strict: removing the comment would cause a competent engineer to write a bug,
  undo a deliberate workaround, or violate a constraint they had no way to see
  from the code. Examples that clear it: a workaround with a link to the issue
  that forced it, "must run before X or Y races," "the obvious approach
  deadlocks on input Z," a non-local invariant another file depends on. What
  does *not* clear it: rationale that's merely nice to know, design exposition,
  reassurance that something is correct/safe, or anything a reader recovers by
  reading the names and the adjacent code. When it clears the bar, keep only the
  one sentence that does — not the surrounding paragraph.

Docstrings, JSDoc, and rustdoc get **no special protection**. Delete them like
any other comment when the signature and names already say what they say —
including on public functions. Keep one only when a linter, doc generator, or an
enforced project convention *requires* it; then reduce it to a single honest
line, never a multi-line block.

Note what's gone: "it's a public API," "it might help someone," and "match the
surrounding comment density" are *not* keep reasons. Be aggressive even in a
heavily commented file — neighbors having comments says nothing about whether
this one carries non-recoverable technical information.

When unsure, **delete** — no hedging. The single exception: a comment that
plausibly encodes a real gotcha or workaround you genuinely cannot confirm or
refute from the code in front of you. There, keep it and flag it in the report.
That is the only case where uncertainty favors keeping; everything else, cut.

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
