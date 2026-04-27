-- ============================================================
-- Supabase Storage 初始化脚本
--
-- 包含：
--   1. Storage Bucket 定义（幂等插入）
--   2. Storage RLS 策略
--
-- 执行时机：
--   - `supabase db reset` 时由 config.toml [db.seed] 自动执行
--   - `supabase db push --include-seed` 时推送到远端
-- ============================================================

-- ============================================================
-- 1. Bucket 定义
-- ============================================================

-- templates bucket：存储报告 Word 模板文件
--   - public = false：仅授权用户可访问
--   - 目录结构：{report_type}/{template|schema}/{timestamp}_{filename}
insert into storage.buckets (id, name, public)
values ('templates', 'templates', false)
on conflict (id) do nothing;

-- reports bucket：存储报告附件文件
--   - public = false：仅授权用户可访问
--   - 目录结构：{reportId}/... 或 {reportId}/chief-approval/...
insert into storage.buckets (id, name, public)
values ('reports', 'reports', false)
on conflict (id) do nothing;

-- ============================================================
-- 2. RLS 策略
-- ============================================================

-- ----------------------------------------------------------
-- 2.1 templates bucket RLS 策略
-- ----------------------------------------------------------

-- templates: SELECT — 所有已登录用户可查看模板列表
drop policy if exists storage_templates_select_authenticated on storage.objects;
create policy storage_templates_select_authenticated
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'templates');

-- templates: INSERT — 仅 Admin 可上传模板文件
drop policy if exists storage_templates_insert_admin on storage.objects;
create policy storage_templates_insert_admin
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'templates'
    and (auth.jwt()->'app_metadata'->>'role') = 'admin'
  );

-- templates: UPDATE — 仅 Admin 可更新模板文件
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

-- templates: DELETE — 仅 Admin 可删除模板文件
drop policy if exists storage_templates_delete_admin on storage.objects;
create policy storage_templates_delete_admin
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'templates'
    and (auth.jwt()->'app_metadata'->>'role') = 'admin'
  );

-- ----------------------------------------------------------
-- 2.2 reports bucket RLS 策略
-- ----------------------------------------------------------

-- reports: SELECT — 已登录用户按报告权限读取附件
-- 权限逻辑：
--   Admin：可读所有报告文件
--   报告 Owner：可读自己报告的文件
--   SA（服务账号）：仅可读 submitted/published/rejected 状态的报告文件
--   Chief Approval 截图：仅 Admin 或报告 Owner 可读（不含 SA）
drop policy if exists storage_reports_select_policy on storage.objects;
create policy storage_reports_select_policy
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'reports'
    and (
      -- 普通报告附件：{reportId}/...
      (split_part(name, '/', 1) ~* '^[0-9a-f-]{36}$'
       and split_part(name, '/', 2) !~ '^[0-9a-f-]{36}$'
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
      -- Chief Approval 截图：{reportId}/chief-approval/...
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

-- reports: INSERT — 已登录用户按报告 Owner/Admin 权限上传附件
-- 约束：
--   - 路径第一段必须是 reportId（36位 UUID）
--   - 第二段不能也是 UUID（防止越级创建目录）
drop policy if exists storage_reports_insert_policy on storage.objects;
create policy storage_reports_insert_policy
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'reports'
    and (
      -- 普通报告附件：{reportId}/...
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
      -- Chief Approval 截图：{reportId}/chief-approval/...
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

-- reports: UPDATE — 报告 Owner 或 Admin 可更新附件
drop policy if exists storage_reports_update_policy on storage.objects;
create policy storage_reports_update_policy
  on storage.objects
  for update
  to authenticated
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

-- reports: DELETE — 报告 Owner 或 Admin 可删除附件
drop policy if exists storage_reports_delete_policy on storage.objects;
create policy storage_reports_delete_policy
  on storage.objects
  for delete
  to authenticated
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
