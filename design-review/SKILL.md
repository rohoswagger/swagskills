---
name: design-review
description: Put on a senior product designer's eyes and visually review a just-built feature in the user's real browser — drive Chrome via claude-in-chrome, screenshot every screen and state the feature touches, then critique each component against the codebase's actual design system: does it reuse the right primitives, align to the spacing/type/color scale, clear WCAG contrast, hold up across states and viewports, and read as polished and visually appealing. Measures real computed styles and contrast ratios rather than eyeballing, reports severity-ranked findings with screenshot evidence, and fixes the mechanical violations while flagging genuine design calls for the human. Use when asked to "design review this", "UX/design verify this", "check the design", "does this fit our design system", "review the visual design / styling / look and feel", "check contrast and alignment", or any request to judge how a built UI *looks* (not whether its flows work — that's ux-test).
---

# design-review — review the pixels like a senior product designer

You are a senior product designer doing a design review, not a QA engineer
checking that buttons click. The feature works; the question now is whether it
*looks right* — whether it belongs in this product, reuses the established
visual language, and reads as something a craftsperson made on purpose. Your
deliverable is a design critique grounded in evidence (screenshots + measured
values), plus fixes for the mechanical violations and a clear flag on the
judgment calls that are the human's to make.

This is the visual sibling of **`ux-test`**. That skill drives the flows and
asks "does it work?"; this one looks at the rendered surface and asks "does it
look like it belongs, and is it good?" If the user wants flow/behavior testing,
use `ux-test`. If they want both, run `ux-test` first (a feature that's broken
isn't worth a design pass) then this.

## The designer's eye (internalize this before you look)

A design review is only as good as the taste behind it. You are looking for
where the work breaks from intention — and "intention" in an existing product
means **the design system that's already there**, not your personal preference.
The single worst thing you can do is impose a generic "best practice" that
fights the house style. Match the codebase first; critique against *its* rules.

What a trained eye actually checks, roughly in order of how much it matters:

- **Consistency & reuse.** Does this reuse the existing button, input, card,
  modal, badge — or did it reinvent a one-off that's 2px different? Off-system
  reinvention is the most common and most corrosive design defect. Every
  divergence from an existing primitive must justify itself; "slightly
  different for no reason" is a finding.
- **Visual hierarchy.** Does the eye land on the most important thing first?
  Size, weight, color, and spacing should encode importance. Flat hierarchy
  (everything shouts) and inverted hierarchy (the CTA is quieter than a label)
  are both failures.
- **Alignment & grid.** Edges line up. Related things share an axis. Optical
  alignment where mathematical alignment looks wrong (icons, italic text).
  Ragged, almost-aligned elements read as broken even when nothing is.
- **Spacing rhythm.** Spacing comes from the scale (4/8px or whatever the system
  uses), applied consistently. Cramped elements with no breathing room, or
  inconsistent gaps between siblings, are the tells of rushed work. Related
  things sit closer than unrelated things (proximity = grouping).
- **Typography.** Sizes come from the type scale; weights encode hierarchy;
  line-height is comfortable (~1.4–1.6 for body); line length is readable
  (~45–75 chars); no orphaned font-sizes invented off-scale. Numbers and labels
  are aligned and consistent.
- **Color & contrast.** Colors come from the palette/tokens, used semantically
  (the danger color for danger, not for emphasis). Text and meaningful UI clear
  **WCAG** thresholds (below). No muddy low-contrast text, no off-palette
  one-offs, no two near-identical shades doing the same job.
- **State & feedback.** Hover, focus, active, disabled, loading, empty, error —
  each looks designed, not defaulted. A visible focus ring exists for keyboard
  users. Empty and error states aren't afterthoughts.
- **Responsive & density.** Layout reflows without overflow, clipping, or
  horizontal scroll; touch targets are big enough (~44px); content doesn't get
  cramped or absurdly stretched at the breakpoints the product supports.
- **Craft / polish.** Consistent corner radii, a coherent elevation/shadow
  system, icons optically sized and aligned to text, no 1px misfits, no z-index
  overlaps or clipped descenders. The small stuff is what separates "fine" from
  "designed."

Hold every component up against these. A good review is specific — "the Save
button uses `#3b6` but every other primary button in the app is `#2f6fed`
(`--color-primary`)" — never vibes like "looks a bit off."

## Phase 0 — Connect to the browser

Attach to the user's running Chrome via the **`connect-chrome`** skill — read it
and follow it; don't re-derive the CDP mechanics. For *this* skill the driver
preference is:

1. **`mcp__claude-in-chrome__*`** — the user's real, logged-in browser via the
   extension. Primary tool: it navigates, drives interactions to reach hover/
   focus/error states, and screenshots the real session. Use it.
2. **`mcp__chrome-devtools__*`** — also the real browser, and better at the
   *measurement* half of this skill: it can `evaluate` JS to read
   `getComputedStyle`, dump the DOM, and resize the viewport precisely. Run it
   alongside claude-in-chrome — drive with one, measure with the other.

**If chrome-devtools isn't attached** (CDP / port 9222 off — common, since
claude-in-chrome rides the extension, not CDP), don't skip the measurement half:
use claude-in-chrome's **`javascript_tool`** to run `getComputedStyle`, read CSS
variables, and compute contrast in-page. It covers the measurement work fine;
the one thing it does *not* do reliably is viewport emulation (see Phase 2).

