# Supabase 数据库版本管理规范

本规范基于 Supabase 官方在 2026-04-08 可查的 Local Development、Database Migrations、Seeding、Managing Config、Managing Environments 与 Branching 文档整理，并结合本仓库当前脚本与目录结构落地。

本规范替代旧口径：
- 不再以远端 linked project 作为默认开发数据库。
- 默认开发环境改为本地 Supabase。
- 远端环境用于联调、验收、staging、production 与发布。

## 0. 核心原则

- 本地开发优先：日常 schema 变更、RLS 调整、函数/触发器调试，默认在本地 Supabase 完成。
- Schema as Code：所有数据库结构变更必须进入 `supabase/migrations/*.sql`，禁止只在 Dashboard 手工改完不落地代码。
- Forward-only：已提交迁移不回改，后续修复通过新 migration 追加。
- Seed 分层：schema、SQL seed、Auth/程序化初始化三者职责分离。
- 先本地验证，后远端部署：所有 migration 至少通过一次本地 `db reset` 再推远端。

## 1. 环境策略

### 1.1 默认环境

- 开发环境：本地 Supabase CLI 栈。
- 验收/预发环境：优先使用 Supabase Branching 或独立 staging project。
- 生产环境：独立 production project。

### 1.2 推荐环境流转

1. 本地创建/修改 migration。
2. 本地 `supabase db reset` 验证迁移可回放、seed 可重建。
3. 提交代码并进入代码评审。
4. 通过 CI/CD 或受控命令将 migration 部署到远端。
5. 如启用 Branching，staging/preview 环境通过 branch 自动跑 migrate/seed。

### 1.3 远端环境原则

- 远端数据库不是默认开发库。
- 允许把远端项目作为联调、验收、演示环境。
- 生产环境不依赖开发者本机手工维护为长期默认流程，优先 CI/CD。

## 2. 职责边界

### 2.1 `supabase/migrations/*.sql`

只负责 schema 与数据库行为定义：
- 表、视图、索引、约束
- 函数、触发器
- RLS policy
- comment、extension、enum、RPC

禁止项：
- 禁止写业务初始化数据
- 禁止直接插入或更新 `auth.users`
- 禁止依赖某个远端环境的临时数据状态

### 2.2 SQL seed

SQL seed 由 `supabase/config.toml` 的 `[db.seed].sql_paths` 控制，只负责可重复导入的初始数据：
- 字典表
- 缺省配置
- 本地开发/测试所需的演示数据

禁止项：
- 禁止写 schema 语句
- 禁止混入一次性修复 SQL
- 禁止写入 `auth.users`

### 2.3 `supabase/seed.ts`

`seed.ts` 是本项目的补充初始化脚本，不是 Supabase 官方 migration 主机制的一部分。它只负责无法用纯 SQL seed 稳定表达的初始化逻辑，例如：
- 通过 Admin API 初始化 Auth 用户
- 需要 SDK/程序逻辑的幂等补数据

### 2.4 `supabase/config.toml`

`config.toml` 负责本地 Supabase 栈配置与 seed 入口配置：
- 本地端口
- 本地 Auth 配置
- `[db.seed]` 配置
- 需要时通过 `env()` 引用敏感配置

## 3. 当前仓库目录约定

```text
supabase/
  config.toml
  migrations/
    20260407000001_init_schema.sql
    archive/
  seed/
    *.sql                # 当前仓库启用 glob；没有文件时 CLI 会提示 warning
  seed.ts                # Auth / 程序化初始化
  supabase_access.token
scripts/
  db-init.sh             # 远端初始化：push + SQL seed + seed:auth
```

说明：
- 当前仓库 `config.toml` 已启用 `sql_paths = ["./seed/*.sql"]`。
- 当前仓库尚未提交 `supabase/seed/` 目录时，seed 匹配为空会出现 warning；这是配置状态，不是 migration 失败。
- 若后续长期不使用 SQL seed，应显式关闭 `[db.seed]` 或补齐目录与文件，不要让 warning 常驻。

## 4. 标准工作流

### 4.1 本地开发工作流

1. 启动本地 Supabase：

```bash
pnpm run supabase:start
```

2. 创建新 migration：

```bash
pnpm exec supabase migration new <change_name>
```

3. 编写 SQL。

4. 本地重建验证：

```bash
pnpm exec supabase db reset
```

5. 如需查看本地状态：

```bash
pnpm exec supabase status
```

说明：
- 本规范默认使用 CLI 的本地默认行为，文档中省略 `--local`。
- 若你希望显式表达本地目标，使用 `--local` 也允许。

### 4.2 使用 Dashboard 改表后的补录流程

官方允许先在 Dashboard 操作，再用 CLI 生成差异，但本项目仍然推荐直接写 migration SQL。

允许的补录流程：
1. 在本地 Dashboard 或隔离 branch 做结构修改。
2. 生成迁移草稿：

```bash
pnpm exec supabase db diff -f <change_name>
```

3. 人工审查生成的 SQL。
4. 再次执行 `pnpm exec supabase db reset` 验证。

约束：
- 不直接提交未经审查的 `db diff` 产物。
- 一次 migration 应聚焦单个增量变更，避免把无关 diff 混在一起。

### 4.3 远端同步与部署

远端发布前必须先 `link`：

```bash
pnpm exec supabase link --project-ref <project_ref>
```

部署 migration：

```bash
pnpm run supabase:db:push
```

