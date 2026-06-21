#!/usr/bin/env python3
"""
Push all SupplyLens n8n workflows via the n8n API.

Usage:
  export N8N_API_KEY="your-n8n-api-key"
  export N8N_BASE_URL="http://10.0.1.104:5678"
  export PG_CREDENTIAL_ID="your-postgres-credential-id"
  python3 scripts/push_workflows.py

To get your n8n API key: n8n UI → Settings → API Keys → Create key
To get PG credential ID: create a Postgres credential in n8n, then note the ID
  from the URL when you edit it (looks like: /credentials/JbOnOpMsjrzwBdul/edit)

Workflows are pushed in order 01→07. Each workflow that already exists
is updated (PUT); new ones are created via import.
"""
import json
import os
import subprocess
import sys

N8N_KEY = os.environ.get("N8N_API_KEY")
N8N_BASE = os.environ.get("N8N_BASE_URL", "http://10.0.1.104:5678")
PG_CRED_ID = os.environ.get("PG_CREDENTIAL_ID")

if not N8N_KEY:
    print("ERROR: Set N8N_API_KEY env var")
    sys.exit(1)
if not PG_CRED_ID:
    print("ERROR: Set PG_CREDENTIAL_ID env var (postgres credential ID in n8n)")
    sys.exit(1)

WF_DIR = os.path.join(os.path.dirname(__file__), "..", "n8n")

# Map filename → existing workflow ID (fill after first import, or leave empty to create)
# To get IDs: GET /api/v1/workflows and note each id + name
WORKFLOW_IDS: dict[str, str] = {
    # "01-seed.json": "EKasVnAlYFkvZviF",  # uncomment if updating existing
}

WORKFLOW_ORDER = [
    "01-seed.json",
    "02-discover.json",
    "03-challenge.json",
    "04-ingest.json",
    "05-watchdog.json",
    "06-enrich.json",
    "07-report.json",
]


def api(method: str, path: str, data: dict | None = None) -> dict:
    cmd = [
        "curl", "-s", "-X", method,
        f"{N8N_BASE}/api/v1{path}",
        "-H", f"X-N8N-API-KEY: {N8N_KEY}",
        "-H", "Content-Type: application/json",
    ]
    if data:
        cmd += ["-d", json.dumps(data)]
    result = subprocess.check_output(cmd)
    return json.loads(result)


def push_workflow(fname: str) -> None:
    fpath = os.path.join(WF_DIR, fname)
    if not os.path.exists(fpath):
        print(f"  SKIP {fname}: file not found")
        return

    with open(fpath) as f:
        wf = json.load(f)

    # Substitute postgres credential ID placeholder
    wf_str = json.dumps(wf).replace("POSTGRES_CREDENTIAL_ID", PG_CRED_ID)
    wf = json.loads(wf_str)

    payload = {
        "name": wf["name"],
        "nodes": wf["nodes"],
        "connections": wf["connections"],
        "settings": wf.get("settings", {"executionOrder": "v1"}),
    }

    wf_id = WORKFLOW_IDS.get(fname)
    if wf_id:
        # Update existing
        r = api("PUT", f"/workflows/{wf_id}", payload)
        status = "updated" if r.get("id") else f"ERROR: {r.get('message','?')}"
    else:
        # Create new (import)
        r = api("POST", "/workflows", payload)
        status = f"created id={r.get('id','?')}"

    print(f"  {fname}: {wf['name']} → {status}")


print(f"Pushing {len(WORKFLOW_ORDER)} workflows to {N8N_BASE}")
for fname in WORKFLOW_ORDER:
    push_workflow(fname)

print("\nDone. Activate workflows in the n8n UI: open each one → toggle 'Active'")
print("Run 01-seed first to initialize Neo4j + queue, then let schedulers take over.")