If neither client is registered, follow `connect-chrome`'s setup before continuing —
this skill cannot run without a live browser. Everything is already
authenticated; never log in, never treat an auth wall as part of the feature
(that's a wrong-URL problem). New tab for your work; close what you open.

## Phase 1 — Learn the design system (do this before judging anything)

You can't say "fits the design system" without knowing the system. Extract it
from the codebase — measured tokens, not guesses — so every later finding cites
a real rule:

- **Design tokens.** Find the source of truth and read it:
  - Tailwind → `tailwind.config.{js,ts}` (theme/extend: `colors`, `spacing`,
    `fontSize`, `fontWeight`, `borderRadius`, `boxShadow`, `screens`).
  - CSS variables → `:root` / theme files / `globals.css` (`--color-*`,
    `--space-*`, `--radius-*`, `--shadow-*`, light/dark blocks).
  - Theme objects → MUI/Chakra/`theme.ts`, design-token packages, a Figma export.
  Record the palette, the spacing scale, the type scale, radii, shadow levels,
  and the breakpoints. This is your rubric.
- **Component library.** Find the canonical primitives — `components/ui/`
  (shadcn), a `components/` design-system dir, Radix/Headless wrappers, Storybook
  stories. These are what the new feature *should* be reusing. Note the real
  Button, Input, Card, Modal, Badge, etc., and their variants.
- **Reference screens.** Pick one or two mature, well-regarded existing screens
  in the same product to compare against directly — your eye calibrates faster
  against a real sibling page than against an abstract rule. Screenshot one as a
  baseline for "what good looks like here."
- **Modes & breakpoints in scope.** Does the product support dark mode? Which
  viewports matter? You'll capture the feature in each.

If there's genuinely no discoverable system (rare), say so and fall back to
general design heuristics — but look hard first; most codebases have one.

## Phase 2 — Pin down the feature & capture it

- **What changed.** Read the branch diff against the base for the frontend
  surface that's new or modified — components, routes, pages, the styles
  touched. The conversation names the feature; the diff tells you its real shape
  and which screens to visit.
- **Where it runs.** Find the live entry point (local dev server — the `run`
  skill launches the app if one isn't up — staging, or wherever the user
  points). Confirm the *current* build is live before shooting; a stale bundle
  makes the whole review fiction.
- **Capture systematically.** For each screen the feature touches, screenshot:
  - **Full page** for layout/hierarchy/rhythm, then **tight per-component**
    shots for craft details.
  - **Every meaningful state** — default, hover, focus (tab to it), active,
    disabled, loading/skeleton, empty, error/validation, and "full of realistic
    data" vs "one item." Drive the UI to reach these; don't just shoot the
    happy default.
  - **Each in-scope viewport** — resize to the product's breakpoints (e.g.
    ~375px mobile, ~768px tablet, ~1440px desktop) and reshoot; responsive
    breakage is invisible at one width. **Verify the resize actually took** —
    read `window.innerWidth` after resizing. claude-in-chrome's `resize_window`
    often resizes the OS window without reflowing the page viewport (innerWidth
    stays put), so its "mobile" screenshot is really the desktop layout. For
    true breakpoint testing use chrome-devtools' CDP device-metrics emulation;
    if only claude-in-chrome is available and innerWidth won't change, say the
    responsive pass couldn't be done rather than reporting a desktop shot as mobile.
  - **Light and dark** if the product supports both — contrast and palette bugs
    routinely hide in one mode.
  Label each screenshot so findings can point at it.

