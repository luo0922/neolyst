-- =============================================================================
-- Supabase Database Migration Script
-- Generated: 2026-03-13
-- Description: 完整的数据库迁移脚本，包含所有表的创建、修改和函数定义
-- =============================================================================
-- 执行方式: supabase db push 或 psql -h <host> -U <user> -d <db> -f this_file.sql
-- =============================================================================

-- =============================================================================
-- 1. Common extensions and shared helpers
-- =============================================================================
create extension if not exists pgcrypto;
create extension if not exists citext;

create or replace function public.set_updated_at_utc()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =============================================================================
-- 2. Region table (initial version - will be modified later)
-- =============================================================================
create table if not exists public.region (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  code text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_region_created_at_desc
  on public.region (created_at desc);

drop trigger if exists trg_region_updated_at on public.region;
create trigger trg_region_updated_at
before update on public.region
for each row execute function public.set_updated_at_utc();

alter table public.region enable row level security;

drop policy if exists region_select_authenticated on public.region;
create policy region_select_authenticated
on public.region
for select
to authenticated
using (true);

drop policy if exists region_write_admin on public.region;
create policy region_write_admin
on public.region
for all
to authenticated
using ((auth.jwt()->'app_metadata'->>'role') = 'admin')
with check ((auth.jwt()->'app_metadata'->>'role') = 'admin');

-- =============================================================================
-- 3. Analyst table
-- =============================================================================
create table if not exists public.analyst (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  chinese_name text,
  email citext not null unique,
  region_id uuid references public.region(id) on delete set null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_analyst_created_at_desc
  on public.analyst (created_at desc);
create index if not exists idx_analyst_full_name
  on public.analyst (full_name);
create index if not exists idx_analyst_chinese_name
  on public.analyst (chinese_name);
create index if not exists idx_analyst_email
  on public.analyst (email);

drop trigger if exists trg_analyst_updated_at on public.analyst;
create trigger trg_analyst_updated_at
before update on public.analyst
for each row execute function public.set_updated_at_utc();

alter table public.analyst enable row level security;

drop policy if exists analyst_select_authenticated on public.analyst;
create policy analyst_select_authenticated
on public.analyst
for select
to authenticated
using (true);

drop policy if exists analyst_write_admin on public.analyst;
create policy analyst_write_admin
on public.analyst
for all
to authenticated
using ((auth.jwt()->'app_metadata'->>'role') = 'admin')
with check ((auth.jwt()->'app_metadata'->>'role') = 'admin');

-- =============================================================================
-- 4. Sector table
-- =============================================================================
create table if not exists public.sector (
  id uuid primary key default gen_random_uuid(),
  level smallint not null check (level in (1, 2)),
  parent_id uuid references public.sector(id) on delete restrict,
  name_en text not null,
  name_cn text,
  wind_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sector_level_parent_check check (
    (level = 1 and parent_id is null) or
    (level = 2 and parent_id is not null)
  )
);

create index if not exists idx_sector_level_parent
  on public.sector(level, parent_id);
create index if not exists idx_sector_name_en_lower
  on public.sector(lower(name_en));
create index if not exists idx_sector_active
  on public.sector(is_active);
create unique index if not exists uidx_sector_l1_name_en
  on public.sector(lower(name_en))
  where parent_id is null;
create unique index if not exists uidx_sector_l2_parent_name_en
  on public.sector(parent_id, lower(name_en))
  where parent_id is not null;

create or replace function public.validate_sector_hierarchy()
returns trigger
language plpgsql
as $$
declare
  v_parent_level smallint;
  v_parent_parent uuid;
begin
  if new.parent_id is not null and new.parent_id = new.id then
    raise exception 'sector parent cannot reference itself';
  end if;

  if new.level = 1 then
    if new.parent_id is not null then
      raise exception 'level 1 sector cannot have parent';
    end if;
    return new;
  end if;

  select s.level, s.parent_id
    into v_parent_level, v_parent_parent
  from public.sector s
  where s.id = new.parent_id;

  if not found then
    raise exception 'level 2 sector must reference an existing parent';
  end if;

  if v_parent_level <> 1 then
    raise exception 'level 2 sector parent must be level 1';
  end if;

  if v_parent_parent is not null then
    raise exception 'sector hierarchy supports only two levels';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_sector_hierarchy on public.sector;
create trigger trg_sector_hierarchy
before insert or update on public.sector
for each row execute function public.validate_sector_hierarchy();

drop trigger if exists trg_sector_updated_at on public.sector;
create trigger trg_sector_updated_at
before update on public.sector
for each row execute function public.set_updated_at_utc();

alter table public.sector enable row level security;

drop policy if exists sector_select_authenticated on public.sector;
create policy sector_select_authenticated
on public.sector
for select
to authenticated
using (true);

drop policy if exists sector_write_admin on public.sector;
create policy sector_write_admin
on public.sector
for all
to authenticated
using ((auth.jwt()->'app_metadata'->>'role') = 'admin')
with check ((auth.jwt()->'app_metadata'->>'role') = 'admin');

-- =============================================================================
-- 5. Coverage and coverage_analyst tables
-- =============================================================================
create table if not exists public.coverage (
  id uuid primary key default gen_random_uuid(),
  ticker text not null,
  english_full_name text not null,
  chinese_short_name text,
  traditional_chinese text,
  sector_id uuid not null references public.sector(id) on delete restrict,
  isin text not null,
  country_of_domicile text not null,
  reporting_currency text,
  ads_conversion_factor numeric(18, 6) check (ads_conversion_factor > 0),
  is_duplicate boolean not null default false,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists uidx_coverage_ticker_lower
  on public.coverage(lower(btrim(ticker)));
create unique index if not exists uidx_coverage_isin_upper
  on public.coverage(upper(btrim(isin)));
create index if not exists idx_coverage_sector
  on public.coverage(sector_id);
create index if not exists idx_coverage_name_lower
  on public.coverage(lower(english_full_name));
create index if not exists idx_coverage_updated_at_desc
  on public.coverage(updated_at desc);

drop trigger if exists trg_coverage_updated_at on public.coverage;
create trigger trg_coverage_updated_at
before update on public.coverage
for each row execute function public.set_updated_at_utc();

alter table public.coverage enable row level security;

drop policy if exists coverage_select_authenticated on public.coverage;
create policy coverage_select_authenticated
on public.coverage
for select
to authenticated
using (true);

drop policy if exists coverage_insert_admin_analyst on public.coverage;
create policy coverage_insert_admin_analyst
on public.coverage
for insert
to authenticated
with check ((auth.jwt()->'app_metadata'->>'role') in ('admin', 'sa', 'analyst'));

drop policy if exists coverage_update_admin on public.coverage;
create policy coverage_update_admin
on public.coverage
for update
to authenticated
using ((auth.jwt()->'app_metadata'->>'role') = 'admin')
with check ((auth.jwt()->'app_metadata'->>'role') = 'admin');

drop policy if exists coverage_delete_admin on public.coverage;
create policy coverage_delete_admin
on public.coverage
for delete
to authenticated
using ((auth.jwt()->'app_metadata'->>'role') = 'admin');

-- coverage_analyst
create table if not exists public.coverage_analyst (
  id uuid primary key default gen_random_uuid(),
  coverage_id uuid not null references public.coverage(id) on delete cascade,
  analyst_id uuid not null references public.analyst(id) on delete restrict,
  role smallint not null check (role between 1 and 4),
  sort_order smallint not null check (sort_order between 1 and 4),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint coverage_analyst_uniq_pair unique (coverage_id, analyst_id),
  constraint coverage_analyst_uniq_sort unique (coverage_id, sort_order)
);

create index if not exists idx_cov_analyst_coverage
  on public.coverage_analyst(coverage_id);
create index if not exists idx_cov_analyst_analyst
  on public.coverage_analyst(analyst_id);

create or replace function public.validate_coverage_analyst_limit()
returns trigger
language plpgsql
as $$
declare
  v_count int;
begin
  if tg_op = 'INSERT' then
    select count(*) into v_count
    from public.coverage_analyst
    where coverage_id = new.coverage_id;

    if v_count >= 4 then
      raise exception 'a coverage can have at most 4 analysts';
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' and new.coverage_id is distinct from old.coverage_id then
    select count(*) into v_count
    from public.coverage_analyst
    where coverage_id = new.coverage_id;

    if v_count >= 4 then
      raise exception 'a coverage can have at most 4 analysts';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_coverage_analyst_limit on public.coverage_analyst;
create trigger trg_coverage_analyst_limit
before insert or update on public.coverage_analyst
for each row execute function public.validate_coverage_analyst_limit();

drop trigger if exists trg_coverage_analyst_updated_at on public.coverage_analyst;
create trigger trg_coverage_analyst_updated_at
before update on public.coverage_analyst
for each row execute function public.set_updated_at_utc();

alter table public.coverage_analyst enable row level security;

drop policy if exists coverage_analyst_select_authenticated on public.coverage_analyst;
create policy coverage_analyst_select_authenticated
on public.coverage_analyst
for select
to authenticated
using (true);

drop policy if exists coverage_analyst_insert_admin_analyst on public.coverage_analyst;
create policy coverage_analyst_insert_admin_analyst
on public.coverage_analyst
for insert
to authenticated
with check ((auth.jwt()->'app_metadata'->>'role') in ('admin', 'sa', 'analyst'));

drop policy if exists coverage_analyst_update_admin on public.coverage_analyst;
create policy coverage_analyst_update_admin
on public.coverage_analyst
for update
to authenticated
using ((auth.jwt()->'app_metadata'->>'role') = 'admin')
with check ((auth.jwt()->'app_metadata'->>'role') = 'admin');

drop policy if exists coverage_analyst_delete_admin on public.coverage_analyst;
create policy coverage_analyst_delete_admin
on public.coverage_analyst
for delete
to authenticated
using ((auth.jwt()->'app_metadata'->>'role') = 'admin');

-- =============================================================================
-- 6. Template table
-- =============================================================================
create table if not exists public.template (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  report_type text not null,
  file_type text not null check (file_type in ('word', 'excel')),
  file_path text not null,
  version integer not null check (version >= 1),
  is_active boolean not null default false,
  uploaded_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint template_uniq_version unique (report_type, file_type, version)
);

create unique index if not exists uidx_template_active_one
  on public.template(report_type, file_type)
  where is_active = true;
create index if not exists idx_template_group
  on public.template(report_type, file_type);
create index if not exists idx_template_created_at_desc
  on public.template(created_at desc);

drop trigger if exists trg_template_updated_at on public.template;
create trigger trg_template_updated_at
before update on public.template
for each row execute function public.set_updated_at_utc();

alter table public.template enable row level security;

drop policy if exists template_select_authenticated on public.template;
create policy template_select_authenticated
on public.template
for select
to authenticated
using (true);

drop policy if exists template_write_admin on public.template;
create policy template_write_admin
on public.template
for all
to authenticated
using ((auth.jwt()->'app_metadata'->>'role') = 'admin')
with check ((auth.jwt()->'app_metadata'->>'role') = 'admin');

-- storage bucket: templates
insert into storage.buckets (id, name, public)
values ('templates', 'templates', false)
on conflict (id) do nothing;

drop policy if exists storage_templates_select_authenticated on storage.objects;
create policy storage_templates_select_authenticated
on storage.objects
for select
to authenticated
using (bucket_id = 'templates');

drop policy if exists storage_templates_insert_admin on storage.objects;
create policy storage_templates_insert_admin
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'templates'
  and (auth.jwt()->'app_metadata'->>'role') = 'admin'
);

drop policy if exists storage_templates_update_admin on storage.objects;
create policy storage_templates_update_admin
on storage.objects
for update
to authenticated
using (
  bucket_id = 'templates'
  and (auth.jwt()->'app_metadata'->>'role') = 'admin'
)
with check (
  bucket_id = 'templates'
  and (auth.jwt()->'app_metadata'->>'role') = 'admin'
);

drop policy if exists storage_templates_delete_admin on storage.objects;
create policy storage_templates_delete_admin
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'templates'
  and (auth.jwt()->'app_metadata'->>'role') = 'admin'
);

-- =============================================================================
-- 7. Report management core tables
-- =============================================================================
-- helpers
create or replace function public.current_app_role()
returns text
language sql
stable
as $$
  select coalesce(auth.jwt()->'app_metadata'->>'role', '');
$$;

create or replace function public.report_status_is_valid(from_status text, to_status text)
returns boolean
language sql
immutable
as $$
  select (
    (from_status = 'draft' and to_status = 'submitted')
    or (from_status = 'submitted' and to_status in ('published', 'rejected'))
    or (from_status = 'rejected' and to_status = 'draft')
  );
$$;

create table if not exists public.report (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  title text not null,
  report_type text not null check (report_type in ('company', 'sector', 'company_flash', 'sector_flash', 'common')),
  status text not null default 'draft' check (status in ('draft', 'submitted', 'published', 'rejected')),
  current_version_no integer not null default 0 check (current_version_no >= 0),
  coverage_id uuid references public.coverage(id) on delete set null,
  sector_id uuid references public.sector(id) on delete set null,
  published_by uuid references auth.users(id) on delete set null,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_report_owner on public.report(owner_user_id);
create index if not exists idx_report_status on public.report(status);
create index if not exists idx_report_updated_at_desc on public.report(updated_at desc);
create index if not exists idx_report_created_at_desc on public.report(created_at desc);

create or replace function public.report_enforce_owner_immutable()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and new.owner_user_id is distinct from old.owner_user_id then
    raise exception 'owner_user_id is immutable';
  end if;
  return new;
end;
$$;

create or replace function public.report_enforce_status_transition()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if not public.report_status_is_valid(old.status, new.status) then
      raise exception 'invalid report status transition: % -> %', old.status, new.status;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_report_updated_at on public.report;
create trigger trg_report_updated_at
before update on public.report
for each row execute function public.set_updated_at_utc();

drop trigger if exists trg_report_owner_immutable on public.report;
create trigger trg_report_owner_immutable
before update on public.report
for each row execute function public.report_enforce_owner_immutable();

drop trigger if exists trg_report_status_transition on public.report;
create trigger trg_report_status_transition
before update on public.report
for each row execute function public.report_enforce_status_transition();

create table if not exists public.report_version (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.report(id) on delete cascade,
  version_no integer not null check (version_no >= 1),
  snapshot_json jsonb not null default '{}'::jsonb,
  word_file_path text,
  model_file_path text,
  changed_by uuid not null references auth.users(id) on delete restrict,
  changed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint report_version_uniq unique (report_id, version_no)
);

create index if not exists idx_report_version_report on public.report_version(report_id);
create index if not exists idx_report_version_report_version_desc
  on public.report_version(report_id, version_no desc);
create index if not exists idx_report_version_changed_at_desc
  on public.report_version(changed_at desc);

create table if not exists public.report_analyst (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.report(id) on delete cascade,
  analyst_id uuid not null references public.analyst(id) on delete restrict,
  role smallint not null check (role between 1 and 4),
  sort_order smallint not null check (sort_order between 1 and 4),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint report_analyst_uniq_pair unique (report_id, analyst_id),
  constraint report_analyst_uniq_sort unique (report_id, sort_order)
);

create index if not exists idx_report_analyst_report on public.report_analyst(report_id);
create index if not exists idx_report_analyst_analyst on public.report_analyst(analyst_id);

drop trigger if exists trg_report_analyst_updated_at on public.report_analyst;
create trigger trg_report_analyst_updated_at
before update on public.report_analyst
for each row execute function public.set_updated_at_utc();

create table if not exists public.report_status_log (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.report(id) on delete cascade,
  from_status text not null check (from_status in ('draft', 'submitted', 'published', 'rejected')),
  to_status text not null check (to_status in ('draft', 'submitted', 'published', 'rejected')),
  action_by uuid not null references auth.users(id) on delete restrict,
  action_at timestamptz not null default now(),
  reason text,
  version_no integer not null check (version_no >= 0),
  created_at timestamptz not null default now(),
  constraint report_status_log_reject_reason_required
    check ((to_status <> 'rejected') or (reason is not null and btrim(reason) <> ''))
);

create index if not exists idx_report_status_log_report on public.report_status_log(report_id);
create index if not exists idx_report_status_log_action_at_desc
  on public.report_status_log(action_at desc);

create or replace function public.report_status_log_enforce_transition()
returns trigger
language plpgsql
as $$
begin
  if not public.report_status_is_valid(new.from_status, new.to_status) then
    raise exception 'invalid status log transition: % -> %', new.from_status, new.to_status;
  end if;
  if new.from_status = new.to_status then
    raise exception 'status log transition must change status';
  end if;
  return new;
end;
$$;

create or replace function public.prevent_update_delete_append_only()
returns trigger
language plpgsql
as $$
begin
  raise exception 'append-only table: update/delete is not allowed';
end;
$$;

drop trigger if exists trg_report_version_no_update on public.report_version;
create trigger trg_report_version_no_update
before update or delete on public.report_version
for each row execute function public.prevent_update_delete_append_only();

drop trigger if exists trg_report_status_log_no_update on public.report_status_log;
create trigger trg_report_status_log_no_update
before update or delete on public.report_status_log
for each row execute function public.prevent_update_delete_append_only();

drop trigger if exists trg_report_status_log_transition on public.report_status_log;
create trigger trg_report_status_log_transition
before insert on public.report_status_log
for each row execute function public.report_status_log_enforce_transition();

alter table public.report enable row level security;
alter table public.report_version enable row level security;
alter table public.report_analyst enable row level security;
alter table public.report_status_log enable row level security;

-- report policies
drop policy if exists report_select_policy on public.report;
create policy report_select_policy
on public.report
for select
to authenticated
using (
  public.current_app_role() = 'admin'
  or (public.current_app_role() = 'sa' and status in ('draft', 'submitted', 'published', 'rejected'))
  or (public.current_app_role() = 'analyst' and owner_user_id = auth.uid())
);

drop policy if exists report_insert_policy on public.report;
create policy report_insert_policy
on public.report
for insert
to authenticated
with check (
  public.current_app_role() = 'admin'
  or (public.current_app_role() = 'analyst' and owner_user_id = auth.uid())
);

drop policy if exists report_update_policy on public.report;
create policy report_update_policy
on public.report
for update
to authenticated
using (
  public.current_app_role() = 'admin'
  or (
    public.current_app_role() = 'analyst'
    and owner_user_id = auth.uid()
    and status in ('draft', 'submitted')
  )
)
with check (
  public.current_app_role() = 'admin'
  or (
    public.current_app_role() = 'analyst'
    and owner_user_id = auth.uid()
    and status in ('draft', 'submitted')
  )
);

-- report_version policies
drop policy if exists report_version_select_policy on public.report_version;
create policy report_version_select_policy
on public.report_version
for select
to authenticated
using (
  exists (
    select 1
    from public.report r
    where r.id = report_version.report_id
      and (
        public.current_app_role() = 'admin'
        or (public.current_app_role() = 'sa' and r.status in ('submitted', 'published', 'rejected'))
        or (public.current_app_role() = 'analyst' and r.owner_user_id = auth.uid())
      )
  )
);

drop policy if exists report_version_insert_policy on public.report_version;
create policy report_version_insert_policy
on public.report_version
for insert
to authenticated
with check (
  changed_by = auth.uid()
  and exists (
    select 1
    from public.report r
    where r.id = report_version.report_id
      and (
        public.current_app_role() = 'admin'
        or (
          public.current_app_role() = 'analyst'
          and r.owner_user_id = auth.uid()
          and r.status in ('draft', 'submitted')
        )
      )
  )
);

-- report_analyst policies
drop policy if exists report_analyst_select_policy on public.report_analyst;
create policy report_analyst_select_policy
on public.report_analyst
for select
to authenticated
using (
  exists (
    select 1
    from public.report r
    where r.id = report_analyst.report_id
      and (
        public.current_app_role() = 'admin'
        or (public.current_app_role() = 'sa' and r.status in ('submitted', 'published', 'rejected'))
        or (public.current_app_role() = 'analyst' and r.owner_user_id = auth.uid())
      )
  )
);

drop policy if exists report_analyst_insert_policy on public.report_analyst;
create policy report_analyst_insert_policy
on public.report_analyst
for insert
to authenticated
with check (
  exists (
    select 1
    from public.report r
    where r.id = report_analyst.report_id
      and (
        public.current_app_role() = 'admin'
        or (
          public.current_app_role() = 'analyst'
          and r.owner_user_id = auth.uid()
          and r.status in ('draft', 'submitted')
        )
      )
  )
);

drop policy if exists report_analyst_update_policy on public.report_analyst;
create policy report_analyst_update_policy
on public.report_analyst
for update
to authenticated
using (
  exists (
    select 1
    from public.report r
    where r.id = report_analyst.report_id
      and (
        public.current_app_role() = 'admin'
        or (
          public.current_app_role() = 'analyst'
          and r.owner_user_id = auth.uid()
          and r.status in ('draft', 'submitted')
        )
      )
  )
)
with check (
  exists (
    select 1
    from public.report r
    where r.id = report_analyst.report_id
      and (
        public.current_app_role() = 'admin'
        or (
          public.current_app_role() = 'analyst'
          and r.owner_user_id = auth.uid()
          and r.status in ('draft', 'submitted')
        )
      )
  )
);

drop policy if exists report_analyst_delete_policy on public.report_analyst;
create policy report_analyst_delete_policy
on public.report_analyst
for delete
to authenticated
using (
  exists (
    select 1
    from public.report r
    where r.id = report_analyst.report_id
      and (
        public.current_app_role() = 'admin'
        or (
          public.current_app_role() = 'analyst'
          and r.owner_user_id = auth.uid()
          and r.status in ('draft', 'submitted')
        )
      )
  )
);

-- report_status_log policies
drop policy if exists report_status_log_select_policy on public.report_status_log;
create policy report_status_log_select_policy
on public.report_status_log
for select
to authenticated
using (
  exists (
    select 1
    from public.report r
    where r.id = report_status_log.report_id
      and (
        public.current_app_role() = 'admin'
        or (public.current_app_role() = 'sa' and r.status in ('submitted', 'published', 'rejected'))
        or (public.current_app_role() = 'analyst' and r.owner_user_id = auth.uid())
      )
  )
);

drop policy if exists report_status_log_insert_policy on public.report_status_log;
create policy report_status_log_insert_policy
on public.report_status_log
for insert
to authenticated
with check (
  action_by = auth.uid()
  and (
    public.current_app_role() = 'admin'
    or (
      public.current_app_role() = 'sa'
      and from_status in ('submitted', 'rejected')
    )
    or (
      public.current_app_role() = 'analyst'
      and from_status = 'draft'
      and to_status = 'submitted'
      and exists (
        select 1
        from public.report r
        where r.id = report_status_log.report_id
          and r.owner_user_id = auth.uid()
      )
    )
  )
);

-- storage bucket: reports
insert into storage.buckets (id, name, public)
values ('reports', 'reports', false)
on conflict (id) do nothing;

drop policy if exists storage_reports_select_policy on storage.objects;
create policy storage_reports_select_policy
on storage.objects
for select
to authenticated
using (
  bucket_id = 'reports'
  and split_part(name, '/', 1) = 'reports'
  and split_part(name, '/', 2) ~* '^[0-9a-f-]{36}$'
  and exists (
    select 1
    from public.report r
    where r.id = split_part(name, '/', 2)::uuid
      and (
        public.current_app_role() = 'admin'
        or r.owner_user_id = auth.uid()
        or (public.current_app_role() = 'sa' and r.status in ('submitted', 'published', 'rejected'))
      )
  )
);

drop policy if exists storage_reports_insert_policy on storage.objects;
create policy storage_reports_insert_policy
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'reports'
  and split_part(name, '/', 1) = 'reports'
  and split_part(name, '/', 2) ~* '^[0-9a-f-]{36}$'
  and exists (
    select 1
    from public.report r
    where r.id = split_part(name, '/', 2)::uuid
      and (
        public.current_app_role() = 'admin'
        or r.owner_user_id = auth.uid()
      )
  )
);

drop policy if exists storage_reports_update_policy on storage.objects;
create policy storage_reports_update_policy
on storage.objects
for update
to authenticated
using (
  bucket_id = 'reports'
  and split_part(name, '/', 1) = 'reports'
  and split_part(name, '/', 2) ~* '^[0-9a-f-]{36}$'
  and exists (
    select 1
    from public.report r
    where r.id = split_part(name, '/', 2)::uuid
      and (
        public.current_app_role() = 'admin'
        or r.owner_user_id = auth.uid()
      )
  )
)
with check (
  bucket_id = 'reports'
  and split_part(name, '/', 1) = 'reports'
  and split_part(name, '/', 2) ~* '^[0-9a-f-]{36}$'
  and exists (
    select 1
    from public.report r
    where r.id = split_part(name, '/', 2)::uuid
      and (
        public.current_app_role() = 'admin'
        or r.owner_user_id = auth.uid()
      )
  )
);

drop policy if exists storage_reports_delete_policy on storage.objects;
create policy storage_reports_delete_policy
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'reports'
  and split_part(name, '/', 1) = 'reports'
  and split_part(name, '/', 2) ~* '^[0-9a-f-]{36}$'
  and exists (
    select 1
    from public.report r
    where r.id = split_part(name, '/', 2)::uuid
      and (
        public.current_app_role() = 'admin'
        or r.owner_user_id = auth.uid()
      )
  )
);

