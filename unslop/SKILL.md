---
name: unslop
description: Cut AI tells from anything you produce. Covers prose, document and deck layout, landing pages, and UI. Must always apply.
---

# Unslop

Remove AI patterns and add human voice. This applies to words, to the structure
of the sentences carrying them, and to the visual design of anything you build
to hold them.

Three layers give an artifact away, and fixing one does not fix the others:

- **Vocabulary.** The words. Easiest to catch, easiest to swap.
- **Structure.** The shape of sentences and paragraphs. Survives a
  find-and-replace. See [references/structures.md](references/structures.md).
- **Design.** Layout, palette, typography, and what is missing from the page.
  Applies whenever the output is a document, deck, page, or interface. See
  [references/design.md](references/design.md).

## Process

1. Scan for the patterns below.
2. Read references/structures.md and fix what survives a word-level pass.
3. If the output is a document, deck, landing page, report, or UI, read
   references/design.md and fix the layout too.
4. Rewrite. Preserve meaning, match intended tone.
5. Add soul (see next section).
6. Self-audit: "What makes this obviously AI generated?" Fix remaining tells.
7. Score (see the end of this file). Below 35 out of 50, revise again.

## Adding soul

Removing patterns is half the job. Sterile, voiceless writing is just as obvious.

- **Have opinions.** React to facts instead of neutrally listing pros and cons.
- **Vary rhythm.** Short sentences. Then longer ones that take their time. Mix it up.
- **Acknowledge complexity.** "Impressive but also kind of unsettling" beats "impressive."
- **Use "I" when it fits.** First person isn't unprofessional.
- **Let some mess in.** Perfect structure looks machine-made.
- **Be specific.** Not "this is concerning" but "there's something unsettling about agents churning away at 3am."
- **Let friction show.** Name what was hard, what got abandoned, what took
  longer than it should have. Writing where nothing went wrong reads as
  fiction. This is the tell that survives every other fix.

## Patterns to detect and fix

### Content

1. **Puffery.** "pivotal moment", "testament to", "evolving landscape", "setting the stage for", "indelible mark", "deeply rooted". Cut puffery, state what happened.
2. **Name-dropping.** Listing media outlets without context. Pick one, say what was said.
3. **Superficial -ing phrases.** "highlighting...", "ensuring...", "reflecting...", "showcasing...", "fostering...". Delete or expand with real sources.
4. **Promotional language.** "nestled", "vibrant", "breathtaking", "groundbreaking", "renowned", "stunning", "must-visit". Use neutral descriptions.
5. **Vague attributions.** "Experts believe", "Industry reports suggest", "Some critics argue". Name the source or delete.
6. **Formulaic challenges.** "Despite challenges... continues to thrive." Replace with specific facts.

### Language

7. **AI vocabulary.** Additionally, crucial, delve, enduring, enhance, fostering, garner, interplay, intricate, landscape (abstract), pivotal, showcase, tapestry (abstract), testament, underscore, vibrant. Replace with plain words.
8. **Fancy ways to say "is".** "serves as", "stands as", "boasts", "features". Just say "is" or "has".
9. **Binary contrasts.** "Not just X, but Y." "It's not X, it's Y." "The question isn't X. It's Y." "X isn't the problem. Y is." A whole family, not one phrase. State Y directly and drop the negation. Full list in references/structures.md.
10. **Rule of three.** Forcing ideas into groups of three. Use the natural number.
11. **Synonym cycling.** Protagonist, main character, central figure, hero all in one paragraph. Pick one, repeat it.
12. **False ranges.** "from X to Y" where X and Y aren't on a meaningful scale. List topics directly.

### Structure

These survive a vocabulary pass, because the shape is the tell. References/structures.md has the full tables.

