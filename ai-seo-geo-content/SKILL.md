---
name: ai-seo-geo-content
description: Research, plan, draft, refresh, and QA evidence-led SEO/GEO content for any product, including best-of lists, alternatives, comparisons, use-case pages, and programmatic content clusters. Use for AI-search visibility, answer-engine citations, competitor content reverse-engineering, or scalable keyword-page production. Do not use for deceptive doorway pages, copied competitor prose, or unsupported mass publishing.
---

# AI SEO/GEO content

Create pages that answer a real buyer question, can stand alone when quoted by an answer engine, and remain honest about the product and its competitors. Adapt the workflow to the repository instead of assuming a CMS or frontmatter schema.

## Choose the operating mode

- **Single page:** research and draft one article.
- **Content cluster:** build a scored keyword matrix, approve or infer a bounded first batch, then produce differentiated pages.
- **Competitor reverse-engineering:** inventory public patterns, sources, claims, and gaps. Reuse the strategy and information architecture, never their wording or distinctive creative work.
- **Refresh:** compare an existing page with current evidence and cited winners, then update what has decayed.
- **Visibility loop:** design or operate citation, coverage, source-authority, entity, freshness, and decay monitoring. Read [visibility-loops.md](references/visibility-loops.md).

For article and cluster work, read [page-formats.md](references/page-formats.md) before outlining. For batches, also read [batch-production.md](references/batch-production.md). Use [quality-gate.md](references/quality-gate.md) for final review.

## Discover the product and publishing system

Inspect the target repository before writing:

1. Find product truth: positioning, features, pricing, platforms, integrations, proof, limitations, security claims, and customer language.
2. Read at least three nearby published pages, prioritizing the same intent and template family.
3. Find the content loader, schema, routes, categories, author rules, sitemap, structured-data generation, image conventions, and validation commands.
4. Search for an existing keyword inventory, Search Console export, analytics, citation logs, editorial calendar, and canonical rules.
5. Record unknown facts. Do not fill gaps with plausible copy.

If the repository lacks a product-truth file, derive a provisional fact sheet from first-party materials and label uncertainties. Ask only for facts that materially change the output and cannot be discovered safely.

## Research current evidence

Browse for current external facts and competitor claims. Prefer first-party product docs, pricing pages, changelogs, help centers, official repositories, and regulatory or standards sources. Use reputable third-party sources for independent testing, market context, or review evidence.

Create a lightweight evidence ledger with: claim, source URL, source type, observed date, and whether the claim is safe to state or needs qualification. Never invent prices, feature support, rankings, benchmarks, customer names, citations, or statistics. Treat snippets and AI answers as leads, not proof.

For competitor reverse-engineering, inspect search results, sitemaps, navigation, page templates, internal links, structured data, freshness signals, and the questions each page answers. Separate observed facts from inference.

## Build a content matrix

Map each proposed page to one primary intent, one audience or constraint, and one distinct decision. Common formats include:

- best X, top X, and open-source X
- best X for Y, X for Y, X by industry, and X by company size
- X alternatives, X competitors, and alternatives to X for Y
- X vs Y and X vs Y vs Z
- X by feature, integration, platform, deployment, privacy model, or workflow

Score candidates for buyer intent, product fit, sourceability, differentiation, and overlap risk. Search the existing site before approving a slug. Merge near-duplicates when their answer, comparison set, and recommendation would be substantially the same. A modifier alone does not justify a page.

Every approved page needs a differentiation brief: target question, reader, reason to exist, unique evidence, expected recommendation, sibling pages, and internal-link role.

## Draft for retrieval and buyers

Answer the title in the opening paragraph. Put a compact, quotable summary near the top. Explain the category before pitching the product. State evaluation criteria, compare expected options fairly, disclose meaningful limits, and recommend by fit rather than declaring one universal winner.

Use short paragraphs, descriptive sentence-case headings, concise tables, explicit entities, exact dates where freshness matters, and FAQ questions drawn from real query evidence when available. For comparisons, include at least one near-top decision table and one later recommendation or trade-off table. Keep table cells independently understandable.

Link important factual claims to their sources. Use the site's existing citation style. Add schema only through the repository's established mechanism. Do not add FAQ content solely to manufacture schema.

Apply `$unslop` to every final draft when available. It is required in environments that provide it. Also use a relevant copywriting or product-marketing skill when available and compatible with the product's voice. Preserve factual precision during copy edits.

## Run programmatic batches safely

When the user requests multi-agent production and delegation is available, use a coordinator-led pipeline:

1. The coordinator owns product truth, taxonomy, keyword uniqueness, evidence standards, and final integration.
2. Terra research agents audit competitors, collect primary sources, or review high-risk claims in independent shards.
3. Luna drafting agents produce pages from locked briefs and evidence packets.
4. Terra review agents check intent fit, unsupported claims, duplication, and recommendation fairness.
5. The coordinator reads every artifact, resolves conflicts, runs site checks, and performs the final `$unslop` pass.

Give each agent a non-overlapping file set and a complete brief. Cap the first batch to a size that can be reviewed in full. Do not publish, submit URLs, send outreach, or operate third-party accounts unless the user explicitly authorizes those external actions. See [batch-production.md](references/batch-production.md) for schemas and prompts.

## Validate and report

Run repository formatting, linting, content-schema, link, and build checks when practical. Confirm facts against the evidence ledger and use [quality-gate.md](references/quality-gate.md). Report files changed, content-matrix decisions, sources researched at a high level, checks run, and unresolved fact or publishing risks.
