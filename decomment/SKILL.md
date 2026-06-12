---
name: decomment
description: Strip low-value comments from the current diff — change-narration, restating-the-code comments, tombstones, commented-out code, and AI-style explainers added in this branch. Use when asked to "clean up comments", "decomment the diff", "remove noisy comments", or before opening a PR. Only touches lines the diff added or modified; never sweeps the whole repo.
---

# decomment — delete comments that talk to the reviewer, keep ones that talk to the next reader

A good comment states a constraint the code itself can't show. Everything else —
narrating what the next line does, explaining why a change is correct, marking
where something used to be — is noise the moment the PR merges. This skill
removes that noise **from the diff only**: pre-existing comments are someone
else's call and out of scope.

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

### Delete

1. **Code narration** — restates what the adjacent line obviously does:
   `# increment counter`, `// loop over users`, `# call the helper`.
2. **Change narration** — talks about the edit, not the code: `# Added to fix
   the race`, `// Updated to use the new API`, `# Now we also handle null`,
   `# This change ensures...`. The commit message is where that belongs.
3. **Tombstones** — `# removed X`, `// previously this did Y`, `# moved to
   utils.py`. Git history is the tombstone.
4. **Commented-out code** added in this diff. (In pre-existing lines it's out
   of scope here — that's the `cleanup` skill.)
5. **Reviewer-directed justification** — `# this is safe because the lock is
   held` *when the lock acquisition is two lines above and obvious*. If the
   safety argument is genuinely non-local, it's a keeper (see below).
6. **Redundant section banners** added in the diff (`# ===== helpers =====`)
   in codebases that don't use them elsewhere.
7. **Docstrings that only restate the signature** — `"""Gets the user.
   Args: user_id: the user id."""` — *unless* lint or the project's convention
   requires a docstring there; then reduce it to one honest line instead.
8. **Placeholder TODOs with no content** — `# TODO: improve this`. A TODO
   survives only if it names a concrete condition, ticket, or follow-up.

### Keep (never touch)

- **Why-comments and constraints**: invariants, ordering requirements,
  workarounds with the bug link, "must run before X because Y", off-by-one
  explanations, performance rationale.
- **Lint/tooling directives**: `# noqa`, `# type: ignore`, `// eslint-disable`,
  `#[allow(...)]`, `@ts-expect-error`, pragmas, coverage markers.
- **Public API doc comments** (docstrings, JSDoc, rustdoc) — trim padding if
  bloated, but a documented public surface stays documented.
- **License/copyright headers** and file-level boilerplate the repo mandates.
- **Anything matching the file's existing comment density and style.** The bar
  is the surrounding code: in a heavily commented codebase, lean toward
  keeping; in a sparse one, lean toward deleting.

When genuinely unsure whether a comment carries non-obvious information, keep
it and list it in the report — deleting a load-bearing comment is worse than
leaving a mediocre one.

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