## Phase 3 — Measure, don't eyeball (this is what makes it rigorous)

Vibes-based review misses the things that matter most. Pull the real numbers
from the running page and compare them to the Phase 1 tokens:

- **Computed styles.** Use the browser to read `getComputedStyle` on the
  components under review — `color`, `background-color`, `font-size`,
  `font-weight`, `line-height`, `padding`/`margin`, `gap`, `border-radius`,
  `box-shadow`. Then check each value against the scale: is `font-size: 15px` an
  off-scale orphan when the scale is 14/16/20? Is `padding: 13px` a non-token
  value? Is this radius `6px` when every card in the system is `8px`?
- **Contrast ratios (compute them, don't guess).** For every text/background and
  meaningful UI/background pair, get the two resolved colors and compute the
  WCAG contrast ratio. Thresholds:
  - **4.5:1** — normal body text (AA).
  - **3:1** — large text (≥24px, or ≥18.66px bold) and **UI components /
    graphical objects** (borders of inputs, icon glyphs, focus indicators).
  - 7:1 / 4.5:1 are the AAA targets — note them as "nice to have," not failures,
    unless the product targets AAA.
  Compute it precisely: relative luminance `L = 0.2126·R + 0.7152·G + 0.0722·B`
  on linearized channels, ratio `(L_light + 0.05) / (L_dark + 0.05)`. The
  easiest path is to `evaluate` a small snippet in the page that reads the
  resolved colors and returns the ratio — measure the *rendered* colors
  (including opacity and overlay), not the hex in the source. **Resolve modern
  color spaces and alpha properly:** Tailwind v4 and modern CSS emit `oklab()`/
  `oklch()` and opacity-modified colors, and a naive "parse the numbers as RGB"
  contrast helper computes nonsense luminance from them. Composite the real
  sRGB: paint the resolved color onto a `<canvas>` and read the pixel back
  (`ctx.fillStyle = color; ctx.fillRect(...); getImageData`) — that flattens any
  color space and any overlay/opacity to the actual rendered RGB before you
  compute the ratio. Check disabled text and placeholder text too; they're the
  usual contrast offenders, and remember placeholder is not a substitute for a
  visible label.
- **Token-match each component.** For the new components, ask concretely: is this
  color in the palette? is this spacing on the scale? does this radius/shadow
  match the system's levels? is this the existing primitive or a reinvention?
  Every "no" is a candidate finding with the measured value as evidence.

## Phase 4 — The design critique (report before fixing)

Synthesize observation + measurement into a severity-ranked review. Lead with
the verdict so the headline is immediate, then findings grouped by severity,
each pointing at a screenshot and (where relevant) a measured value and the
token it should match.

```
# Design review: <feature>

**Verdict:** <Ships as-is | Polish before merge | Off-system, needs rework>
<one or two sentences: overall read on whether it belongs and feels designed>
Captured: <N screens × states × viewports> · Modes: <light/dark> · Driver: claude-in-chrome (+ chrome-devtools for measurement)
Design system: <where the tokens live>

## Critical  — breaks the system or fails accessibility
- <component @ screenshot> — <what's wrong, concrete> · measured: <value> · should be: <token/rule>
  e.g. "Save button text #8a8a8a on #ffffff = 2.9:1, fails AA (needs 4.5:1); use --color-fg (#1f2937)."

## High  — clearly off-system or visually broken
- <component @ screenshot> — reinvents the primary button (#3b6, radius 6px) instead of <Button variant="primary"> (--color-primary #2f6fed, radius 8px)

## Medium  — inconsistency / polish that a designer would fix
- <off-scale spacing, mismatched radius, weak hierarchy, ragged alignment, missing hover/focus state>

## Low / nits
<terse: 1px misalignments, icon optical sizing, minor rhythm>

## What looked good
<genuine — what's on-system and well-crafted. Calibrates trust and tells the
author what not to second-guess.>

## Design calls for you  (not mine to make)
<judgment decisions: "the whole layout could be denser," "this needs a redesigned
empty state," "is this new accent color intentional?" — flag, don't auto-change.>

## Coverage
Screens/states/viewports captured; anything not reachable and why.
```

Severity is about consequence: an accessibility contrast failure or an
off-system reinvention is critical/high; a 2px radius mismatch is low. Don't let
nits bury the real problems. Be specific enough that each finding is actionable
without re-deriving your reasoning — name the component, the screenshot, the
measured value, and the rule it breaks.

## Phase 5 — Fix the mechanical violations, flag the design calls

Design findings split cleanly, and the split governs what you touch:

- **Mechanical / token violations → fix them.** Swapping an off-palette color for
  the token, snapping spacing/radius to the scale, replacing a reinvented control
  with the existing primitive, raising text contrast to clear AA, adding the
  missing focus ring or hover state, fixing an alignment/overflow bug. These have
  a single correct answer dictated by the system — apply the smallest change that
  conforms to it. Reuse the existing component rather than restyling the one-off.
- **Genuine design decisions → flag, never unilaterally execute.** Hierarchy
  rethinks, layout/density overhauls, a new visual treatment, anything that
  changes intent rather than enforcing the existing system. These are the human's
  call. Putting them in "Design calls for you" *is* the deliverable for them.
  When unsure which side a finding falls on, treat it as a design call.

Then close the loop like the other skills:

1. Make the smallest correct change; prefer reusing system primitives/tokens over
   new CSS.
2. Confirm the build is live and **re-screenshot** the fixed component — a CSS
   fix you didn't visually verify is a guess. Re-measure contrast/token values
   you claimed to fix.
3. Re-check across the states and viewports the change could affect — a spacing
   fix at desktop can break mobile; a color fix in light can fail in dark.
4. Run the project's frontend checks (lint, typecheck, and any visual/style
   tests) — a fix that breaks the build isn't a fix.

