## Context

本文承接 `proposal.md`，基于现有报告审批流程（`approveReport()` -> `report_change_status_atomic()`）扩展推送能力。假设读者已阅读 proposal，以下仅说明技术实现方案与关键权衡。

## Goals / Non-Goals

**Goals:**
- 在 `submitted -> published` 审批通过后，异步调用外部接口推送报告。
- 通过数据库记录每次推送请求的完整信息。
- 提供手动重推入口。

**Non-Goals:**
- 不做定时批量推送。
- 不做推送失败自动重试。
- 不做通用推送抽象，当前仅对接已知外部接口规范。

---

## Decisions

### 1) 设计基线

技术基线继承项目约定（Server-first，Server Actions + Repo 模式）。

主要依赖现有代码：
- `approveReport()` — `web/features/report-review/repo/report-review-repo.ts`
- `report_change_status_atomic()` RPC — 状态机约束
- `report_version` — PDF 文件路径字段 `pdf_file_path` / `pdf_file_name`
- `report` — 报告元数据（title、report_type、published_at 等）
- `report_analyst` — 作者关联
- `region` — 地区名称（通过 `region_code` 关联）
- `sector` — 行业名称（通过 `sector_id` 关联）
- `storage.objects` — PDF 文件读取（bucket `reports`）

### 2) 数据模型

#### 2.1 新增表：`report_push_log`

```sql
create table if not exists public.report_push_log (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.report(id) on delete cascade,
  status text not null check (status in ('success', 'failed', 'pending')),
  http_status_code integer,
  response_body text,
  error_message text,
  payload_sent jsonb,
  trigger_type text not null check (trigger_type in ('auto', 'manual')),
  triggered_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);
```

**约束：**
- `report_push_log` 为 INSERT-only，不支持 UPDATE/DELETE。
- 通过 trigger `trg_report_push_log_no_update_delete` 阻止 UPDATE/DELETE。

**索引：**
- `(report_id, created_at DESC)` — 推送历史查询
- `(triggered_by, created_at DESC)` — 按操作人查询

#### 2.2 RLS Policy

```sql
-- Admin: 全部可见
create policy "report_push_log_select_admin"
  on public.report_push_log for select
  using (auth.jwt() ->> 'role' = 'admin');

-- SA: 仅可见 submitted/published/rejected 报告的推送记录
create policy "report_push_log_select_sa"
  on public.report_push_log for select
  using (
    auth.jwt() ->> 'role' = 'sa'
    and exists (
      select 1 from public.report r
      where r.id = report_push_log.report_id
        and r.status in ('submitted', 'published', 'rejected')
    )
  );

-- Analyst: 仅可见自己的报告的推送记录
create policy "report_push_log_select_analyst"
  on public.report_push_log for select
  using (
    auth.jwt() ->> 'role' = 'analyst'
    and exists (
      select 1 from public.report r
      where r.id = report_push_log.report_id
        and r.owner_user_id = (auth.jwt() ->> 'id')::uuid
    )
  );

-- INSERT: 仅系统（通过 service_role key）或 Admin 可写入
create policy "report_push_log_insert_admin"
  on public.report_push_log for insert
  with check (
    auth.jwt() ->> 'role' = 'admin'
    or auth.jwt() ->> 'role' = 'service_role'
  );
```

### 3) 推送触发流程

#### 3.1 自动推送（审批通过）

在 `approveReport()` 函数中，`submitted -> published` 成功后，异步触发推送：

```
approveReport()
  → changeReportStatus()  [status -> published]
  → 插入 report_distribution_queue 记录（现有逻辑）
  → 异步任务: pushReportExternal(report_id, triggered_by=审批人, trigger_type=auto)
```

**推送任务 `pushReportExternal()` 执行步骤：**

