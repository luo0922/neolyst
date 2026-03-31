## Why

报告审批通过（`submitted -> published`）后，需要将已发布报告自动推送至外部系统。目前系统仅支持内部发布，外部合作方无法及时获取报告数据，需要在审批流程中增加自动推送机制，形成完整的报告发布闭环。

## What Changes

## 一、目标与范围

### 1.1 目标
- 在报告审批通过（`submitted -> published`）时，自动调用外部接口推送报告元数据与附件。
- 支持幂等推送：相同 `external_id` 重复推送返回 200，不报错。
- 将推送结果（成功/失败）记录到数据库，供管理员查看推送历史与排查问题。
- 支持管理员手动重推（对已发布报告重新触发推送）。

### 1.2 范围边界
- 仅处理 `submitted -> published` 这一审批通过触点，不处理其他状态流转。
- 不做定时轮询/批量推送，本 change 均为单报告触发。
- 不做推送失败后的自动重试（由管理员手动重推）。
- 外部系统接口规范以本提案为准，不做通用抽象。

## 二、需求

### 2.1 推送触发时机
- 报告状态由 `submitted` 变为 `published` 时（SA 或 Admin 审批通过），自动触发外部推送。
- 推送为异步执行，不阻塞审批响应。
- 推送失败不影响报告状态变更（审批仍视为通过）。

### 2.2 外部接口规范

**基本信息**
- URL：`POST /api/external/reports`
- Content-Type：`multipart/form-data`
- 认证：Header `X-API-Key`，值从 `.env` 的 `EXTERNAL_REPORT_API_KEY` 读取
- 幂等键：`external_id` 字段，相同值重复推送返回 200

**必填字段**

| 字段 | 类型 | 最大长度 | 说明 |
|------|------|---------|------|
| `external_id` | string | 100 | 外部系统唯一标识，使用 `report.id`（UUID），保证幂等 |
| `title` | string | 500 | 报告标题，直接取 `report.title` |
| `report_type` | string | 100 | 报告类型，取 `report.report_type` 映射值 |
| `published_at` | string | — | 发布时间，ISO 8601 格式，取 `report.published_at` |

**可选字段**

| 字段 | 类型 | 最大长度 | 说明 |
|------|------|---------|------|
| `ticker` | string | 50 | 股票代码，取 `report.ticker`（如有） |
| `rating` | string | 100 | 评级，取 `report.rating`（如有） |
| `target_price` | string/numeric | — | 目标价，必须 > 0，取 `report.target_price`（如有） |
| `sector` | string | 200 | 行业分类名称，取关联 `sector.name` |
| `region` | string | 100 | 地区名称，取关联 `region.name` |
| `report_language` | string | 10 | 语言，仅允许 `zh` 或 `en` |
| `investment_thesis` | string | 5000 | 投资摘要，取 `report.investment_thesis`（如有） |
| `analyst` | string | 500 | 分析师信息，格式：`名字<邮箱>,...` |
| `contact_person` | string | 200 | 联系人信息，格式：`名字<邮箱>`（仅单人） |

**附件字段**
- 字段名：`attachment_*`，如 `attachment_report`、`attachment_pdf`
- 仅推送报告最新版本的 **PDF 文件**，取 `report_version` 中关联的 PDF 文件
- 最多 1 个，单文件最大 50MB

**analyst 字段格式**
- 支持多作者，逗号分隔，每人格式：`名字<邮箱>`
- 示例：`张明<zhangming@example.com>,李华<lihua@example.com>`

**contact_person 字段格式**
- 仅支持单人，格式：`名字<邮箱>`
- 示例：`王芳<wangfang@example.com>`

### 2.3 推送记录表

新建 `report_push_log` 表，记录每次推送请求的完整信息：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | uuid | 主键 |
| `report_id` | uuid | FK -> `report.id` |
| `status` | text | `success` / `failed` / `pending` |
| `http_status_code` | integer | 外部接口返回的 HTTP 状态码 |
| `response_body` | text | 外部接口响应体（截断至 2000 字符） |
| `error_message` | text | 错误信息（网络异常/超时等） |
| `payload_sent` | jsonb | 本次推送的完整 payload（调试用，敏感字段可脱敏） |
| `trigger_type` | text | `auto`（自动推送）或 `manual`（手动重推） |
| `triggered_by` | uuid | 触发人（自动推送时为审批人，手动时为操作人） |
| `created_at` | timestamptz | 推送时间 |

