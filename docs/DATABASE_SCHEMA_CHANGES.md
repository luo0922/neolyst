# 数据库 Schema 调整记录

> 基于 `neolyst_schema.sql`（生产库 pg_dump）重建本地干净数据库的完整调整记录。
> 调整原则详见 [DATABASE_CLEANUP_PRINCIPLES.md](./DATABASE_CLEANUP_PRINCIPLES.md)。

---

## 一、表级别调整

### 1.1 删除的表（3 张）

| 表 | 理由 |
|---|---|
| report_push_log | 报告推送到外部系统的日志，当前不需要 |
| chief_approve | 首席确认附件表，当前不需要 |
| rqc_approve | RQC 审批确认附件表，当前不需要 |

### 1.2 新增的表（6 张）

| 表 | 说明 |
|---|---|
| coverage | 公司覆盖（原 schema 已有，重新建表） |
| coverage_analyst | 覆盖-分析师关系 |
| report | 研究报告主表 |
| report_version | 报告版本快照 |
| report_analyst | 报告-分析师关系 |
| report_status_log | 报告状态变更日志 |

### 1.3 表重命名

| 原名 | 新名 | 理由 |
|------|------|------|
| template | report_template | 明确是"报告模板"，避免与其他模板概念混淆 |

---

## 二、列级别调整

### 2.1 删除的列

| 表 | 列 | 理由 |
|---|---|---|
| coverage | ads_conversion_factor | ADS 折算因子当前不使用 |
| coverage | is_duplicate | 重复标记当前不使用 |
| coverage | approved_by | 审批人字段当前不使用 |
| coverage | approved_at | 审批时间字段当前不使用 |
| coverage | index_code | 原由触发器自动填充，触发器已删除，字段不保留 |
| coverage_analyst | role | 与 sort_order 语义重叠，合并为 author_order |
| coverage_analyst | sort_order | 同上 |
| report_analyst | role | 同上 |
| report_analyst | sort_order | 同上 |
| report | certificate_confirmed | SFC 证书确认标记当前不使用 |
| report_version | word_file_name | 原始文件名不需要单独存储 |
| report_version | model_file_name | 同上 |
| report_version | pdf_file_name | 同上 |
| report_version | changed_at | 与 created_at 冗余，每次 INSERT 值相同 |
| report_status_log | created_at | 与 action_at 冗余，每次 INSERT 值相同 |

### 2.2 列重命名

| 表 | 原名 | 新名 | 理由 |
|---|---|---|---|
| coverage | english_full_name | english_name | 简化，"全称"无区分必要 |
| coverage | chinese_short_name | chinese_name | 简化，去掉冗余的"short"前缀 |
| coverage | traditional_chinese | traditional_chinese（保留原名） | 补齐 name 后缀 |
| report | contact_person_id | contact_person | 改为存储 analyst.email（自然键）而非 auth.users UUID |
| report_version | changed_by | created_by | 语义更准确：是"谁创建了这个版本" |

### 2.3 新增的列

| 表 | 列 | 类型 | 理由 |
|---|---|---|---|
| coverage_analyst | author_order | integer | 合并原 role + sort_order，表达第几作者（1=一作，2=二作...），无上限限制 |
| report_analyst | author_order | integer | 同上 |

### 2.4 类型变更

| 表 | 列 | 原类型 | 新类型 | 理由 |
|---|---|---|---|---|
| report | contact_person | uuid | text | 改为引用 analyst.email（自然键）而非 auth.users.id |

---

## 三、外键调整

### 3.1 删除的外键（14 个）

所有非 CASCADE 外键全部删除。理由：被引用的表（region、sector、analyst、coverage）均使用 `is_active` 软删除设计，不会真正 DELETE 行，RESTRICT/SET NULL 约束无实际作用。

| 表 | 列 | 原引用 | ON DELETE |
|---|---|---|---|
| analyst | region_code | region.code | SET NULL |
| sector | parent_id | sector.id | RESTRICT |
| coverage | sector_id | sector.id | RESTRICT |
| coverage | country_of_domicile | region.code | RESTRICT |
| coverage_analyst | analyst_email | analyst.email | RESTRICT |
| report | owner_user_id | auth.users.id | RESTRICT |
| report | coverage_id | coverage.id | SET NULL |
| report | sector_id | sector.id | SET NULL |
| report | published_by | auth.users.id | SET NULL |
| report | contact_person | analyst.email | SET NULL |
| report | region_code | region.code | SET NULL |
| report_analyst | analyst_email | analyst.email | RESTRICT |
| report_version | created_by | auth.users.id | RESTRICT |
| report_status_log | action_by | auth.users.id | RESTRICT |

