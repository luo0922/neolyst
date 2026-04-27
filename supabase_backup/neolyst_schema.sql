--
-- PostgreSQL database dump
--



-- Dumped from database version 17.8
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: add_to_distribution_queue(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_to_distribution_queue(p_report_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
  insert into public.report_distribution_queue (report_id, status)
  values (p_report_id, 'pending')
  on conflict do nothing;
end;
$$;


--
-- Name: FUNCTION add_to_distribution_queue(p_report_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.add_to_distribution_queue(p_report_id uuid) IS '将报告添加到分发队列（幂等操作）';


--
-- Name: current_app_role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_app_role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select coalesce(auth.jwt()->'app_metadata'->>'role', '');
$$;


--
-- Name: FUNCTION current_app_role(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.current_app_role() IS '获取当前用户的应用角色（从JWT的app_metadata.role读取）';


--
-- Name: get_active_subscription_emails(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_active_subscription_emails() RETURNS SETOF text
    LANGUAGE sql STABLE
    AS $$
  select email from public.email_subscription
  where is_active = true and email is not null;
$$;


--
-- Name: FUNCTION get_active_subscription_emails(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_active_subscription_emails() IS '获取所有启用状态的订阅邮箱列表';


--
-- Name: get_user_full_name(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_full_name(p_user_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: FUNCTION get_user_full_name(p_user_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_user_full_name(p_user_id uuid) IS '根据用户ID获取用户在auth.users中的full_name';


--
-- Name: prevent_update_delete_append_only(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_update_delete_append_only() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  raise exception 'append-only table: update/delete is not allowed';
end;
$$;


--
-- Name: FUNCTION prevent_update_delete_append_only(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.prevent_update_delete_append_only() IS '触发器函数：禁止对append-only表的UPDATE和DELETE操作';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: report; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_user_id uuid NOT NULL,
    title text NOT NULL,
    report_type text NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    current_version_no integer DEFAULT 0 NOT NULL,
    coverage_id uuid,
    sector_id uuid,
    published_by uuid,
    published_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    ticker text,
    rating text,
    target_price numeric,
    report_language text,
    investment_thesis text,
    certificate_confirmed boolean DEFAULT false NOT NULL,
    contact_person_id uuid,
    region_code text,
    CONSTRAINT report_current_version_no_check CHECK ((current_version_no >= 0)),
    CONSTRAINT report_report_language_check CHECK ((report_language = ANY (ARRAY['zh'::text, 'en'::text]))),
    CONSTRAINT report_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'submitted'::text, 'published'::text, 'rejected'::text]))),
    CONSTRAINT report_target_price_check CHECK (((target_price IS NULL) OR (target_price > (0)::numeric)))
);


--
-- Name: TABLE report; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.report IS '研究报告主表：存储报告的核心信息，支持草稿/提交/发布/驳回状态流转';


--
-- Name: COLUMN report.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.id IS '主键UUID';


--
-- Name: COLUMN report.owner_user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.owner_user_id IS '报告所有者用户ID，关联auth.users，创建后不可变更';


--
-- Name: COLUMN report.title; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.title IS '报告标题';


--
-- Name: COLUMN report.report_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.report_type IS '报告类型代码（如company/sector/company_flash等），合法值由template.report_type驱动';


--
-- Name: COLUMN report.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.status IS '报告状态：draft=草稿，submitted=已提交待审核，published=已发布，rejected=已驳回';


--
-- Name: COLUMN report.current_version_no; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.current_version_no IS '当前版本号（>=0），每次内容更新递增';


--
-- Name: COLUMN report.coverage_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.coverage_id IS '关联公司ID，关联coverage.id，删除公司时置空';


--
-- Name: COLUMN report.sector_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.sector_id IS '关联行业ID，关联sector.id，删除行业时置空';


--
-- Name: COLUMN report.published_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.published_by IS '发布人ID，关联auth.users，仅在published状态时记录';


--
-- Name: COLUMN report.published_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.published_at IS '发布时间，仅在published状态时记录';


--
-- Name: COLUMN report.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.created_at IS '创建时间（UTC）';


--
-- Name: COLUMN report.updated_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.updated_at IS '最后更新时间（UTC）';


--
-- Name: COLUMN report.ticker; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.ticker IS '关联股票代码';


--
-- Name: COLUMN report.rating; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.rating IS '投资评级（如OUTPERFORM/NEUTRAL等）';


--
-- Name: COLUMN report.target_price; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.target_price IS '目标价（numeric类型，必须大于0）';


--
-- Name: COLUMN report.report_language; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.report_language IS '报告语言：zh=中文，en=英文';


--
-- Name: COLUMN report.investment_thesis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.investment_thesis IS '投资要点摘要';


--
-- Name: COLUMN report.certificate_confirmed; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.certificate_confirmed IS '证书确认状态：true=已确认，false=未确认';


--
-- Name: COLUMN report.contact_person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.contact_person_id IS '联系人ID，关联auth.users';


--
-- Name: COLUMN report.region_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report.region_code IS '报告覆盖区域代码，关联region.code，删除区域时置空';


--
-- Name: report_change_status_atomic(uuid, text, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.report_change_status_atomic(p_report_id uuid, p_to_status text, p_action_by uuid, p_reason text DEFAULT NULL::text) RETURNS public.report
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: report_enforce_owner_immutable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.report_enforce_owner_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if tg_op = 'UPDATE' and new.owner_user_id is distinct from old.owner_user_id then
    raise exception 'owner_user_id is immutable';
  end if;
  return new;
end;
$$;


--
-- Name: FUNCTION report_enforce_owner_immutable(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.report_enforce_owner_immutable() IS '触发器函数：禁止修改报告的owner_user_id';


--
-- Name: report_enforce_status_transition(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.report_enforce_status_transition() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if not public.report_status_is_valid(old.status, new.status) then
      raise exception 'invalid report status transition: % -> %', old.status, new.status;
    end if;
  end if;
  return new;
end;
$$;


--
-- Name: FUNCTION report_enforce_status_transition(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.report_enforce_status_transition() IS '触发器函数：验证报告状态转换合法性';


--
-- Name: report_save_content_atomic(uuid, text, text, uuid, uuid, jsonb, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text) RETURNS public.report
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
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


--
-- Name: report_save_content_atomic(uuid, text, text, text, text, numeric, uuid, uuid, text, uuid, text, boolean, uuid, jsonb, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text) RETURNS public.report
    LANGUAGE plpgsql
    AS $$
declare
  v_report public.report;
  v_current_version_no integer;
  v_updated public.report;
begin
  -- 获取当前版本号
  select current_version_no into v_current_version_no
  from public.report
  where id = p_report_id;

  -- 保存内容到 report 表
  update public.report
  set
    title = coalesce(nullif(btrim(p_title), ''), title),
    report_type = coalesce(nullif(btrim(p_report_type), ''), report_type),
    ticker = nullif(btrim(p_ticker), ''),
    rating = nullif(btrim(p_rating), ''),
    target_price = case when p_target_price is null or p_target_price <= 0 then null else p_target_price end,
    region_id = p_region_id,
    sector_id = p_sector_id,
    report_language = nullif(btrim(p_report_language), ''),
    contact_person_id = p_contact_person_id,
    investment_thesis = nullif(btrim(p_investment_thesis), ''),
    certificate_confirmed = p_certificate_confirmed,
    coverage_id = p_coverage_id,
    updated_at = now()
  where id = p_report_id
  returning * into v_updated;

  -- 处理作者关系
  if p_analysts is not null and jsonb_typeof(p_analysts) = 'array' then
    -- 删除旧的作者关系
    delete from public.report_analyst where report_id = p_report_id;

    -- 插入新的作者关系
    insert into public.report_analyst (report_id, analyst_id, role, sort_order)
    select
      p_report_id,
      (elem->>'analyst_id')::uuid,
      (elem->>'role')::smallint,
      (elem->>'sort_order')::smallint
    from jsonb_array_elements(p_analysts) as elem;
  end if;

  -- 处理文件
  if p_word_file_path is not null or p_model_file_path is not null then
    -- 增加版本号
    v_current_version_no := v_current_version_no + 1;

    update public.report
    set current_version_no = v_current_version_no,
        updated_at = now()
    where id = p_report_id;

    -- 插入新版本
    insert into public.report_version (
      report_id,
      version_no,
      snapshot_json,
      word_file_path,
      model_file_path,
      changed_by
    ) values (
      p_report_id,
      v_current_version_no,
      jsonb_build_object(
        'title', v_updated.title,
        'report_type', v_updated.report_type,
        'ticker', v_updated.ticker,
        'rating', v_updated.rating,
        'target_price', v_updated.target_price,
        'region_id', v_updated.region_id,
        'sector_id', v_updated.sector_id,
        'report_language', v_updated.report_language,
        'contact_person_id', v_updated.contact_person_id,
        'investment_thesis', v_updated.investment_thesis,
        'certificate_confirmed', v_updated.certificate_confirmed,
        'coverage_id', v_updated.coverage_id
      ),
      p_word_file_path,
      p_model_file_path,
      p_changed_by
    );
  end if;

  -- 返回更新后的报告
  select * into v_report from public.report where id = p_report_id;
  return v_report;
end;
$$;


--
-- Name: report_save_content_atomic(uuid, text, text, text, text, text, uuid, uuid, text, text, text, boolean, uuid, jsonb, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person text, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text) RETURNS public.report
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
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
    ticker = nullif(btrim(coalesce(p_ticker, '')), ''),
    rating = nullif(btrim(coalesce(p_rating, '')), ''),
    target_price = nullif(btrim(coalesce(p_target_price, '')), ''),
    region_id = p_region_id,
    sector_id = p_sector_id,
    report_language = nullif(btrim(coalesce(p_report_language, '')), ''),
    contact_person = nullif(btrim(coalesce(p_contact_person, '')), ''),
    investment_thesis = nullif(btrim(coalesce(p_investment_thesis, '')), ''),
    certificate_confirmed = coalesce(p_certificate_confirmed, false),
    coverage_id = p_coverage_id,
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
    'ticker', v_updated.ticker,
    'rating', v_updated.rating,
    'target_price', v_updated.target_price,
    'region_id', v_updated.region_id,
    'sector_id', v_updated.sector_id,
    'report_language', v_updated.report_language,
    'contact_person', v_updated.contact_person,
    'investment_thesis', v_updated.investment_thesis,
    'certificate_confirmed', v_updated.certificate_confirmed,
    'status', v_updated.status,
    'version_no', v_updated.current_version_no,
    'coverage_id', v_updated.coverage_id,
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


--
-- Name: report_save_content_atomic(uuid, text, text, text, text, numeric, text, uuid, text, uuid, text, boolean, uuid, jsonb, uuid, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_code text, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text) RETURNS public.report
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
declare
  v_report public.report;
  v_current_version_no integer;
  v_updated public.report;
begin
  -- 获取当前版本号
  select current_version_no into v_current_version_no
  from public.report
  where id = p_report_id;

  if not found then
    raise exception 'Report not found';
  end if;

  -- 更新 report 表
  update public.report
  set
    title = p_title,
    report_type = p_report_type,
    ticker = p_ticker,
    rating = p_rating,
    target_price = p_target_price,
    region_code = p_region_code,
    sector_id = p_sector_id,
    report_language = p_report_language,
    contact_person_id = p_contact_person_id,
    investment_thesis = p_investment_thesis,
    certificate_confirmed = p_certificate_confirmed,
    coverage_id = p_coverage_id,
    current_version_no = v_current_version_no + 1,
    updated_at = now()
  where id = p_report_id
  returning * into v_updated;

  -- 删除旧的分析师关联
  delete from public.report_analyst where report_id = p_report_id;

  -- 插入新的分析师关联
  if p_analysts is not null and jsonb_array_length(p_analysts) > 0 then
    insert into public.report_analyst (report_id, analyst_id, role, sort_order)
    select
      p_report_id,
      (jsonb_array_elements(p_analysts)->>'analyst_id')::uuid,
      (jsonb_array_elements(p_analysts)->>'role')::integer,
      (jsonb_array_elements(p_analysts)->>'sort_order')::integer
    from jsonb_array_elements(p_analysts);
  end if;

  -- 插入新版本记录
  insert into public.report_version (
    report_id,
    version_no,
    snapshot_json,
    word_file_path,
    word_file_name,
    model_file_path,
    model_file_name,
    changed_by
  ) values (
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
      'coverage_id', p_coverage_id
    ),
    p_word_file_path,
    p_word_file_name,
    p_model_file_path,
    p_model_file_name,
    p_changed_by
  );

  return v_updated;
end;
$$;


--
-- Name: report_save_content_atomic(uuid, text, text, text, text, numeric, uuid, uuid, text, uuid, text, boolean, uuid, jsonb, uuid, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text) RETURNS public.report
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
declare
  v_report public.report;
  v_current_version_no integer;
  v_updated public.report;
begin
  -- 获取当前版本号
  select current_version_no into v_current_version_no
  from public.report
  where id = p_report_id;

  if not found then
    raise exception 'Report not found';
  end if;

  -- 更新 report 表
  update public.report
  set
    title = p_title,
    report_type = p_report_type,
    ticker = p_ticker,
    rating = p_rating,
    target_price = p_target_price,
    region_id = p_region_id,
    sector_id = p_sector_id,
    report_language = p_report_language,
    contact_person_id = p_contact_person_id,
    investment_thesis = p_investment_thesis,
    certificate_confirmed = p_certificate_confirmed,
    coverage_id = p_coverage_id,
    current_version_no = v_current_version_no + 1,
    updated_at = now()
  where id = p_report_id
  returning * into v_updated;

  -- 删除旧的分析师关联
  delete from public.report_analyst where report_id = p_report_id;

  -- 插入新的分析师关联
  if p_analysts is not null and jsonb_array_length(p_analysts) > 0 then
    insert into public.report_analyst (report_id, analyst_id, role, sort_order)
    select
      p_report_id,
      (jsonb_array_elements(p_analysts)->>'analyst_id')::uuid,
      (jsonb_array_elements(p_analysts)->>'role')::integer,
      (jsonb_array_elements(p_analysts)->>'sort_order')::integer
    from jsonb_array_elements(p_analysts);
  end if;

  -- 插入新版本记录
  insert into public.report_version (
    report_id,
    version_no,
    snapshot_json,
    word_file_path,
    word_file_name,
    model_file_path,
    model_file_name,
    changed_by
  ) values (
    p_report_id,
    v_current_version_no + 1,
    jsonb_build_object(
      'title', p_title,
      'report_type', p_report_type,
      'ticker', p_ticker,
      'rating', p_rating,
      'target_price', p_target_price,
      'region_id', p_region_id,
      'sector_id', p_sector_id,
      'report_language', p_report_language,
      'contact_person_id', p_contact_person_id,
      'investment_thesis', p_investment_thesis,
      'certificate_confirmed', p_certificate_confirmed,
      'coverage_id', p_coverage_id
    ),
    p_word_file_path,
    p_word_file_name,
    p_model_file_path,
    p_model_file_name,
    p_changed_by
  );

  return v_updated;
end;
$$;


--
-- Name: report_save_content_atomic(uuid, text, text, text, text, text, text, uuid, text, uuid, text, boolean, uuid, jsonb, uuid, text, text, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_code text, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_pdf_file_path text, p_model_file_path text, p_word_file_name text, p_pdf_file_name text, p_model_file_name text) RETURNS public.report
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
  DECLARE
    v_report public.report;
    v_current_version_no integer;
    v_updated public.report;
  BEGIN
    -- Get current version number
    SELECT current_version_no INTO v_current_version_no
    FROM public.report
    WHERE id = p_report_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Report not found';
    END IF;

    -- Update report table
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

    -- Insert new version record
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

    -- Delete old analyst associations and insert new ones
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
  $$;


--
-- Name: report_save_content_atomic(uuid, text, text, text, text, text, uuid, uuid, text, text, text, boolean, uuid, jsonb, uuid, text, text, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person text, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text, p_chief_approval_screenshot_path text DEFAULT NULL::text, p_chief_approval_screenshot_name text DEFAULT NULL::text) RETURNS public.report
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
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
    ticker = nullif(btrim(coalesce(p_ticker, '')), ''),
    rating = nullif(btrim(coalesce(p_rating, '')), ''),
    target_price = nullif(btrim(coalesce(p_target_price, '')), ''),
    region_id = p_region_id,
    sector_id = p_sector_id,
    report_language = nullif(btrim(coalesce(p_report_language, '')), ''),
    contact_person = nullif(btrim(coalesce(p_contact_person, '')), ''),
    investment_thesis = nullif(btrim(coalesce(p_investment_thesis, '')), ''),
    certificate_confirmed = coalesce(p_certificate_confirmed, false),
    coverage_id = p_coverage_id,
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
    'ticker', v_updated.ticker,
    'rating', v_updated.rating,
    'target_price', v_updated.target_price,
    'region_id', v_updated.region_id,
    'sector_id', v_updated.sector_id,
    'report_language', v_updated.report_language,
    'contact_person', v_updated.contact_person,
    'investment_thesis', v_updated.investment_thesis,
    'certificate_confirmed', v_updated.certificate_confirmed,
    'status', v_updated.status,
    'version_no', v_updated.current_version_no,
    'coverage_id', v_updated.coverage_id,
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
    word_file_name,
    model_file_path,
    model_file_name,
    chief_approval_screenshot_path,
    chief_approval_screenshot_name,
    changed_by,
    changed_at
  )
  values (
    p_report_id,
    v_next_version,
    v_snapshot,
    p_word_file_path,
    p_word_file_name,
    p_model_file_path,
    p_model_file_name,
    p_chief_approval_screenshot_path,
    p_chief_approval_screenshot_name,
    p_changed_by,
    now()
  );

  return v_updated;
end;
$$;


--
-- Name: report_status_is_valid(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.report_status_is_valid(from_status text, to_status text) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  select (
    (from_status = 'draft' and to_status = 'submitted')
    or (from_status = 'submitted' and to_status in ('published', 'rejected'))
    or (from_status = 'rejected' and to_status = 'draft')
  );
$$;


--
-- Name: FUNCTION report_status_is_valid(from_status text, to_status text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.report_status_is_valid(from_status text, to_status text) IS '验证报告状态转换是否合法：draft->submitted, submitted->published/rejected, rejected->draft';


--
-- Name: report_status_log_enforce_transition(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.report_status_log_enforce_transition() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: FUNCTION report_status_log_enforce_transition(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.report_status_log_enforce_transition() IS '触发器函数：验证状态日志记录的状态转换合法性';


--
-- Name: rpc_report_create(text, text, uuid, uuid, text, uuid[], uuid, numeric, uuid, bytea, text, integer, text, date, text, text, date, numeric, text, date, numeric, text, date, jsonb, jsonb, text, text, text, text, jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rpc_report_create(p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_region_code text, p_analyst_ids uuid[], p_contact_user_id uuid, p_target_price numeric, p_rating_id uuid, p_pdf_data bytea, p_pdf_filename text, p_current_version_no integer, p_rating_agency text, p_report_date date, p_price_currency text, p_target_price_currency text, p_target_price_maturity date, p_target_price_2 numeric, p_target_price_2_currency text, p_target_price_2_maturity date, p_irr numeric, p_irr_currency text, p_irr_maturity date, p_key_metrics jsonb, p_key_risks jsonb, p_investment_teaser text, p_investment_highlight text, p_investment_summary text, p_executive_summary text, p_table_of_contents jsonb, p_analyst_note text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_report_id uuid;
  v_version_id uuid;
begin
  -- Create report
  insert into public.report (
    title,
    report_type,
    coverage_id,
    sector_id,
    region_code,
    current_version_no,
    rating_id,
    target_price,
    target_price_currency,
    target_price_maturity,
    target_price_2,
    target_price_2_currency,
    target_price_2_maturity,
    irr,
    irr_currency,
    irr_maturity,
    key_metrics,
    key_risks,
    investment_teaser,
    investment_highlight,
    investment_summary,
    executive_summary,
    table_of_contents,
    analyst_note,
    owner_user_id,
    report_date,
    rating_agency,
    price_currency
  ) values (
    p_title,
    p_report_type,
    p_coverage_id,
    p_sector_id,
    p_region_code,
    p_current_version_no,
    p_rating_id,
    p_target_price,
    p_target_price_currency,
    p_target_price_maturity,
    p_target_price_2,
    p_target_price_2_currency,
    p_target_price_2_maturity,
    p_irr,
    p_irr_currency,
    p_irr_maturity,
    p_key_metrics,
    p_key_risks,
    p_investment_teaser,
    p_investment_highlight,
    p_investment_summary,
    p_executive_summary,
    p_table_of_contents,
    p_analyst_note,
    p_contact_user_id,
    p_report_date,
    p_rating_agency,
    p_price_currency
  )
  returning id into v_report_id;

  -- Handle PDF
  if p_pdf_data is not null and length(p_pdf_data) > 0 then
    insert into public.report_version (
      report_id,
      version_no,
      pdf_data,
      pdf_filename
    ) values (
      v_report_id,
      1,
      p_pdf_data,
      p_pdf_filename
    )
    returning id into v_version_id;
  end if;

  -- Add analysts
  if p_analyst_ids is not null and array_length(p_analyst_ids, 1) > 0 then
    insert into public.report_analyst (report_id, analyst_user_id)
    select v_report_id, unnest(p_analyst_ids)
    on conflict do nothing;
  end if;

  return v_report_id;
end;
$$;


--
-- Name: rpc_report_update(uuid, text, text, uuid, uuid, text, uuid[], uuid, numeric, uuid, bytea, text, integer, text, date, text, text, date, numeric, text, date, numeric, text, date, jsonb, jsonb, text, text, text, text, jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rpc_report_update(p_report_id uuid, p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_region_code text, p_analyst_ids uuid[], p_contact_user_id uuid, p_target_price numeric, p_rating_id uuid, p_pdf_data bytea, p_pdf_filename text, p_current_version_no integer, p_rating_agency text, p_report_date date, p_price_currency text, p_target_price_currency text, p_target_price_maturity date, p_target_price_2 numeric, p_target_price_2_currency text, p_target_price_2_maturity date, p_irr numeric, p_irr_currency text, p_irr_maturity date, p_key_metrics jsonb, p_key_risks jsonb, p_investment_teaser text, p_investment_highlight text, p_investment_summary text, p_executive_summary text, p_table_of_contents jsonb, p_analyst_note text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_current_version_no integer;
  v_new_version_no integer;
  v_version_id uuid;
begin
  -- Get current version
  select current_version_no into v_current_version_no from public.report where id = p_report_id;

  -- Update report
  update public.report set
    title = p_title,
    report_type = p_report_type,
    coverage_id = p_coverage_id,
    sector_id = p_sector_id,
    region_code = p_region_code,
    current_version_no = p_current_version_no,
    rating_id = p_rating_id,
    target_price = p_target_price,
    target_price_currency = p_target_price_currency,
    target_price_maturity = p_target_price_maturity,
    target_price_2 = p_target_price_2,
    target_price_2_currency = p_target_price_2_currency,
    target_price_2_maturity = p_target_price_2_maturity,
    irr = p_irr,
    irr_currency = p_irr_currency,
    irr_maturity = p_irr_maturity,
    key_metrics = p_key_metrics,
    key_risks = p_key_risks,
    investment_teaser = p_investment_teaser,
    investment_highlight = p_investment_highlight,
    investment_summary = p_investment_summary,
    executive_summary = p_executive_summary,
    table_of_contents = p_table_of_contents,
    analyst_note = p_analyst_note,
    rating_agency = p_rating_agency,
    report_date = p_report_date,
    price_currency = p_price_currency,
    updated_at = now()
  where id = p_report_id;

  -- Handle PDF
  if p_pdf_data is not null and length(p_pdf_data) > 0 then
    v_new_version_no := v_current_version_no + 1;

    insert into public.report_version (
      report_id,
      version_no,
      pdf_data,
      pdf_filename
    ) values (
      p_report_id,
      v_new_version_no,
      p_pdf_data,
      p_pdf_filename
    )
    returning id into v_version_id;

    update public.report set current_version_no = v_new_version_no where id = p_report_id;
  end if;

  -- Update analysts
  delete from public.report_analyst where report_id = p_report_id;
  if p_analyst_ids is not null and array_length(p_analyst_ids, 1) > 0 then
    insert into public.report_analyst (report_id, analyst_user_id)
    select p_report_id, unnest(p_analyst_ids)
    on conflict do nothing;
  end if;
end;
$$;


--
-- Name: set_coverage_index_code(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_coverage_index_code() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  -- 当 country_of_domicile 变化时，自动设置 index_code
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


--
-- Name: FUNCTION set_coverage_index_code(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.set_coverage_index_code() IS '根据 country_of_domicile 自动设置 index_code 的触发器函数';


--
-- Name: set_updated_at_utc(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at_utc() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


--
-- Name: FUNCTION set_updated_at_utc(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.set_updated_at_utc() IS '触发器函数：自动将updated_at字段更新为当前UTC时间';


--
-- Name: trg_report_push_log_no_update_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_report_push_log_no_update_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  raise exception 'UPDATE and DELETE on report_push_log are not allowed';
end;
$$;


--
-- Name: validate_coverage_analyst_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_coverage_analyst_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: FUNCTION validate_coverage_analyst_limit(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.validate_coverage_analyst_limit() IS '触发器函数：验证每个coverage最多关联4位分析师';


--
-- Name: validate_sector_hierarchy(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_sector_hierarchy() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: FUNCTION validate_sector_hierarchy(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.validate_sector_hierarchy() IS '触发器函数：验证行业分类层级结构合法性（两级，禁止循环，禁止跨级引用）';


--
-- Name: analyst; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analyst (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    full_name text NOT NULL,
    chinese_name text,
    email public.citext NOT NULL,
    suffix text,
    sfc text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    region_code text
);


--
-- Name: TABLE analyst; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.analyst IS '分析师信息表：存储分析师的详细资料，与auth.users解耦';


--
-- Name: COLUMN analyst.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analyst.id IS '主键UUID';


--
-- Name: COLUMN analyst.full_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analyst.full_name IS '分析师英文全名';


--
-- Name: COLUMN analyst.chinese_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analyst.chinese_name IS '分析师中文名';


--
-- Name: COLUMN analyst.email; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analyst.email IS '分析师邮箱（唯一，citext类型不区分大小写）';


--
-- Name: COLUMN analyst.suffix; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analyst.suffix IS '分析师姓名后缀（如Jr.、Sr.等）';


--
-- Name: COLUMN analyst.sfc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analyst.sfc IS '分析师SFC注册编号（香港证监会）';


--
-- Name: COLUMN analyst.is_active; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analyst.is_active IS '是否在职：true=在职，false=离职';


--
-- Name: COLUMN analyst.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analyst.created_at IS '创建时间（UTC）';


--
-- Name: COLUMN analyst.updated_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analyst.updated_at IS '最后更新时间（UTC）';


--
-- Name: COLUMN analyst.region_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analyst.region_code IS '所属区域代码（ISO 3166-1 alpha-2），关联region.code，删除区域时置空';


--
-- Name: chief_approve; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_approve (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    report_id uuid NOT NULL,
    file_path text NOT NULL,
    file_name text NOT NULL,
    file_type text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE chief_approve; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.chief_approve IS '首席确认附件表：存储首席审核确认时的附件信息';


--
-- Name: COLUMN chief_approve.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.chief_approve.id IS '主键UUID';


--
-- Name: COLUMN chief_approve.report_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.chief_approve.report_id IS '关联报告ID';


--
-- Name: COLUMN chief_approve.file_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.chief_approve.file_path IS '文件存储路径';


--
-- Name: COLUMN chief_approve.file_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.chief_approve.file_name IS '原始文件名';


--
-- Name: COLUMN chief_approve.file_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.chief_approve.file_type IS '文件MIME类型';


--
-- Name: COLUMN chief_approve.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.chief_approve.created_at IS '创建时间';


--
-- Name: coverage; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coverage (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ticker text NOT NULL,
    english_full_name text NOT NULL,
    chinese_short_name text,
    traditional_chinese text,
    sector_id uuid NOT NULL,
    isin text NOT NULL,
    country_of_domicile text NOT NULL,
    reporting_currency text,
    ads_conversion_factor numeric(18,6),
    is_duplicate boolean DEFAULT false NOT NULL,
    approved_by uuid,
    approved_at timestamp with time zone,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    index_code text,
    CONSTRAINT coverage_ads_conversion_factor_check CHECK ((ads_conversion_factor > (0)::numeric))
);


--
-- Name: TABLE coverage; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.coverage IS '公司覆盖表：存储被研究覆盖的上市公司基本信息';


--
-- Name: COLUMN coverage.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.id IS '主键UUID';


--
-- Name: COLUMN coverage.ticker; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.ticker IS '股票代码（唯一，存储时统一处理大小写和空格）';


--
-- Name: COLUMN coverage.english_full_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.english_full_name IS '公司英文全称';


--
-- Name: COLUMN coverage.chinese_short_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.chinese_short_name IS '公司中文简称';


--
-- Name: COLUMN coverage.traditional_chinese; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.traditional_chinese IS '公司繁体中文名称';


--
-- Name: COLUMN coverage.sector_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.sector_id IS '所属行业ID，关联sector.id，禁止删除已关联行业';


--
-- Name: COLUMN coverage.isin; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.isin IS 'ISIN国际证券识别码（唯一，存储时统一大写）';


--
-- Name: COLUMN coverage.country_of_domicile; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.country_of_domicile IS '公司注册地/上市地';


--
-- Name: COLUMN coverage.reporting_currency; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.reporting_currency IS '报告使用货币';


--
-- Name: COLUMN coverage.ads_conversion_factor; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.ads_conversion_factor IS 'ADS美股存托股折算因子';


--
-- Name: COLUMN coverage.is_duplicate; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.is_duplicate IS '是否重复记录';


--
-- Name: COLUMN coverage.approved_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.approved_by IS '审批人ID，关联auth.users，删除用户时置空';


--
-- Name: COLUMN coverage.approved_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.approved_at IS '审批时间';


--
-- Name: COLUMN coverage.is_active; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.is_active IS '是否启用：true=启用，false=禁用';


--
-- Name: COLUMN coverage.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.created_at IS '创建时间（UTC）';


--
-- Name: COLUMN coverage.updated_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.updated_at IS '最后更新时间（UTC）';


--
-- Name: COLUMN coverage.index_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage.index_code IS '关联的指数代码，关联 index_quotes 表的 index_code';


--
-- Name: coverage_analyst; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coverage_analyst (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    coverage_id uuid NOT NULL,
    analyst_id uuid NOT NULL,
    role smallint NOT NULL,
    sort_order smallint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT coverage_analyst_role_check CHECK (((role >= 1) AND (role <= 4))),
    CONSTRAINT coverage_analyst_sort_order_check CHECK (((sort_order >= 1) AND (sort_order <= 4)))
);


--
-- Name: TABLE coverage_analyst; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.coverage_analyst IS '覆盖-分析师关系表：建立公司与分析师的覆盖关系，每公司最多4位分析师';


--
-- Name: COLUMN coverage_analyst.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage_analyst.id IS '主键UUID';


--
-- Name: COLUMN coverage_analyst.coverage_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage_analyst.coverage_id IS '覆盖公司ID，关联coverage.id，删除公司时级联删除';


--
-- Name: COLUMN coverage_analyst.analyst_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage_analyst.analyst_id IS '分析师ID，关联analyst.id，禁止删除已关联分析师';


--
-- Name: COLUMN coverage_analyst.role; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage_analyst.role IS '角色序号（1-4）：1=主分析师，2=联合分析师，3=辅助分析师，4=审核分析师';


--
-- Name: COLUMN coverage_analyst.sort_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage_analyst.sort_order IS '排序序号（1-4），决定前端展示顺序，同公司内唯一';


--
-- Name: COLUMN coverage_analyst.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage_analyst.created_at IS '创建时间（UTC）';


--
-- Name: COLUMN coverage_analyst.updated_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.coverage_analyst.updated_at IS '最后更新时间（UTC）';


--
-- Name: rating; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rating (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    sort integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE rating; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.rating IS '投资评级表：存储研究报告的投资评级选项';


--
-- Name: COLUMN rating.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.rating.id IS '主键UUID';


--
-- Name: COLUMN rating.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.rating.name IS '评级名称（中文）';


--
-- Name: COLUMN rating.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.rating.code IS '评级代码（英文缩写）';


--
-- Name: COLUMN rating.sort; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.rating.sort IS '排序权重';


--
-- Name: COLUMN rating.is_active; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.rating.is_active IS '是否启用';


--
-- Name: COLUMN rating.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.rating.created_at IS '创建时间';


--
-- Name: region; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.region (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    name_en text NOT NULL,
    name_cn text NOT NULL,
    code text NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE region; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.region IS '区域表：存储研究覆盖的地理区域信息，支持中英文名称和ISO 3166-1 alpha-2编码';


--
-- Name: COLUMN region.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region.id IS '主键UUID';


--
-- Name: COLUMN region.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region.created_at IS '创建时间（UTC）';


--
-- Name: COLUMN region.updated_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region.updated_at IS '最后更新时间（UTC）';


--
-- Name: COLUMN region.name_en; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region.name_en IS '区域英文名称';


--
-- Name: COLUMN region.name_cn; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region.name_cn IS '区域中文名称';


--
-- Name: COLUMN region.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region.code IS 'ISO 3166-1 alpha-2 国家/地区代码（如CN、HK、JP等）';


--
-- Name: COLUMN region.is_active; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.region.is_active IS '是否启用：true=启用，false=禁用';


--
-- Name: report_analyst; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_analyst (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    report_id uuid NOT NULL,
    analyst_id uuid NOT NULL,
    role smallint NOT NULL,
    sort_order smallint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT report_analyst_role_check CHECK (((role >= 1) AND (role <= 4))),
    CONSTRAINT report_analyst_sort_order_check CHECK (((sort_order >= 1) AND (sort_order <= 4)))
);


--
-- Name: TABLE report_analyst; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.report_analyst IS '报告-分析师关系表：建立报告与分析师的作者关系';


--
-- Name: COLUMN report_analyst.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_analyst.id IS '主键UUID';


--
-- Name: COLUMN report_analyst.report_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_analyst.report_id IS '报告ID，关联report.id，删除报告时级联删除';


--
-- Name: COLUMN report_analyst.analyst_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_analyst.analyst_id IS '分析师ID，关联analyst.id，禁止删除已关联分析师';


--
-- Name: COLUMN report_analyst.role; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_analyst.role IS '角色序号（1-4）：1=主分析师，2=联合分析师，3=辅助分析师，4=审核分析师';


--
-- Name: COLUMN report_analyst.sort_order; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_analyst.sort_order IS '排序序号（1-4），决定展示顺序，同报告内唯一';


--
-- Name: COLUMN report_analyst.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_analyst.created_at IS '创建时间（UTC）';


--
-- Name: COLUMN report_analyst.updated_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_analyst.updated_at IS '最后更新时间（UTC）';


--
-- Name: report_push_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_push_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    report_id uuid NOT NULL,
    status text NOT NULL,
    http_status_code integer,
    response_body text,
    error_message text,
    payload_sent jsonb,
    trigger_type text NOT NULL,
    triggered_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT report_push_log_status_check CHECK ((status = ANY (ARRAY['success'::text, 'failed'::text, 'pending'::text]))),
    CONSTRAINT report_push_log_trigger_type_check CHECK ((trigger_type = ANY (ARRAY['auto'::text, 'manual'::text])))
);


--
-- Name: TABLE report_push_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.report_push_log IS '报告外部推送日志记录表';


--
-- Name: COLUMN report_push_log.report_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_push_log.report_id IS '关联报告ID';


--
-- Name: COLUMN report_push_log.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_push_log.status IS '推送状态: success/failed/pending';


--
-- Name: COLUMN report_push_log.http_status_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_push_log.http_status_code IS '外部接口返回的HTTP状态码';


--
-- Name: COLUMN report_push_log.response_body; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_push_log.response_body IS '外部接口响应体（截断至2000字符）';


--
-- Name: COLUMN report_push_log.error_message; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_push_log.error_message IS '错误信息（网络异常/超时等）';


--
-- Name: COLUMN report_push_log.payload_sent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_push_log.payload_sent IS '本次推送的完整payload（附件内容不存储）';


--
-- Name: COLUMN report_push_log.trigger_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_push_log.trigger_type IS '触发类型: auto（自动推送）/manual（手动重推）';


--
-- Name: COLUMN report_push_log.triggered_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_push_log.triggered_by IS '触发人';


--
-- Name: report_status_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_status_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    report_id uuid NOT NULL,
    from_status text NOT NULL,
    to_status text NOT NULL,
    action_by uuid NOT NULL,
    action_at timestamp with time zone DEFAULT now() NOT NULL,
    reason text,
    version_no integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    action_by_name text,
    CONSTRAINT report_status_log_from_status_check CHECK ((from_status = ANY (ARRAY['draft'::text, 'submitted'::text, 'published'::text, 'rejected'::text]))),
    CONSTRAINT report_status_log_reject_reason_required CHECK (((to_status <> 'rejected'::text) OR ((reason IS NOT NULL) AND (btrim(reason) <> ''::text)))),
    CONSTRAINT report_status_log_to_status_check CHECK ((to_status = ANY (ARRAY['draft'::text, 'submitted'::text, 'published'::text, 'rejected'::text]))),
    CONSTRAINT report_status_log_version_no_check CHECK ((version_no >= 0))
);


--
-- Name: TABLE report_status_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.report_status_log IS '报告状态变更日志表（append-only）：记录报告所有状态流转历史，不允许修改或删除';


--
-- Name: COLUMN report_status_log.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_status_log.id IS '主键UUID';


--
-- Name: COLUMN report_status_log.report_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_status_log.report_id IS '报告ID，关联report.id，删除报告时级联删除';


--
-- Name: COLUMN report_status_log.from_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_status_log.from_status IS '变更前状态';


--
-- Name: COLUMN report_status_log.to_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_status_log.to_status IS '变更后状态';


--
-- Name: COLUMN report_status_log.action_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_status_log.action_by IS '操作人ID，关联auth.users';


--
-- Name: COLUMN report_status_log.action_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_status_log.action_at IS '操作时间';


--
-- Name: COLUMN report_status_log.reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_status_log.reason IS '驳回原因（仅to_status=rejected时必填），业务语义为批注Note';


--
-- Name: COLUMN report_status_log.version_no; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_status_log.version_no IS '状态变更发生时的报告版本号';


--
-- Name: COLUMN report_status_log.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_status_log.created_at IS '创建时间（UTC）';


--
-- Name: COLUMN report_status_log.action_by_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_status_log.action_by_name IS '操作人姓名（从analyst表冗余存储，避免删除用户后丢失）';


--
-- Name: report_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_type (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    sort integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE report_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.report_type IS '报告类型表：存储研究报告的分类选项';


--
-- Name: COLUMN report_type.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_type.id IS '主键UUID';


--
-- Name: COLUMN report_type.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_type.name IS '报告类型名称（中文）';


--
-- Name: COLUMN report_type.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_type.code IS '报告类型代码（英文）';


--
-- Name: COLUMN report_type.sort; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_type.sort IS '排序权重';


--
-- Name: COLUMN report_type.is_active; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_type.is_active IS '是否启用';


--
-- Name: COLUMN report_type.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_type.created_at IS '创建时间';


--
-- Name: report_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_version (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    report_id uuid NOT NULL,
    version_no integer NOT NULL,
    snapshot_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    word_file_path text,
    model_file_path text,
    changed_by uuid NOT NULL,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    word_file_name text,
    model_file_name text,
    pdf_file_path text,
    pdf_file_name text,
    CONSTRAINT report_version_version_no_check CHECK ((version_no >= 1))
);


--
-- Name: TABLE report_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.report_version IS '报告版本表（append-only）：记录报告每次提交的快照和文件信息，不允许修改或删除';


--
-- Name: COLUMN report_version.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_version.id IS '主键UUID';


--
-- Name: COLUMN report_version.report_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_version.report_id IS '所属报告ID，关联report.id，删除报告时级联删除';


--
-- Name: COLUMN report_version.version_no; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_version.version_no IS '版本号（>=1），同一报告内递增';


--
-- Name: COLUMN report_version.snapshot_json; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_version.snapshot_json IS '报告内容快照（JSONB），包含标题、类型、评级、目标价、分析师等核心字段';


--
-- Name: COLUMN report_version.word_file_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_version.word_file_path IS 'Word/PPT文件存储路径（Supabase Storage）';


--
-- Name: COLUMN report_version.model_file_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_version.model_file_path IS '模型文件存储路径（Supabase Storage）';


--
-- Name: COLUMN report_version.changed_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_version.changed_by IS '变更人ID，关联auth.users';


--
-- Name: COLUMN report_version.changed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_version.changed_at IS '变更时间';


--
-- Name: COLUMN report_version.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_version.created_at IS '创建时间（UTC）';


--
-- Name: COLUMN report_version.word_file_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_version.word_file_name IS 'Word/PPT原始文件名（含扩展名）';


--
-- Name: COLUMN report_version.model_file_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_version.model_file_name IS '模型原始文件名（含扩展名）';


--
-- Name: COLUMN report_version.pdf_file_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_version.pdf_file_path IS 'PDF文件存储路径（Supabase Storage）';


--
-- Name: COLUMN report_version.pdf_file_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.report_version.pdf_file_name IS 'PDF原始文件名（含扩展名）';


--
-- Name: rqc_approve; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rqc_approve (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    report_id uuid NOT NULL,
    file_path text NOT NULL,
    file_name text NOT NULL,
    file_type text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE rqc_approve; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.rqc_approve IS 'RQC审批确认附件表：存储RQC审核确认时的附件信息';


--
-- Name: COLUMN rqc_approve.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.rqc_approve.id IS '主键UUID';


--
-- Name: COLUMN rqc_approve.report_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.rqc_approve.report_id IS '关联报告ID';


--
-- Name: COLUMN rqc_approve.file_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.rqc_approve.file_path IS '文件存储路径';


--
-- Name: COLUMN rqc_approve.file_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.rqc_approve.file_name IS '原始文件名';


--
-- Name: COLUMN rqc_approve.file_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.rqc_approve.file_type IS '文件MIME类型';


--
-- Name: COLUMN rqc_approve.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.rqc_approve.created_at IS '创建时间';


--
-- Name: sector; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sector (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    level smallint NOT NULL,
    parent_id uuid,
    name_en text NOT NULL,
    name_cn text,
    wind_name text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT sector_level_check CHECK ((level = ANY (ARRAY[1, 2]))),
    CONSTRAINT sector_level_parent_check CHECK ((((level = 1) AND (parent_id IS NULL)) OR ((level = 2) AND (parent_id IS NOT NULL))))
);


--
-- Name: TABLE sector; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.sector IS '行业分类表：存储两级行业分类体系（level=1一级/level=2二级），通过parent_id建立层级关系';


--
-- Name: COLUMN sector.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sector.id IS '主键UUID';


--
-- Name: COLUMN sector.level; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sector.level IS '层级：1=一级行业，2=二级行业';


--
-- Name: COLUMN sector.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sector.parent_id IS '父级行业ID（level=1时必须为空，level=2时必须引用level=1的记录）';


--
-- Name: COLUMN sector.name_en; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sector.name_en IS '行业英文名称';


--
-- Name: COLUMN sector.name_cn; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sector.name_cn IS '行业中文名称';


--
-- Name: COLUMN sector.wind_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sector.wind_name IS 'Wind万得行业名称（用于和Wind数据对接）';


--
-- Name: COLUMN sector.is_active; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sector.is_active IS '是否启用：true=启用，false=禁用';


--
-- Name: COLUMN sector.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sector.created_at IS '创建时间（UTC）';


--
-- Name: COLUMN sector.updated_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.sector.updated_at IS '最后更新时间（UTC）';


--
-- Name: template; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.template (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    report_type text NOT NULL,
    template_file_path text NOT NULL,
    uploaded_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    language text DEFAULT 'en'::text NOT NULL,
    schema_file_path text,
    sort integer DEFAULT 0 NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    CONSTRAINT template_language_check CHECK ((language = ANY (ARRAY['en'::text, 'zh'::text])))
);


--
-- Name: TABLE template; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.template IS '报告模板表：存储报告 Word 模板文件信息，每种报告类型+语言按 created_at 倒序取最新一条，不区分 report/model 类型';


--
-- Name: COLUMN template.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.template.id IS '主键UUID';


--
-- Name: COLUMN template.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.template.name IS '模板名称（如"公司报告模板v1"）';


--
-- Name: COLUMN template.report_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.template.report_type IS '报告类型代码（如 company/sector/company_flash 等），值来自 report_type 表';


--
-- Name: COLUMN template.template_file_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.template.template_file_path IS 'Word 模板文件存储路径（Supabase Storage templates bucket 下的路径），非空时表示模板文件已上传';


--
-- Name: COLUMN template.uploaded_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.template.uploaded_by IS '上传人ID，关联 auth.users，初始化占位模板允许为空';


--
-- Name: COLUMN template.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.template.created_at IS '创建时间（UTC），用于倒序取最新版本';


--
-- Name: COLUMN template.updated_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.template.updated_at IS '最后更新时间（UTC）';


--
-- Name: COLUMN template.language; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.template.language IS '模板语言：en=英文模板，zh=中文模板';


--
-- Name: COLUMN template.schema_file_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.template.schema_file_path IS 'Word schema 描述文件存储路径（Supabase Storage 下的 JSON 文件路径），描述模板所需的字段名称、位置和特征，可为空';


--
-- Name: COLUMN template.sort; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.template.sort IS '排序序号（整数，数字越小越靠前），用于 Templates 列表排序，同一 report_type 内有效';


--
-- Name: COLUMN template.version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.template.version IS '版本号（>=1），同一 (report_type, language) 内递增，每次上传新版本时自动分配';


--
-- Name: analyst analyst_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analyst
    ADD CONSTRAINT analyst_email_key UNIQUE (email);


--
-- Name: analyst analyst_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analyst
    ADD CONSTRAINT analyst_pkey PRIMARY KEY (id);


--
-- Name: chief_approve chief_approve_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_approve
    ADD CONSTRAINT chief_approve_pkey PRIMARY KEY (id);


--
-- Name: coverage_analyst coverage_analyst_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coverage_analyst
    ADD CONSTRAINT coverage_analyst_pkey PRIMARY KEY (id);


--
-- Name: coverage_analyst coverage_analyst_uniq_pair; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coverage_analyst
    ADD CONSTRAINT coverage_analyst_uniq_pair UNIQUE (coverage_id, analyst_id);


--
-- Name: coverage_analyst coverage_analyst_uniq_sort; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coverage_analyst
    ADD CONSTRAINT coverage_analyst_uniq_sort UNIQUE (coverage_id, sort_order);


--
-- Name: coverage coverage_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coverage
    ADD CONSTRAINT coverage_pkey PRIMARY KEY (id);


--
-- Name: rating rating_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rating
    ADD CONSTRAINT rating_code_key UNIQUE (code);


--
-- Name: rating rating_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rating
    ADD CONSTRAINT rating_pkey PRIMARY KEY (id);


--
-- Name: region region_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region
    ADD CONSTRAINT region_pkey PRIMARY KEY (id);


--
-- Name: report_analyst report_analyst_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_analyst
    ADD CONSTRAINT report_analyst_pkey PRIMARY KEY (id);


--
-- Name: report_analyst report_analyst_uniq_pair; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_analyst
    ADD CONSTRAINT report_analyst_uniq_pair UNIQUE (report_id, analyst_id);


--
-- Name: report_analyst report_analyst_uniq_sort; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_analyst
    ADD CONSTRAINT report_analyst_uniq_sort UNIQUE (report_id, sort_order);


--
-- Name: report report_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report
    ADD CONSTRAINT report_pkey PRIMARY KEY (id);


--
-- Name: report_push_log report_push_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_push_log
    ADD CONSTRAINT report_push_log_pkey PRIMARY KEY (id);


--
-- Name: report_status_log report_status_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_status_log
    ADD CONSTRAINT report_status_log_pkey PRIMARY KEY (id);


--
-- Name: report_type report_type_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_type
    ADD CONSTRAINT report_type_code_key UNIQUE (code);


--
-- Name: report_type report_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_type
    ADD CONSTRAINT report_type_pkey PRIMARY KEY (id);


--
-- Name: report_version report_version_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_version
    ADD CONSTRAINT report_version_pkey PRIMARY KEY (id);


--
-- Name: report_version report_version_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_version
    ADD CONSTRAINT report_version_uniq UNIQUE (report_id, version_no);


--
-- Name: rqc_approve rqc_approve_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rqc_approve
    ADD CONSTRAINT rqc_approve_pkey PRIMARY KEY (id);


--
-- Name: sector sector_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sector
    ADD CONSTRAINT sector_pkey PRIMARY KEY (id);


--
-- Name: template template_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.template
    ADD CONSTRAINT template_pkey PRIMARY KEY (id);


--
-- Name: template template_uniq_version; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.template
    ADD CONSTRAINT template_uniq_version UNIQUE (report_type, language, version);


--
-- Name: region uk_region_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region
    ADD CONSTRAINT uk_region_code UNIQUE (code);


--
-- Name: region uk_region_name_cn; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region
    ADD CONSTRAINT uk_region_name_cn UNIQUE (name_cn);


--
-- Name: region uk_region_name_en; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.region
    ADD CONSTRAINT uk_region_name_en UNIQUE (name_en);


--
-- Name: idx_analyst_chinese_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_analyst_chinese_name ON public.analyst USING btree (chinese_name);


--
-- Name: idx_analyst_created_at_desc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_analyst_created_at_desc ON public.analyst USING btree (created_at DESC);


--
-- Name: idx_analyst_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_analyst_email ON public.analyst USING btree (email);


--
-- Name: idx_analyst_full_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_analyst_full_name ON public.analyst USING btree (full_name);


--
-- Name: idx_analyst_sfc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_analyst_sfc ON public.analyst USING btree (sfc);


--
-- Name: idx_analyst_suffix; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_analyst_suffix ON public.analyst USING btree (suffix);


--
-- Name: idx_chief_approve_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chief_approve_created_at ON public.chief_approve USING btree (created_at);


--
-- Name: idx_chief_approve_report_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chief_approve_report_id ON public.chief_approve USING btree (report_id);


--
-- Name: idx_cov_analyst_analyst; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cov_analyst_analyst ON public.coverage_analyst USING btree (analyst_id);


--
-- Name: idx_cov_analyst_coverage; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cov_analyst_coverage ON public.coverage_analyst USING btree (coverage_id);


--
-- Name: idx_coverage_index_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coverage_index_code ON public.coverage USING btree (index_code);


--
-- Name: idx_coverage_name_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coverage_name_lower ON public.coverage USING btree (lower(english_full_name));


--
-- Name: idx_coverage_sector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coverage_sector ON public.coverage USING btree (sector_id);


--
-- Name: idx_coverage_updated_at_desc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coverage_updated_at_desc ON public.coverage USING btree (updated_at DESC);


--
-- Name: idx_rating_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rating_code ON public.rating USING btree (code);


--
-- Name: idx_rating_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rating_is_active ON public.rating USING btree (is_active);


--
-- Name: idx_rating_sort; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rating_sort ON public.rating USING btree (sort);


--
-- Name: idx_region_created_at_desc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_region_created_at_desc ON public.region USING btree (created_at DESC);


--
-- Name: idx_report_analyst_analyst; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_analyst_analyst ON public.report_analyst USING btree (analyst_id);


--
-- Name: idx_report_analyst_report; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_analyst_report ON public.report_analyst USING btree (report_id);


--
-- Name: idx_report_contact_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_contact_person_id ON public.report USING btree (contact_person_id);


--
-- Name: idx_report_created_at_desc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_created_at_desc ON public.report USING btree (created_at DESC);


--
-- Name: idx_report_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_owner ON public.report USING btree (owner_user_id);


--
-- Name: idx_report_push_log_report_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_push_log_report_created ON public.report_push_log USING btree (report_id, created_at DESC);


--
-- Name: idx_report_push_log_triggered_by_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_push_log_triggered_by_created ON public.report_push_log USING btree (triggered_by, created_at DESC);


--
-- Name: idx_report_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_status ON public.report USING btree (status);


--
-- Name: idx_report_status_log_action_at_desc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_status_log_action_at_desc ON public.report_status_log USING btree (action_at DESC);


--
-- Name: idx_report_status_log_action_by_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_status_log_action_by_name ON public.report_status_log USING btree (action_by_name);


--
-- Name: idx_report_status_log_report; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_status_log_report ON public.report_status_log USING btree (report_id);


--
-- Name: idx_report_type_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_type_code ON public.report_type USING btree (code);


--
-- Name: idx_report_type_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_type_is_active ON public.report_type USING btree (is_active);


--
-- Name: idx_report_type_sort; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_type_sort ON public.report_type USING btree (sort);


--
-- Name: idx_report_updated_at_desc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_updated_at_desc ON public.report USING btree (updated_at DESC);


--
-- Name: idx_report_version_changed_at_desc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_version_changed_at_desc ON public.report_version USING btree (changed_at DESC);


--
-- Name: idx_report_version_pdf_file_path; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_version_pdf_file_path ON public.report_version USING btree (pdf_file_path) WHERE (pdf_file_path IS NOT NULL);


--
-- Name: idx_report_version_report; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_version_report ON public.report_version USING btree (report_id);


--
-- Name: idx_report_version_report_version_desc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_version_report_version_desc ON public.report_version USING btree (report_id, version_no DESC);


--
-- Name: idx_rqc_approve_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rqc_approve_created_at ON public.rqc_approve USING btree (created_at);


--
-- Name: idx_rqc_approve_report_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rqc_approve_report_id ON public.rqc_approve USING btree (report_id);


--
-- Name: idx_sector_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sector_active ON public.sector USING btree (is_active);


--
-- Name: idx_sector_level_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sector_level_parent ON public.sector USING btree (level, parent_id);


--
-- Name: idx_sector_name_en_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sector_name_en_lower ON public.sector USING btree (lower(name_en));


--
-- Name: idx_template_created_at_desc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_template_created_at_desc ON public.template USING btree (created_at DESC);


--
-- Name: idx_template_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_template_group ON public.template USING btree (report_type, language);


--
-- Name: uidx_coverage_isin_upper; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_coverage_isin_upper ON public.coverage USING btree (upper(btrim(isin)));


--
-- Name: uidx_coverage_ticker_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_coverage_ticker_lower ON public.coverage USING btree (lower(btrim(ticker)));


--
-- Name: uidx_sector_l1_name_en; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_sector_l1_name_en ON public.sector USING btree (lower(name_en)) WHERE (parent_id IS NULL);


--
-- Name: uidx_sector_l2_parent_name_en; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uidx_sector_l2_parent_name_en ON public.sector USING btree (parent_id, lower(name_en)) WHERE (parent_id IS NOT NULL);


--
-- Name: analyst trg_analyst_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_analyst_updated_at BEFORE UPDATE ON public.analyst FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_utc();


--
-- Name: coverage_analyst trg_coverage_analyst_limit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_coverage_analyst_limit BEFORE INSERT OR UPDATE ON public.coverage_analyst FOR EACH ROW EXECUTE FUNCTION public.validate_coverage_analyst_limit();


--
-- Name: coverage_analyst trg_coverage_analyst_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_coverage_analyst_updated_at BEFORE UPDATE ON public.coverage_analyst FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_utc();


--
-- Name: coverage trg_coverage_set_index_code; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_coverage_set_index_code BEFORE INSERT OR UPDATE OF country_of_domicile ON public.coverage FOR EACH ROW EXECUTE FUNCTION public.set_coverage_index_code();


--
-- Name: coverage trg_coverage_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_coverage_updated_at BEFORE UPDATE ON public.coverage FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_utc();


--
-- Name: region trg_region_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_region_updated_at BEFORE UPDATE ON public.region FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_utc();


--
-- Name: report_analyst trg_report_analyst_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_report_analyst_updated_at BEFORE UPDATE ON public.report_analyst FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_utc();


--
-- Name: report trg_report_owner_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_report_owner_immutable BEFORE UPDATE ON public.report FOR EACH ROW EXECUTE FUNCTION public.report_enforce_owner_immutable();


--
-- Name: report_push_log trg_report_push_log_no_update_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_report_push_log_no_update_delete BEFORE DELETE OR UPDATE ON public.report_push_log FOR EACH ROW EXECUTE FUNCTION public.trg_report_push_log_no_update_delete();


--
-- Name: report_status_log trg_report_status_log_no_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_report_status_log_no_update BEFORE DELETE OR UPDATE ON public.report_status_log FOR EACH ROW EXECUTE FUNCTION public.prevent_update_delete_append_only();


--
-- Name: report_status_log trg_report_status_log_transition; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_report_status_log_transition BEFORE INSERT ON public.report_status_log FOR EACH ROW EXECUTE FUNCTION public.report_status_log_enforce_transition();


--
-- Name: report trg_report_status_transition; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_report_status_transition BEFORE UPDATE ON public.report FOR EACH ROW EXECUTE FUNCTION public.report_enforce_status_transition();


--
-- Name: report trg_report_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_report_updated_at BEFORE UPDATE ON public.report FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_utc();


--
-- Name: report_version trg_report_version_no_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_report_version_no_update BEFORE DELETE OR UPDATE ON public.report_version FOR EACH ROW EXECUTE FUNCTION public.prevent_update_delete_append_only();


--
-- Name: sector trg_sector_hierarchy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sector_hierarchy BEFORE INSERT OR UPDATE ON public.sector FOR EACH ROW EXECUTE FUNCTION public.validate_sector_hierarchy();


--
-- Name: sector trg_sector_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sector_updated_at BEFORE UPDATE ON public.sector FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_utc();


--
-- Name: template trg_template_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_template_updated_at BEFORE UPDATE ON public.template FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_utc();


--
-- Name: analyst analyst_region_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analyst
    ADD CONSTRAINT analyst_region_code_fkey FOREIGN KEY (region_code) REFERENCES public.region(code) ON DELETE SET NULL;


--
-- Name: chief_approve chief_approve_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_approve
    ADD CONSTRAINT chief_approve_report_id_fkey FOREIGN KEY (report_id) REFERENCES public.report(id) ON DELETE CASCADE;


--
-- Name: coverage_analyst coverage_analyst_analyst_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coverage_analyst
    ADD CONSTRAINT coverage_analyst_analyst_id_fkey FOREIGN KEY (analyst_id) REFERENCES public.analyst(id) ON DELETE RESTRICT;


--
-- Name: coverage_analyst coverage_analyst_coverage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coverage_analyst
    ADD CONSTRAINT coverage_analyst_coverage_id_fkey FOREIGN KEY (coverage_id) REFERENCES public.coverage(id) ON DELETE CASCADE;


--
-- Name: coverage coverage_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coverage
    ADD CONSTRAINT coverage_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: coverage coverage_sector_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coverage
    ADD CONSTRAINT coverage_sector_id_fkey FOREIGN KEY (sector_id) REFERENCES public.sector(id) ON DELETE RESTRICT;


--
-- Name: report_analyst report_analyst_analyst_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_analyst
    ADD CONSTRAINT report_analyst_analyst_id_fkey FOREIGN KEY (analyst_id) REFERENCES public.analyst(id) ON DELETE RESTRICT;


--
-- Name: report_analyst report_analyst_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_analyst
    ADD CONSTRAINT report_analyst_report_id_fkey FOREIGN KEY (report_id) REFERENCES public.report(id) ON DELETE CASCADE;


--
-- Name: report report_contact_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report
    ADD CONSTRAINT report_contact_person_id_fkey FOREIGN KEY (contact_person_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: report report_coverage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report
    ADD CONSTRAINT report_coverage_id_fkey FOREIGN KEY (coverage_id) REFERENCES public.coverage(id) ON DELETE SET NULL;


--
-- Name: report report_owner_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report
    ADD CONSTRAINT report_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: report report_published_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report
    ADD CONSTRAINT report_published_by_fkey FOREIGN KEY (published_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: report_push_log report_push_log_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_push_log
    ADD CONSTRAINT report_push_log_report_id_fkey FOREIGN KEY (report_id) REFERENCES public.report(id) ON DELETE CASCADE;


--
-- Name: report_push_log report_push_log_triggered_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_push_log
    ADD CONSTRAINT report_push_log_triggered_by_fkey FOREIGN KEY (triggered_by) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: report report_region_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report
    ADD CONSTRAINT report_region_code_fkey FOREIGN KEY (region_code) REFERENCES public.region(code) ON DELETE SET NULL;


--
-- Name: report report_sector_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report
    ADD CONSTRAINT report_sector_id_fkey FOREIGN KEY (sector_id) REFERENCES public.sector(id) ON DELETE SET NULL;


--
-- Name: report_status_log report_status_log_action_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_status_log
    ADD CONSTRAINT report_status_log_action_by_fkey FOREIGN KEY (action_by) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: report_status_log report_status_log_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_status_log
    ADD CONSTRAINT report_status_log_report_id_fkey FOREIGN KEY (report_id) REFERENCES public.report(id) ON DELETE CASCADE;


--
-- Name: report_version report_version_changed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_version
    ADD CONSTRAINT report_version_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: report_version report_version_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_version
    ADD CONSTRAINT report_version_report_id_fkey FOREIGN KEY (report_id) REFERENCES public.report(id) ON DELETE CASCADE;


--
-- Name: rqc_approve rqc_approve_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rqc_approve
    ADD CONSTRAINT rqc_approve_report_id_fkey FOREIGN KEY (report_id) REFERENCES public.report(id) ON DELETE CASCADE;


--
-- Name: sector sector_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sector
    ADD CONSTRAINT sector_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.sector(id) ON DELETE RESTRICT;


--
-- Name: template template_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.template
    ADD CONSTRAINT template_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES auth.users(id) ON DELETE RESTRICT;


--
-- Name: analyst; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.analyst ENABLE ROW LEVEL SECURITY;

--
-- Name: analyst analyst_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY analyst_select_authenticated ON public.analyst FOR SELECT TO authenticated USING (true);


--
-- Name: analyst analyst_write_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY analyst_write_admin ON public.analyst TO authenticated USING ((((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = 'admin'::text)) WITH CHECK ((((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = 'admin'::text));


--
-- Name: chief_approve; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.chief_approve ENABLE ROW LEVEL SECURITY;

--
-- Name: chief_approve chief_approve_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY chief_approve_delete ON public.chief_approve FOR DELETE TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.report
  WHERE ((report.id = chief_approve.report_id) AND (report.owner_user_id = auth.uid())))) OR (public.current_app_role() = ANY (ARRAY['sa'::text, 'admin'::text]))));


--
-- Name: chief_approve chief_approve_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY chief_approve_insert ON public.chief_approve FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: chief_approve chief_approve_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY chief_approve_select ON public.chief_approve FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.report
  WHERE ((report.id = chief_approve.report_id) AND (report.owner_user_id = auth.uid())))) OR (public.current_app_role() = ANY (ARRAY['sa'::text, 'admin'::text]))));


--
-- Name: chief_approve chief_approve_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY chief_approve_update ON public.chief_approve FOR UPDATE TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.report
  WHERE ((report.id = chief_approve.report_id) AND (report.owner_user_id = auth.uid())))) OR (public.current_app_role() = ANY (ARRAY['sa'::text, 'admin'::text]))));


--
-- Name: coverage; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.coverage ENABLE ROW LEVEL SECURITY;

--
-- Name: coverage_analyst; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.coverage_analyst ENABLE ROW LEVEL SECURITY;

--
-- Name: coverage_analyst coverage_analyst_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY coverage_analyst_delete_admin ON public.coverage_analyst FOR DELETE TO authenticated USING ((((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = 'admin'::text));


--
-- Name: coverage_analyst coverage_analyst_insert_admin_analyst; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY coverage_analyst_insert_admin_analyst ON public.coverage_analyst FOR INSERT TO authenticated WITH CHECK ((((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = ANY (ARRAY['admin'::text, 'sa'::text, 'analyst'::text])));


--
-- Name: coverage_analyst coverage_analyst_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY coverage_analyst_select_authenticated ON public.coverage_analyst FOR SELECT TO authenticated USING (true);


--
-- Name: coverage_analyst coverage_analyst_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY coverage_analyst_update_admin ON public.coverage_analyst FOR UPDATE TO authenticated USING ((((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = 'admin'::text)) WITH CHECK ((((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = 'admin'::text));


--
-- Name: coverage coverage_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY coverage_delete_admin ON public.coverage FOR DELETE TO authenticated USING ((((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = 'admin'::text));


--
-- Name: coverage coverage_insert_admin_analyst; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY coverage_insert_admin_analyst ON public.coverage FOR INSERT TO authenticated WITH CHECK ((((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = ANY (ARRAY['admin'::text, 'sa'::text, 'analyst'::text])));


--
-- Name: coverage coverage_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY coverage_select_authenticated ON public.coverage FOR SELECT TO authenticated USING (true);


--
-- Name: coverage coverage_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY coverage_update_admin ON public.coverage FOR UPDATE TO authenticated USING ((((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = 'admin'::text)) WITH CHECK ((((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = 'admin'::text));


--
-- Name: rating; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rating ENABLE ROW LEVEL SECURITY;

--
-- Name: rating rating_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rating_select_authenticated ON public.rating FOR SELECT TO authenticated USING (true);


--
-- Name: region; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.region ENABLE ROW LEVEL SECURITY;

--
-- Name: region region_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY region_select_authenticated ON public.region FOR SELECT TO authenticated USING (true);


--
-- Name: region region_write_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY region_write_admin ON public.region TO authenticated USING ((((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = 'admin'::text)) WITH CHECK ((((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = 'admin'::text));


--
-- Name: report; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.report ENABLE ROW LEVEL SECURITY;

--
-- Name: report_analyst; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.report_analyst ENABLE ROW LEVEL SECURITY;

--
-- Name: report_analyst report_analyst_delete_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_analyst_delete_policy ON public.report_analyst FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.report r
  WHERE ((r.id = report_analyst.report_id) AND ((public.current_app_role() = 'admin'::text) OR ((public.current_app_role() = 'analyst'::text) AND (r.owner_user_id = auth.uid()) AND (r.status = ANY (ARRAY['draft'::text, 'submitted'::text]))))))));


--
-- Name: report_analyst report_analyst_insert_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_analyst_insert_policy ON public.report_analyst FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.report r
  WHERE ((r.id = report_analyst.report_id) AND ((public.current_app_role() = 'admin'::text) OR ((public.current_app_role() = 'analyst'::text) AND (r.owner_user_id = auth.uid()) AND (r.status = ANY (ARRAY['draft'::text, 'submitted'::text]))))))));


--
-- Name: report_analyst report_analyst_select_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_analyst_select_policy ON public.report_analyst FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.report r
  WHERE ((r.id = report_analyst.report_id) AND ((public.current_app_role() = 'admin'::text) OR ((public.current_app_role() = 'sa'::text) AND (r.status = ANY (ARRAY['submitted'::text, 'published'::text, 'rejected'::text]))) OR ((public.current_app_role() = 'analyst'::text) AND (r.owner_user_id = auth.uid())))))));


--
-- Name: report_analyst report_analyst_update_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_analyst_update_policy ON public.report_analyst FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.report r
  WHERE ((r.id = report_analyst.report_id) AND ((public.current_app_role() = 'admin'::text) OR ((public.current_app_role() = 'analyst'::text) AND (r.owner_user_id = auth.uid()) AND (r.status = ANY (ARRAY['draft'::text, 'submitted'::text])))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.report r
  WHERE ((r.id = report_analyst.report_id) AND ((public.current_app_role() = 'admin'::text) OR ((public.current_app_role() = 'analyst'::text) AND (r.owner_user_id = auth.uid()) AND (r.status = ANY (ARRAY['draft'::text, 'submitted'::text]))))))));


--
-- Name: report report_insert_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_insert_policy ON public.report FOR INSERT TO authenticated WITH CHECK (((public.current_app_role() = 'admin'::text) OR ((public.current_app_role() = 'analyst'::text) AND (owner_user_id = auth.uid()))));


--
-- Name: report_push_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.report_push_log ENABLE ROW LEVEL SECURITY;

--
-- Name: report_push_log report_push_log_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_push_log_insert_admin ON public.report_push_log FOR INSERT WITH CHECK (((auth.jwt() ->> 'role'::text) = 'admin'::text));


--
-- Name: report_push_log report_push_log_select_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_push_log_select_admin ON public.report_push_log FOR SELECT USING (((auth.jwt() ->> 'role'::text) = 'admin'::text));


--
-- Name: report_push_log report_push_log_select_analyst; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_push_log_select_analyst ON public.report_push_log FOR SELECT USING ((((auth.jwt() ->> 'role'::text) = 'analyst'::text) AND (EXISTS ( SELECT 1
   FROM public.report r
  WHERE ((r.id = report_push_log.report_id) AND (r.owner_user_id = ((auth.jwt() ->> 'id'::text))::uuid))))));


--
-- Name: report_push_log report_push_log_select_sa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_push_log_select_sa ON public.report_push_log FOR SELECT USING ((((auth.jwt() ->> 'role'::text) = 'sa'::text) AND (EXISTS ( SELECT 1
   FROM public.report r
  WHERE ((r.id = report_push_log.report_id) AND (r.status = ANY (ARRAY['submitted'::text, 'published'::text, 'rejected'::text])))))));


--
-- Name: report report_select_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_select_policy ON public.report FOR SELECT TO authenticated USING (((public.current_app_role() = 'admin'::text) OR ((public.current_app_role() = 'sa'::text) AND (status = ANY (ARRAY['draft'::text, 'submitted'::text, 'published'::text, 'rejected'::text]))) OR ((public.current_app_role() = 'analyst'::text) AND (owner_user_id = auth.uid()))));


--
-- Name: report_status_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.report_status_log ENABLE ROW LEVEL SECURITY;

--
-- Name: report_status_log report_status_log_insert_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_status_log_insert_policy ON public.report_status_log FOR INSERT TO authenticated WITH CHECK (((action_by = auth.uid()) AND ((public.current_app_role() = 'admin'::text) OR ((public.current_app_role() = 'sa'::text) AND (from_status = ANY (ARRAY['submitted'::text, 'rejected'::text]))) OR ((public.current_app_role() = 'analyst'::text) AND (from_status = 'draft'::text) AND (to_status = 'submitted'::text) AND (EXISTS ( SELECT 1
   FROM public.report r
  WHERE ((r.id = report_status_log.report_id) AND (r.owner_user_id = auth.uid()))))))));


--
-- Name: report_status_log report_status_log_select_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_status_log_select_policy ON public.report_status_log FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.report r
  WHERE ((r.id = report_status_log.report_id) AND ((public.current_app_role() = 'admin'::text) OR ((public.current_app_role() = 'sa'::text) AND (r.status = ANY (ARRAY['submitted'::text, 'published'::text, 'rejected'::text]))) OR ((public.current_app_role() = 'analyst'::text) AND (r.owner_user_id = auth.uid())))))));


--
-- Name: report_type; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.report_type ENABLE ROW LEVEL SECURITY;

--
-- Name: report_type report_type_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_type_select_authenticated ON public.report_type FOR SELECT TO authenticated USING (true);


--
-- Name: report report_update_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_update_policy ON public.report FOR UPDATE TO authenticated USING (((public.current_app_role() = 'admin'::text) OR ((public.current_app_role() = 'analyst'::text) AND (owner_user_id = auth.uid()) AND (status = ANY (ARRAY['draft'::text, 'submitted'::text]))))) WITH CHECK (((public.current_app_role() = 'admin'::text) OR ((public.current_app_role() = 'analyst'::text) AND (owner_user_id = auth.uid()) AND (status = ANY (ARRAY['draft'::text, 'submitted'::text])))));


--
-- Name: report_version; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.report_version ENABLE ROW LEVEL SECURITY;

--
-- Name: report_version report_version_insert_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_version_insert_policy ON public.report_version FOR INSERT TO authenticated WITH CHECK (((changed_by = auth.uid()) AND (EXISTS ( SELECT 1
   FROM public.report r
  WHERE ((r.id = report_version.report_id) AND ((public.current_app_role() = 'admin'::text) OR ((public.current_app_role() = 'analyst'::text) AND (r.owner_user_id = auth.uid()) AND (r.status = ANY (ARRAY['draft'::text, 'submitted'::text])))))))));


--
-- Name: report_version report_version_select_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_version_select_policy ON public.report_version FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.report r
  WHERE ((r.id = report_version.report_id) AND ((public.current_app_role() = 'admin'::text) OR ((public.current_app_role() = 'sa'::text) AND (r.status = ANY (ARRAY['submitted'::text, 'published'::text, 'rejected'::text]))) OR ((public.current_app_role() = 'analyst'::text) AND (r.owner_user_id = auth.uid())))))));


--
-- Name: rqc_approve; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rqc_approve ENABLE ROW LEVEL SECURITY;

--
-- Name: rqc_approve rqc_approve_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rqc_approve_delete ON public.rqc_approve FOR DELETE TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.report
  WHERE ((report.id = rqc_approve.report_id) AND (report.owner_user_id = auth.uid())))) OR (public.current_app_role() = ANY (ARRAY['sa'::text, 'admin'::text]))));


--
-- Name: rqc_approve rqc_approve_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rqc_approve_insert ON public.rqc_approve FOR INSERT TO authenticated WITH CHECK (((EXISTS ( SELECT 1
   FROM public.report
  WHERE ((report.id = rqc_approve.report_id) AND (report.owner_user_id = auth.uid())))) OR (public.current_app_role() = ANY (ARRAY['sa'::text, 'admin'::text]))));


--
-- Name: rqc_approve rqc_approve_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rqc_approve_select ON public.rqc_approve FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.report
  WHERE ((report.id = rqc_approve.report_id) AND (report.owner_user_id = auth.uid())))) OR (public.current_app_role() = ANY (ARRAY['sa'::text, 'admin'::text]))));


--
-- Name: rqc_approve rqc_approve_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rqc_approve_update ON public.rqc_approve FOR UPDATE TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.report
  WHERE ((report.id = rqc_approve.report_id) AND (report.owner_user_id = auth.uid())))) OR (public.current_app_role() = ANY (ARRAY['sa'::text, 'admin'::text]))));


--
-- Name: sector; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sector ENABLE ROW LEVEL SECURITY;

--
-- Name: sector sector_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sector_select_authenticated ON public.sector FOR SELECT TO authenticated USING (true);


--
-- Name: sector sector_write_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sector_write_admin ON public.sector TO authenticated USING ((((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = 'admin'::text)) WITH CHECK ((((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = 'admin'::text));


--
-- Name: template; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.template ENABLE ROW LEVEL SECURITY;

--
-- Name: template template_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY template_select_authenticated ON public.template FOR SELECT TO authenticated USING (true);


--
-- Name: template template_write_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY template_write_admin ON public.template TO authenticated USING ((((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = 'admin'::text)) WITH CHECK ((((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = 'admin'::text));


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION add_to_distribution_queue(p_report_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.add_to_distribution_queue(p_report_id uuid) TO postgres;
GRANT ALL ON FUNCTION public.add_to_distribution_queue(p_report_id uuid) TO anon;
GRANT ALL ON FUNCTION public.add_to_distribution_queue(p_report_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.add_to_distribution_queue(p_report_id uuid) TO service_role;


--
-- Name: FUNCTION current_app_role(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.current_app_role() TO postgres;
GRANT ALL ON FUNCTION public.current_app_role() TO anon;
GRANT ALL ON FUNCTION public.current_app_role() TO authenticated;
GRANT ALL ON FUNCTION public.current_app_role() TO service_role;


--
-- Name: FUNCTION get_active_subscription_emails(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.get_active_subscription_emails() TO postgres;
GRANT ALL ON FUNCTION public.get_active_subscription_emails() TO anon;
GRANT ALL ON FUNCTION public.get_active_subscription_emails() TO authenticated;
GRANT ALL ON FUNCTION public.get_active_subscription_emails() TO service_role;


--
-- Name: FUNCTION get_user_full_name(p_user_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.get_user_full_name(p_user_id uuid) TO postgres;
GRANT ALL ON FUNCTION public.get_user_full_name(p_user_id uuid) TO anon;
GRANT ALL ON FUNCTION public.get_user_full_name(p_user_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_user_full_name(p_user_id uuid) TO service_role;


--
-- Name: FUNCTION prevent_update_delete_append_only(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.prevent_update_delete_append_only() TO postgres;
GRANT ALL ON FUNCTION public.prevent_update_delete_append_only() TO anon;
GRANT ALL ON FUNCTION public.prevent_update_delete_append_only() TO authenticated;
GRANT ALL ON FUNCTION public.prevent_update_delete_append_only() TO service_role;


--
-- Name: TABLE report; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.report TO postgres;
GRANT ALL ON TABLE public.report TO anon;
GRANT ALL ON TABLE public.report TO authenticated;
GRANT ALL ON TABLE public.report TO service_role;


--
-- Name: FUNCTION report_change_status_atomic(p_report_id uuid, p_to_status text, p_action_by uuid, p_reason text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.report_change_status_atomic(p_report_id uuid, p_to_status text, p_action_by uuid, p_reason text) TO postgres;
GRANT ALL ON FUNCTION public.report_change_status_atomic(p_report_id uuid, p_to_status text, p_action_by uuid, p_reason text) TO anon;
GRANT ALL ON FUNCTION public.report_change_status_atomic(p_report_id uuid, p_to_status text, p_action_by uuid, p_reason text) TO authenticated;
GRANT ALL ON FUNCTION public.report_change_status_atomic(p_report_id uuid, p_to_status text, p_action_by uuid, p_reason text) TO service_role;


--
-- Name: FUNCTION report_enforce_owner_immutable(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.report_enforce_owner_immutable() TO postgres;
GRANT ALL ON FUNCTION public.report_enforce_owner_immutable() TO anon;
GRANT ALL ON FUNCTION public.report_enforce_owner_immutable() TO authenticated;
GRANT ALL ON FUNCTION public.report_enforce_owner_immutable() TO service_role;


--
-- Name: FUNCTION report_enforce_status_transition(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.report_enforce_status_transition() TO postgres;
GRANT ALL ON FUNCTION public.report_enforce_status_transition() TO anon;
GRANT ALL ON FUNCTION public.report_enforce_status_transition() TO authenticated;
GRANT ALL ON FUNCTION public.report_enforce_status_transition() TO service_role;


--
-- Name: FUNCTION report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text) TO postgres;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text) TO anon;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text) TO authenticated;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text) TO service_role;


--
-- Name: FUNCTION report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text) TO postgres;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text) TO anon;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text) TO authenticated;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text) TO service_role;


--
-- Name: FUNCTION report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person text, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person text, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text) TO postgres;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person text, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text) TO anon;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person text, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text) TO authenticated;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person text, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text) TO service_role;


--
-- Name: FUNCTION report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_code text, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_code text, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text) TO postgres;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_code text, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text) TO anon;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_code text, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text) TO authenticated;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_code text, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text) TO service_role;


--
-- Name: FUNCTION report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text) TO postgres;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text) TO anon;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text) TO authenticated;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price numeric, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text) TO service_role;


--
-- Name: FUNCTION report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_code text, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_pdf_file_path text, p_model_file_path text, p_word_file_name text, p_pdf_file_name text, p_model_file_name text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_code text, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_pdf_file_path text, p_model_file_path text, p_word_file_name text, p_pdf_file_name text, p_model_file_name text) TO postgres;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_code text, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_pdf_file_path text, p_model_file_path text, p_word_file_name text, p_pdf_file_name text, p_model_file_name text) TO anon;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_code text, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_pdf_file_path text, p_model_file_path text, p_word_file_name text, p_pdf_file_name text, p_model_file_name text) TO authenticated;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_code text, p_sector_id uuid, p_report_language text, p_contact_person_id uuid, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_pdf_file_path text, p_model_file_path text, p_word_file_name text, p_pdf_file_name text, p_model_file_name text) TO service_role;


--
-- Name: FUNCTION report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person text, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text, p_chief_approval_screenshot_path text, p_chief_approval_screenshot_name text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person text, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text, p_chief_approval_screenshot_path text, p_chief_approval_screenshot_name text) TO postgres;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person text, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text, p_chief_approval_screenshot_path text, p_chief_approval_screenshot_name text) TO anon;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person text, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text, p_chief_approval_screenshot_path text, p_chief_approval_screenshot_name text) TO authenticated;
GRANT ALL ON FUNCTION public.report_save_content_atomic(p_report_id uuid, p_title text, p_report_type text, p_ticker text, p_rating text, p_target_price text, p_region_id uuid, p_sector_id uuid, p_report_language text, p_contact_person text, p_investment_thesis text, p_certificate_confirmed boolean, p_coverage_id uuid, p_analysts jsonb, p_changed_by uuid, p_word_file_path text, p_model_file_path text, p_word_file_name text, p_model_file_name text, p_chief_approval_screenshot_path text, p_chief_approval_screenshot_name text) TO service_role;


--
-- Name: FUNCTION report_status_is_valid(from_status text, to_status text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.report_status_is_valid(from_status text, to_status text) TO postgres;
GRANT ALL ON FUNCTION public.report_status_is_valid(from_status text, to_status text) TO anon;
GRANT ALL ON FUNCTION public.report_status_is_valid(from_status text, to_status text) TO authenticated;
GRANT ALL ON FUNCTION public.report_status_is_valid(from_status text, to_status text) TO service_role;


--
-- Name: FUNCTION report_status_log_enforce_transition(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.report_status_log_enforce_transition() TO postgres;
GRANT ALL ON FUNCTION public.report_status_log_enforce_transition() TO anon;
GRANT ALL ON FUNCTION public.report_status_log_enforce_transition() TO authenticated;
GRANT ALL ON FUNCTION public.report_status_log_enforce_transition() TO service_role;


--
-- Name: FUNCTION rpc_report_create(p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_region_code text, p_analyst_ids uuid[], p_contact_user_id uuid, p_target_price numeric, p_rating_id uuid, p_pdf_data bytea, p_pdf_filename text, p_current_version_no integer, p_rating_agency text, p_report_date date, p_price_currency text, p_target_price_currency text, p_target_price_maturity date, p_target_price_2 numeric, p_target_price_2_currency text, p_target_price_2_maturity date, p_irr numeric, p_irr_currency text, p_irr_maturity date, p_key_metrics jsonb, p_key_risks jsonb, p_investment_teaser text, p_investment_highlight text, p_investment_summary text, p_executive_summary text, p_table_of_contents jsonb, p_analyst_note text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.rpc_report_create(p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_region_code text, p_analyst_ids uuid[], p_contact_user_id uuid, p_target_price numeric, p_rating_id uuid, p_pdf_data bytea, p_pdf_filename text, p_current_version_no integer, p_rating_agency text, p_report_date date, p_price_currency text, p_target_price_currency text, p_target_price_maturity date, p_target_price_2 numeric, p_target_price_2_currency text, p_target_price_2_maturity date, p_irr numeric, p_irr_currency text, p_irr_maturity date, p_key_metrics jsonb, p_key_risks jsonb, p_investment_teaser text, p_investment_highlight text, p_investment_summary text, p_executive_summary text, p_table_of_contents jsonb, p_analyst_note text) TO postgres;
GRANT ALL ON FUNCTION public.rpc_report_create(p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_region_code text, p_analyst_ids uuid[], p_contact_user_id uuid, p_target_price numeric, p_rating_id uuid, p_pdf_data bytea, p_pdf_filename text, p_current_version_no integer, p_rating_agency text, p_report_date date, p_price_currency text, p_target_price_currency text, p_target_price_maturity date, p_target_price_2 numeric, p_target_price_2_currency text, p_target_price_2_maturity date, p_irr numeric, p_irr_currency text, p_irr_maturity date, p_key_metrics jsonb, p_key_risks jsonb, p_investment_teaser text, p_investment_highlight text, p_investment_summary text, p_executive_summary text, p_table_of_contents jsonb, p_analyst_note text) TO anon;
GRANT ALL ON FUNCTION public.rpc_report_create(p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_region_code text, p_analyst_ids uuid[], p_contact_user_id uuid, p_target_price numeric, p_rating_id uuid, p_pdf_data bytea, p_pdf_filename text, p_current_version_no integer, p_rating_agency text, p_report_date date, p_price_currency text, p_target_price_currency text, p_target_price_maturity date, p_target_price_2 numeric, p_target_price_2_currency text, p_target_price_2_maturity date, p_irr numeric, p_irr_currency text, p_irr_maturity date, p_key_metrics jsonb, p_key_risks jsonb, p_investment_teaser text, p_investment_highlight text, p_investment_summary text, p_executive_summary text, p_table_of_contents jsonb, p_analyst_note text) TO authenticated;
GRANT ALL ON FUNCTION public.rpc_report_create(p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_region_code text, p_analyst_ids uuid[], p_contact_user_id uuid, p_target_price numeric, p_rating_id uuid, p_pdf_data bytea, p_pdf_filename text, p_current_version_no integer, p_rating_agency text, p_report_date date, p_price_currency text, p_target_price_currency text, p_target_price_maturity date, p_target_price_2 numeric, p_target_price_2_currency text, p_target_price_2_maturity date, p_irr numeric, p_irr_currency text, p_irr_maturity date, p_key_metrics jsonb, p_key_risks jsonb, p_investment_teaser text, p_investment_highlight text, p_investment_summary text, p_executive_summary text, p_table_of_contents jsonb, p_analyst_note text) TO service_role;


--
-- Name: FUNCTION rpc_report_update(p_report_id uuid, p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_region_code text, p_analyst_ids uuid[], p_contact_user_id uuid, p_target_price numeric, p_rating_id uuid, p_pdf_data bytea, p_pdf_filename text, p_current_version_no integer, p_rating_agency text, p_report_date date, p_price_currency text, p_target_price_currency text, p_target_price_maturity date, p_target_price_2 numeric, p_target_price_2_currency text, p_target_price_2_maturity date, p_irr numeric, p_irr_currency text, p_irr_maturity date, p_key_metrics jsonb, p_key_risks jsonb, p_investment_teaser text, p_investment_highlight text, p_investment_summary text, p_executive_summary text, p_table_of_contents jsonb, p_analyst_note text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.rpc_report_update(p_report_id uuid, p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_region_code text, p_analyst_ids uuid[], p_contact_user_id uuid, p_target_price numeric, p_rating_id uuid, p_pdf_data bytea, p_pdf_filename text, p_current_version_no integer, p_rating_agency text, p_report_date date, p_price_currency text, p_target_price_currency text, p_target_price_maturity date, p_target_price_2 numeric, p_target_price_2_currency text, p_target_price_2_maturity date, p_irr numeric, p_irr_currency text, p_irr_maturity date, p_key_metrics jsonb, p_key_risks jsonb, p_investment_teaser text, p_investment_highlight text, p_investment_summary text, p_executive_summary text, p_table_of_contents jsonb, p_analyst_note text) TO postgres;
GRANT ALL ON FUNCTION public.rpc_report_update(p_report_id uuid, p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_region_code text, p_analyst_ids uuid[], p_contact_user_id uuid, p_target_price numeric, p_rating_id uuid, p_pdf_data bytea, p_pdf_filename text, p_current_version_no integer, p_rating_agency text, p_report_date date, p_price_currency text, p_target_price_currency text, p_target_price_maturity date, p_target_price_2 numeric, p_target_price_2_currency text, p_target_price_2_maturity date, p_irr numeric, p_irr_currency text, p_irr_maturity date, p_key_metrics jsonb, p_key_risks jsonb, p_investment_teaser text, p_investment_highlight text, p_investment_summary text, p_executive_summary text, p_table_of_contents jsonb, p_analyst_note text) TO anon;
GRANT ALL ON FUNCTION public.rpc_report_update(p_report_id uuid, p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_region_code text, p_analyst_ids uuid[], p_contact_user_id uuid, p_target_price numeric, p_rating_id uuid, p_pdf_data bytea, p_pdf_filename text, p_current_version_no integer, p_rating_agency text, p_report_date date, p_price_currency text, p_target_price_currency text, p_target_price_maturity date, p_target_price_2 numeric, p_target_price_2_currency text, p_target_price_2_maturity date, p_irr numeric, p_irr_currency text, p_irr_maturity date, p_key_metrics jsonb, p_key_risks jsonb, p_investment_teaser text, p_investment_highlight text, p_investment_summary text, p_executive_summary text, p_table_of_contents jsonb, p_analyst_note text) TO authenticated;
GRANT ALL ON FUNCTION public.rpc_report_update(p_report_id uuid, p_title text, p_report_type text, p_coverage_id uuid, p_sector_id uuid, p_region_code text, p_analyst_ids uuid[], p_contact_user_id uuid, p_target_price numeric, p_rating_id uuid, p_pdf_data bytea, p_pdf_filename text, p_current_version_no integer, p_rating_agency text, p_report_date date, p_price_currency text, p_target_price_currency text, p_target_price_maturity date, p_target_price_2 numeric, p_target_price_2_currency text, p_target_price_2_maturity date, p_irr numeric, p_irr_currency text, p_irr_maturity date, p_key_metrics jsonb, p_key_risks jsonb, p_investment_teaser text, p_investment_highlight text, p_investment_summary text, p_executive_summary text, p_table_of_contents jsonb, p_analyst_note text) TO service_role;


--
-- Name: FUNCTION set_coverage_index_code(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.set_coverage_index_code() TO postgres;
GRANT ALL ON FUNCTION public.set_coverage_index_code() TO anon;
GRANT ALL ON FUNCTION public.set_coverage_index_code() TO authenticated;
GRANT ALL ON FUNCTION public.set_coverage_index_code() TO service_role;


--
-- Name: FUNCTION set_updated_at_utc(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.set_updated_at_utc() TO postgres;
GRANT ALL ON FUNCTION public.set_updated_at_utc() TO anon;
GRANT ALL ON FUNCTION public.set_updated_at_utc() TO authenticated;
GRANT ALL ON FUNCTION public.set_updated_at_utc() TO service_role;


--
-- Name: FUNCTION trg_report_push_log_no_update_delete(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.trg_report_push_log_no_update_delete() TO anon;
GRANT ALL ON FUNCTION public.trg_report_push_log_no_update_delete() TO authenticated;
GRANT ALL ON FUNCTION public.trg_report_push_log_no_update_delete() TO service_role;


--
-- Name: FUNCTION validate_coverage_analyst_limit(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.validate_coverage_analyst_limit() TO postgres;
GRANT ALL ON FUNCTION public.validate_coverage_analyst_limit() TO anon;
GRANT ALL ON FUNCTION public.validate_coverage_analyst_limit() TO authenticated;
GRANT ALL ON FUNCTION public.validate_coverage_analyst_limit() TO service_role;


--
-- Name: FUNCTION validate_sector_hierarchy(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.validate_sector_hierarchy() TO postgres;
GRANT ALL ON FUNCTION public.validate_sector_hierarchy() TO anon;
GRANT ALL ON FUNCTION public.validate_sector_hierarchy() TO authenticated;
GRANT ALL ON FUNCTION public.validate_sector_hierarchy() TO service_role;


--
-- Name: TABLE analyst; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.analyst TO postgres;
GRANT ALL ON TABLE public.analyst TO anon;
GRANT ALL ON TABLE public.analyst TO authenticated;
GRANT ALL ON TABLE public.analyst TO service_role;


--
-- Name: TABLE chief_approve; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.chief_approve TO postgres;
GRANT ALL ON TABLE public.chief_approve TO anon;
GRANT ALL ON TABLE public.chief_approve TO authenticated;
GRANT ALL ON TABLE public.chief_approve TO service_role;


--
-- Name: TABLE coverage; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.coverage TO postgres;
GRANT ALL ON TABLE public.coverage TO anon;
GRANT ALL ON TABLE public.coverage TO authenticated;
GRANT ALL ON TABLE public.coverage TO service_role;


--
-- Name: TABLE coverage_analyst; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.coverage_analyst TO postgres;
GRANT ALL ON TABLE public.coverage_analyst TO anon;
GRANT ALL ON TABLE public.coverage_analyst TO authenticated;
GRANT ALL ON TABLE public.coverage_analyst TO service_role;


--
-- Name: TABLE rating; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.rating TO postgres;
GRANT ALL ON TABLE public.rating TO anon;
GRANT ALL ON TABLE public.rating TO authenticated;
GRANT ALL ON TABLE public.rating TO service_role;


--
-- Name: TABLE region; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.region TO postgres;
GRANT ALL ON TABLE public.region TO anon;
GRANT ALL ON TABLE public.region TO authenticated;
GRANT ALL ON TABLE public.region TO service_role;


--
-- Name: TABLE report_analyst; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.report_analyst TO postgres;
GRANT ALL ON TABLE public.report_analyst TO anon;
GRANT ALL ON TABLE public.report_analyst TO authenticated;
GRANT ALL ON TABLE public.report_analyst TO service_role;


--
-- Name: TABLE report_push_log; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.report_push_log TO anon;
GRANT ALL ON TABLE public.report_push_log TO authenticated;
GRANT ALL ON TABLE public.report_push_log TO service_role;


--
-- Name: TABLE report_status_log; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.report_status_log TO postgres;
GRANT ALL ON TABLE public.report_status_log TO anon;
GRANT ALL ON TABLE public.report_status_log TO authenticated;
GRANT ALL ON TABLE public.report_status_log TO service_role;


--
-- Name: TABLE report_type; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.report_type TO postgres;
GRANT ALL ON TABLE public.report_type TO anon;
GRANT ALL ON TABLE public.report_type TO authenticated;
GRANT ALL ON TABLE public.report_type TO service_role;


--
-- Name: TABLE report_version; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.report_version TO postgres;
GRANT ALL ON TABLE public.report_version TO anon;
GRANT ALL ON TABLE public.report_version TO authenticated;
GRANT ALL ON TABLE public.report_version TO service_role;


--
-- Name: TABLE rqc_approve; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.rqc_approve TO postgres;
GRANT ALL ON TABLE public.rqc_approve TO anon;
GRANT ALL ON TABLE public.rqc_approve TO authenticated;
GRANT ALL ON TABLE public.rqc_approve TO service_role;


--
-- Name: TABLE sector; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.sector TO postgres;
GRANT ALL ON TABLE public.sector TO anon;
GRANT ALL ON TABLE public.sector TO authenticated;
GRANT ALL ON TABLE public.sector TO service_role;


--
-- Name: TABLE template; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.template TO postgres;
GRANT ALL ON TABLE public.template TO anon;
GRANT ALL ON TABLE public.template TO authenticated;
GRANT ALL ON TABLE public.template TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- PostgreSQL database dump complete
--

\unrestrict CsOnN4EwvUlZi2SPqCDOm8LsCjCpd6ip7ipfdUDRjueBcwqyYUYasdOP7o7go8F

