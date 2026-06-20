-- SupplyLens PostgreSQL schema
-- Run as: psql -U postgres -c "CREATE DATABASE supply_chain; CREATE USER supply_chain WITH PASSWORD 'CHANGE_ME'; GRANT ALL ON DATABASE supply_chain TO supply_chain;"
-- Then: psql -U supply_chain -d supply_chain -f 01_schema.sql

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject TEXT NOT NULL,
  predicate TEXT NOT NULL DEFAULT 'SUPPLIES',
  object TEXT NOT NULL,
  subject_country TEXT,
  object_country TEXT,
  tier INTEGER DEFAULT 1,
  confidence FLOAT,
  contested BOOLEAN DEFAULT false,
  sources JSONB DEFAULT '[]',
  prosecution JSONB,
  defense JSONB,
  validation_status TEXT DEFAULT 'pending',
  written_to_graph BOOLEAN DEFAULT false,
  raw_text TEXT,
  source_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  validated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_claims_status ON claims(validation_status);
CREATE INDEX IF NOT EXISTS idx_claims_graph ON claims(written_to_graph) WHERE written_to_graph = false;
CREATE INDEX IF NOT EXISTS idx_claims_confidence ON claims(confidence);

CREATE TABLE IF NOT EXISTS expand_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_name TEXT NOT NULL,
  country TEXT,
  tier INTEGER DEFAULT 0,
  status TEXT DEFAULT 'queued',
  parent_company TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  started_at TIMESTAMPTZ,
  UNIQUE(company_name, tier)
);

CREATE INDEX IF NOT EXISTS idx_queue_status ON expand_queue(status, tier);

CREATE TABLE IF NOT EXISTS pipeline_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit_log (
  id SERIAL PRIMARY KEY,
  pipeline TEXT NOT NULL,
  action TEXT NOT NULL,
  subject TEXT,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

GRANT ALL ON ALL TABLES IN SCHEMA public TO supply_chain;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO supply_chain;
