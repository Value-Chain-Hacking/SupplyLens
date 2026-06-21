# SupplyLens Deployment Guide

## Architecture

| Component | Container | IP | Role |
|-----------|-----------|-----|------|
| n8n | CT104 | 10.0.1.104:5678 | Pipeline orchestration |
| PostgreSQL | CT100 | 10.0.1.100:5432 | Claims + config DB |
| Neo4j | CT114 | 10.0.1.114:7474 | Graph knowledge store |
| SearXNG | CT105 | 10.0.1.105:8080 | Web search |
| Gitea | CT200 | 10.0.2.200:3000 | Report output repo |

## Prerequisites

- VPN connected to 10.0.x.x subnets
- n8n v2.x running on CT104
- PostgreSQL `supply_chain` database initialized
- Neo4j with `neo4j` database
- SearXNG with JSON format enabled
- Gitea `admin/supplylens-output` repo + API token

## Database Setup

```bash
ssh root@10.0.1.100
psql -U postgres

CREATE USER supply_chain WITH PASSWORD 'SupplyLens2026!';
CREATE DATABASE supply_chain OWNER supply_chain;
\c supply_chain supply_chain
```

Run `sql/schema.sql` to create tables.

Seed initial config:
```sql
INSERT INTO pipeline_config (key, value) VALUES
  ('gitea_base', 'http://10.0.2.200:3000'),
  ('gitea_output_repo', 'admin/supplylens-output'),
  ('gitea_token', '<your-gitea-token>'),
  ('openrouter_base', 'https://openrouter.ai/api/v1'),
  ('extract_key', '<openrouter-key-1>'),
  ('prosecutor_key', '<openrouter-key-2>'),
  ('defender_key', '<openrouter-key-3>'),
  ('judge_key', '<openrouter-key-4>'),
  ('enrich_key', '<openrouter-key-5>'),
  ('extract_model', 'openai/gpt-oss-120b:free'),
  ('prosecutor_model', 'nvidia/nemotron-3-ultra-550b-a55b:free'),
  ('defender_model', 'openai/gpt-oss-120b:free'),
  ('judge_model', 'openai/gpt-oss-120b:free'),
  ('enrich_model', 'openai/gpt-oss-20b:free'),
  ('seed_company', 'YourCompany'),
  ('seed_country', 'NL'),
  ('neo4j_base', 'http://10.0.1.114:7474'),
  ('neo4j_user', 'neo4j'),
  ('neo4j_password', '<neo4j-password>'),
  ('searxng_base', 'http://10.0.1.105:8080'),
  ('confidence_threshold', '0.5'),
  ('max_claims_per_batch', '5'),
  ('max_tier_depth', '3'),
  ('search_results_per_query', '5');
```

## Importing Workflows

1. Log in to n8n at http://10.0.1.104:5678
2. Create a PostgreSQL credential with connection to CT100 supply_chain DB
3. Note the credential ID (shown in URL when editing credential)
4. Run the push script:

```bash
# Set your credential ID and n8n API key
export PG_CRED_ID="your-pg-cred-id"
export N8N_KEY="your-n8n-api-key"

python3 scripts/push_workflows.py
```

Or import manually: Settings → Import → paste each `n8n/*.json` file.

## Running the Pipeline

### Manual trigger (all workflows have Manual Trigger node):
1. Open n8n UI
2. Open workflow → click "Test workflow"

### Scheduled (auto-runs):
- `01-seed`: run once to initialize
- `02-discover`: every 30 min (searches for supply chain claims)
- `03-challenge`: every hour (adversarial reasoning on pending claims)
- `04-ingest`: every hour (writes accepted claims to Neo4j graph)
- `05-watchdog`: every 2 hours (resets stuck queue items)
- `06-enrich`: daily (enriches Neo4j company nodes with attributes)
- `07-report`: weekly Sunday 08:00 (pushes HTML report to Gitea)

## Free OpenRouter Models

Models with `:free` suffix only. Check current availability:
```bash
curl https://openrouter.ai/api/v1/models | python3 -c "
import json,sys
d=json.load(sys.stdin)
for m in d['data']:
    if ':free' in m['id']:
        print(m['id'])
"
```

Update `pipeline_config` if models become unavailable:
```sql
UPDATE pipeline_config SET value='new/model:free' WHERE key='extract_model';
```

## Changing the Seed Company

```sql
UPDATE pipeline_config SET value='AcmeSupply' WHERE key='seed_company';
UPDATE pipeline_config SET value='DE' WHERE key='seed_country';
-- Reset queue for new company
DELETE FROM expand_queue;
-- Re-run 01-seed workflow
```

## Monitoring

```bash
# Check claims accumulating
ssh root@10.0.1.100 "psql -U supply_chain -d supply_chain -c \
  'SELECT validation_status, count(*) FROM claims GROUP BY 1;'"

# Check Neo4j graph
curl -s -X POST http://10.0.1.114:7474/db/neo4j/tx/commit \
  -H 'Authorization: Basic bmVvNGo6...' \
  -H 'Content-Type: application/json' \
  -d '{"statements":[{"statement":"MATCH (n) RETURN count(n)"}]}'

# Check queue
ssh root@10.0.1.100 "psql -U supply_chain -d supply_chain -c \
  'SELECT status, count(*) FROM expand_queue GROUP BY 1;'"
```

## Security Notes

- All OpenRouter API keys are 5 separate keys (one per role) — rotate independently
- Neo4j password stored in pipeline_config (DB-level access required to read)
- n8n API key: stored in `.env` or admin panel → Settings → API keys
- Gitea token: only needs `repo:write` scope on `supplylens-output` repo

## Report Output

HTML reports pushed to Gitea `admin/supplylens-output/reports/` weekly.
Each report filename includes timestamp: `report-YYYY-MM-DD-HH-MM-SS.html`
