# skills_neolyst 设计文档

## 1. 定位与范围

### 1.1 背景

`report_maker` 是一条报告生成流程，最后一步调用 `neolyst` skill，将标准化后的报告数据提交到 Neolyst。

### 1.2 职责定位

- 接收标准化提交数据，执行报告落库与提交流程
- 负责与 Neolyst Supabase 的认证、读写与文件上传
- 管理和复用 Neolyst Supabase 登录身份
- 不绑定 `report_maker` 的内部目录结构
- 不负责报告生成、模板渲染、内容抽取和目录整理

### 1.3 目标

- 提供 `submit_report(submission)` 作为 `report_maker` 的提交出口
- 设计口径严格对齐当前 Neolyst 数据库表定义，而不是历史 Web 代码中的旧字段

## 2. 当前数据库基线

本设计以当前运行中的本地 Supabase `public` schema 为准。

### 2.1 提交流程涉及的核心表

- `report`
- `report_analyst`
- `report_version`
- `report_status_log`
- `report_type`
- `report_template`
- `analyst`
- `region`
- `sector`
- `coverage`
- `coverage_analyst`

### 2.2 当前表结构里的关键事实

- `report.report_type` 是普通 `text` 列，合法值应来自 `report_type.report_type`
- 模板表当前是 `report_template`，不是历史文档中的 `template`
- `report.contact_person` 当前是 `text`，不是 `contact_person_id`
- `report.region_code` 是地区关联字段，当前不是 `region_id`
- `report_analyst` 当前使用 `analyst_email + author_order`，不再使用 `analyst_id / role / sort_order`
- `coverage_analyst` 也使用 `analyst_email + author_order`
- `report_version` 只保存 `word_file_path / pdf_file_path / model_file_path`，当前没有文件名列
- `report_version` 的操作者字段是 `created_by`，不是 `changed_by`
- `report.current_version_no` 初始值为 `0`，每次成功保存内容后递增
- `report_status_log` 记录状态流转，提交动作写入 `from_status='draft'`、`to_status='submitted'`

### 2.3 当前数据库约束

- `report.status` 允许值：`draft | submitted | published | rejected`
- `report.target_price` 为 `numeric`，若提供则必须 `> 0`
- `report.report_language` 允许值：`en | zh`
- `report_version.version_no >= 1`
- `report_status_log.to_status = 'rejected'` 时，`reason` 必填
- `report_analyst` 唯一约束：
  - `(report_id, analyst_email)`
  - `(report_id, author_order)`
- `coverage_analyst` 唯一约束：
  - `(coverage_id, analyst_email)`
  - `(coverage_id, author_order)`

### 2.4 当前数据库能力边界

- 当前本地库未暴露专用的 `submit_report` / `report_save_content_atomic` / `report_change_status_atomic` RPC
- 当前本地库中也没有已初始化的 `storage.buckets` 记录，因此 bucket 名称不能硬编码成数据库既有事实，必须放到 skill 配置中
- 当前本地库未发现挂在 `public` 业务表上的用户自定义 trigger，因此不要假设 `updated_at` 会自动刷新；需要由 skill 显式维护
- 设计上默认仍沿用 `reports` bucket 约定，但这是 skill 配置，不是当前数据库表结构的一部分

## 3. 对外接口

### 3.1 核心接口

- 当前对外核心接口：`submit_report(submission)`
- skill 自行完成：
  - 登录
  - 数据校验
  - 文件上传
  - 数据落库
  - 状态提交

### 3.2 输入结构

`submission` 采用当前数据库可直接映射的字段口径：

```json
{
  "title": "string",
  "report_type": "string",
  "ticker": "string | null",
  "rating": "string | null",
  "target_price": "number | null",
  "region_code": "string | null",
  "sector_id": "uuid | null",
  "report_language": "en | zh | null",
  "contact_person": "string | null",
  "investment_thesis": "string | null",
  "analysts": [
    {
      "analyst_email": "analyst@company.com",
      "author_order": 1
    }
  ],
  "files": {
    "report_file": "/abs/or/relative/path/to/report.docx",
    "pdf_file": "/abs/or/relative/path/to/report.pdf",
    "model_file": "/abs/or/relative/path/to/model.xlsx"
  }
}
```

字段说明：

