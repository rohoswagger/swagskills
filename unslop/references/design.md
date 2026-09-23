# Design and layout tells

Read this when the output is a document, deck, landing page, report, brand
one-pager, or UI, not just running prose. Text can pass every prose check and
the artifact still reads as machine-made, because the layout gives it away.

The root cause is the same in every case below. A generator reaches for a
decoration or a container when it has nothing specific to say, applies the same
treatment everywhere because variation requires a reason and it has none, and
accepts every library default because a default is never wrong enough to
notice.

## Document and deck layout

1. **Giant faded numerals as decoration.** A huge ghosted "01" or "02" behind
   the content. It carries no information the heading doesn't already carry.
   Delete it. If the reader needs sequence, a small numeral in the running head
   does the job.

2. **Big stat, tiny caption.** The "30x" in 96pt with "ROI measured by Ramp"
   whispered underneath. This is the single most recognizable slop pattern in
   marketing collateral. Use it once in a document at most, for the one number
   the whole piece exists to deliver. Everywhere else, put the number in the
   sentence where the reader meets the claim.

3. **Everything in a rounded card.** Text that would sit fine as a paragraph
   gets a gray rounded rectangle around it, radius 12, subtle border, faint drop
   shadow. Boxing signals that the content is a distinct unit of a set. If it
   isn't one, the box is lying. Default to plain text on the page, box only what
   genuinely repeats, and when you do box it, let the border do the work instead
   of a shadow.

4. **Symmetric two-column lists.** "Good fit if" beside "Typical starting
   setup", each with four colored dot bullets, each bullet a similar length.
   Real content is lopsided. One side usually has six items and the other has
   two. If both columns came out even, you padded one.

5. **Decorative texture.** Radial dot fields in the corners, dot grids, glowing
   radial orbs behind the hero, gradient mesh blobs, noise overlays, faint grid
   lines. Ask what job it does. If the answer is "fills space" or "adds visual
   interest", cut it.

6. **Alternating dark and light sections for rhythm.** Inverting every other
   page or band because the eye wants variety. Invert for meaning instead. One
   dark section because it is the turn in the argument, not because it is even
   numbered.

7. **Fill-the-template micro-tables.** A three-row key/value block on every
   page: Hosting, Interface, Sources. The template demanded three rows, so three
   rows appeared, and row three is filler. Let the count vary, or drop the block
   on pages where it has nothing to report.

8. **Bento grids.** A mosaic of unequal tiles, one wide, one tall, three small,
   arranged for visual balance rather than by what the content weighs. The
   layout was chosen first and the content poured in. Lay out by importance,
   which usually means a plain stack or a plain grid.

9. **Layout uniformity.** Every page is number, eyebrow, headline, paragraph,
   quote, stat, card, two lists. Humans vary because their content varies. A
   page with a strong quote and nothing else, next to a dense page of tables,
   reads as authored. Identical scaffolding across ten pages reads as generated.

10. **An icon for every item.** A neat little glyph beside each bullet or tile,
    chosen by keyword match. Icons earn their place when the reader scans for
    one among many. A decorative icon per bullet is noise. Checkmark bullets on
    a feature list are the worst case, since the checkmark asserts approval the
    reader hasn't given yet.

## Web and interface defaults

These are the settings nobody chose. Each one on its own is defensible. Six of
them together is a fingerprint.

11. **The default type stack.** Inter, Geist, Space Grotesk. Good typefaces,
    and the three a model reaches for when no brand exists. Pick something with
    a reason behind it, and if you keep one of these, pair it with a contrasting
    face so it reads as a choice.

12. **The default palettes.** Purple on black. One accent blue plus green for
    good numbers and red for bad. Neon on dark. Flat pastels. Rainbow-coded
    categories where the colors carry no order. Pick an actual palette, and stop
    color-coding sentiment unless the reader is comparing values.

13. **Harsh gradients.** A saturated two-stop gradient across a hero, a button,
    or heading text. Gradients work as a thin atmospheric wash. As a primary
    surface treatment they read as filler.

14. **Liquid glass and frosted panels.** Blurred translucent layers stacked over
    a busy background. Expensive to render, hard to keep legible, and applied
    almost always as decoration rather than to show depth that matters.

15. **Sparkle icons for anything AI.** The four-point sparkle has become the
    "this is the AI button" glyph. It says nothing about what the feature does.
    Name the action instead.

16. **Pure white on pure black.** `#fff` and `#000` are the two colors you get
    for free. Off-white and near-black look deliberate and are easier on the
    eye. Give the background a tint that belongs to the palette.

