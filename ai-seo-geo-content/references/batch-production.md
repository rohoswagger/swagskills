# Batch production

Use this workflow only when the user requests multiple pages or a programmatic system.

## Inputs

Collect or infer the product and canonical domain, product-truth sources, prohibited claims, target modifiers, competitors, markets, repository output path, metadata schema, publication state, and available query or citation data. Record `target_count`, required format families, any minimum per family, wave size, and maximum pages per normalized intent. Draft is the default publication state unless the repository or user explicitly says otherwise.

Before drafting, produce the complete manifest for review. If the user requests 20 pages, plan and process 20 approved rows in reviewable waves. Do not silently turn the requested count into a smaller batch. If quality gates reject rows, replace them with qualified candidates or report the shortfall.

## Content matrix row

Track each proposed page with these fields:

```text
id, primary_keyword, format, intent, audience, modifier, competitors,
unique_question, unique_evidence, product_fit, buyer_intent,
sourceability, overlap_risk, canonical_slug, sibling_slugs,
evidence_path, brief_path, status, owner, last_fact_check
```

Use a stable `id`. Define the normalized collision key per format. Alternatives and comparisons include every named product; feature and deployment pages include that constraint; role pages include the audience and workflow. Enforce unique canonical slugs. Keep rejected and merged ideas in the ledger so they do not return in the next run.

Score buyer intent, product fit, sourceability, and distinctness from 1 to 5. Approve only rows scoring at least 3 on every dimension. Use overlap risk as a separate 1 to 5 penalty and manually review scores of 4 or 5. Break ties by buyer intent, then product fit, then sourceability.

## Differentiation brief

Each page packet must include:

```text
Title and primary query
Reader and buying stage
Question answered in one sentence
Why this is distinct from sibling pages
Required products or options
Evaluation criteria and their order
Product position, including honest non-fit cases
Approved facts and prohibited claims
Primary sources with observed dates
Internal links and anchor purpose
Metadata and output path
```

An agent may not broaden the comparison set or add a factual claim without sourcing it.

Role-specific briefs must define the role's workflow, sensitive data, failure modes, permissions, success criteria, vocabulary, and why the recommendation differs. A role name alone is not differentiation.

## Suggested multi-agent split

- Terra research shards: one competitor family, use-case family, or source set per agent.
- Luna drafting shards: one or a few non-overlapping briefs per agent.
- Terra review shards: compare drafts against packets, sibling pages, and evidence ledgers.
- Coordinator: taxonomy, assignments, conflict resolution, integration, full diff review, and checks.

Do not have several agents edit one shared index or manifest. Let the coordinator update shared files after page drafts settle.

Use a durable artifact contract when the repository has no equivalent:

```text
research/{page_id}.json
briefs/{page_id}.md
drafts/{page_id}.md
reviews/{page_id}.json
```

Research packets contain claims, URLs, source tier, observed date, confidence, caveat, and unresolved questions. Luna drafts may use only approved product truth and their packet. Missing evidence stays visibly unresolved. Only the coordinator promotes drafts to final content paths. Retry failures by stable page ID and never regenerate completed rows accidentally. When Terra or Luna profiles are unavailable, preserve the same separation of research, drafting, and review with available agents or sequential passes.

For a GEO measurement request, sample only authorized answer engines and retain engine, model, locale, timestamp, prompt ID, raw response, named brands, and cited URLs. Answer-engine output is an observation, not proof of a product fact or of citation causality.

## Task templates

Drafting task:

```text
Use $ai-seo-geo-content for the attached locked brief.
Write only the assigned files. Follow the repository's existing schema and voice.
Use only approved evidence. Mark missing facts instead of inventing them.
Run the specified checks and report files, sources, and unresolved issues.
```

Review task:

```text
Review these drafts against their differentiation briefs, evidence packets,
existing sibling pages, and $ai-seo-geo-content quality gate. Report unsupported
claims, stale facts, copied phrasing, search-intent mismatch, unfair comparisons,
cannibalization, weak standalone passages, and broken repository conventions.
Do not rewrite files unless explicitly assigned.
```

## Batch stopping conditions

Stop expanding when the next pages lack distinct intent, reliable evidence, meaningful product fit, or enough review capacity. A large matrix is a backlog, not permission to generate or publish every row.
