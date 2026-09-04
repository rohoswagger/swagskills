# AI visibility loops

These loops measure where the product appears in answer engines and turn gaps into research or editorial work. Engine access, automated querying, scraping, account use, publishing, outreach, and messaging must follow provider terms and require the user's authorization when they mutate external systems.

## Durable data model

Append observations instead of overwriting history. Store at least: date and time, locale, prompt ID and text, engine and model, run number, brands mentioned, cited URLs, mention position, response snapshot reference, and collection status. Keep prompts versioned.

Repeated samples reduce noise but do not make engines deterministic. Report sample count and avoid treating small changes as trends.

## Core loops

1. **Citation tracking:** run the prompt set repeatedly across authorized engines; compute mention share, citation share, position, and change over time.
2. **Prompt coverage:** output high-intent questions where the product was absent and which products appeared instead.
3. **Competitor sources:** aggregate citations from answers that named a competitor but not the product. Rank pages and domains by observed influence.
4. **Answer gaps:** find buyer questions answered vaguely or without evidence. Turn them into source-backed briefs.
5. **llms.txt and discovery:** generate only from canonical, useful pages. Treat `llms.txt` as optional discovery help, not a ranking guarantee.
6. **Entity accuracy:** compare engine statements about category, audience, price, competitors, and company facts with approved truth.
7. **Source authority:** group observed citations by domain and section, then identify relevant pages and whether the brand is represented accurately.
8. **Freshness alerts:** detect sustained wins that disappear, new competitors, or owned URLs that stop receiving citations.
9. **Content decay:** compare the slipped page with newly cited sources. Propose evidence-backed updates and never invent a proprietary statistic.
10. **Daily reporting:** record coverage, mention share, citation share, wins, losses, sample size, and concrete next actions.
11. **Distribution:** adapt approved source material for relevant platforms only when each version serves that platform and the user authorizes publishing. Do not spin doorway content or fake community participation.

## Interpretation guardrails

Answer-engine outputs vary by model, session, locale, retrieval state, and time. Keep raw samples, show denominators, and distinguish correlation from causation. A cited domain may influence an answer, but the citation alone does not prove it caused the product mention.