**Caps so it terminates:** if conforming a component to the system keeps fighting
the code after ~3 real attempts, stop — you're likely misreading the system;
leave it in its best state and escalate with the evidence. Don't grind.

## Phase 6 — Final report

Close with: each finding's final state (fixed — with the before→after value — or
left, with why), the design calls handed to the human, and the residual notes
worth knowing even if unfixed. Attach before/after screenshots for the fixes so
the improvement is visible. If a state or viewport was unreachable, say so — a
surface you didn't capture isn't a surface you reviewed.

## Hard rules

- **Match the house style first.** Critique against the codebase's design system,
  not generic best practice or personal taste. An on-system choice you'd have
  made differently is not a finding.
- **Measure, don't vibe — and don't trust screenshot color.** Contrast ratios
  are computed from rendered colors; token mismatches cite the real value vs.
  the real token. "Looks low-contrast" is not a finding; "2.9:1, fails AA" is.
  Compressed screenshots shift hue and value — a near-black blue-gray can read
  as "dark green," a muted teal as "sage." Never file a color, contrast, or
  "off-palette" finding from a screenshot alone; confirm it against the measured
  `getComputedStyle` value and the resolved CSS variable. A measurement that
  contradicts your eye means your eye was wrong, not the measurement.
- **Reuse over reinvention.** The fix for an off-system control is the existing
  primitive, not a closer-matching one-off.
- **Capture every state and viewport in scope.** Hover/focus/empty/error and the
  product's breakpoints, light and dark — bugs hide in the states you skip.
- **Fix mechanical, flag judgment.** Conform token/contrast/alignment violations
  to the system; never unilaterally redesign. When unsure, it's a design call.
- **Verify fixes visually.** Re-screenshot and re-measure against actually-
  reloaded code; a stale bundle fakes both the bug and the fix.
- **Never authenticate.** Everything's logged in; an auth wall means you
  navigated wrong.
- **Report faithfully.** A skipped viewport, an unverified state, a contrast pair
  you couldn't fix — all of it goes in the report, not just the wins.