17. **Decorative terminal windows.** A fake macOS terminal chrome in the hero
    with three traffic-light dots, showing a command nobody will run. If the
    product is a CLI, show real output. Otherwise cut it.

18. **Colored left stripe callouts.** Every note, tip, and warning gets a 4px
    colored bar and a tinted background. Fine once. Applied to every aside, it
    turns the page into a stack of banners and the reader stops seeing them.

19. **Motion applied uniformly.** Every card lifts and scales on hover, every
    arrow slides on hover, every section fades up on scroll. Motion should mark
    the one or two interactions that matter. Applied everywhere it becomes
    wallpaper, and on a trackpad it makes the page feel unstable.

20. **Emoji as interface furniture.** In headings, in bullets, on buttons, in
    section dividers. Cut them from anything that is not conversational.

21. **Three feature cards, three pricing tiers.** The rule of three shows up in
    layout more strongly than in prose, because the grid makes it visible at a
    glance. Most products have two plans or five. Ship the real number, and let
    a row of two or four break the grid.

22. **Parallel tile construction.** Every tile reads "[Thing] that [does X]"
    with a one-line description of matched length. Vary the shape. Some tiles
    need a sentence, some need a number, some need nothing but a name.

## Copy on the page

23. **Fragment headlines.** "Ask the bot before you ask a person." "73,000
    people. One AI. Your data center." Punchy staccato triplets and verbless
    fragments are a strong tell. Write a headline that is a sentence and says
    the specific thing.

24. **Meta-label eyebrows.** "In one paragraph", "Five patterns", "What happens
    next". Sentence case doesn't rescue them. They label the section instead of
    saying anything. Either name the actual subject or drop the eyebrow.

25. **Summary sentence chains.** "Connects to your tools, lets you search across
    them, gives everyone the same answer. Anyone can use it. It runs wherever
    you need." Verb-led clauses strung in sequence, each one a feature, none with
    a subject doing work. Rewrite around who does what.

26. **Chatbot warmth in the frame.** "Thanks for the conversation." "Here is
    what other teams have built, and the numbers they reported back." Cover
    pages and intros inherit assistant voice. Cut the warmth and open on
    content.

27. **Soft generic section titles.** "Where teams start, and where they end up."
    "How most teams get started." These fit any vendor in any category. If you
    can swap in a competitor's name and the title still works, it says nothing.

28. **Second-person symptom lists.** "You want everyone to have access, not just
    the teams with budget." Sales-copy voice that no salesperson writes in an
    actual follow-up. Describe the situation in third person, or quote a real
    customer saying it.

29. **Polished-quote uniformity.** Every pull quote is the same length, trimmed
    to its cleanest clause, ellipses smoothed away. Real quotes are ragged. Keep
    the ums, the run-ons, and the qualifier the speaker actually said. If you
    must trim, mark it and don't trim all of them to the same shape.

30. **Invented social proof.** Testimonials from people who do not exist, logo
    walls of companies that are not customers, star ratings nobody gave, "used
    by 10,000 teams" with no source. Never fabricate these. Ship the section
    empty, or cut it until there is something real to put in it.

31. **No real product.** A landing page for software with no screenshot of the
    software, no recorded demo, no sample output. Placeholder art and abstract
    illustration stand in for the thing itself. If the product cannot be shown
    yet, say what it will do in concrete terms rather than illustrating around
    the gap.

32. **No friction anywhere.** Nothing in the document was hard. Nobody
    struggled, no timeline slipped, no security review took ten weeks, no
    approach got tried and abandoned. This is the deepest tell in the whole
    list, and the hardest to fake back in. Find the real difficulty and name it.
    A piece where everything went well reads as fiction, because it is.

## Absence tells

What is missing gives it away as reliably as what is there. Generated sites skip
the unglamorous parts because nothing in the prompt asked for them.

33. **No loading, empty, or error states.** Every screen is rendered at its
    happy path with populated data. Real interfaces spend real time empty,
    loading, and broken. Build the skeleton, the empty state with its first
    action, and the error with a way out.

34. **No terms, privacy policy, or contact route.** A footer with links that go
    nowhere, or no footer at all. Any site that collects an email needs a real
    privacy policy and a real way to reach a human. Their absence marks the page
    as a mockup.

35. **No edge content.** No pricing footnotes, no "what counts as a seat", no
    changelog, no status page, no support hours. The boring pages are where
    real products prove they exist.

## The test

Cover the text and look at the page. If you can tell which product it is for
from the layout alone, the design is doing work. If it could be any B2B company
in any category, the design is template, and the template is the tell.
