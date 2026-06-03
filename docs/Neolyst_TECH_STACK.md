# 技术栈文档

本文档整理项目的技术选型与依赖。

---

## 1. 前端

### 1.1 框架与语言

| 类别 | 技术 | 版本 | 说明 |
|------|------|------|------|
| 框架 | Next.js (App Router) | ^16.1.6 | 唯一应用入口，支持 Server Components / Server Actions / Route Handlers |
| 语言 | TypeScript | ^5.9.3 | 类型安全 |
| UI 库 | React | ^19.2.4 | 组件化开发 |
| 包管理器 | pnpm | 10.29.3 | 高性能依赖管理 |

### 1.2 样式与 UI

| 类别 | 技术 | 版本 | 说明 |
|------|------|------|------|
| CSS 框架 | Tailwind CSS | ^4.1.18 | 原子化 CSS，与 PostCSS 集成 |
| 样式工具 | tailwind-merge + clsx | ^3.5.0 / ^2.1.1 | 条件类名合并 |
| 图标库 | lucide-react | ^0.574.0 | 轻量级图标 |
| 主题切换 | next-themes | ^0.4.6 | 支持亮/暗模式 |

### 1.3 编辑器与内容

| 类别 | 技术 | 版本 | 说明 |
|------|------|------|------|
| 富文本编辑 | Tiptap | ^3.20.0 | 报告正文编辑，支持 StarterKit + Placeholder |
| Markdown 编辑 | @uiw/react-md-editor | ^4.1.1 | 报告摘要编辑 |
| 唯一标识 | uuid | ^14.0.0 | 生成唯一 ID |

### 1.4 数据与验证

| 类别 | 技术 | 版本 | 说明 |
|------|------|------|------|
| 股票数据 | yahoo-finance2 | ^3.13.2 | 获取股票信息 |
| 表单验证 | Zod | ^4.3.6 | 类型安全的 schema 验证 |

### 1.5 前端构建配置

```javascript
// next.config.mjs 关键配置
{
  reactStrictMode: true,
  experimental: {
    serverActions: {
      bodySizeLimit: '50mb',  // 支持大文件上传
    },
  },
}
```

---

## 2. 后端 / 基础设施

### 2.1 Supabase 核心组件

| 组件 | 说明 | 配置 |
|------|------|------|
| Supabase Auth | 用户认证 (JWT + 刷新令牌) | JWT 有效期 3600s，支持刷新令牌轮换 |
| Supabase Postgres | 主数据库 | 版本 17，主键默认 uuid，时间字段用 `timestamptz` |
| PostgREST | RESTful API 层 | 自动生成 CRUD 接口，最大返回 1000 行 |
| Storage | 文件存储 | 文件大小限制 50MiB，桶：templates / reports |
| Realtime | 实时订阅 | 已启用（当前未使用） |
| Edge Functions | Edge Runtime | 已启用 Deno 2（当前未使用） |
| Analytics | 数据分析 | 使用 Postgres 后端 |
| Inbucket | 本地邮件测试 | 端口 54324（本地开发用） |

### 2.2 数据库配置

```toml
# supabase/config.toml 关键配置
[db]
port = 54322              # Postgres 端口
shadow_port = 54320       # 影子数据库端口
major_version = 17        # Postgres 版本
health_timeout = "2m"     # 健康检查超时

[db.pooler]
enabled = false
pool_mode = "transaction"  # 事务模式连接池
default_pool_size = 20    # 默认连接池大小
max_client_conn = 100      # 最大客户端连接数
```

### 2.3 权限与安全

| 层级 | 技术 | 说明 |
|------|------|------|
| 认证层 | Supabase Auth + @supabase/ssr | SSR cookies 方案，会话刷新 |
| 权限层 | RLS（行级安全）+ 应用层权限 | 双层防护，RLS 为最终裁判 |
| API 层 | Supabase PostgREST | 通过 RLS 策略控制数据访问 |
| 路由门禁 | proxy.ts | 会话刷新 + 轻量权限拦截 |

---

## 3. 开发工具

| 工具 | 版本 | 说明 |
|------|------|------|
| ESLint | ^8.57.1 | 代码 lint |
| Playwright | ^1.58.2 | E2E 测试 |
| Supabase CLI | ^2.76.8 | 本地开发 / 数据库迁移 |
| pg | ^8.18.0 | Postgres 客户端 |
| tsx | ^4.21.0 | TypeScript 执行器 |