1. **读取报告数据**：从 `report`、`report_version`、`report_analyst`、`region`、`sector` 等表聚合元数据
2. **读取 PDF 文件**：从 `storage.objects` 下载最新版本的 PDF 文件（`report_version.pdf_file_path`）
3. **构造 payload**：按外部接口规范构造 `multipart/form-data`
4. **调用外部接口**：POST `{EXTERNAL_API_URL}/api/external/reports`
5. **记录日志**：向 `report_push_log` 插入记录
6. **返回**：不影响审批主流程

**推送为异步**：`pushReportExternal()` 使用 `Promise` / 忽略 await，或通过数据库队列触发（参考现有 `report_distribution_queue` 模式），不阻塞审批响应。

#### 3.2 手动重推

在报告详情页，提供"重新推送"按钮（仅 Admin 可见）：

- 点击后调用 Server Action `repushReportExternal(report_id)`
- 同样调用 `pushReportExternal()`，但 `trigger_type = 'manual'`，`triggered_by = 当前用户`

### 4) API 设计

#### 4.1 Server Action

**文件**：`web/features/report-review/actions.ts`（扩展现有 actions）

```typescript
// 手动重推
export async function repushReportExternal(reportId: string): Promise<Result<void>> { ... }
```

**权限**：仅 Admin 可调用。

#### 4.2 推送任务函数

**文件**：`web/features/report-review/repo/report-push-repo.ts`（新建）

```typescript
export async function pushReportExternal(params: {
  reportId: string;
  triggeredBy: string;
  triggerType: 'auto' | 'manual';
}): Promise<Result<void>> { ... }
```

**内部逻辑**：
1. 聚合报告元数据 + 关联数据
2. 下载 PDF 文件（通过 Supabase Storage SDK）
3. 构造 `FormData`，调用外部接口
4. 写入 `report_push_log`

### 5) Payload 构造

#### 5.1 必填字段

| 字段 | 来源 |
|------|------|
| `external_id` | `report.id`（UUID string） |
| `title` | `report.title` |
| `report_type` | `report.report_type` |
| `published_at` | `report.published_at`（ISO 8601） |

#### 5.2 可选字段

| 字段 | 来源 |
|------|------|
| `ticker` | `report.ticker`（如有） |
| `rating` | `report.rating`（如有） |
| `target_price` | `report.target_price`（仅当 > 0 时传递） |
| `sector` | `sector.name`（通过 `report.sector_id` 关联） |
| `region` | `region.name`（通过 `report.region_code` 关联） |
| `report_language` | `report.report_language` |
| `investment_thesis` | `report.investment_thesis` |
| `analyst` | 从 `report_analyst` + `analyst` 表聚合，格式 `名字<邮箱>,...`（仅用于构造推送字段，不回写数据库） |
| `contact_person` | 从 `report.contact_person_id` 关联 `auth.users` 聚合，格式 `名字<邮箱>`（单人） |

#### 5.3 PDF 附件

- 从 `report_version` 读取 `pdf_file_path`
- 下载文件内容（Supabase Storage → `download()`）
- 添加到 `FormData`，字段名 `attachment_pdf`

**注意**：`pdf_file_path` 为空时，跳过附件，不视为错误。

#### 5.4 analyst 字段构造示例

```
张明<zhangming@example.com>,李华<lihua@example.com>
```

- 从 `report_analyst` 表查询所有作者（通过 `analyst` 表 join 获取邮箱）
- 多个逗号拼接

#### 5.5 contact_person 字段构造示例

```
王芳<wangfang@example.com>
```

- 从 `report.contact_person_id` join `auth.users` 获取名字和 email
- 如果 `contact_person_id` 为空，跳过该字段

### 6) 外部接口调用

```typescript
const formData = new FormData();
// ... 填充字段

const apiKey = process.env.EXTERNAL_REPORT_API_KEY;
if (!apiKey) {
  await logPush({ reportId, status: 'failed', error: 'EXTERNAL_REPORT_API_KEY not configured' });
  return;
}

const response = await fetch(`${process.env.EXTERNAL_API_URL}/api/external/reports`, {
  method: 'POST',
  headers: { 'X-API-Key': apiKey },
  body: formData,
  signal: AbortSignal.timeout(30_000), // 30s 超时
});
```

