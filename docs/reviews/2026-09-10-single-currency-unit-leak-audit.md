# 单币种隐藏单位失效点审查（2026-09-10）

用户报告：设置里已打开「单币种隐藏单位」，账本也确实只有一种货币，但界面上仍有多处显示
「单位：¥」「本位币 CNY」这类文字。本文件是**待确认的清单**，确认后再统一修复；本轮不改代码。

审查方式：六种独立搜索角度并行扫描 → 按文件分组逐条证伪 → 补漏复查。
共确认 **17 处泄漏**（含用户报告的 7 处）、**3 处待产品决策**、**30 余处确认干净**。

> **整改已落地（2026-09-10）**：本清单全部修复，含第 4 节三处元信息（用户确认「单币种账本
> 下不该出现任何币种字样」）。落地做法与后续新增位置的约束见
> [组件清单 §维护约定](../dev/components.md) 与 [设计规范](../design-system.md)。
> 账本列表行尾的币种改为「只有一个账本时不显示、多账本才显示」——单一账本没有可比较的
> 对象，多账本时它承担区分口径的作用，因此没有沿用账本级的单币种闸门。

---

## 1. 根因

隐藏开关的唯一闸门是 [amount_format.dart](../../lib/app/amount_format.dart) 的：

```dart
MoneyCodeDisplay get activeMoneyCodeDisplay =>
    hideUnitInSingleCurrency && !activeBookUsesMultipleCurrencies
    ? MoneyCodeDisplay.none : preferredMoneyCodeDisplay;
```

以及 [currency_math.dart](../../lib/app/currency_math.dart) 的 `formatUserMoney` / `formatSignedUserMoney`
（默认走上面这个闸门，只有 `forceUnit: true` 才强制显示单位）。

**问题不是「某几处忘了加判断」，而是闸门只存在于「格式化函数」里，不存在于「给用户看的文字」这一层。**
一共有三条绕过路径：

