# Supabase CLI 开发手册

数据库版本管理规则以 `supabase/SUPABASE_DB_VERSIONING.md` 为准；本文件只保留当前仓库的日常命令和最短操作路径。

## 1. 当前口径

- 默认开发环境是本地 Supabase，不是远端 linked project。
- 数据库结构变更统一进入 `supabase/migrations/`。
- SQL seed 由 `supabase/config.toml` 的 `[db.seed].sql_paths` 控制。
- `supabase/seed.ts` 只做 Auth / 程序化初始化。
- `scripts/db-init.sh` 与 `pnpm run db:init` 是远端初始化脚本，不是本地开发默认入口。

## 2. 目录速览

```text
supabase/
  config.toml
  migrations/
  seed/
  seed.ts
```

## 3. 前置准备

1. 安装 Supabase CLI，并确认可用：

```bash
supabase --version
```

2. 启动本地容器环境前，确保 Docker / Podman 类运行时可用。

3. 如需操作远端项目，先执行：

```bash
pnpm exec supabase link --project-ref <project_ref>
```

4. 远端初始化脚本默认会尝试从 `web/.env` 读取：
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`

5. 若使用远端推送，`supabase/supabase_access.token` 可作为 `SUPABASE_ACCESS_TOKEN` 来源。

## 4. 本地开发工作流

1. 启动本地 Supabase：

```bash
pnpm run supabase:start
```

2. 新建 migration：

```bash
pnpm exec supabase migration new <change_name>
```

3. 编写 `supabase/migrations/*.sql`。

4. 本地重建验证：

```bash
pnpm exec supabase db reset
```

5. 查看本地状态：

```bash
pnpm exec supabase status
```

6. 停止本地环境：

```bash
pnpm run supabase:stop
```

## 5. 远端同步工作流

推送 migration：

```bash
pnpm run supabase:db:push
```

推送 migration + SQL seed：

```bash
pnpm exec supabase db push --include-seed --linked --yes
```

查看远端迁移状态：

```bash
pnpm exec supabase migration list --linked
```

若远端被手工改过，需要先回收差异：

```bash
pnpm exec supabase db pull --linked
```

## 6. 数据初始化

本地数据库重建时：

```bash
pnpm exec supabase db reset
```

说明：
- 该命令会重放 migration。
- 若 `[db.seed]` 启用且匹配到 SQL 文件，会执行 SQL seed。

Auth / 程序化初始化：

```bash
pnpm run seed:auth
```

远端一键初始化：

```bash
pnpm run db:init
```

说明：
- `db:init` 当前会执行远端 `db push --linked --include-seed --yes`，随后执行 `seed:auth`。
- 不要把 `db:init` 当成本地开发默认流程。

## 7. 常用命令速查

```bash
# 本地
pnpm run supabase:start
pnpm run supabase:stop
pnpm exec supabase status
pnpm exec supabase migration new <change_name>
pnpm exec supabase db reset

# 远端
pnpm run supabase:db:push
pnpm exec supabase db push --include-seed --linked --yes
pnpm exec supabase migration list --linked
pnpm exec supabase db pull --linked

# 初始化
pnpm run seed:auth
pnpm run db:init
```

## 8. 提交前检查

1. `migrations/` 是否只包含 schema / RLS / trigger / function 变更。
2. SQL seed 是否幂等。
3. `seed.ts` 是否仍然只通过 Admin API 处理 Auth 用户。
4. 是否至少成功执行过一次 `pnpm exec supabase db reset`。
5. 若改过远端库，是否已经执行 `db pull` 回收到仓库。

## 9. 回滚策略

- 已提交 migration 不回改，使用新 migration 修复。
- staging / production 问题优先追加修复迁移，不手工改库。
