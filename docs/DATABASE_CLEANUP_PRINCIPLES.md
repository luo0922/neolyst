# 数据库清理原则

从 neolyst 项目清理生产 schema dump 重建干净数据库的过程中总结的原则。

---

## 1. 自然键优先

- 有业务含义的字段做主键：region→code，analyst→email，rating→rank，report_type→report_type
- 没有自然键的才用 UUID（sector、coverage、report 等）
- 外键引用也跟着用自然键：contact_person 存 analyst.email 而非 UUID

## 2. 字段精简

- 每个字段必须回答"谁用、什么时候用"
- 不为假设的未来需求留字段
- 语义重叠的列合并：role + sort_order → author_order
- 冗余时间戳只保留一个：changed_at + created_at → 保留语义更准确的那个
- 文件名不需要单独列：原始文件名可存 snapshot_json，file_path 已足够定位文件

## 3. 函数/触发器最小化

- 只保留应用层无法替代的数据完整性保护（如 report 状态转换校验）
- 不做防御性重复校验：report 表已校验状态转换，status_log 不需要再重复校验
- 能用 RLS 解决的不用触发器：append-only 保护由 RLS 统一处理
- 能用 CHECK 约束解决的不用触发器
- 能用默认值解决的不用触发器（但 updated_at 保留触发器，因为 UPDATE 时需要动态刷新）

## 4. 索引精简

- 只保留唯一约束索引和高频查询索引
- 主键自动有索引，不重复建
- 组合索引的前缀覆盖：有 (report_id, version_no DESC) 就不需要单独的 (report_id)
- 条件索引要有明确的查询场景

## 5. 不需要的表直接砍

- 功能不需要就不建
- 例：report_push_log、chief_approve、rqc_approve 整个砍掉

## 6. 外键：只保留 CASCADE

- 只有 CASCADE 外键有实际价值：删除父记录时自动清理子记录
- RESTRICT 和 SET NULL 外键在软删除场景下无意义：被引用表用 is_active 标记，不会真正 DELETE
- 删除外键后，列注释改为"对应 xxx"的逻辑关联描述，保持语义清晰

## 7. CHECK 约束不重复

- 下游表的约束不重复上游已保证的值域：report_status_log 的 from/to_status 由 report 表触发器保证，无需重复 CHECK
- 只在数据写入点（最上游）做约束校验

## 8. 注释要准确

- 注释是给 LLM 看的，必须反映当前真实状态
- 改了结构必须同步改注释
- 删除了外键/触发器后，注释中去掉"由触发器强制"、"ON DELETE RESTRICT"等描述
- 过时的注释比没有注释更危险

## 9. RLS 最后统一加

- 表结构稳定后再一次性加 RLS
- 避免中途反复调整 RLS 策略
- RLS 承担部分原来由触发器实现的功能（如 append-only 保护、写入权限控制）

## 10. 每个对象都要过一遍

- 不信任原始 schema dump 中的任何对象
- 逐个审查"是否真的需要"
- 拿不准的先不加，等需要时再补