### 3.2 保留的外键（4 个）

均为 CASCADE 删除，用于删除父记录时自动清理关联数据。

| 表 | 列 | 引用 | 用途 |
|---|---|---|---|
| coverage_analyst | coverage_id | coverage.id | 删公司时清理关联分析师 |
| report_analyst | report_id | report.id | 删报告时清理关联分析师 |
| report_version | report_id | report.id | 删报告时清理版本记录 |
| report_status_log | report_id | report.id | 删报告时清理状态日志 |

---

## 四、函数调整

### 4.1 删除的函数（5 个）

| 函数 | 原用途 | 删除理由 |
|---|---|---|
| prevent_update_delete_append_only | append-only 表的 UPDATE/DELETE 保护 | 改由 RLS 控制（report_version 和 report_status_log 禁止 UPDATE/DELETE） |
| report_enforce_owner_immutable | 禁止修改 report.owner_user_id | 应用层控制，数据完整性由业务逻辑保证 |
| report_status_log_enforce_transition | 校验状态日志的 from/to 合法性 | 与 report 表的 report_enforce_status_transition 重复 |
| set_coverage_index_code | 根据 country 自动设 index_code | index_code 列已删除 |
| validate_coverage_analyst_limit | 每公司最多 4 位分析师 | 取消了人数上限限制 |

### 4.2 保留的函数（5 个）

| 函数 | 用途 | 保留理由 |
|---|---|---|
| current_app_role | 从 JWT 读取当前用户角色 | RLS 策略依赖此函数 |
| set_updated_at_utc | 触发器自动刷新 updated_at | UPDATE 时需要动态取 now()，默认值只能覆盖 INSERT |
| validate_sector_hierarchy | 校验行业两级层级合法性 | 行业层级是数据完整性约束，应用层难以保证 |
| report_status_is_valid | 校验报告状态转换合法性 | 被多个触发器共享的校验逻辑 |
| report_enforce_status_transition | report 表状态转换校验触发器 | 核心业务规则，防止非法状态跳转 |

---

## 五、触发器调整

### 5.1 删除的触发器（5 个）

| 触发器 | 表 | 删除理由 |
|---|---|---|
| trg_report_version_no_update | report_version | append-only 保护改由 RLS 实现 |
| trg_report_status_log_no_update | report_status_log | 同上 |
| trg_report_status_log_transition | report_status_log | 与 report 表状态校验重复 |
| trg_report_owner_immutable | report | 应用层控制 |
| trg_coverage_set_index_code | coverage | index_code 列已删除 |
| trg_coverage_analyst_limit | coverage_analyst | 取消人数上限 |

### 5.2 保留的触发器（11 个）

| 触发器 | 表 | 用途 |
|---|---|---|
| trg_region_updated_at | region | 自动刷新 updated_at |
| trg_analyst_updated_at | analyst | 同上 |
| trg_sector_updated_at | sector | 同上 |
| trg_sector_hierarchy | sector | 校验行业层级合法性 |
| trg_report_type_updated_at | report_type | 自动刷新 updated_at |
| trg_template_updated_at | report_template | 同上 |
| trg_coverage_updated_at | coverage | 同上 |
| trg_coverage_analyst_updated_at | coverage_analyst | 同上 |
| trg_report_updated_at | report | 同上 |
| trg_report_status_transition | report | 校验状态转换合法性 |
| trg_report_analyst_updated_at | report_analyst | 自动刷新 updated_at |

---

## 六、索引调整

### 6.1 删除的索引（2 个）

| 索引 | 表 | 删除理由 |
|---|---|---|
| idx_report_status_log_action_at_desc | report_status_log | 按 report_id 查询已覆盖主要场景，按时间排序场景少 |
| idx_report_version_report | report_version | 被组合索引 idx_report_version_report_version_desc (report_id, version_no DESC) 前缀覆盖 |