如需同时执行 SQL seed：

```bash
pnpm exec supabase db push --include-seed --linked --yes
```

适用场景：
- staging 初始化
- preview/staging 补充演示数据
- 明确需要把 SQL seed 同步到远端时

### 4.4 远端库被手工改动后的回收流程

如果有人在远端 Dashboard、SQL Editor、branch 环境直接改了 schema，必须把变化回收到代码库：

```bash
pnpm exec supabase db pull
```

或在需要明确目标时使用：

```bash
pnpm exec supabase db pull --linked
```

然后：
1. 审查生成结果
2. 清理不需要提交的噪音
3. 提交 migration

规则：
- 不允许远端 schema 长期领先于仓库 migration。
- 远端手工改动如果不回收，后续 `db push` 会持续制造不可预测差异。

## 5. Migration 规范

- 命名要表达单一意图，如 `add_report_status_log`、`fix_storage_rls_path`。
- 一次 migration 聚焦一个主题，避免把表结构、RLS、补数据、临时修复混成一个大文件。
- 新增列优先追加到表尾，减少 diff 噪音。
- 所有对象名、约束名、索引名、policy 名保持稳定、可读、可搜索。
- migration 必须可以从空库完整回放。
- 依赖扩展、函数、枚举时，顺序必须自洽。

禁止项：
- 禁止修改历史 migration 以“伪装没有变更”
- 禁止把本地调试 SQL 直接提交为正式迁移
- 禁止把需要人工前置步骤的 SQL 当成标准 migration

## 6. SQL Seed 规范

- SQL seed 只放“数据”，不放“结构”。
- 必须幂等，优先使用 `insert ... on conflict do update` 或 `do nothing`。
- 文件拆分按数据域组织，不按个人临时用途组织。
- 多文件执行顺序必须稳定；当前仓库使用 glob 时按字典序执行。
- 测试专用数据不要进入公共 seed。

推荐命名：

```text
supabase/seed/
  01_base.sql
  02_lookup_tables.sql
  90_demo.sql
```

## 7. `seed.ts` 规范

`seed.ts` 只处理以下类型的数据：
- Auth 用户
- 依赖 Admin API 的初始化
- 必须用代码判断后再执行的幂等逻辑

规则：
- 必须通过 `supabase.auth.admin.*` 操作 Auth 用户。
- 必须先查后建或使用可重复执行的更新逻辑。
- 对应业务表的映射写入必须幂等。
- 失败时必须非零退出，并打印可定位错误。

本仓库当前口径：
- 统一通过 `pnpm run seed:auth` 执行。
- 当前实现实际读取 `NEXT_PUBLIC_SUPABASE_URL` 与 `SUPABASE_SERVICE_ROLE_KEY`。
- Auth 用户写入路径以 `docs/DECISIONS.md` 的 `D-014` 为准。

## 8. 本仓库命令约定

本地开发：

```bash
pnpm run supabase:start
pnpm exec supabase db reset
pnpm exec supabase migration new <change_name>
pnpm exec supabase status
```

远端部署：

```bash
pnpm run supabase:db:push
pnpm exec supabase db push --include-seed --linked --yes
pnpm exec supabase migration list --linked
```

项目补充初始化：

```bash
pnpm run seed:auth
pnpm run db:init
```

说明：
- `pnpm run db:init` 是当前仓库的远端初始化脚本，不是本地开发默认入口。
- 本地开发默认仍以 `supabase start` + `db reset` 为主。

## 9. 环境变量与安全

- 不在仓库中提交真实密钥。
- 敏感值优先放 `.env`，并在 `config.toml` 中通过 `env()` 引用。
- `SUPABASE_SERVICE_ROLE_KEY` 仅允许用于服务端脚本、受控初始化脚本与 CI Secret。
- 默认测试账号仅允许开发/测试环境使用。
- 在不可信网络中运行本地栈时，按官方建议绑定到 `127.0.0.1`，不要把本地 Supabase 暴露到公网。

## 10. Branching 与 CI/CD

- 如启用 Supabase Branching：
  - preview branch 用于 PR 预览与隔离测试
  - persistent branch 用于 staging / QA
  - 新 branch 默认不带生产数据，需要依赖 seed 补数

- 生产发布优先：
  - Supabase GitHub integration
  - 或自建 CI/CD 调用 Supabase CLI

- 不推荐把“开发者本机手动 `db push` 到 production”作为长期正式流程。

## 11. 禁止清单

- 禁止把远端项目当默认开发数据库。
- 禁止只改 Dashboard 不提交 migration。
- 禁止在 migration 中塞 seed 数据。
- 禁止通过 SQL 直接写 `auth.users`。
- 禁止修改历史 migration 来适配当前库状态。
- 禁止让远端 schema 漂移而不执行 `db pull` 回收。

## 12. 参考

- Local Development & CLI：
  `https://supabase.com/docs/guides/local-development`
- Database Migrations：
  `https://supabase.com/docs/guides/deployment/database-migrations`
- Seeding your database：
  `https://supabase.com/docs/guides/local-development/seeding-your-database`
- Managing config and secrets：
  `https://supabase.com/docs/guides/local-development/managing-config`
- Managing Environments：
  `https://supabase.com/docs/guides/deployment/managing-environments`
- Deployment & Branching：
  `https://supabase.com/docs/guides/deployment`
- Branching：
  `https://supabase.com/docs/guides/deployment/branching`
