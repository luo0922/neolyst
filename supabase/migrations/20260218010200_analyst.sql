-- ============================================================
-- 分析师表 (analyst)
-- 依赖：20260218010100_region
-- ============================================================

create table if not exists public.analyst (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  chinese_name text,
  email citext not null unique,
  region_id uuid references public.region(id) on delete set null,
  suffix text,
  sfc text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 索引
create index if not exists idx_analyst_created_at_desc on public.analyst(created_at desc);
create index if not exists idx_analyst_full_name on public.analyst(full_name);
create index if not exists idx_analyst_chinese_name on public.analyst(chinese_name);
create index if not exists idx_analyst_email on public.analyst(email);
create index if not exists idx_analyst_suffix on public.analyst(suffix);
create index if not exists idx_analyst_sfc on public.analyst(sfc);

-- 触发器
drop trigger if exists trg_analyst_updated_at on public.analyst;
create trigger trg_analyst_updated_at
before update on public.analyst
for each row execute function public.set_updated_at_utc();

-- RLS
alter table public.analyst enable row level security;

drop policy if exists analyst_select_authenticated on public.analyst;
create policy analyst_select_authenticated
on public.analyst
for select to authenticated using (true);

drop policy if exists analyst_write_admin on public.analyst;
create policy analyst_write_admin
on public.analyst
for all to authenticated
using ((auth.jwt()->'app_metadata'->>'role') = 'admin')
with check ((auth.jwt()->'app_metadata'->>'role') = 'admin');
