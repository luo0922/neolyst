-- 修改 template 表的 file_type 从 word/excel 改为 report/model

-- Step 1: 先删除 check 约束（允许任意值）
ALTER TABLE public.template DROP CONSTRAINT IF EXISTS template_file_type_check;

-- Step 2: 更新所有 file_type 值为新值
-- 先把所有非 report/model 的值转为 report
UPDATE public.template SET file_type = 'report'
WHERE file_type NOT IN ('report', 'model')
   OR file_type IS NULL
   OR file_type = '';

-- Step 3: 重新添加新的 check 约束
ALTER TABLE public.template ADD CONSTRAINT template_file_type_check CHECK (file_type IN ('report', 'model'));

-- Step 4: 更新唯一约束
-- 先删除重复记录（保留 id 最大的那条）
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

-- Step 5: 更新部分唯一索引
DROP INDEX IF EXISTS template_report_type_file_type_active_idx;
CREATE UNIQUE INDEX template_report_type_file_type_active_idx
ON public.template (report_type, file_type)
WHERE is_active = true;
