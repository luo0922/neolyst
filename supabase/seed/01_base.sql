-- Seed preset regions
-- Run with: psql exec -f supabase/seed/regions.sql --db-url "postgresql://postgres:postgres@localhost:54322/postgres"

INSERT INTO public.region (name_cn, name_en, code) VALUES
  ('中国', 'China', 'CN'),
  ('香港', 'Hong Kong', 'HK'),
  ('日本', 'Japan', 'JP'),
  ('台湾', 'Taiwan', 'TW'),
  ('韩国', 'Korea', 'KR'),
  ('印度', 'India', 'IN'),
  ('澳门', 'Macau', 'MO'),
  ('美国', 'US', 'US')
ON CONFLICT DO NOTHING;
