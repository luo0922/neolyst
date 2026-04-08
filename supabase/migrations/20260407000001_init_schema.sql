-- ============================================================
-- 数据库初始化脚本 (Unified DDL)
-- 创建时间: 2026-04-07
-- 说明: 此文件为一次性初始化脚本，包含完整的 schema 定义
-- ============================================================

-- ============================================================
-- 1. 扩展
-- ============================================================
create extension if not exists pgcrypto;
create extension if not exists citext;

-- ============================================================
-- 2. 公共辅助函数
-- ============================================================

-- 自动更新时间戳
create or replace function public.set_updated_at_utc()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
comment on function public.set_updated_at_utc() is '触发器函数：自动将updated_at字段更新为当前UTC时间';

-- 获取当前应用角色
create or replace function public.current_app_role()
returns text
language sql
stable
as $$
  select coalesce(auth.jwt()->'app_metadata'->>'role', '');
$$;
comment on function public.current_app_role() is '获取当前用户的应用角色（从JWT的app_metadata.role读取）';

-- 报告状态转换验证
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
comment on function public.report_status_is_valid(text, text) is '验证报告状态转换是否合法：draft->submitted, submitted->published/rejected, rejected->draft';

-- 获取用户全名
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
comment on function public.get_user_full_name(uuid) is '根据用户ID获取用户在auth.users中的full_name';

-- append-only 表保护
create or replace function public.prevent_update_delete_append_only()
returns trigger
language plpgsql
as $$
begin
  raise exception 'append-only table: update/delete is not allowed';
end;
$$;
comment on function public.prevent_update_delete_append_only() is '触发器函数：禁止对append-only表的UPDATE和DELETE操作';

-- ============================================================
-- 3. Storage Buckets
-- ============================================================

-- templates bucket
insert into storage.buckets (id, name, public)
values ('templates', 'templates', false)
on conflict (id) do nothing;

-- reports bucket
insert into storage.buckets (id, name, public)
values ('reports', 'reports', false)
on conflict (id) do nothing;

-- ============================================================
-- 4. 基础字典表
-- ============================================================

-- region 表
create table public.region (
  id uuid primary key default gen_random_uuid(),
  name_en text not null,
  name_cn text not null,
  code text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uk_region_name_en unique (name_en),
  constraint uk_region_name_cn unique (name_cn)
);

comment on table public.region is '区域表：存储研究覆盖的地理区域信息，支持中英文名称和ISO 3166-1 alpha-2编码';
comment on column public.region.id is '主键UUID';
comment on column public.region.name_en is '区域英文名称';
comment on column public.region.name_cn is '区域中文名称';
comment on column public.region.code is 'ISO 3166-1 alpha-2 国家/地区代码（如CN、HK、JP等）';
comment on column public.region.is_active is '是否启用：true=启用，false=禁用';
comment on column public.region.created_at is '创建时间（UTC）';
comment on column public.region.updated_at is '最后更新时间（UTC）';

create index idx_region_created_at_desc on public.region(created_at desc);
create trigger trg_region_updated_at
  before update on public.region
  for each row execute function public.set_updated_at_utc();

