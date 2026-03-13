-- Modify report table: change region_id to region_code

-- 1. Drop the old region_id column and its foreign key constraint (if exists)
alter table public.report drop constraint if exists report_region_id_fkey;
alter table public.report drop column if exists region_id;

-- 2. Add new region_code column (references region.code)
-- Use DO block to handle if column already exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'report' AND column_name = 'region_code'
  ) THEN
    alter table public.report add column region_code text references public.region(code) on delete set null;
  END IF;
END $$;

-- 3. Add comment
comment on column public.report.region_code is 'Region code (ISO 3166-1 alpha-2), references region.code';