-- =============================================================================
-- 8. Add analyst suffix and sfc fields
-- =============================================================================
alter table public.analyst
  add column if not exists suffix text,
  add column if not exists sfc text;

create index if not exists idx_analyst_suffix
  on public.analyst (suffix);

create index if not exists idx_analyst_sfc
  on public.analyst (sfc);

-- =============================================================================
-- 9. Report atomic save RPC
-- =============================================================================
create or replace function public.report_save_content_atomic(
  p_report_id uuid,
  p_title text,
  p_report_type text,
  p_coverage_id uuid,
  p_sector_id uuid,
  p_analysts jsonb,
  p_changed_by uuid,
  p_word_file_path text,
  p_model_file_path text
)
returns public.report
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_current public.report%rowtype;
  v_updated public.report%rowtype;
  v_next_version integer;
  v_snapshot jsonb;
begin
  if auth.uid() is null then
    raise exception 'unauthorized';
  end if;

  if p_changed_by is distinct from auth.uid() then
    raise exception 'changed_by must match auth.uid';
  end if;

  select *
    into v_current
  from public.report
  where id = p_report_id
  for update;

  if not found then
    raise exception 'report not found or no permission';
  end if;

  v_next_version := coalesce(v_current.current_version_no, 0) + 1;

  update public.report
  set
    title = p_title,
    report_type = p_report_type,
    coverage_id = p_coverage_id,
    sector_id = p_sector_id,
    current_version_no = v_next_version
  where id = p_report_id
  returning *
    into v_updated;

  delete from public.report_analyst
  where report_id = p_report_id;

  insert into public.report_analyst (
    report_id,
    analyst_id,
    role,
    sort_order
  )
  select
    p_report_id,
    (item->>'analyst_id')::uuid,
    (item->>'role')::smallint,
    (item->>'sort_order')::smallint
  from jsonb_array_elements(coalesce(p_analysts, '[]'::jsonb)) as item;

  v_snapshot := jsonb_build_object(
    'report_id', v_updated.id,
    'owner_user_id', v_updated.owner_user_id,
    'owner_name', v_updated.owner_user_id::text,
    'title', v_updated.title,
    'report_type', v_updated.report_type,
    'status', v_updated.status,
    'version_no', v_updated.current_version_no,
    'coverage_id', v_updated.coverage_id,
    'sector_id', v_updated.sector_id,
    'analyst_names',
      coalesce(
        (
          select jsonb_agg(coalesce(a.full_name, 'Unknown') order by ra.sort_order)
          from public.report_analyst ra
          left join public.analyst a on a.id = ra.analyst_id
          where ra.report_id = p_report_id
        ),
        '[]'::jsonb
      ),
    'analysts',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'analyst_id', ra.analyst_id,
              'analyst_name', coalesce(a.full_name, 'Unknown'),
              'role', ra.role,
              'sort_order', ra.sort_order
            )
            order by ra.sort_order
          )
          from public.report_analyst ra
          left join public.analyst a on a.id = ra.analyst_id
          where ra.report_id = p_report_id
        ),
        '[]'::jsonb
      )
  );

  insert into public.report_version (
    report_id,
    version_no,
    snapshot_json,
    word_file_path,
    model_file_path,
    changed_by,
    changed_at
  )
  values (
    p_report_id,
    v_next_version,
    v_snapshot,
    p_word_file_path,
    p_model_file_path,
    p_changed_by,
    now()
  );

  return v_updated;