- `title`：对应 `report.title`
- `report_type`：对应 `report.report_type`，值来自 `report_type.report_type`
- `ticker`：对应 `report.ticker`
- `rating`：对应 `report.rating`
- `target_price`：对应 `report.target_price`
- `region_code`：对应 `report.region_code`
- `sector_id`：对应 `report.sector_id`
- `report_language`：对应 `report.report_language`
- `contact_person`：对应 `report.contact_person`，建议使用分析师邮箱
- `investment_thesis`：对应 `report.investment_thesis`
- `analysts[]`：对应 `report_analyst`
- `files.report_file`：最终落到 `report_version.word_file_path`
- `files.pdf_file`：最终落到 `report_version.pdf_file_path`
- `files.model_file`：最终落到 `report_version.model_file_path`

明确不再使用的旧字段：

- `contact_person_id`
- `certificate_confirmed`
- `analyst_id`
- `role`
- `sort_order`
- `word_file_name`
- `pdf_file_name`
- `model_file_name`

### 3.3 返回结构

成功时返回：

```json
{
  "ok": true,
  "report_id": "uuid",
  "status": "submitted",
  "version_no": 1
}
```

失败时返回：

```json
{
  "ok": false,
  "error": "human readable message",
  "report_id": "uuid | null"
}
```

约定：

- 如果 draft 已创建但提交失败，返回 `ok: false`，同时带回已创建的 `report_id`
- 调用方可据此决定后续补救或清理策略

## 4. 落库映射

### 4.1 `report`

首次创建写入：

```json
{
  "title": "...",
  "report_type": "...",
  "status": "draft",
  "current_version_no": 0,
  "owner_user_id": "<auth.uid()>",
  "coverage_id": "<解析后可空>",
  "ticker": "...",
  "sector_id": "...",
  "region_code": "...",
  "rating": "...",
  "target_price": 123.45,
  "investment_thesis": "...",
  "report_language": "en",
  "contact_person": "analyst@company.com"
}
```

说明：

- `coverage_id` 仅对 `company` / `company_flash` 尝试解析
- `published_by` / `published_at` 不在 submit 阶段写入

### 4.2 `report_analyst`

每个 analyst 写一行：

```json
{
  "report_id": "<report.id>",
  "analyst_email": "analyst@company.com",
  "author_order": 1
}
```

### 4.3 `report_version`

首次保存内容时写入版本 `1`：

```json
{
  "report_id": "<report.id>",
  "version_no": 1,
  "snapshot_json": {
    "title": "...",
    "report_type": "...",
    "ticker": "...",
    "rating": "...",
    "target_price": 123.45,
    "region_code": "...",
    "sector_id": "...",
    "report_language": "en",
    "contact_person": "analyst@company.com",
    "investment_thesis": "...",
    "analysts": [
      {
        "analyst_email": "analyst@company.com",
        "author_order": 1
      }
    ]
  },
  "word_file_path": "...",
  "pdf_file_path": "...",
  "model_file_path": "...",
  "created_by": "<auth.uid()>"
}
```

### 4.4 `report_status_log`

提交成功后写入：

```json
{
  "report_id": "<report.id>",
  "from_status": "draft",
  "to_status": "submitted",
  "action_by": "<auth.uid()>",
  "action_by_name": "<可空>",
  "version_no": 1,
  "reason": null
}
```

## 5. 提交流程设计

### 5.1 总流程

`scripts/submit-report.ts` 负责主流程实现。

主流程：

1. 获取已认证的 Supabase client
2. 校验 `submission`
3. 校验来源表与关联关系
4. 创建 `report` draft
5. 写入 `report_analyst`
6. 上传文件到 Storage
7. 写入 `report_version`
8. 回写 `report.current_version_no = 1`，并显式更新 `report.updated_at`
9. 更新 `report.status = 'submitted'`，并显式更新 `report.updated_at`
10. 写入 `report_status_log`
11. 返回结果

### 5.2 两段式提交

整体流程仍采用两段式思想：

- 第一段：创建 draft + 保存版本
- 第二段：状态从 `draft` 切到 `submitted`

这样做的原因：

- 与当前 `report` / `report_version` / `report_status_log` 三表分工一致
- 第二段失败时，前面已创建的 draft 和版本可保留，便于排查与补救

### 5.3 失败处理

- `report` 创建成功前失败：直接返回错误，不产生业务对象
- `report` 创建后、`report_version` 写入前失败：保留 draft，返回 `report_id`
- 文件上传成功但版本写入失败：保留 draft，返回 `report_id`，由后续清理脚本处理孤儿文件
- `report_version` 写入成功但 submit 失败：保留 `draft + version 1`，返回 `report_id`

## 6. 校验规则

### 6.1 基础字段校验

