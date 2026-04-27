# report-review - ADDED Requirements

## 新增需求

### 需求: System SHALL display read-only publish_title on review page
系统在 `/report-review` 和 `/report-review/{id}` 页面必须展示 `publish_title` 为只读字段。

#### 场景: Review page displays publish_title
- **当** SA 或 Admin 打开 `/report-review/{id}` 审批详情页
- **那么** 系统必须展示该报告的 `publish_title` 且不可编辑