**环境变量**（`.env`）：

```env
EXTERNAL_REPORT_API_KEY=57d0aa51be428493583034d7a9f68389b7e48d194303c8f2c8ecd469672a7d31
EXTERNAL_API_URL=http://localhost:3001  # 外部系统根地址
```

### 7) 推送日志写入

```typescript
await supabase.from('report_push_log').insert({
  report_id: reportId,
  status: response.ok ? 'success' : 'failed',
  http_status_code: response.status,
  response_body: (await response.text()).slice(0, 2000),
  error_message: response.ok ? null : `HTTP ${response.status}`,
  payload_sent: {
    external_id: report.id,
    title: report.title,
    // ... 可选字段（不含附件内容）
    attachment_count: pdfFile ? 1 : 0,
    attachment_size: pdfFile?.size,
  },
  trigger_type: triggerType,
  triggered_by: triggeredBy,
});
```

**脱敏规则**：`payload_sent` 中不存储 PDF 文件内容，仅记录字段名和大小。

### 8) 前置条件校验

推送前校验（任一不满足则跳过推送，记录 `status=failed`）：

- `report.title` 非空
- `report.report_type` 非空
- `report.published_at` 非空
- `EXTERNAL_REPORT_API_KEY` 已配置

### 9) 错误处理

| 场景 | 处理 |
|------|------|
| 网络超时 | 记录 `error_message='timeout'`，`http_status_code=null` |
| HTTP 非 2xx | 记录 `http_status_code` + `response_body`（截断 2000 字符） |
| API Key 未配置 | 跳过推送，记录 `error_message='EXTERNAL_REPORT_API_KEY not configured'`，**不阻塞审批** |
| PDF 文件不存在 | 跳过附件，继续推送元数据，记录 `attachment_missing=true` |
| 报告数据不完整 | 跳过推送，记录失败原因 |

### 10) 数据库 Migration 清单

| 顺序 | 文件名 | 内容 |
|------|--------|------|
| 1 | `2026xxxxxx_report_push_log.sql` | 创建 `report_push_log` 表 + trigger + indexes + RLS policies |

### 11) 文件结构

```
web/features/report-review/
  repo/
    report-push-repo.ts   # [新建] pushReportExternal()
  actions.ts              # [扩展] repushReportExternal()
  components/
    ReportPushHistory.tsx # [新建] 推送历史列表组件
    PushStatusBadge.tsx   # [新建] 推送状态徽章

web/app/reports/[id]/
  page.tsx                # [扩展] 增加推送历史展示区 + 手动重推按钮

supabase/migrations/
  2026xxxxxx_report_push_log.sql  # [新建]
```

### 12) 推送历史 UI

在报告详情页（`/reports/[id]`）新增推送历史区域：

- 展示最近 10 条推送记录（时间、触发类型、操作人、状态、状态码）
- 状态徽章：`success`（绿色）、`failed`（红色）、`pending`（灰色）
- Admin 可见"重新推送"按钮
- Analyst/SA 不可见重推按钮

---

## Key Implementation Notes

1. **异步不阻塞**：推送在 `approveReport()` 中以 fire-and-forget 方式触发（`void pushReportExternal(...)` 或通过 `report_distribution_queue` 模式），审批响应不受影响。
2. **幂等键**：`external_id = report.id`（UUID），外部接口保证幂等，内部无需额外去重。
3. **API Key 安全**：仅在 Server-side 读取 `process.env`，不暴露给客户端。
4. **PDF 路径**：`report_version.pdf_file_path` 已存在，直接使用，无需新建字段。
5. **`report.analyst` 字段**：需确认 `report` 表是否有 `analyst` 字段（目前 schema 中未发现，如有则回填第一作者名字，否则跳过）。
6. **`region.name`**：通过 `report.region_code` join `region` 表获取地区名称。
7. **脱敏**：`payload_sent.jsonb` 中 PDF 文件内容不存储，仅记录元数据。
