# publish-title-generation Specification

## Purpose
定义研究报告 `publish_title` 字段的自动生成逻辑：公司类（`company`）报告包含首次覆盖判定、评级变动映射和目标价变动百分比计算；其他类型报告（`sector`/`company_flash`/`sector_flash`/`common` 等）则直接复制 `title` 作为 `publish_title`。

## Requirements
### 需求: System SHALL generate publish_title for company-type reports
系统必须在保存公司类报告时自动生成 `publish_title` 字段。

#### 场景: 首次覆盖生成标题
- **当** Analyst 保存公司类报告（`report_type = 'company'`）且该 coverage 最近一次发布报告不存在
- **那么** 系统必须生成 `publish_title` 格式为：`公司简称 (股票代码)：首次覆盖：中文title（English Full Name：英文title）`
- **例如**：`威胜控股 (3393 HK)：首次覆盖：配网投资与AI算力双轮驱动（Wasion Holdings：Dual-Driven by...: Initiation）`

#### 场景: 非首次覆盖生成标题
- **当** Analyst 保存公司类报告且该 coverage 存在最近一次发布报告
- **那么** 系统必须生成 `publish_title`，格式为：`公司简称 (股票代码)：中文title—中文评级变动; 上调/下调目标价X%（English Full Name：英文title—英文评级变动 & Raise/Cut TP by X%）`

### 需求: System SHALL apply rating change mapping
系统必须根据当前评级与上一次发布报告评级的对比结果，按照以下映射表生成评级变动文本。

#### 场景: 维持评级（OUTPERFORM → OUTPERFORM）
- **当** `currentRating = OUTPERFORM` 且 `lastRating = OUTPERFORM`
- **那么** 中文评级变动 = `—维持优于大市`，英文评级变动 = `—Maintain OP`

#### 场景: 上调至优于大市（OUTPERFORM ← NEUTRAL/UNDERPERFORM）
- **当** `currentRating = OUTPERFORM` 且 `lastRating` 为 `NEUTRAL` 或 `UNDERPERFORM`
- **那么** 中文评级变动 = `—上调至优于大市`，英文评级变动 = `—UG to OP`

#### 场景: 上调至中性（NEUTRAL ← UNDERPERFORM）
- **当** `currentRating = NEUTRAL` 且 `lastRating = UNDERPERFORM`
- **那么** 中文评级变动 = `—上调至中性`，英文评级变动 = `—UG to NEUTRAL`

#### 场景: 维持中性（NEUTRAL → NEUTRAL）
- **当** `currentRating = NEUTRAL` 且 `lastRating = NEUTRAL`
- **那么** 中文评级变动 = `—维持中性`，英文评级变动 = `—Maintain NEUTRAL`

#### 场景: 下调至弱于大市（UNDERPERFORM ← OUTPERFORM/NEUTRAL）
- **当** `currentRating = UNDERPERFORM` 且 `lastRating` 为 `OUTPERFORM` 或 `NEUTRAL`
- **那么** 中文评级变动 = `—下调至弱于大市`，英文评级变动 = `—DG to UP`

#### 场景: 维持弱于大市（UNDERPERFORM → UNDERPERFORM）
- **当** `currentRating = UNDERPERFORM` 且 `lastRating = UNDERPERFORM`
- **那么** 中文评级变动 = `—维持弱于大市`，英文评级变动 = `—Maintain UP`

#### 场景: 当前评级为 Non-rated 时不处理
- **当** `currentRating = Non-rated`
- **那么** 评级变动部分必须为空字符串，`publish_title` 仅包含 `公司简称 (股票代码)：title（English Full Name：English Title）`

#### 场景: 上一次评级为 Non-rated 时视为首次覆盖
- **当** 上一次发布报告的评级为 `Non-rated`
- **那么** 系统必须忽略该记录，继续查找更早的发布报告（最近一次非 `Non-rated` 的发布报告）

### 需求: System SHALL calculate target price change percentage
系统必须计算当前目标价与上一次发布报告目标价的变动百分比。

#### 场景: 目标价上调
- **当** `currentTargetPrice > lastTargetPrice`
- **那么** 中文目标价变动 = `; 上调目标价X%`，英文目标价变动 = ` & Raise TP by X%`
- **计算公式**：`X = ROUND((currentTargetPrice - lastTargetPrice) / lastTargetPrice * 100, 1)`

#### 场景: 目标价下调
- **当** `currentTargetPrice < lastTargetPrice`
- **那么** 中文目标价变动 = `; 下调目标价X%`，英文目标价变动 = ` & Cut TP by X%`
- **计算公式**：`X = ROUND((lastTargetPrice - currentTargetPrice) / lastTargetPrice * 100, 1)`

#### 场景: 目标价不变
- **当** `currentTargetPrice = lastTargetPrice`
- **那么** 目标价变动部分必须为空字符串

#### 场景: 当前目标价为空时不处理
- **当** `currentTargetPrice` 为 `null`
- **那么** 目标价变动部分必须为空字符串

### 需求: System SHALL persist publish_title on report save
系统必须在报告保存时持久化 `publish_title` 到 `reports` 表。

#### 场景: 保存报告时生成 publish_title
- **当** Analyst 调用保存报告接口（`saveReportContentAction`）且报告为 `report_type = 'company'`
- **那么** 系统必须计算 `publish_title` 并写入 `reports.publish_title`
- **且** 该操作必须与报告内容保存在同一事务中

#### 场景: 非公司类报告 publish_title 等于 title
- **当** 报告的 `report_type` 不为 `company`（如 `sector`、`company_flash`、`sector_flash`、`common` 等）
- **那么** 系统必须将 `publish_title` 设置为与 `title` 完全相同的值
