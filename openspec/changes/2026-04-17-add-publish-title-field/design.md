## 上下文

系统中 `reports` 表目前没有 `publish_title` 字段。Analyst 创建公司类研究报告时，需要一个自动生成的正式发布标题，包含评级变动和目标价调整信息，供下游发布流程使用。

当前相关技术栈：
- 数据库：Supabase（PostgreSQL）
- 前端：Next.js App Router，React Server Components + Client Components
- 报告数据层：`web/features/reports/repo/reports-repo.ts`
- 报告操作：`web/features/reports/actions.ts`
- 评级数据：`rating` 表（已有 `OUTPERFORM/NEUTRAL/UNDERPERFORM/NON_RATED`）
- Coverage 链接：通过 `reports.coverage_id` → `coverage.ticker`

## 目标 / 非目标

**目标：**
- 在 `reports` 表新增 `publish_title`（text，可为空）字段
- 实现 `publish_title` 生成逻辑：
  - 公司类（`report_type = 'company'`）：首次覆盖/非首次覆盖标题 + 评级变动 + 目标价变动
  - 其他类型（如 `sector`/`company_flash`/`sector_flash`/`common`）：`publish_title = title`
- 在 `/reports/new`、`/reports/{id}/edit`、`/report-review` 三处页面正确展示该字段

**非目标：**
- `publish_title` 仅后端写入，Analyst 无法手动编辑
- 不修改已发布报告的 `publish_title`（幂等）
- 不在报告列表页（`/reports`）展示该字段

## 决策

### D1：数据库字段位置

**选择：** 在 `reports` 表直接新增 `publish_title text` 字段。

**理由：** `publish_title` 是报告的核心属性，与 `title`、`rating`、`target_price` 同属报告级别，放在 `reports` 表最简单直接。`report_version.snapshot_json` 虽然可以存储历史快照，但当前报告的正式标题应存在于主表。

### D2：`publish_title` 生成时机

**选择：** 在 `saveReportContentAction`（保存报告内容）时，后端统一调用 `generate_publish_title`，内部根据 `report_type` 分支处理。

**理由：** 评级和目标价在表单填写后才会确定，此时才具备生成条件。相比前端实时预览，后端生成更可靠（避免前端修改绕过生成逻辑）。统一调用点简化事务管理。

### D3：最近一次发布报告的查询逻辑

**选择：** 查询逻辑使用 SQL 直接在 Supabase 中执行，封装为 `public.get_last_published_rating_and_targetprice(p_coverage_id uuid)` RPC 函数。

**理由：** 评级和目标价数据存储在 `report_version.snapshot_json` 中（JSONB），需要 JSON 查询提取。封装为 RPC 可复用，且避免在应用层传递大量数据。

### D4：Rating 变动映射表存储

**选择：** 将评级变动映射表硬编码在 RPC 函数逻辑中。

**理由：** 评级对照表是业务规则，映射项固定（10种组合），硬编码比数据库存储更简洁、无额外表维护成本。

### D5：目标价百分比精度

**选择：** 百分比计算保留到小数点后一位。

**理由：** 金融报告常用 1 位小数（如"上调目标价20.0%"），避免过长的数字字符串。

### D6：英文公司名获取

**选择：** 从 `coverage.english_full_name` 获取英文公司全称用于英文标题。

**理由：** coverage 表已有此字段，且与 `coverage.ticker` 一一对应，无需额外数据源。

## 风险 / 权衡

- **[风险]** `report_version.snapshot_json` 结构未知或字段名不固定 → **缓解措施**：先确认 `snapshot_json` 中 `rating` 和 `target_price` 的 key 名称，如有变更需同步更新 RPC 函数。
- **[风险]** Analyst 填写 Rating 为 `Non-rated` 时不对 `publish_title` 做任何处理 → **缓解措施**：RPC 函数中对 `current_rating = 'Non-rated'` 时直接跳过评级变动部分，生成 "公司简称 (股票代码)：title（English Title）" 格式。
- **[风险]** 首次覆盖时英文标题格式 "Initiation" vs 其他场景混用 → **缓解措施**：明确定义首次覆盖用 "Initiation"，其他维持/变动场景用原始 title。

## Migration Plan

### Phase 1：数据库 Migration
1. 新增 migration 文件，添加 `reports.publish_title text DEFAULT NULL`
2. 新增 RPC 函数 `get_last_published_rating_and_targetprice(p_coverage_id uuid)` 返回 `{rating, target_price}` 或 `null`
3. 修改 `report_save_content_atomic` 或新增 RPC，保存时统一调用 `generate_publish_title`，内部根据 `report_type` 分支（company 类走复杂逻辑，其他类型直接复制 `title`）
4. 执行 migration，确认幂等（`CREATE INDEX IF NOT EXISTS`、`DO $$ BEGIN ... END$$` 语法）

### Phase 2：前端变更
1. `/reports/new` 页面：移除 `publish_title` 字段展示（不传该字段，后端自动生成）
2. `/reports/{id}/edit` 页面：新增只读 `publish_title` 字段展示区域（读取已有值）
3. `/report-review` 页面：新增只读 `publish_title` 字段展示区域
4. 更新 `ReportDetail` 类型，添加 `publish_title` 字段
5. 测试：创建新报告 → 检查 DB 中 `publish_title` 是否正确（公司类按首次覆盖/变动逻辑生成，其他类型等于 `title`）；修改/审批页面是否正确展示

### Rollback
- 前端：直接回退代码
- 数据库：`ALTER TABLE reports DROP COLUMN IF EXISTS publish_title; DROP FUNCTION IF EXISTS get_last_published_rating_and_targetprice;`