- `title` 必填
- `report_type` 必填
- `analysts` 至少 1 个
- `files.report_file` 必填
- `target_price` 若提供，必须可转成正数
- `author_order` 必须为正整数
- `analyst_email` 必须是合法邮箱格式

### 6.2 按报告类型的字段要求

- `company`：`ticker`、`rating`、`target_price`、`files.model_file`
- `company_flash`：`ticker`
- `sector`：`region_code`、`sector_id`
- `sector_flash`：`region_code`、`sector_id`
- `common`：`region_code`

### 6.3 来源合法性校验

- `report_type` 必须存在于启用中的 `report_type`
- `region_code` 若提供，必须存在于有效 `region`
- `sector_id` 若提供，必须存在于有效 `sector`
- `analysts[].analyst_email` 必须存在于有效 `analyst`
- `contact_person` 若提供，必须属于 `analysts[].analyst_email`
- `analysts[].analyst_email` 不能重复
- `analysts[].author_order` 不能重复

### 6.4 模板可用性校验

当前数据库没有 `template.is_active` 这一旧口径，校验改为：

- `report_template` 中至少存在一条对应 `report_type` 的模板记录
- `template_file_path` 不能为空
- 如后续业务要求按语言区分，则追加 `language = report_language`

### 6.5 Coverage 关系校验

针对 `company` / `company_flash`：

1. 先用 `ticker` 在 `coverage` 中找到目标公司
2. 再用 `coverage_analyst` 检查该 `coverage.id` 下是否存在至少一名与 `submission.analysts[].analyst_email` 重叠的记录
3. 命中则将 `coverage.id` 回写到 `report.coverage_id`

说明：

- skill 依赖的是当前表中的 `analyst_email` 逻辑关联，而不是历史版本里的 `analyst_id`

## 7. 文件上传设计

### 7.1 文件类型

- 报告主文件：`.doc` / `.docx` / `.ppt` / `.pptx`
- PDF：`.pdf`
- Model：`.xls` / `.xlsx` / `.csv`

### 7.2 Storage 路径

默认沿用现有命名约定：

```text
{report_id}/{report_id}_{version_no3}_{label}_{timestamp}.{ext}
```

例如：

```text
2f4.../2f4..._001_report_20260409T120000Z.docx
```

说明：

- bucket 默认值建议为 `reports`
- 但 bucket 名必须通过 skill 配置提供，不能把“数据库当前已有 bucket”当成前提

### 7.3 上传结果

上传后只返回当前数据库真正需要的字段：

```ts
type UploadedReportFiles = {
  word_file_path: string | null
  pdf_file_path: string | null
  model_file_path: string | null
}
```

## 8. 技术结构

整体骨架：

```text
neolyst/
  SKILL.md
  scripts/
    auth.ts
    config.ts
    client.ts
    submit-report.ts
    storage.ts
    validators.ts
```

模块分工：

- `auth.ts`：登录、session 恢复、重新登录
- `config.ts`：读写工作目录根下的 `/.neolyst`
- `client.ts`：导出 `getAuthenticatedClient()`
- `submit-report.ts`：主提交流程
- `storage.ts`：文件上传与路径构造
- `validators.ts`：payload 校验与来源合法性校验

## 9. 配置与会话

### 9.1 `/.neolyst`

skill 在工作目录根下维护 `/.neolyst`：

```ts
type NeolystConfig = {
  server?: {
    url?: string
    storage_bucket?: string
  }
  auth?: {
    email?: string
    password?: string
  }
  session?: Record<string, unknown> | null
}
```

说明：

- `server.url`：Supabase URL
- `server.storage_bucket`：默认文件 bucket，建议默认 `reports`
- `auth.email/password`：自动重登用
- `session`：当前 session 缓存

### 9.2 会话策略

- 使用 `email + password` 登录
- 优先恢复 `session`
- `session` 失效时尝试用保存的账号密码重登
- 重登成功后回写最新 `session`
- 当前不做代理执行，不支持多身份切换

## 10. 当前联调环境

### 10.1 当前联调测试环境

- URL：`http://47.57.213.88:80`
- Admin username：`admin@neolyst.com`
- Admin password：`Admin123`

## 11. 设计结论

这份 skill 设计必须以当前库表定义为准，后续若数据库再次演进，至少需要同步复核以下项目：

- `report` 字段是否变化
- `report_analyst` 是否继续使用 `analyst_email`
- `report_template` / `report_type` 的关系是否变化
- `report_version` 是否新增文件元数据列
- 是否新增可替代当前顺序写入的 RPC