13. **Throat-clearing openers.** "Here's the thing:", "The truth is,", "It turns out", "At its core", "When it comes to". Cut and state the point.
14. **Emphasis crutches.** "Full stop.", "Let that sink in.", "Make no mistake", "It's worth noting". Delete on sight.
15. **Negative listing.** "Not a framework. Not a library. A way of thinking." State the last item, skip the runway.
16. **Dramatic fragmentation.** "That's it. That's the whole idea." "X. And Y. And Z." Write complete sentences. A fragment lands when it is rare.
17. **Rhetorical setups.** "What if we reframed this?", "Here's what I mean:", "Think about it:", "And that's okay." Make the point.
18. **False agency.** "The complaint becomes a fix." "The decision emerges." "The data tells us." Inanimate things don't act. Name the human, or use "you".
19. **Narrator from a distance.** "Nobody designed this." "People tend to." Put the reader in the room instead.
20. **Vague declaratives.** "The implications are significant." "The reasons are structural." Name the implication or cut the sentence.
21. **Telling instead of showing.** "This is genuinely hard." If it were, the detail would show it. Give the detail.
22. **Meta-commentary.** "In this section we'll", "Let me walk you through", "The rest of this post explains". Delete. Let the piece move.
23. **Wh- sentence openers.** "What makes this hard is" becomes "The constraint is", then name it. Same for When, Which, Why, How as sentence starts.
24. **Lazy extremes.** "Every", "always", "never", "nobody". Use the real scope: "every team I asked", "three of the five".

### Style

25. **Em dash overuse.** Avoid em dashes entirely. Use periods or commas only (no parentheses, no en dashes, no hyphen-as-dash substitutes). Em dashes are an AI tell, and reaching for parentheses instead just trades one tell for another. If a thought needs separation, end the sentence or use a comma.
26. **Colon overuse.** Colons are fine before a list or example. Not as mid-sentence connectors. "If you're coming from traditional automation: instead of registering event handlers, you describe conditions" adds nothing with the colon. Rewrite to let the point stand on its own without comparison framing. "Describing when the scheduler should fire works best as plain English." Same meaning, no crutch punctuation.
27. **Boldface overuse.** Don't bold every proper noun or acronym.
28. **Inline-header lists.** The tell is a bold label and colon that restates the line: "**Performance:** Performance improved...". Convert those to prose. A bold lead-in that ends in a period, names the item, and is followed by genuinely new detail ("**Schema in TypeScript.** Tables live in one file.") is fine, not a tell.
29. **Title case headings.** Use sentence case.
30. **Decorative emojis.** Remove from headings and bullets.
31. **Curly quotes.** Replace with straight quotes.

### Communication artifacts

32. **Chatbot phrases.** "I hope this helps!", "Let me know if...", "Of course!", "Certainly!", "Found the smoking gun!" Remove.
33. **Cutoff disclaimers.** "While specific details are limited..." Find sources or remove.
34. **Sycophantic tone.** "Great question! You're absolutely right!" Respond directly.

### Filler

35. **Filler phrases.** "In order to" becomes "To". "Due to the fact that" becomes "Because". "It is important to note that" gets deleted.
36. **Excessive hedging.** "could potentially possibly be argued that it might" becomes "may".
37. **Generic conclusions.** "The future looks bright." State specific plans or facts.

### Jargon

38. **Abstract metaphor nouns.** Substrate, wedge, vector, locus, vantage, nexus, primitive (as noun), harness (as metaphor), surface (as in "API surface"), bedrock, scaffolding (as metaphor), modality, paradigm, gold-plating, ratchet (as metaphor), evacuate (for moving code), endgame, north star, flywheel. These read as technical but usually have a plainer concrete word. "Substrate" becomes "base". "Wedge in" becomes "add". "Vector" becomes "way" or "method". "Gold-plating" becomes "more than the job needs". "Ratchet" becomes the mechanism's real name or "a limit that only tightens". "Evacuate" becomes "move out". "Endgame" becomes "the last phase". Pick the concrete word.
39. **Business jargon.** "navigate" becomes "handle", "unpack" becomes "explain", "lean into" becomes "commit to", "deep dive" becomes "analysis", "circle back" becomes "return to", "moving forward" becomes "next". Table in references/structures.md.

### Plain speech

