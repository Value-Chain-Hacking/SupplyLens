# SupplyLens Implementation Plan

**Goal:** Build 7 autonomous n8n pipelines that map supply chains into Neo4j using EDRM forensic methodology and adversarial LLM reasoning.

**Architecture:** Seed company → web discovery → prosecution/defense/judge validation → Neo4j ingest → recursive tier expansion → enrichment → weekly report. Every inferred link carries a confidence score. Uncertain links are flagged, not discarded.

**Affected infrastructure:** Neo4j CT114 (10.0.1.114), PostgreSQL CT100, n8n CT104, LiteLLM CT205, SearXNG CT105, Browserless CT400, CrewAI CT308, Graphiti CT124.

---

## Status flow

```
seed_queued → discovering → challenging → ingested → expanding → enriched → reported
```

## Task list

### TASK 0: PostgreSQL schema

**Files:**
- Create: `sql/01_schema.sql`
- Create: `sql/02_seed_config.sql`

- [ ] Create `supply_chain` database + user
- [ ] Tables: `companies`, `claims`, `pipeline_config`, `expand_queue`, `audit_log`
- [ ] Indexes: `claims(confidence)`, `claims(written_to_graph)`, `expand_queue(status)`
- [ ] Seed config: Neo4j URI, LiteLLM base/key/model, SearXNG base, Browserless URL, confidence threshold (0.60), max tier depth (3)

---

### TASK 1: Neo4j schema init

**Files:**
- Create: `sql/03_neo4j_constraints.cypher`

- [ ] Constraints: `UNIQUE (Company.id)`, `UNIQUE (Product.id)`, etc.
- [ ] Indexes on `Company.name`, `Company.country`, `Risk.type`
- [ ] Run via cypher-shell on CT114

---

### TASK 2: Workflow 01 — Seed

**Files:**
- Create: `n8n/01-seed.json`

- [ ] Manual trigger: accepts `{company, country, product?}`
- [ ] Check if company already exists in Neo4j (skip if exists)
- [ ] Write root `:Company` node with `confidence: 1.0` (seed = known)
- [ ] Insert into `expand_queue` with `tier: 0, status: queued`
- [ ] Trigger 02-discover

---

### TASK 3: Workflow 02 — Discover

**Files:**
- Create: `n8n/02-discover.json`
- Create: `prompts/02-extract-claims.md`

- [ ] Poll `expand_queue WHERE status='queued'` every 15min + direct trigger
- [ ] For each queued company: run 3 SearXNG searches:
  - `"{company}" supplier manufacturer`
  - `"{company}" supply chain partners sourcing`
  - `"{company}" annual report supplier list`
- [ ] Fetch top 3 result pages via Browserless (text extraction)
- [ ] LLM call: extract structured claims from raw text → `[{subject, predicate, object, source_url, raw_excerpt}]`
- [ ] Insert raw claims into PostgreSQL `claims` table with `validation_status: pending`
- [ ] Trigger 03-challenge for each claim batch

---

### TASK 4: Workflow 03 — Challenge (Adversarial Reasoning)

**Files:**
- Create: `n8n/03-challenge.json`
- Create: `prompts/03-prosecutor.md`
- Create: `prompts/03-defender.md`
- Create: `prompts/03-judge.md`

- [ ] Poll `claims WHERE validation_status='pending'` every 10min + direct trigger
- [ ] For each pending claim — 3 sequential LLM calls:
  1. **Prosecutor**: "Given this evidence, argue the claim is TRUE. List supporting points."
  2. **Defender**: "Given this evidence, argue the claim is FALSE. List counter-points."
  3. **Judge**: "Given prosecution and defense, assign confidence 0.0–1.0 and verdict: ACCEPTED / REJECTED / NEEDS_REVIEW"
- [ ] Parse judge response → update claim: `{confidence, contested, prosecution, defense, validation_status}`
- [ ] Claims with `confidence >= threshold` → `validation_status: accepted`
- [ ] Trigger 04-ingest

---

### TASK 5: Workflow 04 — Ingest

**Files:**
- Create: `n8n/04-ingest.json`

