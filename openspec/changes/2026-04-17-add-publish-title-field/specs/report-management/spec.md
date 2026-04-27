# report-management - ADDED Requirements

## 新增需求

### 需求: System SHALL hide publish_title on report creation page
系统在 `/reports/new` 页面必须不展示 `publish_title` 字段。

#### 场景: Open create page
- **当** Analyst 打开 `/reports/new` 页面
- **那么** 系统必须不渲染 `publish_title` 字段

### 需求: System SHALL display read-only publish_title on report edit page
系统在 `/reports/{id}/edit` 页面必须展示 `publish_title` 为只读字段。

#### 场景: Open edit page with existing publish_title
- **当** Analyst 打开已保存过 `publish_title` 的报告编辑页
- **那么** 系统必须展示 `publish_title` 字段且不可编辑

#### 场景: Open edit page without publish_title
- **当** Analyst 打开尚未生成 `publish_title` 的报告编辑页（如草稿状态未触发生成）
- **那么** 系统可以展示为空或隐藏该字段
