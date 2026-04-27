-- 报告外部推送日志表

-- -----------------------------------------------------------------------------
-- 1. report_push_log 表
-- -----------------------------------------------------------------------------
create table if not exists public.report_push_log (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.report(id) on delete cascade,
  status text not null check (status in ('success', 'failed', 'pending')),
  http_status_code integer,
  response_body text,
  error_message text,
  payload_sent jsonb,
  trigger_type text not null check (trigger_type in ('auto', 'manual')),
  triggered_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

comment on table public.report_push_log is '报告外部推送日志记录表';
comment on column public.report_push_log.report_id is '关联报告ID';
comment on column public.report_push_log.status is '推送状态: success/failed/pending';
comment on column public.report_push_log.http_status_code is '外部接口返回的HTTP状态码';
comment on column public.report_push_log.response_body is '外部接口响应体（截断至2000字符）';
comment on column public.report_push_log.error_message is '错误信息（网络异常/超时等）';
comment on column public.report_push_log.payload_sent is '本次推送的完整payload（附件内容不存储）';
comment on column public.report_push_log.trigger_type is '触发类型: auto（自动推送）/manual（手动重推）';
comment on column public.report_push_log.triggered_by is '触发人';

-- -----------------------------------------------------------------------------
-- 2. 索引
-- -----------------------------------------------------------------------------
create index if not exists idx_report_push_log_report_created
  on public.report_push_log(report_id, created_at desc);
create index if not exists idx_report_push_log_triggered_by_created
  on public.report_push_log(triggered_by, created_at desc);

-- -----------------------------------------------------------------------------
-- 3. INSERT-only 保护 trigger
-- -----------------------------------------------------------------------------
create or replace function public.trg_report_push_log_no_update_delete()
returns trigger language plpgsql as $$
begin
  raise exception 'UPDATE and DELETE on report_push_log are not allowed';
end;
$$;

drop trigger if exists trg_report_push_log_no_update_delete on public.report_push_log;
create trigger trg_report_push_log_no_update_delete
  before update or delete on public.report_push_log
  for each row execute function public.trg_report_push_log_no_update_delete();

-- -----------------------------------------------------------------------------
-- 4. 行级安全策略 (RLS)
-- -----------------------------------------------------------------------------
alter table public.report_push_log enable row level security;

-- Admin: 全部可见
drop policy if exists report_push_log_select_admin on public.report_push_log;
create policy report_push_log_select_admin
  on public.report_push_log
  for select
  using (auth.jwt() ->> 'role' = 'admin');

-- SA: 仅可见 submitted/published/rejected 报告的推送记录
drop policy if exists report_push_log_select_sa on public.report_push_log;
create policy report_push_log_select_sa
  on public.report_push_log
  for select
  using (
    auth.jwt() ->> 'role' = 'sa'
    and exists (
      select 1 from public.report r
      where r.id = report_push_log.report_id
        and r.status in ('submitted', 'published', 'rejected')
    )
  );

-- Analyst: 仅可见自己的报告的推送记录
drop policy if exists report_push_log_select_analyst on public.report_push_log;
create policy report_push_log_select_analyst
  on public.report_push_log
  for select
  using (
    auth.jwt() ->> 'role' = 'analyst'
    and exists (
      select 1 from public.report r
      where r.id = report_push_log.report_id
        and r.owner_user_id = (auth.jwt() ->> 'id')::uuid
    )
  );

-- INSERT: 仅 Admin 可手动补录（自动写入由 service_role key 触发）
drop policy if exists report_push_log_insert_admin on public.report_push_log;
create policy report_push_log_insert_admin
  on public.report_push_log
  for insert
  with check (auth.jwt() ->> 'role' = 'admin');
