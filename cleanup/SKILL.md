---
name: cleanup
description: Audit the codebase for dead code and delete it — unused functions/classes/files, unreachable branches, commented-out code, stale comments and docstrings, unused imports/exports/dependencies. Use when asked to "clean up", "remove dead code", "prune unused code", or audit a repo/directory for cruft.
---

# cleanup — find dead code, prove it's dead, delete it

Dead code removal is a verification problem, not a search problem. Anything can
*look* unused and still be loaded dynamically. The workflow is: inventory
candidates broadly, prove each one dead, delete, verify the build, commit in
reviewable chunks. **Never delete on a single grep.**

## Scope

If the user gave a path, stay in it. Otherwise audit the whole repo but skip
vendored code, generated files (`*_pb2.py`, `*.gen.ts`, lockfiles), migrations,
and anything in `.gitignore`. Tests are in scope only as *consumers* of code —
a function whose only caller is its own test is dead, and its test dies with it.

## What counts as dead

Hunt all of these categories, not just unused functions:

1. **Unused symbols** — functions, classes, methods, constants with zero
   references outside their own definition (and their own tests).
2. **Unreachable code** — branches behind always-false conditions, code after
   unconditional return/raise/throw, dead feature flags hardcoded one way,
   `if False:` / `#if 0` blocks.
3. **Commented-out code** — blocks of real code in comments. Git remembers;
   delete them. (Leave commented *examples* in docs/docstrings alone.)
4. **Stale comments & docstrings** — comments describing parameters, behavior,
   or TODOs that no longer match the code; docstrings for removed arguments;
   references to deleted functions/files. Fix or delete the comment — never
   "fix" working code to match a stale comment.
5. **Unused imports and variables** — let linters find these wholesale.
6. **Unused exports** — symbols exported from a module/package that nothing
   imports. **Caution:** in a published library, exports ARE the public API —
   flag these to the user instead of deleting.
7. **Dead files** — modules nothing imports, assets nothing references.
8. **Unused dependencies** — packages in the manifest no source file imports.

## Workflow

### 1. Inventory (tools first, grep second)

Prefer language tooling — it understands scope and shadowing where grep doesn't:

- **Python**: `ruff check --select F401,F811,F841,ERA` (unused imports/vars,
  commented-out code); `vulture <path> --min-confidence 80` if installed.
- **TypeScript/JS**: `knip` or `ts-prune` for unused exports/files/deps;
  `eslint` with `no-unused-vars`; `tsc --noUnusedLocals --noUnusedParameters`.
- **Go**: `staticcheck` (U1000), `deadcode ./...`.
- **Rust**: `cargo check` already reports `dead_code`; `cargo +nightly udeps`
  or `cargo machete` for unused deps.

If no tool is available, fan out `Explore` agents per directory to list
candidate symbols, then verify each yourself. Build one flat candidate list
with file:line before deleting anything.

### 2. Verify each candidate is actually dead

For every candidate, check ALL the ways code gets referenced without a direct
call. A candidate survives (gets dropped from the kill list) if it's reachable
via any of:

- **String/dynamic dispatch**: `getattr`, `globals()`, `importlib`,
  reflection, `window[name]`, registry/plugin patterns, DI containers. Grep for
  the symbol name as a *string*, not just as an identifier.
- **Framework magic**: route decorators, Celery task names, Django signals,
  pytest fixtures (used by name in test signatures!), CLI entry points in
  `pyproject.toml`/`package.json` `bin`/`setup.cfg`, serializer field names.
- **Config and non-code files**: YAML/JSON/TOML configs, HTML templates,
  CI workflows, Dockerfiles, SQL, docs that embed code.
- **Public API**: anything in `__init__.py` exports, `index.ts` re-exports,
  or a published package's documented surface. These need user sign-off.
- **Cross-repo use**: if this repo is a library or service consumed elsewhere,
  say so in the report and treat exported symbols as keep-by-default.

Minimum bar: `grep -rn '<name>' --include-pattern-for-non-code-files-too`
across the whole repo (not just the audited path) plus a moment of judgment
about dynamic patterns the codebase actually uses. If you can't prove it dead,
move it to a "suspicious, not deleted" list in the report.

### 3. Delete

Work in dependency order: removing a dead function often makes its private
helpers, imports, and tests dead too — re-run the relevant linter after each
batch to catch the newly-orphaned. When deleting a symbol, also delete:

- its tests (only ones that exclusively test it)
- its docstring/comment references elsewhere
- its entry in `__all__` / barrel exports
- now-unused imports it leaves behind

Delete whole blocks cleanly — no `# removed X` tombstone comments, no renaming
to `_unused`. Git history is the tombstone.

### 4. Verify the build

Run, in order, whatever the project has: formatter → linter → type checker →
full test suite → build. All must pass. If a test fails, that test was a live
reference you missed — restore the code, re-verify, and note it.

### 5. Commit & report

If the repo uses ez (`.git/ez/stack.json` exists), use `ez create` / `ez commit`
per the ez-workflow skill; otherwise plain git on a branch. Group commits by
category or subsystem so each is reviewable — one giant "remove dead code"
commit is unreviewable.

Final report:
- what was deleted, grouped by category, with line counts (`git diff --stat`)
- the "suspicious but kept" list with why each survived
- anything needing user sign-off (public API exports, cross-repo symbols)

## Hard rules

- Never delete on grep-count-zero alone — always do the dynamic-reference pass.
- Never touch generated files, vendored code, or migrations.
- Public API of a published library: flag, don't delete, unless the user
  explicitly okays it.
- Don't "improve" live code along the way. This skill deletes; refactors are a
  separate task (use /simplify).
- If the test suite doesn't exist or can't run, say so and downgrade the whole
  operation to a report-only audit unless the user accepts the risk.