---

## 七、CHECK 约束调整

### 7.1 删除的约束（3 个）

| 约束 | 表 | 删除理由 |
|---|---|---|
| report_status_log_from_check | report_status_log | from_status 的值域由 report 表的状态校验保证，无需重复 |
| report_status_log_to_check | report_status_log | 同上 |
| report_status_log_version_check | report_status_log | version_no 来源于 report.current_version_no，值域由 report 表约束保证 |

### 7.2 保留的约束（6 个）

| 约束 | 表 | 定义 | 用途 |
|---|---|---|---|
| report_status_check | report | status IN (draft/submitted/published/rejected) | 限定合法状态值 |
| report_version_no_check | report | current_version_no >= 0 | 版本号非负 |
| report_target_price_check | report | target_price > 0 OR NULL | 目标价合法性 |
| report_language_check | report | report_language IN (zh, en) OR NULL | 限定语言选项 |
| report_status_log_reason_required | report_status_log | to_status≠rejected OR reason 非空 | 驳回必须填原因 |
| report_version_no_check | report_version | version_no >= 1 | 版本号从 1 开始 |

---

## 八、RLS 策略（新增）

12 张表全部启用 RLS，共 31 条策略。按权限矩阵分为三组：

### 第一组：字典表（6 张）

region、analyst、sector、rating、report_type、report_template

| 操作 | admin | sa | analyst |
|------|-------|----|---------|
| SELECT | ✅ | ✅ | ✅ |
| INSERT/UPDATE/DELETE | ✅ | ❌ | ❌ |

### 第二组：覆盖（2 张）

coverage、coverage_analyst

| 操作 | admin | sa | analyst |
|------|-------|----|---------|
| SELECT | ✅ | ✅ | ✅ |
| INSERT | ✅ | ✅ | ✅ |
| UPDATE/DELETE | ✅ | ❌ | ❌ |

### 第三组：报告（4 张）

**report 主表：**

| 操作 | admin | sa | analyst |
|------|-------|----|---------|
| SELECT | ✅ 全部 | ✅ submitted/published/rejected | ✅ 仅自己的 |
| INSERT | ✅ | ❌ | ✅（owner_user_id = 自己） |
| UPDATE | ✅ | ❌ | ✅（自己的 + draft/submitted） |
| DELETE | ✅ | ❌ | ❌ |

**report_analyst、report_version：**

| 操作 | admin | sa | analyst |
|------|-------|----|---------|
| SELECT | ✅ 全部 | ✅ 可见的报告 | ✅ 自己的报告 |
| INSERT | ✅ | ❌ | ✅（自己的 + draft/submitted） |
| UPDATE/DELETE | ❌ | ❌ | ❌ |

**report_status_log：**

| 操作 | admin | sa | analyst |
|------|-------|----|---------|
| SELECT | ✅ 全部 | ✅ 可见的报告 | ✅ 自己的报告 |
| INSERT | ✅ 全量 | ✅ submitted/rejected → 其他 | ✅ draft → submitted（自己的） |
| UPDATE/DELETE | ❌ | ❌ | ❌ |

---

## 九、注释重写

全部 12 张表的表级注释和所有列的注释重写，主要改进：

1. 删除了对已删对象（触发器、外键）的引用
2. 每个外键关联字段改为"对应 xxx"的逻辑关联描述（FK 已删但语义关系仍需说明）
3. 补充了 CHECK 约束范围、唯一索引逻辑（如 lower/btrim）等细节
4. 修正了不准确的说法（如"最多 4 位分析师"、"不允许修改或删除"等）

---

## 十、最终数据库对象汇总

| 类型 | 数量 | 说明 |
|------|------|------|
| 表 | 12 | 6 字典表 + 2 覆盖表 + 4 报告表 |
| 函数 | 5 | 3 基础 + 2 报告状态 |
| 触发器 | 11 | 6 updated_at + 1 层级校验 + 1 状态校验 + 3 其他 |
| 索引 | 19 | 6 PK + 8 UNIQUE + 5 查询 |
| 约束 | 4 FK + 6 CHECK + 8 UNIQUE + 12 PK |  |
| RLS 策略 | 31 | 12 SELECT + 10 INSERT + 5 UPDATE + 4 DELETE |
