# 标题规范

## 业务背景

本规范仅适用于 **Company 类报告**。

报告有四种版本，标题语言要求取决于目标读者：

| 版本 | 撰写语言 | 目标读者 | 标题语言要求 |
|------|---------|---------|------------|
| 中文原版 | 中文 | 国内客户为主，兼顾海外客户 | 中文 + 英文 |
| 英文原版 | 英文 | 海外客户 | 英文 |
| 中文翻译版 | 中文 | 国内客户 | 中文 |
| 英文翻译版 | 英文 | 海外客户 | 英文 |

本规范据此分为两类：
- **简单情况**：英文版和翻译版，目标读者单一，标题只需一种语言。
- **复杂情况**：分析师用中文撰写，但要照顾海外客户（因为可能没有英文翻译版），所以标题必须同时包含中英文信息。

同样，中文原版的报告正文末尾还需提供 EN summary，方便海外客户阅读。其他版本不需要。

## 简单情况

- 只需照顾单一语言的客户，比如：英文原版，中文翻译版，英文翻译版。
- 标题分三部分：公司标识，标题内容，首次覆盖/变动标注

### 格式与示例

| 语言 | 类型 | 格式 | 示例 |
|------|------|------|------|
| 中文 | 首次覆盖 | `公司标识：首次覆盖：中文标题` | 西锐飞机 (2507 HK)：首次覆盖：安全、创新与强大生态系统铸就西锐私人航空全球领导者地位 |
| 中文 | 非首次覆盖 | `公司标识：中文标题 — 中文变动标注` | 西锐飞机 (2507 HK)：安全、创新与强大生态系统铸就西锐私人航空全球领导者地位 — 维持优于大市; 上调目标价 24% |
| 英文 | 首次覆盖 | `公司标识：英文标题 : Initiation` | Cirrus Aircraft (2507 HK)：Global Leader in Private Aviation: Dominating Personal Aviation with Safety, Innovation, and a Robust Ecosystem : Initiation |
| 英文 | 非首次覆盖 | `公司标识：英文标题 — 英文变动标注` | Cirrus Aircraft (2507 HK)：Global Leader in Private Aviation: Dominating Personal Aviation with Safety, Innovation, and a Robust Ecosystem — Maintain OP & Raise TP by 24% |

### 公司标识

| 中文 | 英文 |
|------|------|
| 公司中文名 (ticker)，没有中文名的话用英文名 | 公司英文名 (ticker) |
| 示例：西锐飞机 (2507 HK) | 示例：Cirrus Aircraft (2507 HK) |

注：ticker（股票代码含交易所后缀，如 `2507 HK`）用圆括号包裹。


### 首次覆盖/变动标注

- 首次覆盖时，标注首次覆盖评级。
  - 中文放标题前：`首次覆盖：`
  - 英文放标题后：`: Initiation`

- 非首次覆盖时，标注评级和目标价的变动。目标价无变动时只显示评级变动，两者都变动时中文用 `;` 拼接、英文用 `&` 拼接。
  - 中文示例：`— 维持优于大市; 上调目标价 5%`
  - 英文示例：`— Maintain OP & Raise TP by 5%`

**评级变动**：取同一coverage最近一次已发布报告的 Rating，对比本次Rating。

| 上次评级 | 本次评级 | 中文 | 英文 |
|---------|---------|------|------|
| 无 | OUTPERFORM | 首次覆盖优于大市 | Initiate with OUTPERFORM |
| 无 | NEUTRAL | 首次覆盖维持中性 | Initiate with NEUTRAL |
| 无 | UNDERPERFORM | 首次覆盖弱于大市 | Initiate with UNDERPERFORM |
| OUTPERFORM | OUTPERFORM | 维持优于大市 | Maintain OP |
| NEUTRAL | NEUTRAL | 维持中性 | Maintain Neutral |
| UNDERPERFORM | UNDERPERFORM | 维持弱于大市 | Maintain UP |
| NEUTRAL | OUTPERFORM | 上调至优于大市 | UG to OP |
| UNDERPERFORM | OUTPERFORM | 上调至优于大市 | UG to OP |
| UNDERPERFORM | NEUTRAL | 上调至中性 | UG to Neutral |
| OUTPERFORM | NEUTRAL | 下调至中性 | DG to Neutral |
| OUTPERFORM | UNDERPERFORM | 下调至弱于大市 | DG to UP |
| NEUTRAL | UNDERPERFORM | 下调至弱于大市 | DG to UP |

**目标价变动**：`round((本次目标价 - 上次目标价) / 上次目标价 * 100)`

| 计算结果 | 中文 | 英文 |
|---------|------|------|
| >= 1 | 上调目标价 X% | Raise TP by X% |
| <= -1 | 下调目标价 X% | Cut TP by X% |
| 0（-1 < 变动 < 1）| （空，不显示） | （空，不显示） |

评级中英文对照

| 中文 | 英文 | 缩写 |
|------|------|------|
| 优于大市 | Outperform | OP |
| 中性 | Neutral | Neutral |
| 弱于大市 | Underperform | UP |


## 复杂情况（中文原版）

中文原版需要兼顾英文用户的需求,所以中英文信息都要有。

格式：`公司中文名 + 英文名 (ticker)：[首次覆盖：]中文标题 [— 中文变动标注]（EN title[: Initiation][ — 英文变动标注]）`

> 注：括号内的英文标题前可视情况加公司英文名前缀，如 `（Vertiv: EN title — Maintain OP）`。

首次覆盖示例:
西锐飞机 Cirrus Aircraft (2507 HK)：首次覆盖：安全、创新与强大生态系统铸就西锐私人航空全球领导者地位（Global Leader in Private Aviation: Dominating Personal Aviation with Safety, Innovation, and a Robust Ecosystem: Initiation）
非首次覆盖示例：
西锐飞机 Cirrus Aircraft (2507 HK)：安全、创新与强大生态系统铸就西锐私人航空全球领导者地位 — 维持优于大市; 上调目标价 24%（Global Leader in Private Aviation: Dominating Personal Aviation with Safety, Innovation, and a Robust Ecosystem — Maintain OP & Raise TP by 24%）


## 待确认
- [ ] 标题长度是否有限制？