end;
$$;

-- =============================================================================
-- 10. Report status change atomic RPC
-- =============================================================================
create or replace function public.report_change_status_atomic(
  p_report_id uuid,
  p_to_status text,
  p_action_by uuid,
  p_reason text default null
)
returns public.report
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current public.report%rowtype;
  v_updated public.report%rowtype;
  v_now timestamptz := now();
  v_role text := public.current_app_role();
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'unauthorized';
  end if;

  if p_action_by is distinct from v_uid then
    raise exception 'action_by must match auth.uid';
  end if;

  select *
    into v_current
  from public.report
  where id = p_report_id
  for update;

  if not found then
    raise exception 'report not found or no permission';
  end if;

  if v_role = 'admin' then
    null;
  elsif v_role = 'sa' then
    if not (
      (v_current.status = 'submitted' and p_to_status in ('published', 'rejected'))
      or (v_current.status = 'rejected' and p_to_status = 'draft')
    ) then
      raise exception 'no permission for this status transition';
    end if;
  elsif v_role = 'analyst' then
    if not (
      v_current.owner_user_id = v_uid
      and v_current.status = 'draft'
      and p_to_status = 'submitted'
    ) then
      raise exception 'no permission for this status transition';
    end if;
  else
    raise exception 'no permission';
  end if;

  update public.report
  set
    status = p_to_status,
    published_by = case when p_to_status = 'published' then p_action_by else published_by end,
    published_at = case when p_to_status = 'published' then v_now else published_at end
  where id = p_report_id
  returning *
    into v_updated;

  insert into public.report_status_log (
    report_id,
    from_status,
    to_status,
    action_by,
    action_at,
    reason,
    version_no
  )
  values (
    p_report_id,
    v_current.status,
    p_to_status,
    p_action_by,
    v_now,
    nullif(btrim(coalesce(p_reason, '')), ''),
    v_current.current_version_no
  );

  return v_updated;