-- rating 表
create table public.rating (
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

create index idx_rating_sort on public.rating(sort);
create index idx_rating_code on public.rating(code);
create index idx_rating_is_active on public.rating(is_active);

-- report_type 表
create table public.report_type (
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

create index idx_report_type_sort on public.report_type(sort);
create index idx_report_type_code on public.report_type(code);
create index idx_report_type_is_active on public.report_type(is_active);

-- ============================================================
-- 5. 分析师表
-- ============================================================

create table public.analyst (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  chinese_name text,
  email citext not null unique,
  region_code text references public.region(code) on delete set null,
  suffix text,
  sfc text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.analyst is '分析师信息表：存储分析师的详细资料，与auth.users解耦';
comment on column public.analyst.id is '主键UUID';
comment on column public.analyst.full_name is '分析师英文全名';
comment on column public.analyst.chinese_name is '分析师中文名';
comment on column public.analyst.email is '分析师邮箱（唯一，citext类型不区分大小写）';
comment on column public.analyst.region_code is '所属区域代码（ISO 3166-1 alpha-2），关联region.code，删除区域时置空';
comment on column public.analyst.suffix is '分析师姓名后缀（如Jr.、Sr.等）';
comment on column public.analyst.sfc is '分析师SFC注册编号（香港证监会）';
comment on column public.analyst.is_active is '是否在职：true=在职，false=离职';
comment on column public.analyst.created_at is '创建时间（UTC）';
comment on column public.analyst.updated_at is '最后更新时间（UTC）';

create index idx_analyst_created_at_desc on public.analyst(created_at desc);
create index idx_analyst_full_name on public.analyst(full_name);
create index idx_analyst_chinese_name on public.analyst(chinese_name);
create index idx_analyst_email on public.analyst(email);
create index idx_analyst_suffix on public.analyst(suffix);
create index idx_analyst_sfc on public.analyst(sfc);

create trigger trg_analyst_updated_at
  before update on public.analyst
  for each row execute function public.set_updated_at_utc();

-- ============================================================
-- 6. 行业分类表
-- ============================================================

-- 层级验证函数
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
comment on function public.validate_sector_hierarchy() is '触发器函数：验证行业分类层级结构合法性（两级，禁止循环，禁止跨级引用）';

create table public.sector (
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

comment on table public.sector is '行业分类表：存储两级行业分类体系（level=1一级/level=2二级），通过parent_id建立层级关系';
comment on column public.sector.id is '主键UUID';
comment on column public.sector.level is '层级：1=一级行业，2=二级行业';
comment on column public.sector.parent_id is '父级行业ID（level=1时必须为空，level=2时必须引用level=1的记录）';
comment on column public.sector.name_en is '行业英文名称';
comment on column public.sector.name_cn is '行业中文名称';
comment on column public.sector.wind_name is 'Wind万得行业名称（用于与Wind数据对接）';
comment on column public.sector.is_active is '是否启用：true=启用，false=禁用';
comment on column public.sector.created_at is '创建时间（UTC）';
comment on column public.sector.updated_at is '最后更新时间（UTC）';

create index idx_sector_level_parent on public.sector(level, parent_id);
create index idx_sector_name_en_lower on public.sector(lower(name_en));
create index idx_sector_active on public.sector(is_active);
create unique index uidx_sector_l1_name_en
  on public.sector(lower(name_en)) where parent_id is null;
create unique index uidx_sector_l2_parent_name_en
  on public.sector(parent_id, lower(name_en)) where parent_id is not null;

create trigger trg_sector_hierarchy
  before insert or update on public.sector
  for each row execute function public.validate_sector_hierarchy();

create trigger trg_sector_updated_at
  before update on public.sector
  for each row execute function public.set_updated_at_utc();

-- ============================================================
-- 7. 公司覆盖表
-- ============================================================

create table public.coverage (
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

comment on table public.coverage is '公司覆盖表：存储被研究覆盖的上市公司基本信息';
comment on column public.coverage.id is '主键UUID';
comment on column public.coverage.ticker is '股票代码（唯一，存储时统一处理大小写和空格）';
comment on column public.coverage.english_full_name is '公司英文全称';
comment on column public.coverage.chinese_short_name is '公司中文简称';
comment on column public.coverage.traditional_chinese is '公司繁体中文名称';
comment on column public.coverage.sector_id is '所属行业ID，关联sector.id，禁止删除已关联行业';
comment on column public.coverage.isin is 'ISIN国际证券识别码（唯一，存储时统一大写）';
comment on column public.coverage.country_of_domicile is '公司注册地/上市地';
comment on column public.coverage.reporting_currency is '报告使用货币';
comment on column public.coverage.ads_conversion_factor is 'ADS美股存托股折算因子';
comment on column public.coverage.is_duplicate is '是否重复记录';
comment on column public.coverage.approved_by is '审批人ID，关联auth.users，删除用户时置空';
comment on column public.coverage.approved_at is '审批时间';
comment on column public.coverage.is_active is '是否启用：true=启用，false=禁用';
comment on column public.coverage.created_at is '创建时间（UTC）';
comment on column public.coverage.updated_at is '最后更新时间（UTC）';

create unique index uidx_coverage_ticker_lower on public.coverage(lower(btrim(ticker)));
create unique index uidx_coverage_isin_upper on public.coverage(upper(btrim(isin)));
create index idx_coverage_sector on public.coverage(sector_id);
create index idx_coverage_name_lower on public.coverage(lower(english_full_name));
create index idx_coverage_updated_at_desc on public.coverage(updated_at desc);

create trigger trg_coverage_updated_at
  before update on public.coverage
  for each row execute function public.set_updated_at_utc();

-- ============================================================
-- 8. 覆盖-分析师关系表
-- ============================================================

-- 分析师数量限制验证函数
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
comment on function public.validate_coverage_analyst_limit() is '触发器函数：验证每个coverage最多关联4位分析师';

create table public.coverage_analyst (
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

comment on table public.coverage_analyst is '覆盖-分析师关系表：建立公司与分析师的覆盖关系，每公司最多4位分析师';
comment on column public.coverage_analyst.id is '主键UUID';
comment on column public.coverage_analyst.coverage_id is '覆盖公司ID，关联coverage.id，删除公司时级联删除';
comment on column public.coverage_analyst.analyst_id is '分析师ID，关联analyst.id，禁止删除已关联分析师';
comment on column public.coverage_analyst.role is '角色序号（1-4）：1=主分析师，2=联合分析师，3=辅助分析师，4=审核分析师';
comment on column public.coverage_analyst.sort_order is '排序序号（1-4），决定前端展示顺序，同公司内唯一';
comment on column public.coverage_analyst.created_at is '创建时间（UTC）';
comment on column public.coverage_analyst.updated_at is '最后更新时间（UTC）';

create index idx_cov_analyst_coverage on public.coverage_analyst(coverage_id);
create index idx_cov_analyst_analyst on public.coverage_analyst(analyst_id);

create trigger trg_coverage_analyst_limit
  before insert or update on public.coverage_analyst
  for each row execute function public.validate_coverage_analyst_limit();

create trigger trg_coverage_analyst_updated_at
  before update on public.coverage_analyst
  for each row execute function public.set_updated_at_utc();

-- ============================================================
-- 9. 模板表
-- ============================================================

create table public.template (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  report_type text not null,
  template_file_path text,
  schema_file_path text,
  version integer not null default 1,
  sort integer not null default 0,
  uploaded_by uuid references auth.users(id) on delete restrict,
  language text not null default 'en',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint template_language_check check (language in ('en', 'zh')),
  constraint template_uniq_version unique (report_type, language, version)
);

comment on table public.template is '报告模板表：存储报告 Word 模板文件信息，每种报告类型+语言按 created_at 倒序取最新一条，不区分 report/model 类型';
comment on column public.template.id is '主键UUID';
comment on column public.template.name is '模板名称（如"公司报告模板v1"）';
comment on column public.template.report_type is '报告类型代码（如 company/sector/company_flash 等），值来自 report_type 表';
comment on column public.template.template_file_path is 'Word 模板文件存储路径（Supabase Storage templates bucket 下的路径），非空时表示模板文件已上传';
comment on column public.template.schema_file_path is 'Word schema 描述文件存储路径（Supabase Storage 下的 JSON 文件路径），描述模板所需的字段名称、位置和特征，可为空';
comment on column public.template.version is '版本号（>=1），同一 (report_type, language) 内递增，每次上传新版本时自动分配';
comment on column public.template.sort is '排序序号（整数，数字越小越靠前），用于 Templates 列表排序，同一 report_type 内有效';
comment on column public.template.uploaded_by is '上传人ID，关联 auth.users，初始化占位模板允许为空';
comment on column public.template.language is '模板语言：en=英文模板，zh=中文模板';
comment on column public.template.created_at is '创建时间（UTC），用于倒序取最新版本';
comment on column public.template.updated_at is '最后更新时间（UTC）';

create index idx_template_group on public.template(report_type, language);
create index idx_template_created_at_desc on public.template(created_at desc);

create trigger trg_template_updated_at
  before update on public.template
  for each row execute function public.set_updated_at_utc();

-- ============================================================
-- 10. 研究报告主表
-- ============================================================

-- 报告所有者不可变更验证
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
comment on function public.report_enforce_owner_immutable() is '触发器函数：禁止修改报告的owner_user_id';

-- 报告状态转换验证
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
comment on function public.report_enforce_status_transition() is '触发器函数：验证报告状态转换合法性';

create table public.report (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  title text not null,
  report_type text not null,
  status text not null default 'draft' check (status in ('draft', 'submitted', 'published', 'rejected')),
  current_version_no integer not null default 0 check (current_version_no >= 0),
  coverage_id uuid references public.coverage(id) on delete set null,
  sector_id uuid references public.sector(id) on delete set null,
  region_code text references public.region(code) on delete set null,
  ticker text,
  rating text,
  target_price numeric check (target_price is null or target_price > 0),
  report_language text check (report_language in ('zh', 'en')),
  contact_person_id uuid references auth.users(id) on delete set null,
  investment_thesis text,
  certificate_confirmed boolean not null default false,
  published_by uuid references auth.users(id) on delete set null,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.report is '研究报告主表：存储报告的核心信息，支持草稿/提交/发布/驳回状态流转';
comment on column public.report.id is '主键UUID';
comment on column public.report.owner_user_id is '报告所有者用户ID，关联auth.users，创建后不可变更';
comment on column public.report.title is '报告标题';
comment on column public.report.report_type is '报告类型代码（如company/sector/company_flash等），合法值由template.report_type驱动';
comment on column public.report.status is '报告状态：draft=草稿，submitted=已提交待审核，published=已发布，rejected=已驳回';
comment on column public.report.current_version_no is '当前版本号（>=0），每次内容更新递增';
comment on column public.report.coverage_id is '关联公司ID，关联coverage.id，删除公司时置空';
comment on column public.report.sector_id is '关联行业ID，关联sector.id，删除行业时置空';
comment on column public.report.region_code is '报告覆盖区域代码，关联region.code，删除区域时置空';
comment on column public.report.published_by is '发布人ID，关联auth.users，仅在published状态时记录';
comment on column public.report.published_at is '发布时间，仅在published状态时记录';
comment on column public.report.created_at is '创建时间（UTC）';
comment on column public.report.updated_at is '最后更新时间（UTC）';
comment on column public.report.ticker is '关联股票代码';
comment on column public.report.rating is '投资评级（如OUTPERFORM/NEUTRAL等）';
comment on column public.report.target_price is '目标价（numeric类型，必须大于0）';
comment on column public.report.report_language is '报告语言：zh=中文，en=英文';
comment on column public.report.contact_person_id is '联系人ID，关联auth.users';
comment on column public.report.investment_thesis is '投资要点摘要';
comment on column public.report.certificate_confirmed is '证书确认状态：true=已确认，false=未确认';

create index idx_report_owner on public.report(owner_user_id);
create index idx_report_status on public.report(status);
create index idx_report_updated_at_desc on public.report(updated_at desc);
create index idx_report_created_at_desc on public.report(created_at desc);
create index idx_report_region_id on public.report(region_code);
create index idx_report_contact_person_id on public.report(contact_person_id);

create trigger trg_report_updated_at
  before update on public.report
  for each row execute function public.set_updated_at_utc();

create trigger trg_report_owner_immutable
  before update on public.report
  for each row execute function public.report_enforce_owner_immutable();

create trigger trg_report_status_transition
  before update on public.report
  for each row execute function public.report_enforce_status_transition();

-- ============================================================
-- 11. 报告版本表 (append-only)
-- ============================================================

create table public.report_version (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.report(id) on delete cascade,
  version_no integer not null check (version_no >= 1),
  snapshot_json jsonb not null default '{}'::jsonb,
  word_file_path text,
  pdf_file_path text,
  model_file_path text,
  word_file_name text,
  pdf_file_name text,
  model_file_name text,
  changed_by uuid not null references auth.users(id) on delete restrict,
  changed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint report_version_uniq unique (report_id, version_no)
);

comment on table public.report_version is '报告版本表（append-only）：记录报告每次提交的快照和文件信息，不允许修改或删除';
comment on column public.report_version.id is '主键UUID';
comment on column public.report_version.report_id is '所属报告ID，关联report.id，删除报告时级联删除';
comment on column public.report_version.version_no is '版本号（>=1），同一报告内递增';
comment on column public.report_version.snapshot_json is '报告内容快照（JSONB），包含标题、类型、评级、目标价、分析师等核心字段';
comment on column public.report_version.word_file_path is 'Word/PPT文件存储路径（Supabase Storage）';
comment on column public.report_version.pdf_file_path is 'PDF文件存储路径（Supabase Storage）';
comment on column public.report_version.model_file_path is '模型文件存储路径（Supabase Storage）';
comment on column public.report_version.word_file_name is 'Word/PPT原始文件名（含扩展名）';
comment on column public.report_version.pdf_file_name is 'PDF原始文件名（含扩展名）';
comment on column public.report_version.model_file_name is '模型原始文件名（含扩展名）';
comment on column public.report_version.changed_by is '变更人ID，关联auth.users';
comment on column public.report_version.changed_at is '变更时间';
comment on column public.report_version.created_at is '创建时间（UTC）';

create index idx_report_version_report on public.report_version(report_id);
create index idx_report_version_report_version_desc on public.report_version(report_id, version_no desc);
create index idx_report_version_changed_at_desc on public.report_version(changed_at desc);
create index idx_report_version_pdf_file_path on public.report_version(pdf_file_path) where pdf_file_path is not null;

create trigger trg_report_version_no_update
  before update or delete on public.report_version
  for each row execute function public.prevent_update_delete_append_only();

-- ============================================================
-- 12. 报告-分析师关系表
-- ============================================================

create table public.report_analyst (
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

comment on table public.report_analyst is '报告-分析师关系表：建立报告与分析师的作者关系';
comment on column public.report_analyst.id is '主键UUID';
comment on column public.report_analyst.report_id is '报告ID，关联report.id，删除报告时级联删除';
comment on column public.report_analyst.analyst_id is '分析师ID，关联analyst.id，禁止删除已关联分析师';
comment on column public.report_analyst.role is '角色序号（1-4）：1=主分析师，2=联合分析师，3=辅助分析师，4=审核分析师';
comment on column public.report_analyst.sort_order is '排序序号（1-4），决定展示顺序，同报告内唯一';
comment on column public.report_analyst.created_at is '创建时间（UTC）';
comment on column public.report_analyst.updated_at is '最后更新时间（UTC）';

create index idx_report_analyst_report on public.report_analyst(report_id);
create index idx_report_analyst_analyst on public.report_analyst(analyst_id);

create trigger trg_report_analyst_updated_at
  before update on public.report_analyst
  for each row execute function public.set_updated_at_utc();

-- ============================================================
-- 13. 报告状态变更日志表 (append-only)
-- ============================================================

-- 状态日志转换验证
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
comment on function public.report_status_log_enforce_transition() is '触发器函数：验证状态日志记录的状态转换合法性';

create table public.report_status_log (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.report(id) on delete cascade,
  from_status text not null check (from_status in ('draft', 'submitted', 'published', 'rejected')),
  to_status text not null check (to_status in ('draft', 'submitted', 'published', 'rejected')),
  action_by uuid not null references auth.users(id) on delete restrict,
  action_by_name text,
  action_at timestamptz not null default now(),
  reason text,
  version_no integer not null check (version_no >= 0),
  created_at timestamptz not null default now(),
  constraint report_status_log_reject_reason_required
    check ((to_status <> 'rejected') or (reason is not null and btrim(reason) <> ''))
);

comment on table public.report_status_log is '报告状态变更日志表（append-only）：记录报告所有状态流转历史，不允许修改或删除';
comment on column public.report_status_log.id is '主键UUID';
comment on column public.report_status_log.report_id is '报告ID，关联report.id，删除报告时级联删除';
comment on column public.report_status_log.from_status is '变更前状态';
comment on column public.report_status_log.to_status is '变更后状态';
comment on column public.report_status_log.action_by is '操作人ID，关联auth.users';
comment on column public.report_status_log.action_by_name is '操作人姓名（从analyst表冗余存储，避免删除用户后丢失）';
comment on column public.report_status_log.action_at is '操作时间';
comment on column public.report_status_log.reason is '驳回原因（仅to_status=rejected时必填），业务语义为批注Note';
comment on column public.report_status_log.version_no is '状态变更发生时的报告版本号';
comment on column public.report_status_log.created_at is '创建时间（UTC）';

create index idx_report_status_log_report on public.report_status_log(report_id);
create index idx_report_status_log_action_at_desc on public.report_status_log(action_at desc);
create index idx_report_status_log_action_by_name on public.report_status_log(action_by_name);

create trigger trg_report_status_log_no_update
  before update or delete on public.report_status_log
  for each row execute function public.prevent_update_delete_append_only();

create trigger trg_report_status_log_transition
  before insert on public.report_status_log
  for each row execute function public.report_status_log_enforce_transition();

-- ============================================================
-- 14. 首席确认附件表
-- ============================================================

create table public.chief_approve (
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

create index idx_chief_approve_report_id on public.chief_approve(report_id);
create index idx_chief_approve_created_at on public.chief_approve(created_at);

-- ============================================================
-- 15. RQC审批确认附件表
-- ============================================================

create table public.rqc_approve (
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

create index idx_rqc_approve_report_id on public.rqc_approve(report_id);
create index idx_rqc_approve_created_at on public.rqc_approve(created_at);

-- ============================================================
-- 16. 报告外部推送日志表 (append-only)
-- ============================================================

create table public.report_push_log (
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

create index idx_report_push_log_report_created on public.report_push_log(report_id, created_at desc);
create index idx_report_push_log_triggered_by_created on public.report_push_log(triggered_by, created_at desc);

create or replace function public.trg_report_push_log_no_update_delete()
returns trigger language plpgsql as $$
begin
  raise exception 'UPDATE and DELETE on report_push_log are not allowed';
end;
$$;

create trigger trg_report_push_log_no_update_delete
  before update or delete on public.report_push_log
  for each row execute function public.trg_report_push_log_no_update_delete();

-- ============================================================
-- 17. RPC 函数
-- ============================================================

-- 原子化保存报告内容
create or replace function public.report_save_content_atomic(
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
returns public.report
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_report public.report;
  v_current_version_no integer;
begin
  select current_version_no into v_current_version_no
  from public.report
  where id = p_report_id;

  if not found then
    raise exception 'Report not found';
  end if;

  update public.report
  set
    title = p_title,
    report_type = p_report_type,
    ticker = p_ticker,
    rating = p_rating,
    target_price = case when p_target_price is null or p_target_price = '' then null else p_target_price::numeric end,
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
  returning * into v_report;

  insert into public.report_version (
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
  ) values (
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
    now(),
    now()
  );

  delete from public.report_analyst where report_id = p_report_id;

  if p_analysts is not null and jsonb_array_length(p_analysts) > 0 then
    insert into public.report_analyst (id, report_id, analyst_id, role, sort_order, created_at, updated_at)
    select
      gen_random_uuid(),
      p_report_id,
      (elem->>'analyst_id')::uuid,
      (elem->>'role')::smallint,
      (elem->>'sort_order')::smallint,
      now(),
      now()
    from jsonb_array_elements(p_analysts) as elem;
  end if;

  return v_report;
end;
$$;
comment on function public.report_save_content_atomic(uuid, text, text, text, text, text, text, uuid, text, uuid, text, boolean, uuid, jsonb, uuid, text, text, text, text, text, text) is '原子化保存报告内容的RPC函数：在单事务内更新报告基本信息、作者关系和版本快照';

-- 原子化变更报告状态
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
comment on function public.report_change_status_atomic(uuid, text, uuid, text) is '原子化变更报告状态的RPC函数：在单事务内更新状态并写入状态日志';

-- ============================================================
-- 18. RLS 策略
-- ============================================================

-- region RLS
alter table public.region enable row level security;

create policy region_select_authenticated
  on public.region
  for select to authenticated using (true);

create policy region_write_admin
  on public.region
  for all to authenticated
  using ((auth.jwt()->'app_metadata'->>'role') = 'admin')
  with check ((auth.jwt()->'app_metadata'->>'role') = 'admin');

-- rating RLS
alter table public.rating enable row level security;

create policy rating_select_authenticated
  on public.rating
  for select to authenticated using (true);

-- report_type RLS
alter table public.report_type enable row level security;

create policy report_type_select_authenticated
  on public.report_type
  for select to authenticated using (true);

-- analyst RLS
alter table public.analyst enable row level security;

create policy analyst_select_authenticated
  on public.analyst
  for select to authenticated using (true);

create policy analyst_write_admin
  on public.analyst
  for all to authenticated
  using ((auth.jwt()->'app_metadata'->>'role') = 'admin')
  with check ((auth.jwt()->'app_metadata'->>'role') = 'admin');

-- sector RLS
alter table public.sector enable row level security;

create policy sector_select_authenticated
  on public.sector
  for select to authenticated using (true);

create policy sector_write_admin
  on public.sector
  for all to authenticated
  using ((auth.jwt()->'app_metadata'->>'role') = 'admin')
  with check ((auth.jwt()->'app_metadata'->>'role') = 'admin');

-- coverage RLS
alter table public.coverage enable row level security;

create policy coverage_select_authenticated
  on public.coverage
  for select to authenticated using (true);

create policy coverage_insert_admin_analyst
  on public.coverage
  for insert to authenticated
  with check ((auth.jwt()->'app_metadata'->>'role') in ('admin', 'sa', 'analyst'));

create policy coverage_update_admin
  on public.coverage
  for update to authenticated
  using ((auth.jwt()->'app_metadata'->>'role') = 'admin')
  with check ((auth.jwt()->'app_metadata'->>'role') = 'admin');

create policy coverage_delete_admin
  on public.coverage
  for delete to authenticated
  using ((auth.jwt()->'app_metadata'->>'role') = 'admin');

-- coverage_analyst RLS
alter table public.coverage_analyst enable row level security;

create policy coverage_analyst_select_authenticated
  on public.coverage_analyst
  for select to authenticated using (true);

create policy coverage_analyst_insert_admin_analyst
  on public.coverage_analyst
  for insert to authenticated
  with check ((auth.jwt()->'app_metadata'->>'role') in ('admin', 'sa', 'analyst'));

create policy coverage_analyst_update_admin
  on public.coverage_analyst
  for update to authenticated
  using ((auth.jwt()->'app_metadata'->>'role') = 'admin')
  with check ((auth.jwt()->'app_metadata'->>'role') = 'admin');

create policy coverage_analyst_delete_admin
  on public.coverage_analyst
  for delete to authenticated
  using ((auth.jwt()->'app_metadata'->>'role') = 'admin');

-- template RLS
alter table public.template enable row level security;

create policy template_select_authenticated
  on public.template
  for select to authenticated using (true);

create policy template_write_admin
  on public.template
  for all to authenticated
  using ((auth.jwt()->'app_metadata'->>'role') = 'admin')
  with check ((auth.jwt()->'app_metadata'->>'role') = 'admin');

-- report RLS
alter table public.report enable row level security;

create policy report_select_policy
  on public.report
  for select to authenticated
  using (
    public.current_app_role() = 'admin'
    or (public.current_app_role() = 'sa' and status in ('draft', 'submitted', 'published', 'rejected'))
    or (public.current_app_role() = 'analyst' and owner_user_id = auth.uid())
  );

create policy report_insert_policy
  on public.report
  for insert to authenticated
  with check (
    public.current_app_role() = 'admin'
    or (public.current_app_role() = 'analyst' and owner_user_id = auth.uid())
  );

create policy report_update_policy
  on public.report
  for update to authenticated
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

-- report_version RLS
alter table public.report_version enable row level security;

create policy report_version_select_policy
  on public.report_version
  for select to authenticated
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

create policy report_version_insert_policy
  on public.report_version
  for insert to authenticated
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

-- report_analyst RLS
alter table public.report_analyst enable row level security;

create policy report_analyst_select_policy
  on public.report_analyst
  for select to authenticated
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

create policy report_analyst_insert_policy
  on public.report_analyst
  for insert to authenticated
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

create policy report_analyst_update_policy
  on public.report_analyst
  for update to authenticated
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

create policy report_analyst_delete_policy
  on public.report_analyst
  for delete to authenticated
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

-- report_status_log RLS
alter table public.report_status_log enable row level security;

create policy report_status_log_select_policy
  on public.report_status_log
  for select to authenticated
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

create policy report_status_log_insert_policy
  on public.report_status_log
  for insert to authenticated
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

-- chief_approve RLS
alter table public.chief_approve enable row level security;

create policy chief_approve_select
  on public.chief_approve
  for select to authenticated
  using (
    exists (
      select 1 from public.report
      where id = chief_approve.report_id
      and owner_user_id = auth.uid()
    )
    or public.current_app_role() in ('sa', 'admin')
  );

create policy chief_approve_insert
  on public.chief_approve
  for insert to authenticated
  with check (
    exists (
      select 1 from public.report
      where id = chief_approve.report_id
      and owner_user_id = auth.uid()
    )
    or public.current_app_role() in ('sa', 'admin')
  );

create policy chief_approve_update
  on public.chief_approve
  for update to authenticated
  using (
    exists (
      select 1 from public.report
      where id = chief_approve.report_id
      and owner_user_id = auth.uid()
    )
    or public.current_app_role() in ('sa', 'admin')
  );

create policy chief_approve_delete
  on public.chief_approve
  for delete to authenticated
  using (
    exists (
      select 1 from public.report
      where id = chief_approve.report_id
      and owner_user_id = auth.uid()
    )
    or public.current_app_role() in ('sa', 'admin')
  );

-- rqc_approve RLS
alter table public.rqc_approve enable row level security;

create policy rqc_approve_select
  on public.rqc_approve
  for select to authenticated
  using (
    exists (
      select 1 from public.report
      where id = rqc_approve.report_id
      and owner_user_id = auth.uid()
    )
    or public.current_app_role() in ('sa', 'admin')
  );

create policy rqc_approve_insert
  on public.rqc_approve
  for insert to authenticated
  with check (
    exists (
      select 1 from public.report
      where id = rqc_approve.report_id
      and owner_user_id = auth.uid()
    )
    or public.current_app_role() in ('sa', 'admin')
  );

create policy rqc_approve_update
  on public.rqc_approve
  for update to authenticated
  using (
    exists (
      select 1 from public.report
      where id = rqc_approve.report_id
      and owner_user_id = auth.uid()
    )
    or public.current_app_role() in ('sa', 'admin')
  );

create policy rqc_approve_delete
  on public.rqc_approve
  for delete to authenticated
  using (
    exists (
      select 1 from public.report
      where id = rqc_approve.report_id
      and owner_user_id = auth.uid()
    )
    or public.current_app_role() in ('sa', 'admin')
  );

-- report_push_log RLS
alter table public.report_push_log enable row level security;

create policy report_push_log_select_admin
  on public.report_push_log
  for select
  using (auth.jwt() ->> 'role' = 'admin');

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

create policy report_push_log_insert_admin
  on public.report_push_log
  for insert
  with check (auth.jwt() ->> 'role' = 'admin');

-- ============================================================
-- 19. Storage RLS 策略
-- ============================================================

-- templates bucket policies
create policy storage_templates_select_authenticated
  on storage.objects
  for select to authenticated
  using (bucket_id = 'templates');

create policy storage_templates_insert_admin
  on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'templates'
    and (auth.jwt()->'app_metadata'->>'role') = 'admin'
  );

create policy storage_templates_update_admin
  on storage.objects
  for update to authenticated
  using (
    bucket_id = 'templates'
    and (auth.jwt()->'app_metadata'->>'role') = 'admin'
  )
  with check (
    bucket_id = 'templates'
    and (auth.jwt()->'app_metadata'->>'role') = 'admin'
  );

create policy storage_templates_delete_admin
  on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'templates'
    and (auth.jwt()->'app_metadata'->>'role') = 'admin'
  );

-- reports bucket policies
create policy storage_reports_select_policy
  on storage.objects
  for select to authenticated
  using (
    bucket_id = 'reports'
    and (
      -- Report files: first segment is UUID
      (split_part(name, '/', 1) ~* '^[0-9a-f-]{36}$'
       and exists (
         select 1
         from public.report r
         where r.id = split_part(name, '/', 1)::uuid
           and (
             public.current_app_role() = 'admin'
             or r.owner_user_id = auth.uid()
             or (public.current_app_role() = 'sa' and r.status in ('submitted', 'published', 'rejected'))
           )
       ))
      or
      -- Chief approval screenshots: ${reportId}/chief-approval/...
      (split_part(name, '/', 1) ~* '^[0-9a-f-]{36}$'
       and split_part(name, '/', 2) = 'chief-approval'
       and exists (
         select 1
         from public.report r
         where r.id = split_part(name, '/', 1)::uuid
           and (
             public.current_app_role() = 'admin'
             or r.owner_user_id = auth.uid()
           )
       ))
    )
  );

create policy storage_reports_insert_policy
  on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'reports'
    and (
      -- Report files: first segment is UUID
      (split_part(name, '/', 1) ~* '^[0-9a-f-]{36}$'
       and split_part(name, '/', 2) !~ '^[0-9a-f-]{36}$'
       and exists (
         select 1
         from public.report r
         where r.id = split_part(name, '/', 1)::uuid
           and (
             public.current_app_role() = 'admin'
             or r.owner_user_id = auth.uid()
           )
       ))
      or
      -- Chief approval screenshots: ${reportId}/chief-approval/...
      (split_part(name, '/', 1) ~* '^[0-9a-f-]{36}$'
       and split_part(name, '/', 2) = 'chief-approval'
       and exists (
         select 1
         from public.report r
         where r.id = split_part(name, '/', 1)::uuid
           and (
             public.current_app_role() = 'admin'
             or r.owner_user_id = auth.uid()
           )
       ))
    )
  );

create policy storage_reports_update_policy
  on storage.objects
  for update to authenticated
  using (
    bucket_id = 'reports'
    and split_part(name, '/', 1) ~* '^[0-9a-f-]{36}$'
    and exists (
      select 1
      from public.report r
      where r.id = split_part(name, '/', 1)::uuid
        and (
          public.current_app_role() = 'admin'
          or r.owner_user_id = auth.uid()
        )
    )
  )
  with check (
    bucket_id = 'reports'
    and split_part(name, '/', 1) ~* '^[0-9a-f-]{36}$'
    and exists (
      select 1
      from public.report r
      where r.id = split_part(name, '/', 1)::uuid
        and (
          public.current_app_role() = 'admin'
          or r.owner_user_id = auth.uid()
        )
    )
  );

create policy storage_reports_delete_policy
  on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'reports'
    and split_part(name, '/', 1) ~* '^[0-9a-f-]{36}$'
    and exists (
      select 1
      from public.report r
      where r.id = split_part(name, '/', 1)::uuid
        and (
          public.current_app_role() = 'admin'
          or r.owner_user_id = auth.uid()
        )
    )
  );

-- ============================================================
-- 20. 初始数据
-- ============================================================

-- rating 初始数据
insert into public.rating (name, code, sort, is_active) values
  ('优于大市', 'OUTPERFORM', 1, true),
  ('中性', 'NEUTRAL', 2, true),
  ('弱于大市', 'UNDERPERFORM', 3, true),
  ('未评级', 'NON_RATED', 4, true)
on conflict (code) do nothing;

-- report_type 初始数据
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

-- region 初始数据
insert into public.region (name_en, name_cn, code, is_active) values
  ('China', '中国', 'CN', true),
  ('Hong Kong', '香港', 'HK', true),
  ('Japan', '日本', 'JP', true),
  ('Taiwan', '台湾', 'TW', true),
  ('South Korea', '韩国', 'KR', true),
  ('India', '印度', 'IN', true),
  ('Macau', '澳门', 'MO', true),
  ('United States', '美国', 'US', true)
on conflict (code) do nothing;

-- template 初始数据（每个 report_type 中英文版本）
insert into public.template (name, report_type, template_file_path, schema_file_path, version, sort, language, uploaded_by) values
  ('Company_Template_CN', 'company', '', null, 1, 1, 'zh', null),
  ('Company_Template_EN', 'company', '', null, 1, 2, 'en', null),
  ('Sector_Template_CN', 'sector', '', null, 1, 3, 'zh', null),
  ('Sector_Template_EN', 'sector', '', null, 1, 4, 'en', null),
  ('Company_Flash_Template_CN', 'company_flash', '', null, 1, 5, 'zh', null),
  ('Company_Flash_Template_EN', 'company_flash', '', null, 1, 6, 'en', null),
  ('Sector_Flash_Template_CN', 'sector_flash', '', null, 1, 7, 'zh', null),
  ('Sector_Flash_Template_EN', 'sector_flash', '', null, 1, 8, 'en', null),
  ('Macro_Template_CN', 'macro', '', null, 1, 9, 'zh', null),
  ('Macro_Template_EN', 'macro', '', null, 1, 10, 'en', null),
  ('Strategy_Template_CN', 'strategy', '', null, 1, 11, 'zh', null),
  ('Strategy_Template_EN', 'strategy', '', null, 1, 12, 'en', null),
  ('Quantitative_Template_CN', 'quantitative', '', null, 1, 13, 'zh', null),
  ('Quantitative_Template_EN', 'quantitative', '', null, 1, 14, 'en', null),
  ('Bond_Template_CN', 'bond', '', null, 1, 15, 'zh', null),
  ('Bond_Template_EN', 'bond', '', null, 1, 16, 'en', null)
on conflict do nothing;
