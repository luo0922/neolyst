-- ============================================================
-- 基础扩展和公共函数
-- 依赖：无
-- ============================================================

-- 扩展
create extension if not exists pgcrypto;
create extension if not exists citext;

-- 公共函数：自动更新时间戳
create or replace function public.set_updated_at_utc()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- 公共函数：获取当前应用角色
create or replace function public.current_app_role()
returns text
language sql
stable
as $$
  select coalesce(auth.jwt()->'app_metadata'->>'role', '');
$$;

-- 公共函数：报告状态转换验证
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

-- 公共函数：获取用户全名
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