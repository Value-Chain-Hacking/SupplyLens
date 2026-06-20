-- SupplyLens pipeline_config seed
-- Edit CHANGE_ME values before running

INSERT INTO pipeline_config (key, value) VALUES
  -- Infrastructure
  ('neo4j_uri',            'http://10.0.1.114:7474'),
  ('neo4j_user',           'neo4j'),
  ('neo4j_password',       'CHANGE_ME'),
  ('searxng_base',         'http://10.0.1.105:8080'),
  ('browserless_url',      'http://10.0.5.100:3500'),
  ('gitea_base',           'http://10.0.2.200:3000'),
  ('gitea_token',          'CHANGE_ME'),
  ('gitea_output_repo',    'admin/supplylens-output'),

  -- Model assignments (different model per role — true adversarial reasoning)
  -- Prosecutor: Cohere Command R — good at building arguments from evidence
  ('prosecutor_model',     'cohere/command-r7b-12-2024:free'),
  ('prosecutor_key',       'OPENROUTER_KEY_1'),

  -- Defender: Llama 3.3 70B — strong at finding gaps and counter-arguments
  ('defender_model',       'meta-llama/llama-3.3-70b-instruct:free'),
  ('defender_key',         'OPENROUTER_KEY_2'),

  -- Judge: DeepSeek R1 — reasoning/synthesis specialist
  ('judge_model',          'deepseek/deepseek-r1:free'),
  ('judge_key',            'OPENROUTER_KEY_3'),

  -- Extractor: Gemini Flash — fast entity extraction from web text
  ('extract_model',        'google/gemini-2.0-flash-exp:free'),
  ('extract_key',          'OPENROUTER_KEY_4'),

  -- Enricher: Mistral 7B — ESG/risk flag extraction
  ('enrich_model',         'mistralai/mistral-7b-instruct:free'),
  ('enrich_key',           'OPENROUTER_KEY_5'),

  -- Pipeline tuning
  ('confidence_threshold', '0.60'),
  ('max_tier_depth',       '3'),
  ('search_results_per_query', '3'),
  ('max_claims_per_batch', '5'),
  ('openrouter_base',      'https://openrouter.ai/api/v1')
ON CONFLICT (key) DO NOTHING;