end;
$$;

-- =============================================================================
-- 11. Add action_by_name to report_status_log
-- =============================================================================
alter table public.report_status_log
  add column if not exists action_by_name text;

-- Update existing records with names from analyst table (by email matching)
update public.report_status_log rsl
set action_by_name = a.full_name
from public.analyst a
where a.email = (
  select email from auth.users where id = rsl.action_by
);

-- Create index for the new column
create index if not exists idx_report_status_log_action_by_name
  on public.report_status_log (action_by_name);

-- Update the RPC function to include action_by_name
create or replace function public.report_change_status_atomic(
  p_report_id uuid,
  p_to_status text,
  p_action_by uuid,
  p_reason text default null
)
returns public.report
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current public.report%rowtype;
  v_updated public.report%rowtype;
  v_now timestamptz := now();
  v_role text := public.current_app_role();
  v_uid uuid := auth.uid();
  v_action_by_name text;
begin
  if v_uid is null then
    raise exception 'unauthorized';
  end if;

  if p_action_by is distinct from v_uid then
    raise exception 'action_by must match auth.uid';
  end if;

  -- Get action_by_name from analyst table
  select a.full_name into v_action_by_name
  from public.analyst a
  inner join auth.users u on u.email = a.email
  where u.id = p_action_by;

  select *
    into v_current
  from public.report
  where id = p_report_id
  for update;

  if not found then
    raise exception 'report not found or no permission';
  end if;

  if v_role = 'admin' then
    null;
  elsif v_role = 'sa' then
    if not (
      (v_current.status = 'submitted' and p_to_status in ('published', 'rejected'))
      or (v_current.status = 'rejected' and p_to_status = 'draft')
    ) then
      raise exception 'no permission for this status transition';
    end if;
  elsif v_role = 'analyst' then
    if not (
      v_current.owner_user_id = v_uid
      and v_current.status = 'draft'
      and p_to_status = 'submitted'
    ) then
      raise exception 'no permission for this status transition';
    end if;
  else
    raise exception 'no permission';
  end if;

  update public.report
  set
    status = p_to_status,
    published_by = case when p_to_status = 'published' then p_action_by else published_by end,
    published_at = case when p_to_status = 'published' then v_now else published_at end
  where id = p_report_id
  returning *
    into v_updated;

  insert into public.report_status_log (
    report_id,
    from_status,
    to_status,
    action_by,
    action_by_name,
    action_at,
    reason,
    version_no
  )
  values (
    p_report_id,
    v_current.status,
    p_to_status,
    p_action_by,
    v_action_by_name,
    v_now,
    nullif(btrim(coalesce(p_reason, '')), ''),
    v_current.current_version_no
  );

  return v_updated;
