# CLAUDE.md — SupplyLens

## What this is

SupplyLens maps hidden supply chains using forensic AI reasoning. Input: a company or product name. Output: a Neo4j knowledge graph of who supplies whom, with confidence scores on every edge, and AI-generated insight on uncertain links.

Key insight: **we cannot know the full supply chain**. So we use adversarial LLM reasoning (prosecution / defense / judge) to assign "reasonable doubt" confidence to every inferred fact before writing it to the graph.

## Pipeline overview

```
01-seed       → input company/product → root node in Neo4j
02-discover   → web search (SearXNG + Browserless) → raw supplier claims
03-challenge  → prosecution / defense / judge LLM loop → confidence score per claim
04-ingest     → claims above threshold → Neo4j nodes + edges
05-expand     → traverse graph tier by tier (SUPPLIES*1..N) → queue next tier
06-enrich     → sanctions (OFAC), certifications, ESG flags, news → enrich nodes
07-report     → weekly supply chain summary → Gitea
```

EDRM mapping:
- **Identification** → 01-seed + 02-discover
- **Preservation** → PostgreSQL `supply_chain_claims` table (raw + scored)
- **Collection** → 02-discover (web), 06-enrich (APIs)
- **Processing** → 03-challenge (LLM extraction + validation)
- **Review** → 03-challenge (adversarial models)
- **Analysis** → 05-expand (graph traversal)
- **Production** → 07-report
- **Presentation** → Neo4j Browser / Superset dashboard

## Infrastructure

All services are on the internal network (VPN required).

| Service | IP | Port | Purpose |
|---------|-----|------|---------|
| Neo4j | 10.0.1.114 | 7687 (Bolt) / 7474 (HTTP) | Supply chain graph |
| PostgreSQL | 10.0.1.100 | 5432 | Claims + audit trail |
| n8n | 10.0.1.104 | 5678 | Workflow engine |
| LiteLLM | 10.0.2.205 | 4000 | LLM proxy (free OpenRouter models) |
| SearXNG | 10.0.1.105 | 8080 | Web search |
| Browserless | 10.0.5.100 | 3500 | Web scraping / PDF |
| CrewAI | 10.0.3.108 | 8600 | Research agent |
| Graphiti | 10.0.1.124 | 8000 | Temporal memory (supplier state changes) |
| Gitea | 10.0.2.200 | 3000 | Output repo |

**LLM**: Only use free models via LiteLLM. Default: `gpt-oss-120b`. Never use paid Anthropic/Gemini/etc.

**Neo4j credentials**: in KeePass → Infrastructure → Neo4j (CT114). Also in `/root/.credentials/neo4j.txt` on CT114.

**PostgreSQL**: database `supply_chain`, user `supply_chain`. Credentials in KeePass.

## Neo4j schema

```cypher
// Nodes
(:Company   {id, name, country, industry, confidence, sources[], risk_flags[], last_verified})
(:Product   {id, name, hs_code, category, confidence})
(:Facility  {id, name, type, country, lat, lng, confidence})
(:Country   {iso_code, name, risk_level})
(:Risk      {id, type, description, severity, source, discovered_at})
(:Cert      {id, name, issuer, scope, valid_until})

// Relationships (all carry confidence + source metadata)
(:Company)-[:SUPPLIES      {confidence, product_ids[], source, verified_date}]->(:Company)
(:Company)-[:MANUFACTURES  {confidence, facility_id, volume}]->(:Product)
(:Company)-[:OPERATES      {since}]->(:Facility)
(:Company)-[:LOCATED_IN]->(:Country)
(:Company)-[:HOLDS_CERT    {confidence, verified_date}]->(:Cert)
(:Company)-[:EXPOSED_TO    {confidence, discovered_at}]->(:Risk)
```

## Claim data structure (PostgreSQL)

Every inferred supply chain link is a Claim before it becomes a graph edge:

```json
{
  "id": "claim-uuid",
  "subject": "Company A",
  "predicate": "SUPPLIES",
  "object": "Company B",
  "confidence": 0.73,
  "contested": true,
  "sources": [{"url": "...", "type": "regulatory|news|self_report|social", "reliability": 0.9, "text": "..."}],
  "prosecution": {"points": ["..."], "confidence_delta": 0.3},
  "defense": {"points": ["..."], "confidence_delta": -0.2},
  "validation_status": "needs_review|accepted|rejected",
  "tier": 2,
  "created_at": "2026-06-20T...",
  "written_to_graph": false
}
```

Claims above `confidence_threshold` (default: 0.60) are written to Neo4j.

## Key files

| File | Purpose |
|------|---------|
| `n8n/` | Workflow JSONs — import to CT104 n8n in order 01→07 |
| `sql/` | DB migrations for PostgreSQL supply_chain database |
| `prompts/` | LLM prompt templates for each pipeline stage |
| `docs/PLAN.md` | Full implementation plan with tasks |
| `passwords.kdbx` | KeePass DB (master: ask Chris) — gitignored |

## Rules

- No code in Code nodes that calls `fetch()` — use HTTP Request nodes
- No paid LLM models — only free via LiteLLM proxy
- Every Neo4j edge must carry `confidence` (0.0–1.0) and `source`
- Every claim must survive adversarial challenge before entering graph
- All pipeline config lives in `pipeline_config` PostgreSQL table — no hardcoded values in n8n JSON
- `Restart=no` on all systemd services (Proxmox shared infra)

## How to run pipelines

```bash
# Seed a company
# In n8n: open 01-seed → Manual Trigger → input {"company": "ACME Corp", "country": "NL"}

# Check graph
# Open http://10.0.1.114:7474 (Neo4j Browser)
# MATCH (n) RETURN n LIMIT 50

# Check claims
# psql -h 10.0.1.100 -U supply_chain -d supply_chain
# SELECT subject, predicate, object, confidence, contested FROM claims ORDER BY confidence DESC LIMIT 20;
```

## Workflow for changes

1. Edit workflow JSON locally
2. Import to n8n at CT104
3. Test with manual trigger
4. Commit + push to this repo
