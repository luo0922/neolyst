# Neoskills 数据库变更协作流程

本文档面向 `neoskills` 项目，定义我们在需要新增存储过程、函数、触发器或其他数据库对象时，与 `neolyst` 主数据库仓库协作的标准流程。

适用前提：
- `neolyst` 是共享 Supabase 数据库的唯一主仓库。
- 正式数据库结构变更只允许落在 `neolyst/supabase/migrations/`。
- 我们可以提出、生成、验证数据库变更，但不维护正式 migration 主线。

## 1. 角色分工

### 1.1 `neolyst`

- 共享数据库 schema 的唯一 source of truth
- 唯一正式 migration 仓库
- 唯一远端 schema 发布入口
- 负责回收远端手工改动（`db pull`）

### 1.2 `neoskills`

- 我们可以提出新的数据库能力需求
- 我们可以由 Claude Code 自动生成候选 SQL
- 我们可以在本地 Supabase 上测试函数行为
- 我们不直接维护共享数据库的正式 migration 历史

## 2. 适用变更类型

本流程适用于：
- `function`
- `procedure`
- `trigger`
- `view`
- `rpc`
- 与 `skills` 业务能力强相关的辅助表、枚举、索引、policy

不适用于：
- 在 `neoskills` 仓库内长期维护一套独立 migration
- 由 `neoskills` 直接对共享远端库执行正式 `db push`

## 3. 基本原则

- 我们可以生成变更，但 `neolyst` 才能收编变更。
- 本地测试可以快，正式落库必须稳。
- 同一个共享数据库只能有一条 migration 主线。
- 远端 staging / production 只从 `neolyst` 发布。

## 4. 推荐目录约定

### 4.1 `neoskills` 中的候选 SQL

`neoskills` 内只存放候选变更，不存放正式 migration。我们推荐使用：

```text
docs/db-proposals/
tmp/db/
scripts/sql/
```

建议文件内容包括：
- SQL 草案
- 用途说明
- 调用示例
- 输入输出说明
- 对现有表/函数的依赖

### 4.2 `neolyst` 中的正式变更

正式变更统一放在：

```text
supabase/migrations/*.sql
```

## 5. 标准工作流

### 5.1 在 `neoskills` 生成候选 SQL

当我们需要新增数据库能力时：

1. 先在 `neoskills` 中描述需求。
2. 由 Claude Code 生成候选 SQL。
3. 候选 SQL 不直接当正式 migration 提交。
4. 先在本地 Supabase 上验证。

候选 SQL 常见形式：

```sql
create or replace function skills_xxx(...)
returns ...
language plpgsql
as $$
begin
  ...
end;
$$;
```

## 5.2 本地测试方式

默认推荐：我们直接连接 `neolyst` 启动的本地 Supabase。

优点：
- 两个项目看到的是同一份本地 schema
- 不会出现两套本地 migration 历史
- 调试结果更接近正式落库后的实际状态

本地连接通常使用：
- API: `http://127.0.0.1:54321`
- DB: `postgresql://postgres:postgres@127.0.0.1:54322/postgres`
- Studio: `http://127.0.0.1:54323`

推荐做法：
1. 在 `neolyst` 启动本地 Supabase。
2. 我们在 `neoskills` 执行候选 SQL。
3. 我们在 `neoskills` 调用并验证结果。
4. 记录最终确认版本。

## 5.3 收编到 `neolyst`

候选 SQL 验证通过后，必须回到 `neolyst` 落正式 migration：

1. 在 `neolyst` 创建 migration：

```bash
pnpm exec supabase migration new <change_name>
```

2. 将已验证的 SQL 收编到 migration 文件。
3. 在 `neolyst` 本地执行：

```bash
pnpm exec supabase db reset
```

4. 确认 migration 可从空库完整回放。
5. 合并后再由 `neolyst` 推送到远端环境。

## 5.4 远端部署

远端部署只从 `neolyst` 执行：

```bash
pnpm run supabase:db:push
```

如需同时执行 SQL seed：

```bash
pnpm exec supabase db push --include-seed --linked --yes
```

`neoskills` 不直接承担共享库的正式发布职责。

## 6. 命名与隔离建议

因为我们主要新增 skills 相关能力，建议数据库对象保持明确隔离。

推荐二选一：

### 方案 A：独立 schema

例如：

```sql
create schema if not exists skills;
create or replace function skills.generate_outline(...)
```

优点：
- 语义清晰
- 与主业务对象隔离更好
- 后续审计和权限控制更方便

### 方案 B：统一前缀

如果暂时仍放在 `public`，则统一前缀：

```sql
create or replace function public.skills_generate_outline(...)
```

优点：
- 迁移成本低
- 更容易接入现有代码

默认推荐：
- 新增数量较少时，先用前缀方案
- skills 数据库对象逐渐增多后，再升级到独立 schema

## 7. 安全与评审要求

以下变更必须提高评审强度：
- `security definer`
- 绕过或放宽 RLS
- 批量写入核心业务表
- 动态 SQL
- 读写 `auth` 相关对象

最低要求：
- 明确调用方是谁
- 明确输入输出
- 明确是否跨表写入
- 明确失败行为
- 明确幂等性与回滚影响

## 8. 验收清单

在 `neolyst` 收编 migration 前，至少确认：

1. SQL 已在本地 Supabase 测通。
2. 变更目标、入参、返回值已写清楚。
3. 不依赖远端临时状态。
4. `pnpm exec supabase db reset` 可通过。
5. 命名符合 `skills` 域约定。
6. 如果涉及权限提升，已做专门评审。

## 9. 允许与禁止

允许：
- 我们用 Claude Code 自动生成候选 SQL
- 我们在本地 Supabase 做快速验证
- 我们驱动数据库新能力需求

禁止：
- 我们长期维护共享库的第二套 migration 历史
- 我们直接对共享远端库做正式 schema 发布
- 两个仓库轮流对同一远端库 `db push`
- 远端 schema 变更不回收到 `neolyst`

## 10. 默认决策

当没有额外说明时，默认按以下方式处理：

- 本地测试库：优先复用 `neolyst` 启动的本地 Supabase
- 正式 migration 落点：`neolyst/supabase/migrations`
- 对象命名：优先 `skills_` 前缀
- 发布入口：只允许 `neolyst`

## 11. 一句话规则

我们负责提出、生成、验证数据库变更；`neolyst` 负责收编、版本化、发布数据库变更。