end;
$$;

-- =============================================================================
-- 12. Report submission rules enhancement
-- =============================================================================
alter table public.report
  drop constraint if exists report_report_type_check;

alter table public.template
  alter column uploaded_by drop not null;

update public.template
set report_type = replace(report_type, '-', '_')
where report_type in ('company-flash', 'sector-flash');

insert into public.template (
  name,
  report_type,
  file_type,
  file_path,
  version,
  is_active,
  uploaded_by
)
select
  src.name,
  src.report_type,
  'word',
  '',
  1,
  false,
  null
from (
  values
    ('Placeholder Company Template', 'company'),
    ('Placeholder Sector Template', 'sector'),
    ('Placeholder Company Flash Template', 'company_flash'),
    ('Placeholder Sector Flash Template', 'sector_flash'),
    ('Placeholder Common Template', 'common')
) as src(name, report_type)
where not exists (
  select 1
  from public.template t
  where t.report_type = src.report_type
);

alter table public.report
  add column if not exists ticker text,
  add column if not exists rating text,
  add column if not exists target_price text,
  add column if not exists region_id uuid references public.region(id) on delete set null,
  add column if not exists report_language text check (report_language in ('zh', 'en')),
  add column if not exists contact_person text,
  add column if not exists investment_thesis text,
  add column if not exists certificate_confirmed boolean not null default false;

create index if not exists idx_report_region_id on public.report(region_id);

-- =============================================================================
-- 13. Add file name fields to report_version
-- =============================================================================
alter table public.report_version
add column if not exists word_file_name text,
add column if not exists model_file_name text;

-- =============================================================================
-- 14. Update RPC for file names
-- =============================================================================
-- (This is handled in later migrations - the function is updated multiple times)