---

## 4. 部署

### 4.1 Docker 配置

```dockerfile
# Dockerfile
FROM node:20-alpine
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@10.29.3 --activate
# ... 构建和运行配置
EXPOSE 3000
CMD ["pnpm", "start"]
```

### 4.2 构建参数（构建时注入）

| 参数 | 说明 |
|------|------|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase 项目 URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase 匿名密钥 |
| `S3_HOST` / `S3_REGION` | S3 兼容存储配置 |
| `S3_ACCESS_KEY` / `S3_SECRET_KEY` | S3 访问凭证 |

---

## 5. 服务器资源估算

### 5.1 Web 应用（AWS ECS）

| 资源 | 最小配置 | 推荐配置 | 说明 |
|------|----------|----------|------|
| CPU | 0.5 vCPU | 1 vCPU | Next.js SSR 较轻量 |
| 内存 | 512 MB | 1 GB | Node.js 运行时 |
| 实例数 | 1 | 2+ | 支持自动扩缩容 |
| 磁盘 | 10 GB | 20 GB | 应用代码 + 临时文件 |
| 带宽 | 1 Mbps | 5 Mbps | 视访问量调整 |

### 5.2 Supabase（自托管参考）

> 注：以下为单节点参考配置，生产环境建议使用 Supabase Cloud 或集群部署。

| 组件 | CPU | 内存 | 磁盘 | 说明 |
|------|-----|------|------|------|
| Postgres | 2 vCPU | 4 GB | 50 GB+ SSD | 数据库存储 |
| Storage API | 0.5 vCPU | 512 MB | - | 文件访问网关 |
| PostgREST | 0.5 vCPU | 256 MB | - | REST API 服务 |
| Auth | 0.5 vCPU | 512 MB | - | 认证服务 |
| Realtime | 1 vCPU | 1 GB | - | 实时订阅服务 |
| Studio | 0.5 vCPU | 256 MB | - | 管理后台 |
| **总计** | **~5 vCPU** | **~7 GB** | **50 GB+** | 单节点最小配置 |

### 5.3 存储估算

| 类型 | 初始估算 | 增长因子 | 说明 |
|------|----------|----------|------|
| 数据库 | 1 GB | +100 MB/月 | 报告数据 + 状态历史 |
| 文件存储 | 5 GB | +500 MB/月 | 模板 + 报告附件 |
| 日志 | - | - | 由 AWS CloudWatch 或 Supabase 管理 |

---

## 6. 技术边界（当前阶段不使用）

| 技术 | 状态 | 说明 |
|------|------|------|
| Edge Functions | 已启用但未使用 | 未来可考虑用于轻量 API |
| Realtime | 已启用但未使用 | 未来可考虑实时通知 |
| External OAuth | 已配置但未启用 | 未来可接入 Google/GitHub 登录 |
| MFA/TOTP | 已禁用 | 当前阶段不需要多因素认证 |
| Vector Storage | 已禁用 | 当前阶段不需要向量搜索 |

---

## 7. 核心架构原则

- Next.js 是唯一应用入口
- Supabase 承担认证、数据访问与数据权限兜底
- 路由门禁：`proxy.ts`（会话刷新 + 轻量权限拦截）
- 服务端鉴权事实源：`getUser()`
- 角色事实源：统一遵循 `docs/DECISIONS.md` 的 `D-003`

## 8. 目录结构

```
web/
├── app/          # 路由与页面
├── features/     # 业务模块
├── domain/       # 业务领域类型与纯规则
├── components/   # 基础 UI 组件
└── lib/          # 基础设施
```

## 9. 数据库规范

- 主键：默认 `uuid`
- 时间字段：`created_at` / `updated_at`，使用 `timestamptz`
- 外键：显式声明 `ON DELETE` 语义
- 唯一性：通过唯一约束或唯一索引在 DB 层保证
- 审计：关键流程使用 append-only 日志表（例如状态历史）
- 删除策略：优先逻辑删除或状态驱动

## 10. 相关文档

- 架构详情：[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- 需求总览：[docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)
- 数据模型：[docs/DATA_MODEL.md](docs/DATA_MODEL.md)
- 代码实现规范：[docs/LOGIC.md](docs/LOGIC.md)
- 长期决策：[docs/DECISIONS.md](docs/DECISIONS.md)