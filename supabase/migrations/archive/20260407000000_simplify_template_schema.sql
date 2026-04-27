-- ============================================================
-- 简化 template 表结构
-- 变更内容：
--   1. 移除 is_active 列（不再需要激活机制，每个 report_type+language 显示最新 version）
--   2. 移除 file_type 列（仅保留 Word 模板，不再区分 report/model）
--   3. 将 file_path 重命名为 template_file_path（明确为模板文件路径）
--   4. 新增 schema_file_path 列（Word schema 描述文件路径，记录模板所需的字段及位置信息）
--   5. 新增 sort 排序字段（用于 Templates 列表排序）
--   6. 保留 version 列（按 version 倒序取每组最新版本）
--   7. 删除 is_active 部分唯一索引
-- ============================================================

-- 1. 删除 is_active 部分唯一索引（如果存在）
DROP INDEX IF EXISTS template_report_type_file_type_active_idx;

-- 2. 删除 is_active 和 file_type 列（如果存在）
ALTER TABLE public.template
  DROP COLUMN IF EXISTS is_active,
  DROP COLUMN IF EXISTS file_type;

-- 3. 将 file_path 重命名为 template_file_path（仅当旧列存在时执行）
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'template'
      AND column_name = 'file_path'
  ) THEN
    ALTER TABLE public.template RENAME COLUMN file_path TO template_file_path;
  END IF;
END
$$;

-- 4. 新增 schema_file_path 列（用于存储 Word schema 描述文件路径）
-- schema 文件为 JSON 格式，描述模板所需字段的名称、大致位置和特征
ALTER TABLE public.template
  ADD COLUMN IF NOT EXISTS schema_file_path text;

-- 4b. 新增 sort 排序字段（用于 Templates 列表排序，数字越小越靠前）
ALTER TABLE public.template
  ADD COLUMN IF NOT EXISTS sort integer NOT NULL DEFAULT 0;

-- 5. 确保 language 列存在（由 20260305000006 添加，如果遗漏则补充）
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'template'
      AND column_name = 'language'
  ) THEN
    ALTER TABLE public.template ADD COLUMN language text NOT NULL DEFAULT 'en';
  END IF;
END
$$;

-- 6. 确保 version 列存在
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'template'
      AND column_name = 'version'
  ) THEN
    ALTER TABLE public.template ADD COLUMN version integer NOT NULL DEFAULT 1;
  END IF;
END
$$;

-- 7. 删除旧唯一约束（同名模板可重复上传，按 created_at 区分最新版本）
ALTER TABLE public.template
  DROP CONSTRAINT IF EXISTS template_uniq_version;
-- 不再添加任何唯一约束

-- 8. 更新分组索引
DROP INDEX IF EXISTS idx_template_group;
CREATE INDEX idx_template_group ON public.template (report_type, language);

-- ============================================================
-- 更新字段注释（与新结构保持一致）
-- ============================================================

-- Table-level comment
COMMENT ON TABLE public.template IS '报告模板表：存储报告 Word 模板文件信息，每种报告类型+语言按 created_at 倒序取最新一条，不区分 report/model 类型';

-- Column comments
COMMENT ON COLUMN public.template.id IS '主键UUID';
COMMENT ON COLUMN public.template.name IS '模板名称（如"公司报告模板v1"）';
COMMENT ON COLUMN public.template.report_type IS '报告类型代码（如 company/sector/company_flash 等），值来自 report_type 表';
COMMENT ON COLUMN public.template.template_file_path IS 'Word 模板文件存储路径（Supabase Storage templates bucket 下的路径），非空时表示模板文件已上传';
COMMENT ON COLUMN public.template.schema_file_path IS 'Word schema 描述文件存储路径（Supabase Storage 下的 JSON 文件路径），描述模板所需的字段名称、位置和特征，可为空';
COMMENT ON COLUMN public.template.version IS '版本号（>=1），同一 (report_type, language) 内递增，每次上传新版本时自动分配';
COMMENT ON COLUMN public.template.sort IS '排序序号（整数，数字越小越靠前），用于 Templates 列表排序，同一 report_type 内有效';
COMMENT ON COLUMN public.template.uploaded_by IS '上传人ID，关联 auth.users，初始化占位模板允许为空';
COMMENT ON COLUMN public.template.language IS '模板语言：en=英文模板，zh=中文模板';
COMMENT ON COLUMN public.template.created_at IS '创建时间（UTC），用于倒序取最新版本';
COMMENT ON COLUMN public.template.updated_at IS '最后更新时间（UTC）';
