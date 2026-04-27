## 1. 数据库 Migration

- [ ] 1.1 新增 Supabase migration，在 `reports` 表添加 `publish_title text DEFAULT NULL` 字段（幂等语法）
- [ ] 1.2 新增 RPC 函数 `get_last_published_rating_and_targetprice(p_coverage_id uuid)`，返回 `{rating text, target_price numeric}` 或 `null`
  - 查询条件：`reports.coverage_id = p_coverage_id AND reports.status = 'published'`
  - 按 `published_at DESC` 排序，取最近一条
  - 从 `report_version.snapshot_json` 提取 `rating` 和 `target_price`
  - 忽略 `rating = 'Non-rated'` 的记录，继续往前找
- [ ] 1.3 新增 RPC 函数 `generate_publish_title(p_report_id uuid)`，实现完整的 `publish_title` 生成逻辑
  - `report_type = 'company'`：首次覆盖/非首次覆盖标题 + 评级变动映射 + 目标价变动计算
  - 其他类型：直接复制 `title` 作为 `publish_title`
- [ ] 1.4 在 `report_save_content_atomic` 中调用 `generate_publish_title`（所有 `report_type` 均调用，内部判断分支）
- [ ] 1.5 执行 migration 并验证幂等

## 2. 类型与数据层

- [ ] 2.1 更新 `ReportDetail` 类型（`web/features/reports/repo/reports-repo.ts`），添加 `publish_title` 字段
- [ ] 2.2 确保 `getReportDetail` 查询包含 `publish_title`
- [ ] 2.3 更新 `ReportDetail` 类型到 `report-review` 的 `getReviewReportDetail`（`web/features/report-review/repo/report-review-repo.ts`）

## 3. 新建报告页面 (`/reports/new`)

- [ ] 3.1 确认 `/reports/new` 页面不渲染 `publish_title` 字段（基于现有代码检查应已满足，如需调整则移除相关代码）

## 4. 编辑报告页面 (`/reports/{id}/edit`)

- [ ] 4.1 在 `edit-report-page-client.tsx` 表单中新增只读 `publish_title` 字段展示区域
- [ ] 4.2 从 `ReportDetail.publish_title` 读取并展示，无值时显示空

## 5. 审批页面 (`/report-review`)

- [ ] 5.1 在 `/report-review/{id}` 详情组件中新增只读 `publish_title` 字段展示区域
- [ ] 5.2 从 `getReviewReportDetail` 返回的 `publish_title` 读取并展示

## 6. 集成测试

- [ ] 6.1 创建公司类报告 → 验证 DB 中 `reports.publish_title` 是否正确生成（首次覆盖格式）
- [ ] 6.2 对同一 coverage 再创建第二份报告 → 验证评级/目标价变动是否正确（维持/上调/下调）
- [ ] 6.3 编辑/审批页面是否正确展示只读 `publish_title`
- [ ] 6.4 其他类型报告（如 sector） → 验证 `publish_title` 等于 `title`
