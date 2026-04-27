## 为什么

Analyst 在创建公司类研究报告时，需要一个自动生成的正式发布标题（`publish_title`），该标题包含评级变动和目标价调整信息，供下游发布流程使用。目前系统中没有此字段和对应生成逻辑。

## 变更内容

1. **新增数据库字段**：`reports.publish_title`（text，非必填）
2. **UI 页面差异展示**：
   - `/reports/new` 页面：**不展示** `publish_title` 字段
   - `/reports/{id}/edit` 页面：**展示** `publish_title` 为只读字段
   - `/report-review` 页面：**展示** `publish_title` 为只读字段
3. **自动生成逻辑**：
   - **公司类报告**（`report_type = 'company'`）：查询当前 coverage 最近一次发布报告的 Rating 和 TargetPrice
     - **首次覆盖**：最近一次没有已发布报告 → 生成 "公司简称 (股票代码)：首次覆盖：title"
     - **非首次覆盖**：按评级对照表 + 目标价变动百分比生成标题
   - **其他类型报告**（`sector`/`company_flash`/`sector_flash`/`common` 等）：`publish_title = title`
4. **生成触发时机**：Analyst 在 `/reports/new` 填写 Report Title 后，后端在保存报告内容时自动生成

## 功能 (Capabilities)

### 新增功能

- `publish-title-generation`: 实现 `publish_title` 自动生成逻辑，包括首次覆盖判定、评级变动映射（维持/上调/下调）和目标价变动百分比计算。

### 修改功能

- `report-management`: 修改报告创建页面（`/reports/new`）和编辑页面（`/reports/{id}/edit`）的字段展示规则。
- `report-review`: 修改审批页面展示 `publish_title` 为只读字段。

## 影响

- **数据库**：需执行 migration，在 `reports` 表新增 `publish_title` 字段
- **前端页面**：`/reports/new`、`/reports/{id}/edit`、`/report-review` 三个页面
- **后端逻辑**：新增 `publish_title` 生成服务函数
- **API**：报告创建/更新接口需要支持 `publish_title` 字段的写入（仅后端写入，前端只读）