-- =============================================================================
-- 15. Get user full name function
-- =============================================================================
create or replace function public.get_user_full_name(p_user_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_full_name text;
begin
  select raw_user_meta_data->>'full_name'
    into v_full_name
  from auth.users
  where id = p_user_id;

  return v_full_name;
end;
$$;

-- =============================================================================
-- 16. Change contact_person to contact_person_id
-- =============================================================================
alter table public.report
  drop column if exists contact_person;

alter table public.report
  add column if not exists contact_person_id uuid references auth.users(id) on delete set null;

create index if not exists idx_report_contact_person_id on public.report(contact_person_id);

-- =============================================================================
-- 17. Add chief approval screenshot fields to report_version
-- =============================================================================
alter table public.report_version
add column if not exists chief_approval_screenshot_path text,
add column if not exists chief_approval_screenshot_name text;

-- =============================================================================
-- 18. Change target_price to numeric
-- =============================================================================
alter table public.report
  alter column target_price type numeric using target_price::numeric;

alter table public.report
  drop constraint if exists report_target_price_check;
alter table public.report
  add constraint report_target_price_check check (target_price is null or target_price > 0);

-- =============================================================================
-- 19. Create rating table
-- =============================================================================
create table if not exists public.rating (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique,
  sort integer not null default 1,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table public.rating is '投资评级表：存储研究报告的投资评级选项';
comment on column public.rating.id is '主键UUID';
comment on column public.rating.name is '评级名称（中文）';
comment on column public.rating.code is '评级代码（英文缩写）';
comment on column public.rating.sort is '排序权重';
comment on column public.rating.is_active is '是否启用';
comment on column public.rating.created_at is '创建时间';

create index if not exists idx_rating_sort on public.rating(sort);
create index if not exists idx_rating_code on public.rating(code);
create index if not exists idx_rating_is_active on public.rating(is_active);

alter table public.rating enable row level security;

drop policy if exists rating_select_authenticated on public.rating;
create policy rating_select_authenticated
on public.rating
for select
to authenticated
using (true);

insert into public.rating (name, code, sort, is_active) values
  ('优于大市', 'OUTPERFORM', 1, true),
  ('中性', 'NEUTRAL', 2, true),
  ('弱于大市', 'UNDERPERFORM', 3, true),
  ('未评级', 'NON_RATED', 4, true)
on conflict (code) do nothing;

-- =============================================================================
-- 20. Create report_type table
-- =============================================================================
create table if not exists public.report_type (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique,
  sort integer not null default 1,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table public.report_type is '报告类型表：存储研究报告的分类选项';
comment on column public.report_type.id is '主键UUID';
comment on column public.report_type.name is '报告类型名称（中文）';
comment on column public.report_type.code is '报告类型代码（英文）';
comment on column public.report_type.sort is '排序权重';
comment on column public.report_type.is_active is '是否启用';
comment on column public.report_type.created_at is '创建时间';

create index if not exists idx_report_type_sort on public.report_type(sort);
create index if not exists idx_report_type_code on public.report_type(code);
create index if not exists idx_report_type_is_active on public.report_type(is_active);

alter table public.report_type enable row level security;

drop policy if exists report_type_select_authenticated on public.report_type;
create policy report_type_select_authenticated
on public.report_type
for select
to authenticated
using (true);

insert into public.report_type (name, code, sort, is_active) values
  ('公司报告', 'company', 1, true),
  ('行业报告', 'sector', 2, true),
  ('公司快评报告', 'company_flash', 3, true),
  ('行业快评报告', 'sector_flash', 4, true),
  ('宏观报告', 'macro', 5, true),
  ('策略报告', 'strategy', 6, true),
  ('量化报告', 'quantitative', 7, true),
  ('债券报告', 'bond', 8, true)
on conflict (code) do nothing;

-- =============================================================================
-- 21. Create chief_approve table
-- =============================================================================
create table if not exists public.chief_approve (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.report(id) on delete cascade,
  file_path text not null,
  file_name text not null,
  file_type text not null,
  created_at timestamptz not null default now()
);

comment on table public.chief_approve is '首席确认附件表：存储首席审核确认时的附件信息';
comment on column public.chief_approve.id is '主键UUID';
comment on column public.chief_approve.report_id is '关联报告ID';
comment on column public.chief_approve.file_path is '文件存储路径';
comment on column public.chief_approve.file_name is '原始文件名';
comment on column public.chief_approve.file_type is '文件MIME类型';
comment on column public.chief_approve.created_at is '创建时间';

create index if not exists idx_chief_approve_report_id on public.chief_approve(report_id);
create index if not exists idx_chief_approve_created_at on public.chief_approve(created_at);

alter table public.chief_approve enable row level security;

drop policy if exists chief_approve_select on public.chief_approve;
create policy chief_approve_select
on public.chief_approve
for select
to authenticated
using (
  exists (
    select 1 from public.report
    where id = chief_approve.report_id
    and owner_user_id = auth.uid()
  )
  or public.current_app_role() in ('sa', 'admin')
);

drop policy if exists chief_approve_insert on public.chief_approve;
create policy chief_approve_insert
on public.chief_approve
for insert
to authenticated
with check (
  exists (
    select 1 from public.report
    where id = chief_approve.report_id
    and owner_user_id = auth.uid()
  )
  or public.current_app_role() in ('sa', 'admin')
);

drop policy if exists chief_approve_update on public.chief_approve;
create policy chief_approve_update
on public.chief_approve
for update
to authenticated
using (
  exists (
    select 1 from public.report
    where id = chief_approve.report_id
    and owner_user_id = auth.uid()
  )
  or public.current_app_role() in ('sa', 'admin')
);

drop policy if exists chief_approve_delete on public.chief_approve;
create policy chief_approve_delete
on public.chief_approve
for delete
to authenticated
using (
  exists (
    select 1 from public.report
    where id = chief_approve.report_id
    and owner_user_id = auth.uid()
  )
  or public.current_app_role() in ('sa', 'admin')
);

-- =============================================================================
-- 22. Drop chief_approval_screenshot columns from report_version
-- =============================================================================
alter table public.report_version drop column if exists chief_approval_screenshot_path;
alter table public.report_version drop column if exists chief_approval_screenshot_name;

-- =============================================================================
-- 23. Update report_save_content_atomic (remove chief_approval)
-- =============================================================================
-- This function is updated multiple times - see later sections

-- =============================================================================
-- 24. Create rqc_approve table
-- =============================================================================
create table if not exists public.rqc_approve (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.report(id) on delete cascade,
  file_path text not null,
  file_name text not null,
  file_type text not null,
  created_at timestamptz not null default now()
);

comment on table public.rqc_approve is 'RQC审批确认附件表：存储RQC审核确认时的附件信息';
comment on column public.rqc_approve.id is '主键UUID';
comment on column public.rqc_approve.report_id is '关联报告ID';
comment on column public.rqc_approve.file_path is '文件存储路径';
comment on column public.rqc_approve.file_name is '原始文件名';
comment on column public.rqc_approve.file_type is '文件MIME类型';
comment on column public.rqc_approve.created_at is '创建时间';

create index if not exists idx_rqc_approve_report_id on public.rqc_approve(report_id);
create index if not exists idx_rqc_approve_created_at on public.rqc_approve(created_at);

alter table public.rqc_approve enable row level security;

drop policy if exists rqc_approve_select on public.rqc_approve;
create policy rqc_approve_select
on public.rqc_approve
for select
to authenticated
using (
  exists (
    select 1 from public.report
    where id = rqc_approve.report_id
    and owner_user_id = auth.uid()
  )
  or public.current_app_role() in ('sa', 'admin')
);

drop policy if exists rqc_approve_insert on public.rqc_approve;
create policy rqc_approve_insert
on public.rqc_approve
for insert
to authenticated
with check (
  exists (
    select 1 from public.report
    where id = rqc_approve.report_id
    and owner_user_id = auth.uid()
  )
  or public.current_app_role() in ('sa', 'admin')
);

drop policy if exists rqc_approve_update on public.rqc_approve;
create policy rqc_approve_update
on public.rqc_approve
for update
to authenticated
using (
  exists (
    select 1 from public.report
    where id = rqc_approve.report_id
    and owner_user_id = auth.uid()
  )
  or public.current_app_role() in ('sa', 'admin')
);

drop policy if exists rqc_approve_delete on public.rqc_approve;
create policy rqc_approve_delete
on public.rqc_approve
for delete
to authenticated
using (
  exists (
    select 1 from public.report
    where id = rqc_approve.report_id
    and owner_user_id = auth.uid()
  )
  or public.current_app_role() in ('sa', 'admin')
);

-- =============================================================================
-- 25. Modify region table (bilingual support)
-- =============================================================================
-- Note: This migration drops region table columns and recreates them
-- This is a complex migration that may cause data loss if not run properly
-- The full implementation is in the original migration file

-- Drop old indexes and trigger first
drop index if exists idx_region_created_at_desc;
drop trigger if exists trg_region_updated_at on public.region;

-- Drop foreign key constraints
alter table public.report drop constraint if exists report_region_code_fkey;
alter table public.analyst drop constraint if exists analyst_region_code_fkey;

-- Drop old columns
alter table public.region drop column if exists name;
alter table public.region drop column if exists code;

-- Add new columns
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'region' AND column_name = 'name_en') THEN
    alter table public.region add column name_en text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'region' AND column_name = 'name_cn') THEN
    alter table public.region add column name_cn text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'region' AND column_name = 'code') THEN
    alter table public.region add column code text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'region' AND column_name = 'is_active') THEN
    alter table public.region add column is_active boolean not null default true;
  END IF;
END $$;

-- Delete rows with null values before seeding
delete from public.region where code is null or code = '';

