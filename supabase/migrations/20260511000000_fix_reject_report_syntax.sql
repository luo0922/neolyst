-- ============================================================
-- Bug 修复迁移：publish_report / reject_report 函数语法错误
--
-- 问题描述：
--   上一版迁移 20260414153404_fix_publish_reject_status_ambiguous.sql
--   在 UPDATE 语句的 SET 子句中错误地使用了表别名（r.column），
--   导致执行 reject_report 时报错：
--     column "r" of relation "report" does not exist
--
-- 原因说明：
--   PostgreSQL 的 UPDATE ... FROM 语法中，允许使用表别名（AS r），
--   但 SET 子句只能写裸列名，不能写 alias.column 的形式。
--   PostgreSQL 会把 "r.status" 中的 "r" 当成一个列名来解析，
--   而 report 表中并没有名为 "r" 的列，因此报错。
--
--   正确写法：
--     FROM public.report r   ← 允许用别名
--     SET status = ...       ← SET 子句必须写裸列名（不能写 r.status）
--     WHERE r.id = ...       ← WHERE 子句允许用别名
--
-- 修复内容：
--   1. publish_report：SET 子句去掉 r. 前缀
--   2. reject_report：SET 子句去掉 r. 前缀
--
-- 影响范围：
--   - 该修复通过 CREATE OR REPLACE FUNCTION 原地替换函数定义，
--     无需重建表或迁移数据，无数据风险。
--   - apply/reject 操作均受影响，建议一并部署。
-- ============================================================

-- ---------- 1. publish_report ----------
-- 功能：将 report.status 从 'submitted' 更新为 'published'
-- 参数：p_report_id (uuid) — 报告 ID
-- 返回：TABLE(report_id uuid, status text)
-- 依赖 auth.uid()，要求调用者已通过 RLS 认证

CREATE OR REPLACE FUNCTION public.publish_report(p_report_id uuid)
RETURNS TABLE(report_id uuid, status text)
LANGUAGE plpgsql
AS $$
declare
    v_status text;
begin
    -- 使用表别名 r 在 SELECT 中查询当前状态，避免列名歧义
    select r.status into v_status
      from public.report r
     where r.id = p_report_id;

    if not found then
        raise exception '报告不存在: %', p_report_id;
    end if;

    if v_status <> 'submitted' then
        raise exception '报告状态为 %，无法发布（仅 submitted 可发布）', v_status;
    end if;

    -- ⚠ 注意：SET 子句只能写裸列名，不能写 r.status
    -- 错误写法：SET r.status = ..., r.published_by = ...  ← PostgreSQL 报 column "r" does not exist
    -- 正确写法：SET status = ..., published_by = ...
    update public.report
       set status       = 'published',
           published_by = auth.uid(),
           published_at = now()
     where id = p_report_id;

    return query select p_report_id, 'published'::text;
end;
$$;

COMMENT ON FUNCTION public.publish_report(uuid) IS
'将 submitted 报告发布为 published，同时记录 published_by 和 published_at。'
;

-- ---------- 2. reject_report ----------
-- 功能：将 report.status 从 'submitted' 更新为 'rejected'
-- 参数：p_report_id (uuid)       — 报告 ID
--       p_rejection_reason (text) — 退回原因（必填，不能为空）
-- 返回：TABLE(report_id uuid, status text)
-- 依赖 auth.uid()，要求调用者已通过 RLS 认证

CREATE OR REPLACE FUNCTION public.reject_report(
    p_report_id uuid,
    p_rejection_reason text
)
RETURNS TABLE(report_id uuid, status text)
LANGUAGE plpgsql
AS $$
declare
    v_status text;
begin
    -- 前置校验：退回原因不能为空
    if coalesce(btrim(p_rejection_reason), '') = '' then
        raise exception '退回原因不能为空';
    end if;

    -- 使用表别名 r 在 SELECT 中查询当前状态
    select r.status into v_status
      from public.report r
     where r.id = p_report_id;

    if not found then
        raise exception '报告不存在: %', p_report_id;
    end if;

    if v_status <> 'submitted' then
        raise exception '报告状态为 %，无法退回（仅 submitted 可退回）', v_status;
    end if;

    -- ⚠ 注意：SET 子句只能写裸列名，不能写 r.status
    update public.report
       set status            = 'rejected',
           rejection_reason  = p_rejection_reason
     where id = p_report_id;

    return query select p_report_id, 'rejected'::text;
end;
$$;

COMMENT ON FUNCTION public.reject_report(uuid, text) IS
'将 submitted 报告退回为 rejected。必填退回原因 p_rejection_reason。'
;