- [ ] Poll `claims WHERE validation_status='accepted' AND written_to_graph=false` + direct trigger
- [ ] For each accepted claim:
  - MERGE source node in Neo4j (upsert by name + country)
  - MERGE target node
  - CREATE/MERGE relationship with `{confidence, source, verified_date}`
- [ ] Mark `written_to_graph=true` in PostgreSQL
- [ ] If new company node added → insert into `expand_queue` with `tier: parent_tier + 1`
- [ ] Stop expansion at `max_tier_depth` (from pipeline_config)
- [ ] Trigger 05-expand if new companies queued

---

### TASK 6: Workflow 05 — Expand

**Files:**
- Create: `n8n/05-expand.json`

- [ ] Poll `expand_queue WHERE status='queued' AND tier <= max_depth` every 15min + direct trigger
- [ ] Mark batch as `status: in_progress`
- [ ] For each company in batch: trigger 02-discover (recursive)
- [ ] Self-healing: reset `in_progress` items older than 2h back to `queued`

---

### TASK 7: Workflow 06 — Enrich

**Files:**
- Create: `n8n/06-enrich.json`

- [ ] Daily cron on all companies with `last_enriched IS NULL OR last_enriched < NOW() - INTERVAL '7 days'`
- [ ] Per company:
  - News search: `"{company}" sanctions OR recall OR fine OR controversy` via SearXNG
  - OFAC SDN check: search `"{company}" site:ofac.treas.gov` (free, no API needed)
  - OpenSupplyHub lookup: `GET https://opensupplyhub.org/api/facilities/?name={company}`
  - Certifications: `"{company}" ISO OR CE OR FSC OR SA8000 certification`
- [ ] LLM extracts: risk flags, certifications, ESG scores from results
- [ ] Update Neo4j node properties + add Risk/Cert nodes if found
- [ ] Update `last_enriched` timestamp

---

### TASK 8: Workflow 07 — Report

**Files:**
- Create: `n8n/07-report.json`

- [ ] Weekly cron Sunday 08:00 + manual trigger
- [ ] Neo4j queries:
  - Total nodes per type
  - Top 10 suppliers by connection count
  - Companies with confidence < 0.6 (uncertain)
  - Companies with Risk nodes (flagged)
  - Tier depth distribution
- [ ] Build self-contained HTML report + markdown summary
- [ ] Push to Gitea `supplylens-output/reports/YYYY-MM-DD.html`

---

## Confidence thresholds

| Score | Label | Action |
|-------|-------|--------|
| ≥ 0.80 | HIGH | Write to graph, green node |
| 0.60–0.79 | MEDIUM | Write to graph, yellow node |
| 0.40–0.59 | LOW | Flag for human review, don't write |
| < 0.40 | REJECTED | Store in claims table only, red flag |

## Questions pending (ask Chris before building)

See bottom of this document.

---

## Open questions

These must be answered before starting implementation:

**Q1 — Graph DB**: BCM doc specifies PostgreSQL + Apache AGE. We already have Neo4j CT114 running and used by other services. Use Neo4j (faster to start) or rebuild with AGE (matches BCM)?

**Q2 — First seed company**: What company or product kicks off the first real supply chain map? Is "knopenkoning" a specific Dutch company (buttons/fasteners)? Or is it the project codename?

**Q3 — Data source priority**: Which discovery sources to build first?
  a) SearXNG web search (already running CT105, free, works now)
  b) OpenCorporates API (free tier, 50k calls/month, structured company data)
  c) OpenSupplyHub (free, factory locations, good for tier-2+)
  d) WikiRate (free ESG data per company)

**Q4 — Competitive model setup**: "Competitive models" = prosecution/defense/judge on same model (gpt-oss-120b × 3 calls)? Or literally different models arguing against each other (one OpenRouter model as prosecutor, different one as defender)?

**Q5 — Tier depth**: How deep to traverse? Default 3 tiers (brand → tier1 supplier → tier2 → raw material)?

**Q6 — Standalone repo**: Should implementation live here in SupplyLens repo, or clone into a separate `knopenkoning/` folder like we did with `career-ops/`? (SupplyLens = public-facing repo, knopenkoning = instance of it for specific use case?)

**Q7 — Output format**: Neo4j Browser for graph viz (already available), or build a custom frontend? Superset dashboard for stats?