-- Seed initial data
insert into public.region (name_en, name_cn, code, is_active) values
  ('China', '中国', 'CN', true),
  ('Hong Kong', '香港', 'HK', true),
  ('Japan', '日本', 'JP', true),
  ('Taiwan', '台湾', 'TW', true),
  ('South Korea', '韩国', 'KR', true),
  ('India', '印度', 'IN', true),
  ('Macau', '澳门', 'MO', true),
  ('United States', '美国', 'US', true)
on conflict do nothing;

-- Delete old rows with empty values
delete from public.region where name_en is null or name_en = '';

-- Set not null constraints
alter table public.region alter column name_en set not null;
alter table public.region alter column name_cn set not null;
alter table public.region alter column code set not null;

-- Add comments
comment on table public.region is 'Region table - stores region information with bilingual names and ISO 3166-1 alpha-2 codes';
comment on column public.region.name_en is 'Region English name';
comment on column public.region.name_cn is 'Region Chinese name';
comment on column public.region.code is 'ISO 3166-1 alpha-2 country/region code';
comment on column public.region.is_active is 'Whether the region is active';

-- Add unique constraints
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uk_region_name_en') THEN
    alter table public.region add constraint uk_region_name_en unique (name_en);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uk_region_name_cn') THEN
    alter table public.region add constraint uk_region_name_cn unique (name_cn);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uk_region_code') THEN
    alter table public.region add constraint uk_region_code unique (code);
  END IF;
END $$;

-- Recreate indexes
create index if not exists idx_region_created_at_desc
  on public.region (created_at desc);

-- Recreate trigger
create trigger trg_region_updated_at
before update on public.region
for each row execute function public.set_updated_at_utc();

-- =============================================================================
-- 26. Change report region_id to region_code
-- =============================================================================
alter table public.report drop constraint if exists report_region_id_fkey;
alter table public.report drop column if exists region_id;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'report' AND column_name = 'region_code'
  ) THEN
    alter table public.report add column region_code text references public.region(code) on delete set null;
  END IF;
END $$;

comment on column public.report.region_code is 'Region code (ISO 3166-1 alpha-2), references region.code';

-- =============================================================================
-- 27. Update RPC functions for region_code
-- =============================================================================
-- (RPC functions are updated in later migrations)

-- =============================================================================
-- 28. Change analyst region_id to region_code
-- =============================================================================
alter table public.analyst drop constraint if exists analyst_region_id_fkey;
alter table public.analyst drop column if exists region_id;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'analyst' AND column_name = 'region_code'
  ) THEN
    alter table public.analyst add column region_code text references public.region(code) on delete set null;
  END IF;
END $$;

comment on column public.analyst.region_code is 'Region code (ISO 3166-1 alpha-2), references region.code';

-- =============================================================================
-- 29. Create stock_quotes table
-- =============================================================================
create table if not exists public.stock_quotes (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  mkt_code text not null,
  trade_date date not null,
  close_price numeric(18, 4),
  volume bigint,
  market_cap numeric(18, 2),
  shares_mn numeric(18, 2),
  year_high numeric(18, 4),
  year_low numeric(18, 4),
  created_at timestamptz not null default now()
);

comment on table public.stock_quotes is '股票行情表：存储股票的每日行情数据';
comment on column public.stock_quotes.id is '主键UUID';
comment on column public.stock_quotes.code is '股票代码';
comment on column public.stock_quotes.mkt_code is '市场代码';
comment on column public.stock_quotes.trade_date is '交易日';
comment on column public.stock_quotes.close_price is '收盘价';
comment on column public.stock_quotes.volume is '成交量';
comment on column public.stock_quotes.market_cap is '市值（十亿美元）';
comment on column public.stock_quotes.shares_mn is '流通股数（百万股）';
comment on column public.stock_quotes.year_high is '一年最高价';
comment on column public.stock_quotes.year_low is '一年最低价';
comment on column public.stock_quotes.created_at is '创建时间';

create index if not exists idx_stock_quotes_code_mkt on public.stock_quotes(code, mkt_code);
create index if not exists idx_stock_quotes_trade_date on public.stock_quotes(trade_date);
create index if not exists idx_stock_quotes_code_mkt_date on public.stock_quotes(code, mkt_code, trade_date);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uk_stock_quotes_code_mkt_date') THEN
    alter table public.stock_quotes add constraint uk_stock_quotes_code_mkt_date unique (code, mkt_code, trade_date);
  END IF;
END $$;

alter table public.stock_quotes enable row level security;

drop policy if exists stock_quotes_select_all on public.stock_quotes;
create policy stock_quotes_select_all
on public.stock_quotes
for select
to anon, authenticated
using (true);

drop policy if exists stock_quotes_insert_all on public.stock_quotes;
create policy stock_quotes_insert_all
on public.stock_quotes
for insert
to anon, authenticated
with check (true);

drop policy if exists stock_quotes_update_all on public.stock_quotes;
create policy stock_quotes_update_all
on public.stock_quotes
for update
to anon, authenticated
using (true);

drop policy if exists stock_quotes_delete_all on public.stock_quotes;
create policy stock_quotes_delete_all
on public.stock_quotes
for delete
to anon, authenticated
using (true);

-- =============================================================================
-- 30. Create index_quotes table
-- =============================================================================
create table if not exists public.index_quotes (
  id uuid primary key default gen_random_uuid(),
  index_code text not null,
  index_name text not null,
  trade_date date not null,
  close_price numeric(18, 4),
  created_at timestamptz not null default now()
);

comment on table public.index_quotes is '指数行情表：存储指数的每日行情数据';
comment on column public.index_quotes.id is '主键UUID';
comment on column public.index_quotes.index_code is '指数代码';
comment on column public.index_quotes.index_name is '指数名称';
comment on column public.index_quotes.trade_date is '交易日';
comment on column public.index_quotes.close_price is '收盘价/收盘点位';
comment on column public.index_quotes.created_at is '创建时间';

create index if not exists idx_index_quotes_code on public.index_quotes(index_code);
create index if not exists idx_index_quotes_trade_date on public.index_quotes(trade_date);
create index if not exists idx_index_quotes_code_date on public.index_quotes(index_code, trade_date);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uk_index_quotes_code_date') THEN
    alter table public.index_quotes add constraint uk_index_quotes_code_date unique (index_code, trade_date);
  END IF;
END $$;

alter table public.index_quotes enable row level security;

drop policy if exists index_quotes_select_all on public.index_quotes;
create policy index_quotes_select_all
on public.index_quotes
for select
to anon, authenticated
using (true);

drop policy if exists index_quotes_insert_all on public.index_quotes;
create policy index_quotes_insert_all
on public.index_quotes
for insert
to anon, authenticated
with check (true);

drop policy if exists index_quotes_update_all on public.index_quotes;
create policy index_quotes_update_all
on public.index_quotes
for update
to anon, authenticated
using (true);

drop policy if exists index_quotes_delete_all on public.index_quotes;
create policy index_quotes_delete_all
on public.index_quotes
for delete
to anon, authenticated
using (true);

-- =============================================================================
-- 31. Add index_code to coverage
-- =============================================================================
alter table public.coverage
add column if not exists index_code text;

comment on column public.coverage.index_code is '关联的指数代码，关联 index_quotes 表的 index_code';

create index if not exists idx_coverage_index_code on public.coverage(index_code);