40. **Say what it does, not how it feels.** "the database stays close at hand", "SQL you can read", "types that follow your schema" name a feeling. The fix names the mechanism or a number: "`.toSQL()` returns the exact string sent to the database", "a column rename fails the build". Ask what the sentence tells the reader to do or know, then write that. If you can't restate it as a concrete instruction, fact, or number, cut it. One more check: if the sentence could appear unchanged in another project's docs, it says nothing about this one. Cut it.
41. **Shorten or split dense sentences.** If the reader has to backtrack to parse a sentence, break it in two or drop clauses. One idea per sentence.
42. **Active voice.** Prefer it. Catch "is/are/was/were + past participle" and name the actor: "queries are validated" becomes "the compiler validates queries", "the file is parsed by the loader" becomes "the loader parses the file". Passive is fine only when the actor is unknown or genuinely doesn't matter.
43. **Cut adverbs, or use a stronger verb.** "runs quickly" becomes "is fast" or the number. "significantly improves" becomes the measured delta. An adverb propping up a weak verb means the verb is wrong.
44. **Prefer the plain word.** "utilize" becomes "use", "leverage" becomes "use", "facilitate" becomes "help", "numerous" becomes "many", "in the event that" becomes "if". The fancier synonym is rarely clearer.

### Product mockups and interface copy

45. **No generic placeholder companies.** Never use "Acme" or stock fictional company names in authored mockups or copy. Use the product's own workspace name or a concrete task or team label. Do not imply a real organization is a customer without evidence.
46. **No mockup disclaimers as decoration.** Do not add "Illustrative interfaces and example content" or similar boilerplate beneath product UI. Keep necessary qualifications next to actual factual or quantitative claims; do not invent claims.
47. **Let the interface explain itself.** When a mockup already shows the feature, omit per-interface marketing descriptions and redundant captions. Keep useful navigation labels and concrete UI content.
48. **Replace AI-sounding filler with task content.** Avoid phrases such as "Ready for the next chapter," "go deeper," "one tab closer," and "Grounded in your company's knowledge." Show the actual task, source, status, or next action instead. If the phrase adds no information, delete it.

### Documents, decks, landing pages, and UI

49. **Check the design, not just the copy.** Whenever the output is a document, deck, landing page, report, or interface, read [references/design.md](references/design.md) and run its list. Text that passes every rule above still reads as machine-made if the page around it is a template. The short version: no giant ghosted numerals, no big-stat-tiny-caption blocks, no boxing text that isn't a repeating unit, no decorative dot grids or radial orbs, no default type stack (Inter, Geist, Space Grotesk) or default palette (purple on black, one accent blue plus green for good), no bento grid chosen before the content, no three-cards-three-tiers grid when the real number is two or five, no sparkle icon standing in for a feature name, no fabricated testimonials or logo walls, and no landing page for software that never shows the software.
50. **Ship the unglamorous parts.** Loading, empty, and error states. A real privacy policy and terms. A route to a human. Their absence marks the artifact as a mockup more reliably than any styling choice.

## Quick checks

Run these before delivering. Each one is fast and catches a different layer.

- Three sentences in a row the same length? Break one.
- Paragraph ends on a punchy one-liner? Vary it.
- Any em dash? Remove it.
- Any adverb propping up a weak verb? Use the stronger verb.
- A sentence starting with What, When, Why, or How? Restructure it.
- An inanimate thing doing a human verb? Name the person.
- A negation setting up a reveal? State the reveal.
- A sentence claiming something is important without naming it? Cut or replace.
- Would this sentence survive unchanged in a competitor's document? Cut it.
- Anything in this piece that was hard? If not, you left out the truth.
- Building a page? Cover the text and look at it. Could it be any company in
  any category? Then the layout is the tell.

## Scoring

Rate 1 to 10 on each, and revise below 35 out of 50.

| Dimension | Question |
|-----------|----------|
| Directness | Statements, or announcements of statements? |
| Rhythm | Varied, or metronomic? |
| Trust | Respects the reader's intelligence? |
| Authenticity | Sounds like a person who was there? |
| Density | Anything cuttable? |

For documents and interfaces, score design separately on the same scale: does
the layout carry information, or fill space?

## Credits

The structural patterns in references/structures.md are adapted from
[stop-slop](https://github.com/hardikpandya/stop-slop) by Hardik Pandya, MIT
licensed.