### 2.4 手动重推功能
- 在报告详情页或发布记录页，提供"重新推送"按钮。
- 仅 `published` 状态的报告可重推。
- 重推后新增 `report_push_log` 记录，`trigger_type` 为 `manual`。
- 重推不改变 `report_push_log` 中已有的历史记录。

### 2.5 推送历史查看
- 在报告详情页展示该报告的推送历史（`report_push_log` 列表）。
- 每条记录显示：推送时间、触发类型、状态、HTTP 状态码、成功/失败原因摘要。

## 三、权限模型

### 3.1 角色功能权限矩阵

以下为全量功能权限矩阵（扩展自已实现模块）：

| 功能模块 | 功能能力 | Admin | SA | Analyst |
|---------|---------|-------|----|---------|
| **已有模块（参考）** | - | - | - | - |
| Reports | 访问/创建/编辑/提交 | ✅ | ❌ | ✅ |
| Report Review | 审批通过/拒绝 | ✅ | ✅ | ❌ |
| **本 change 新增模块** | - | - | - | - |
| Report Push | 查看推送历史 | ✅ | ✅ | ❌（可见自己的报告） |
| Report Push | 手动重推 | ✅ | ❌ | ❌ |

### 3.2 角色数据表权限矩阵（RLS）

| 数据表 | SELECT | INSERT | UPDATE | DELETE | 说明 |
|-------|--------|--------|--------|--------|------|
| **已有表** | - | - | - | - | - |
| `report` | — | — | — | — | 已有 RLS 保持不变 |
| `report_status_log` | — | — | — | — | 已有 RLS 保持不变 |
| **本 change 新增表** | - | - | - | - | - |
| `report_push_log` | Admin 全部；SA 仅 submitted/published/rejected；Analyst 仅 owner | 系统自动写入（Server-side）；Admin 可补录 | ❌ | ❌ | 仅追加，不更新/删除 |

## 四、验收标准

- [ ] 报告审批通过（`submitted -> published`）后，自动触发外部推送，记录推送日志。
- [ ] 推送使用 `X-API-Key` 认证，Key 从 `.env` 的 `EXTERNAL_REPORT_API_KEY` 读取。
- [ ] `external_id` 使用 `report.id`（UUID），保证幂等。
- [ ] 推送必填字段（`external_id`、`title`、`report_type`、`published_at`）正确传递。
- [ ] 推送附件仅含报告最新版本的 PDF 文件，通过 `multipart/form-data` 附带，单文件最大 50MB。
- [ ] 推送失败不影响报告状态变更，仍记录失败日志（`status=failed`）。
- [ ] 管理员可在报告详情页查看推送历史（时间、状态、状态码、失败原因）。
- [ ] 管理员可对已发布报告手动重推。
- [ ] RLS 生效：`report_push_log` 按角色可见性控制。
- [ ] 多次推送（自动或手动）均生成独立记录，不覆盖。

## 五、设计约束与规范

- 推送为**异步**：`submitted -> published` 审批动作完成后，触发推送任务，不阻塞用户响应。
- 幂等保证：外部接口以 `external_id`（即 `report.id`）为幂等键，重复推送不报错。
- 不做自动重试：推送失败后由管理员手动重推。
- `report_push_log` 仅追加（INSERT-only），不更新不删除。
- 敏感信息处理：`payload_sent` 字段中附件内容不存储，仅记录字段名和大小。
- 外部接口超时：设置合理超时（如 30s），超时视为推送失败并记录。
- `.env` 配置：`EXTERNAL_REPORT_API_KEY` 必须配置，缺失时跳过推送并记录警告日志（不影响审批）。
- API Key 不得明文写入代码，必须从环境变量读取。
- 推送前校验必填字段：`title`、`report_type`、`published_at` 任一为空则跳过推送并记录失败。

## Capabilities

### New Capabilities
- `report-external-push`: 报告审批通过后自动推送外部系统。
- `report-push-log`: 推送记录查看与手动重推。

### Modified Capabilities
- `report-review`: 审批通过后触发推送任务（副作用扩展）。
- `report-publishing`: 发布快照后追加推送动作。