-- =============================================================================
-- 32. Add auto-set index_code trigger
-- =============================================================================
create or replace function public.set_coverage_index_code()
returns trigger
language plpgsql
as $$
begin
  if new.country_of_domicile is distinct from old.country_of_domicile then
    case new.country_of_domicile
      when 'CN' then
        new.index_code := '000001.SS';
      when 'HK' then
        new.index_code := '000001.SS';
      when 'MO' then
        new.index_code := '000001.SS';
      when 'US' then
        new.index_code := '^GSPC';
      when 'JP' then
        new.index_code := '^TOPX';
      when 'KR' then
        new.index_code := '^KS11';
      when 'IN' then
        new.index_code := '^NSEI';
      when 'TW' then
        new.index_code := '^TWII';
      else
        new.index_code := null;
    end case;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_coverage_set_index_code on public.coverage;
create trigger trg_coverage_set_index_code
before insert or update of country_of_domicile on public.coverage
for each row
execute function public.set_coverage_index_code();

comment on function public.set_coverage_index_code() is '根据 country_of_domicile 自动设置 index_code 的触发器函数';

-- =============================================================================
-- 33. Change template file_type
-- =============================================================================
ALTER TABLE public.template DROP CONSTRAINT IF EXISTS template_file_type_check;

UPDATE public.template SET file_type = 'report'
WHERE file_type NOT IN ('report', 'model')
   OR file_type IS NULL
   OR file_type = '';

ALTER TABLE public.template ADD CONSTRAINT template_file_type_check CHECK (file_type IN ('report', 'model'));

-- Handle duplicate records
DELETE FROM public.template t1
WHERE EXISTS (
  SELECT 1 FROM public.template t2
  WHERE t2.report_type = t1.report_type
    AND t2.file_type = t1.file_type
    AND t2.version = t1.version
    AND t2.id > t1.id
);

ALTER TABLE public.template DROP CONSTRAINT IF EXISTS template_uniq_version;
ALTER TABLE public.template ADD CONSTRAINT template_uniq_version unique (report_type, file_type, version);

DROP INDEX IF EXISTS template_report_type_file_type_active_idx;
CREATE UNIQUE INDEX template_report_type_file_type_active_idx
ON public.template (report_type, file_type)
WHERE is_active = true;

-- =============================================================================
-- 34. Update RPC for region_code
-- =============================================================================
-- The RPC function is updated to use region_code instead of region_id

-- =============================================================================
-- 35. Add language to template
-- =============================================================================
ALTER TABLE public.template ADD COLUMN IF NOT EXISTS language text NOT NULL DEFAULT 'en';

ALTER TABLE public.template DROP CONSTRAINT IF EXISTS template_language_check;
ALTER TABLE public.template ADD CONSTRAINT template_language_check CHECK (language IN ('en', 'zh'));

ALTER TABLE public.template DROP CONSTRAINT IF EXISTS template_uniq_version;
ALTER TABLE public.template ADD CONSTRAINT template_uniq_version unique (report_type, file_type, language, version);

DROP INDEX IF EXISTS uidx_template_active_one;
CREATE UNIQUE INDEX uidx_template_active_one
ON public.template(report_type, file_type, language)
WHERE is_active = true;

DROP INDEX IF EXISTS idx_template_group;
CREATE INDEX idx_template_group
ON public.template(report_type, file_type, language);

-- =============================================================================
-- 36. Fix template unique index
-- =============================================================================
DROP INDEX IF EXISTS template_report_type_file_type_active_idx;

CREATE UNIQUE INDEX template_report_type_file_type_active_idx
ON public.template (report_type, language, file_type)
WHERE is_active = true;

-- =============================================================================
-- 37. Add PDF columns to report_version
-- =============================================================================
alter table public.report_version
add column if not exists pdf_file_path text,
add column if not exists pdf_file_name text;

create index if not exists idx_report_version_pdf_file_path
on public.report_version(pdf_file_path)
where pdf_file_path is not null;

-- =============================================================================
-- 38. Update report_save_content_atomic RPC with PDF fields
-- =============================================================================
DO $$
BEGIN
  DROP FUNCTION IF EXISTS public.report_save_content_atomic(uuid, text, text, text, text, numeric, text, uuid, text, uuid, text, boolean, uuid, jsonb, uuid, text, text, text, text, text, text);
END $$;

CREATE OR REPLACE FUNCTION public.report_save_content_atomic(
  p_report_id uuid,
  p_title text,
  p_report_type text,
  p_ticker text,
  p_rating text,
  p_target_price text,
  p_region_code text,
  p_sector_id uuid,
  p_report_language text,
  p_contact_person_id uuid,
  p_investment_thesis text,
  p_certificate_confirmed boolean,
  p_coverage_id uuid,
  p_analysts jsonb,
  p_changed_by uuid,
  p_word_file_path text,
  p_pdf_file_path text,
  p_model_file_path text,
  p_word_file_name text,
  p_pdf_file_name text,
  p_model_file_name text
)
RETURNS public.report
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $BODY$
DECLARE
  v_report public.report;
  v_current_version_no integer;
  v_updated public.report;
BEGIN
  SELECT current_version_no INTO v_current_version_no
  FROM public.report
  WHERE id = p_report_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Report not found';
  END IF;

  UPDATE public.report
  SET
    title = p_title,
    report_type = p_report_type,
    ticker = p_ticker,
    rating = p_rating,
    target_price = CASE WHEN p_target_price IS NULL OR p_target_price = '' THEN NULL ELSE p_target_price::numeric END,
    region_code = p_region_code,
    sector_id = p_sector_id,
    report_language = p_report_language,
    contact_person_id = p_contact_person_id,
    investment_thesis = p_investment_thesis,
    certificate_confirmed = p_certificate_confirmed,
    coverage_id = p_coverage_id,
    current_version_no = v_current_version_no + 1,
    updated_at = NOW()
  WHERE id = p_report_id
  RETURNING * INTO v_report;

  INSERT INTO public.report_version (
    id,
    report_id,
    version_no,
    snapshot_json,
    word_file_path,
    pdf_file_path,
    model_file_path,
    word_file_name,
    pdf_file_name,
    model_file_name,
    changed_by,
    changed_at,
    created_at
  ) VALUES (
    gen_random_uuid(),
    p_report_id,
    v_current_version_no + 1,
    jsonb_build_object(
      'title', p_title,
      'report_type', p_report_type,
      'ticker', p_ticker,
      'rating', p_rating,
      'target_price', p_target_price,
      'region_code', p_region_code,
      'sector_id', p_sector_id,
      'report_language', p_report_language,
      'contact_person_id', p_contact_person_id,
      'investment_thesis', p_investment_thesis,
      'certificate_confirmed', p_certificate_confirmed,
      'coverage_id', p_coverage_id,
      'analysts', p_analysts
    ),
    p_word_file_path,
    p_pdf_file_path,
    p_model_file_path,
    p_word_file_name,
    p_pdf_file_name,
    p_model_file_name,
    p_changed_by,
    NOW(),
    NOW()
  );

  DELETE FROM public.report_analyst WHERE report_id = p_report_id;

  IF p_analysts IS NOT NULL AND jsonb_array_length(p_analysts) > 0 THEN
    INSERT INTO public.report_analyst (id, report_id, analyst_id, role, sort_order, created_at, updated_at)
    SELECT
      gen_random_uuid(),
      p_report_id,
      (elem->>'analyst_id')::uuid,
      (elem->>'role')::smallint,
      (elem->>'sort_order')::smallint,
      NOW(),
      NOW()
    FROM jsonb_array_elements(p_analysts) AS elem;
  END IF;

  RETURN v_report;
END;
$BODY$;

-- =============================================================================
-- Migration Complete
-- =============================================================================