| 绕过路径 | 位置 | 为什么漏 |
| --- | --- | --- |
| ① `displayCurrencyUnit()` | [currency_math.dart:101](../../lib/app/currency_math.dart#L101) | 永远返回单位文本，完全不读 `activeMoneyCodeDisplay` |
| ② `MoneyUnitLabel` widget | [common_widgets_display.dart:196](../../lib/app/common_widgets_display.dart#L196) | 内部调 ① |
| ③ `formatMoney()` 的默认参数 | [currency_math.dart:52](../../lib/app/currency_math.dart#L52) | `display` 默认值就是 `MoneyCodeDisplay.code`。调用方写的是看起来中性的 `formatMoney(v, code)`，实际语义却是「强制显示单位」。最隐蔽 |

④ 还有一类 helper 管不到的：直接渲染 model 字段（`book.baseCurrencyCode`、`rule.currencyCode`）。

页头副标题是纯字符串手拼，不受任何 widget 级封装约束，所以「扫 widget 调用点」发现不了——同一个模板在 7 个页面抄了 7 遍。

---

## 2. 你报告的位置（7/7 全部确认）

| 你的编号 | 界面 | 位置 |
| --- | --- | --- |
| 1.1 | 首页页头「我的账本 · 单位：¥」 | [home_page.dart:192](../../lib/pages/home_page.dart#L192) |
| 1.2 | 首页预算卡右上角「单位：¥」 | [home_page.dart:737](../../lib/pages/home_page.dart#L737) |
| 1.3 | 首页日历卡右下角「单位：¥」 | [common_widgets_panels.dart:543](../../lib/app/common_widgets_panels.dart#L543) |
| 1.4 | 资产页页头「本位币 ¥」 | [assets_pages.dart:181](../../lib/pages/assets_pages.dart#L181) |
| 1.5 | 账户详情页页头「储蓄卡 · 单位：¥」 | [account_detail_page.dart:106](../../lib/pages/account_detail_page.dart#L106) |
| 1.6 | 看板页页头「预算与统计 · 单位：¥」 | [reports_page.dart:282](../../lib/pages/reports_page.dart#L282) |
| 1.7 | 预算页页头「2026年7月 · 单位：¥」 | [budget_pages.dart:136](../../lib/pages/budget_pages.dart#L136) |

---

## 3. 你没提到、但同样泄漏的位置

### A. 同一模板的其它页头（7 处）

| 界面 | 位置 |
| --- | --- |
| 预算历史页页头「近12个月 · 单位：¥」 | [budget_pages.dart:594](../../lib/pages/budget_pages.dart#L594) |
| 预算设置页页头「我的账本 · 单位：¥」 | [budget_settings_page.dart:105](../../lib/pages/budget_settings_page.dart#L105) |
| 统计分析页页头「2026年9月 · 单位：¥」 | [report_analysis_page.dart:81](../../lib/pages/report_analysis_page.dart#L81) |
| 交易明细页页头（按日模式「9月10日 · 单位：¥」／普通模式只有「单位：¥」，两个分支都漏） | [transactions_pages.dart:355](../../lib/pages/transactions_pages.dart#L355) |
| 账户报告页页头「招商银行 · 单位：¥」 | [account_detail_page.dart:986](../../lib/pages/account_detail_page.dart#L986) |
| 收支统计二级页页头「单位：¥」 | [home_page.dart:947](../../lib/pages/home_page.dart#L947) |
| AI 结果卡片标题右侧「单位：¥」 | [ai_result_view.dart:47](../../lib/pages/ai_result_view.dart#L47) |

> `budget_settings_page.dart` 是 `part of 'budget_pages.dart'`，按「文件名」扫描会整文件跳过——这也是它和下面几处容易被漏的原因。

**AI 结果卡片额外说明**：一个回答里出现几张卡就重复几次「单位：¥」，而且排行榜／走势／交易筛选**无数据的空态卡片里一个数字都没有，标题右边照样写着「单位：¥」**。

### B. 金额旁的重复单位（3 处，形态和你报的不同）

| 现象 | 位置 |
| --- | --- |
| 同币种转账的副行显示「**100 ¥ → 100 ¥**」，而同一行主金额是「100」 | [common_widgets_transactions.dart:92](../../lib/app/common_widgets_transactions.dart#L92) |
| 打开设置里的「显示逐笔结余」后，每行副行显示「**余额 970 ¥**」，主金额是「-30」 | [common_widgets_transactions.dart:132](../../lib/app/common_widgets_transactions.dart#L132) |
| 退款面板里「**账户实际到账 100 ¥**」「**本位币冲抵额 100 ¥**」，同屏顶部大金额是「+100」 | [common_widgets_display.dart:187](../../lib/app/common_widgets_display.dart#L187) → [refund_editor.dart:727](../../lib/pages/refund_editor.dart#L727) / [:735](../../lib/pages/refund_editor.dart#L735) |

第 1 条的成因：转账分支的守卫只判断两端金额非空，**漏了币种比较**；同文件里非转账分支反而有 `fromAccount.currencyCode != entry.currencyCode` 守卫，口径本应一致。

### C. AI 对话页（隐藏较深）

展开 AI 回答的「步骤条」后，结果摘要整句带 ISO 代码：

- 「2026年8月 收入 CNY 12000.00（3 笔），支出 CNY 4300.00（12 笔），净额 CNY 7700.00。」— [ai_query_tool.dart:503](../../lib/app/ai/ai_query_tool.dart#L503)
- 「2026-7-3 转账 CNY 100 → CNY 100」— [ai_query_tool.dart:788](../../lib/app/ai/ai_query_tool.dart#L788)
- 「共 4 个账户：现金 1000 CNY；储蓄卡 5200 CNY。」— [ai_query_tool.dart:1083](../../lib/app/ai/ai_query_tool.dart#L1083)（手拼字符串，连 `formatMoney` 都没走）
- 「招商信用卡 当前欠款 1000 CNY」— [ai_query_tool.dart:1220](../../lib/app/ai/ai_query_tool.dart#L1220)

**另有一层**：提示词明确告诉模型「统计和筛选金额统一使用账本本位币 `{code}`」（[ai_prompt_tool_protocol.dart:121](../../lib/app/ai/ai_prompt_tool_protocol.dart#L121)）。就算把 UI 侧三条绕过路径全修好，**AI 的回答正文里仍会被诱导写出「合计 CNY 4,300」**。这一层属于单独的改动，见第 6 节。

---

## 4. 需要你决定的两处（元信息，不是「金额旁的单位」）

这三处显示币种**不是**在金额旁边重复，而是「这个入口通往哪个币种设置」的元信息。代码里没有任何注释说明是有意还是遗漏，从实现看不出意图，请你定：

| 界面 | 现象 | 位置 |
| --- | --- | --- |
| 「我的」→「货币与汇率」宫格 | 图标下方小字显示「CNY」 | [profile_pages.dart:275](../../lib/pages/profile_pages.dart#L275) |
| 「我的」→「账本」列表 | 每行「默认账本 · 12 笔交易 · **CNY**」 | [ledger_books_page.dart:130](../../lib/pages/ledger_books_page.dart#L130) |
| AI 对话页「账户余额」卡片 | 三列表格「账户 / **币种** / 余额」，单币种下每行「币种」格都印 CNY | [ai_query_tool.dart:1100](../../lib/app/ai/ai_query_tool.dart#L1100) |

---

## 5. 判定为「有意保留」、本轮不要动

| 保留项 | 理由 |
| --- | --- |
| 记账页／交易详情页／周期规则页的「交易币种」行 | 用户手动选币种的回显，点它能改；是控件不是标签 |
| 9 处带币种守卫的 `forceUnit: true`（跨币种换算字段） | 只在真正出现第二个币种时渲染，届时闸门本来就会打开 |
| 汇率等式、货币选择器、货币与汇率页、入门引导的本位币行 | 界面主题就是币种 |
| 导入 CSV 表头的「币种／本位币金额／账户币种」 | 列名，不是单位标签 |
| `refundBaseAmountLabel`「本位币冲抵额」等字段名 | 表单字段标题 |
| 缺汇率时的提示文案 | 只在多币种/缺汇率时出现 |

**已逐个查过、确认干净的面**（不在这份清单里，说明没问题）：
桌面小组件（原生侧 + Flutter 侧）、本地通知、图表坐标轴、图表 tooltip 与无障碍播报、
CSV 导出、设置页的「货币单位样式」选项、导入预览页头、资产显示设置页预览。

---

## 6. 修复思路（待确认）

目标不是「11 处页头各加一个 `if`」——那样下一个新页面照样漏。建议**加统一入口**：

1. **`currency_math.dart` 加一个「过闸的单位文本」helper**
   隐藏时返回空串／null，让页头副标题去拼。页头再抽一个「上下文标签 + 可选单位」的小 helper，
   一次消除 11 处重复拼接。

2. **`MoneyUnitLabel` 内部短路**
   `activeMoneyCodeDisplay == MoneyCodeDisplay.none` 时 `return const SizedBox.shrink()`。
   **一处改动解决卡片组全部 5 个渲染点**（首页预算卡、首页日历卡、AI 结果卡、走势卡及其设置页预览）。
   该组件只有 `currencyCode` 一个有效入参（`color` 无调用点传入），内部收口是安全的。

3. **C 组按币种守卫收口**，与同文件已有口径一致：
   - 转账副行补 `from.currencyCode != to.currencyCode`
   - 逐笔结余去掉 `forceUnit: true`
   - `CurrencyAmountField` **加可选参数**，只在退款面板两处传 `false`

   > ⚠️ **不要改 `CurrencyAmountField` 的默认值**。记账页／交易详情页／周期规则页允许用币种选择器临时选一个账本里还没有的币种，此刻闸门是关的但界面已同时出现两个币种的换算字段，单位必须保留。改默认值会误伤这些草稿场景。

4. **AI 摘要收口**：`_baseMoney` 与手拼的字符串统一走同一个出口。
   **提示词那层（是否只在多币种账本时才注入币种代码）单独议**，不混在这一批里。

### 连带影响（必须一起处理）

- ~~[test/panels_test.dart:26](../../test/panels_test.dart#L26) / [:63](../../test/panels_test.dart#L63) 拿 `MoneyUnitLabel` 当「首页走势卡渲染出来了」的探针，
  组件短路后这两个断言会失败~~ —— **实际未发生**：短路是让 widget 内部返回 `SizedBox.shrink()`，
  `MoneyUnitLabel` 仍在树上，`find.byType` 照旧命中，无需改锚点（代价是这个探针不再能区分渲染与否）。
- 需补**双向**测试：单币种 + 开关打开时断言这些位置不出现单位；**多币种账本下断言单位仍在**（防止收口过度）。
- `docs/dev/components.md` 登记新 helper；`docs/design-system.md` 补一句「单位只在多币种下显示」。

### 一处需要说明的实现细节

[home_page.dart:445](../../lib/pages/home_page.dart#L445)（首页走势卡右上角）**只在未开启 `UNIFIED_DESIGN_PREVIEW` 的旧外观下**显示单位；
你手机上的正式包这里渲染的是「周／月／季／年」标签，所以你没能看到它。它仍应一并收口，以免两套外观行为不一致。

### 验证方式

`flutter analyze` + `flutter test`（含新增双向测试）+ 393×852 widget 布局测试；
真机用 `--flavor diagnostic` 复看，发布外观需带 `--dart-define=UNIFIED_DESIGN_PREVIEW=true`。
