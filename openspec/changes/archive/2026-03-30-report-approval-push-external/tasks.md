## Tasks

实现清单，按依赖顺序排列。

### Phase 1：数据库层

- [x] **T1.1** 创建 `supabase/migrations/2026xxxxxx_report_push_log.sql`
  - 创建 `report_push_log` 表（字段定义见 design.md §2.1）
  - 创建 trigger `trg_report_push_log_no_update_delete`（阻止 UPDATE/DELETE）
  - 创建索引：`report_id + created_at DESC`、`triggered_by + created_at DESC`
  - 创建 RLS policies（Admin / SA / Analyst / INSERT policy）
  - 执行 `supabase db push` 并验证

### Phase 2：推送任务核心

- [x] **T2.1** 新建 `web/features/report-review/repo/report-push-repo.ts`
  - 实现 `pushReportExternal(params)` 函数
  - 实现元数据聚合：从 `report`、`report_version`、`report_analyst`、`analyst`、`region`、`sector` 等表读取数据
  - 实现 `analyst` 字段构造：从 `report_analyst` + `analyst` 表聚合为 `名字<邮箱>,...` 格式
  - 实现 `contact_person` 字段构造：从 `report.contact_person_id` + `auth.users` 聚合
  - 实现 PDF 文件下载：通过 Supabase Storage SDK 下载 `report_version.pdf_file_path`
  - 实现 FormData 构造：必填字段 + 可选字段 + `attachment_pdf`
  - 实现外部接口调用：POST + `X-API-Key` header + 30s timeout
  - 实现 `report_push_log` 写入（成功/失败均写入）
  - 实现前置校验（必填字段、API Key）
  - 实现异步执行：使用 `Promise` 不 await，不阻塞调用方

- [x] **T2.2** 确认 `.env` 配置项
  - 确认 `EXTERNAL_REPORT_API_KEY` 已添加到 `web/.env`
  - 确认 `EXTERNAL_API_URL` 值（外部系统根地址）

### Phase 3：审批流程集成

- [x] **T3.1** 修改 `web/features/report-review/repo/report-review-repo.ts` 的 `approveReport()`
  - 在 `changeReportStatus()` 成功后，添加 `void pushReportExternal(...)` 调用
  - `triggeredBy = action_by`，`triggerType = 'auto'`
  - 捕获异常，避免推送失败影响审批结果

### Phase 4：手动重推

- [x] **T4.1** 在 `web/features/report-review/actions.ts` 添加 `repushReportExternal(reportId)`
  - 权限：仅 Admin 可调用（通过 RLS + Server Action 层级校验）
  - 调用 `pushReportExternal(reportId, triggeredBy=当前用户, triggerType='manual')`
  - 返回 `Result<void>`

- [x] **T4.2** 新建 `web/features/report-review/components/ReportPushHistory.tsx`
  - 查询 `report_push_log`（按 `created_at DESC`，限制 10 条）
  - 展示字段：推送时间、触发类型（auto/manual 标签）、操作人、状态（徽章）、HTTP 状态码、失败原因摘要
  - 状态徽章样式：`success`（绿色）、`failed`（红色）、`pending`（灰色）

- [x] **T4.3** 新建 `web/features/report-review/components/PushStatusBadge.tsx`
  - 通用状态徽章组件

### Phase 5：页面集成

- [x] **T5.1** 修改报告详情页 `web/app/reports/[id]/page.tsx`
  - 引入 `ReportPushHistory` 组件
  - 放置在报告详情内容下方或侧边栏
  - Admin 可见"重新推送"按钮（调用 `repushReportExternal`）

- [ ] **T5.2** 确保 RLS 生效（需 Supabase 数据库环境手动验证）
  - 以 Analyst 身份登录，验证只能看到 owner 报告的推送历史
  - 以 SA 身份登录，验证只能看到 submitted/published/rejected 报告的推送历史
  - 以 Admin 身份登录，验证可看到所有推送历史 + 手动重推按钮

### Phase 6：端到端测试

- [ ] **T6.1** 端到端测试场景（需 Supabase + 外部 API 环境手动验证）
  - [ ] Analyst 提交报告 → SA 审批通过 → 验证推送日志生成（status=success/failed）
  - [ ] 推送后 PDF 文件正确附带在 multipart 请求中
  - [ ] 推送必填字段（external_id/title/report_type/published_at）正确
  - [ ] 推送失败（模拟）不影响报告状态仍为 published
  - [ ] Admin 手动重推 → 验证新推送记录生成（trigger_type=manual）
  - [ ] Admin 查看推送历史 → 验证 HTTP 状态码和失败原因可见

### 依赖关系

```
T1.1 (DB)
T2.2 (.env) ─┐
             ├─> T2.1 (push repo)
T3.1 ───────────> T3.1 (集成到审批流程)
T2.1 ─────────> T4.1 (手动重推 action)
T4.1 ─────────> T4.2 (推送历史组件) ─> T4.3 (Badge 组件)
T4.3 ───────────────────────────────> T5.1 (页面集成)
T5.1 ───────────────────────────────> T6.1 (E2E 测试)
```
