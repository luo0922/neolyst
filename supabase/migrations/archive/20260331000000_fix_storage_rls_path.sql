-- Fix Storage RLS policies: path structure changed from
--   reports/${reportId}/${filename}
-- to
--   ${reportId}/${filename}
-- (Supabase storage.from('reports').upload() prepends bucket name automatically)
--
-- Also supports chief-approval sub-path:
--   ${reportId}/chief-approval/${filename}

drop policy if exists storage_reports_select_policy on storage.objects;
create policy storage_reports_select_policy
on storage.objects
for select
to authenticated
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

drop policy if exists storage_reports_insert_policy on storage.objects;
create policy storage_reports_insert_policy
on storage.objects
for insert
to authenticated
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
