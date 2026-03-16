-- 报告分发系统 - 邮件订阅与配置表

-- -----------------------------------------------------------------------------
-- 1. 邮件订阅表
-- -----------------------------------------------------------------------------
create table if not exists public.email_subscription (
  id uuid primary key default gen_random_uuid(),
  email varchar(255) not null unique,
  user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  is_active boolean not null default true
);

create index if not exists idx_email_subscription_email on public.email_subscription(email);
create index if not exists idx_email_subscription_user on public.email_subscription(user_id);

-- -----------------------------------------------------------------------------
-- 2. 邮件配置表 (SMTP)
-- -----------------------------------------------------------------------------
create table if not exists public.email_config (
  id uuid primary key default gen_random_uuid(),
  smtp_host varchar(255) not null,
  smtp_port integer not null default 25,
  smtp_user varchar(255) not null,
  smtp_pass varchar(255) not null,
  smtp_from varchar(255) not null,
  is_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- 3. 报告分发队列表
-- -----------------------------------------------------------------------------
create table if not exists public.report_distribution_queue (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.report(id) on delete cascade,
  status varchar(50) not null default 'pending' check (status in ('pending', 'processing', 'completed', 'failed')),
  error_message text,
  scheduled_at timestamptz not null default now(),
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_report_distribution_queue_status on public.report_distribution_queue(status);
create index if not exists idx_report_distribution_queue_report on public.report_distribution_queue(report_id);

-- -----------------------------------------------------------------------------
-- 4. 报告分发历史表
-- -----------------------------------------------------------------------------
create table if not exists public.report_distribution_history (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.report(id) on delete cascade,
  recipient_email varchar(255) not null,
  status varchar(50) not null check (status in ('sent', 'failed')),
  sent_at timestamptz,
  error_message text,
  created_at timestamptz not null default now()
);

create index if not exists idx_report_distribution_history_report on public.report_distribution_history(report_id);
create index if not exists idx_report_distribution_history_email on public.report_distribution_history(recipient_email);

-- -----------------------------------------------------------------------------
-- 行级安全策略 (RLS)
-- -----------------------------------------------------------------------------
alter table public.email_subscription enable row level security;
alter table public.email_config enable row level security;
alter table public.report_distribution_queue enable row level security;
alter table public.report_distribution_history enable row level security;

-- email_subscription 策略
drop policy if exists email_subscription_select_policy on public.email_subscription;
create policy email_subscription_select_policy
on public.email_subscription
for select
to authenticated
using (public.current_app_role() = 'admin' or user_id = auth.uid());

drop policy if exists email_subscription_insert_policy on public.email_subscription;
create policy email_subscription_insert_policy
on public.email_subscription
for insert
to authenticated
with check (public.current_app_role() = 'admin' or user_id = auth.uid());

drop policy if exists email_subscription_update_policy on public.email_subscription;
create policy email_subscription_update_policy
on public.email_subscription
for update
to authenticated
using (public.current_app_role() = 'admin' or user_id = auth.uid())
with check (public.current_app_role() = 'admin' or user_id = auth.uid());

drop policy if exists email_subscription_delete_policy on public.email_subscription;
create policy email_subscription_delete_policy
on public.email_subscription
for delete
to authenticated
using (public.current_app_role() = 'admin' or user_id = auth.uid());

-- email_config 策略（仅管理员）
drop policy if exists email_config_select_policy on public.email_config;
create policy email_config_select_policy
on public.email_config
for select
to authenticated
using (public.current_app_role() = 'admin');

drop policy if exists email_config_insert_policy on public.email_config;
create policy email_config_insert_policy
on public.email_config
for insert
to authenticated
with check (public.current_app_role() = 'admin');

drop policy if exists email_config_update_policy on public.email_config;
create policy email_config_update_policy
on public.email_config
for update
to authenticated
using (public.current_app_role() = 'admin')
with check (public.current_app_role() = 'admin');

-- report_distribution_queue 策略（仅管理员）
drop policy if exists report_distribution_queue_select_policy on public.report_distribution_queue;
create policy report_distribution_queue_select_policy
on public.report_distribution_queue
for select
to authenticated
using (public.current_app_role() = 'admin');

drop policy if exists report_distribution_queue_insert_policy on public.report_distribution_queue;
create policy report_distribution_queue_insert_policy
on public.report_distribution_queue
for insert
to authenticated
with check (public.current_app_role() = 'admin');

drop policy if exists report_distribution_queue_update_policy on public.report_distribution_queue;
create policy report_distribution_queue_update_policy
on public.report_distribution_queue
for update
to authenticated
using (public.current_app_role() = 'admin')
with check (public.current_app_role() = 'admin');

-- report_distribution_history 策略（仅管理员）
drop policy if exists report_distribution_history_select_policy on public.report_distribution_history;
create policy report_distribution_history_select_policy
on public.report_distribution_history
for select
to authenticated
using (public.current_app_role() = 'admin');

drop policy if exists report_distribution_history_insert_policy on public.report_distribution_history;
create policy report_distribution_history_insert_policy
on public.report_distribution_history
for insert
to authenticated
with check (public.current_app_role() = 'admin');

-- -----------------------------------------------------------------------------
-- 辅助函数
-- -----------------------------------------------------------------------------
create or replace function public.add_to_distribution_queue(p_report_id uuid)
returns void
language plpgsql
as $$
begin
  insert into public.report_distribution_queue (report_id, status)
  values (p_report_id, 'pending')
  on conflict do nothing;
end;
$$;

create or replace function public.get_active_subscription_emails()
returns setof text
language sql
stable
as $$
  select email from public.email_subscription
  where is_active = true and email is not null;
$$;
