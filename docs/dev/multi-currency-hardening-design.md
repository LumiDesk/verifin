# 多币种正确性加固与体验改进设计

> 状态：**设计完成，尚未实施**
>
> 审查基线：`main` @ `94eec0d`，Veri Fin `1.15.9+105`，SQLite schema v14
>
> 审查日期：2026-08-25

本文是 `multi-currency-design.md` 落地后的第二轮加固设计。首轮实现已经建立
“账本本位币 → 账户币种 → 交易原币”的三层金额模型；本轮不推翻该模型，而是修复它与
退款导入、历史交易编辑、旧金额格式化、预算输入、筛选排序、余额趋势、周期补记和
Android 小组件之间的接缝问题。

本文只描述待实施方案。凡与当前源码行为不同之处，均以“目标行为”标注；在代码、测试、
文档和 CHANGELOG 完成同步前，不得把本文中的目标行为当成当前事实。

## 1. 二次复核结论

### 1.1 原设计中已经成立、无需推翻的部分

以下核心设计经源码和现有测试复核后仍然成立：

- 汇率方向固定为 `1 外币 = X 本位币`；
- `exchangeRateAt` 只取交易日当天或更早的最近记录，不使用未来汇率；
- 普通收支分别保存原币 `amount`、账户真实金额 `accountAmount` 和冻结本位币
  `baseAmount`；
- 跨币转账保存两端实际金额，且 `baseAmount == 0`、不计入收支；
- 当前资产先算账户原币余额，再按目标日期汇率折算；缺任一必要汇率时不展示部分总额；
- 交易、附件、退款和“记住汇率”可在单个 repository 事务中原子保存；
- SQLite v14、模型 JSON/row 映射、迁移矩阵和仓储契约的主体结构完整。

因此，本轮不改三层金额字段语义，不批量重算历史交易，不接入在线汇率，也不增加新的
金额存储单位。

### 1.2 已确认缺陷

| ID | 问题 | 复核结论 | 风险 |
|---|---|---|---|
| MC-01 | 外币退款导入混用本位币、原币和账户币 | **成立**。`plan_builder` 仍先写旧式 `refundedBaseAmount` 缓存，`_migrateLegacyRefunds` 又把该本位币数值直接写成退款 `amount/accountAmount` | 账户余额和退款上限可能被直接写错 |
| MC-02 | 编辑历史交易日期会重算冻结金额 | **成立**。已有交易初始化后 `*_Touched` 均为 false，改日期会按新日期汇率重新生成 `accountAmount/baseAmount` | 历史实际扣款和统计口径被静默改变；缺率时还可能变成 0 |
| MC-03 | 聚合金额仍固定两位小数 | **成立**。旧 `formatAmount/isZeroAmount` 仍固定两位和 `0.005`，并被首页、预算、看板、统计和图表广泛调用 | KWD 等三位币种丢精度，`0.001 KWD` 可显示为 0；JPY 标准格式错误 |
| MC-04 | 预算、余额、额度和部分快速入口仍默认两位输入 | **成立**。若调用方未传 `maxFractionDigits`，数字键盘默认 2；预算落库也未按本位币规整 | KWD 不能输入合法三位金额，JPY 可留下非法小数 |
| MC-05 | 报销筛选比较不同币种 | **成立**。`refundedAmount` 已是本位币缓存别名，却与原币 `amount` 比较 | 外币支出会错误进入“待报销/已报销”状态 |
| MC-06 | 混币金额排序直接比较原币裸数字 | **成立**。列表按 `entry.amount` 排序 | 100 JPY、10 USD 等记录的顺序没有财务意义 |
| MC-07 | 自动识别直接比较不同币种的原币金额 | **成立**。`suggestEntry` 不接收当前币种，金额相似度直接使用历史 `entry.amount` | 同数字不同币种会互相污染分类、标签和备注建议 |
| MC-08 | 退款对余额的生效日期使用发起日 | **成立**。退款是否影响余额看 `settledAt`，但日/月余额序列仍按 `occurredAt` 分桶 | 余额曲线提前入账；跨月退款落入错误月份 |
| MC-09 | 有关联退款的支出仍可修改原币 | **成立**。UI 允许选择新币种，Controller 随后因退款币种不一致返回 false | 保存无反应且无明确原因，容易误以为应用故障 |
| MC-10 | 导入金额没有统一按目标币种 minor unit 规整 | **成立**。文件提供的 `amount/accountAmount/toAccountAmount/baseAmount` 可直接进入模型 | 导入可留下 UI 无法录入的亚最小单位金额，导致显示、比较和往返不一致 |

### 1.3 已确认的可解释性与系统联动缺口

以下问题不一定立即写错数据，但会显著降低多币种功能的可理解性：

| ID | 缺口 | 复核结论 |
|---|---|---|
| MC-11 | 录入页看不到实际使用的汇率生效日和陈旧状态 | `ConvertedCurrencyAmount` 已携带日期，但页面只取 `amount`，把日期元数据丢弃 |
| MC-12 | 缺汇率周期规则只在周期页面可见 | Controller 有 `dueRecurringMissingRates`，当前只有 `RecurringPage` 使用，根页无提示 |
| MC-13 | 汇率变化不立即刷新桌面资产小组件 | `pushWidgetData` 只在开屏、回前台和记账后调用，汇率保存/删除没有 invalidation 回调 |
| MC-14 | AI 的转账金额筛选/排序/摘要退化为 0 | AI 查询复用 `netBaseAmount`；转账的 `baseAmount` 按设计恒为 0 |

这些项目与 MC-01～MC-10 一并纳入本轮，但实现优先级低于数据正确性缺陷。

## 2. 根因归纳

问题并非汇率公式错误，而是以下四类边界没有完全收口：

1. **裸 `double` 脱离币种上下文**：旧格式化、零值判断、比较、输入和导入仍可只传数字；
2. **“字段是否被触碰”代替了金额权威来源**：页面不知道当前应保留冻结值、手工汇率还是汇率表结果；
3. **旧单币种兼容路径继续承担新多币种数据**：导入退款仍经过 `_migrateLegacyRefunds`；
4. **领域状态变化没有统一投影失效事件**：汇率、账本、账户和预算变化后，小组件和待处理提示各自漏刷新。

本轮方案应优先收口边界，避免在每个页面继续打独立补丁。

## 3. 目标与非目标

### 3.1 目标

1. 外币退款导入、历史交易编辑和报销筛选不再混用金额单位；
2. 所有用户可见金额、零值判断和金额输入遵循对应币种 minor unit；
3. 已保存交易的三层金额默认冻结，只有用户明确操作才重新换算；
4. 新建/编辑交易、退款、周期规则共享同一套金额依赖状态机；
5. 余额趋势使用真实资金生效日期，收支统计仍保持原支出日期口径；
6. 汇率来源、生效日期、陈旧状态和缺率阻塞都能被用户看见；
7. 汇率、账本、账户、预算或交易变化后，Android 小组件能及时刷新；
8. 通过共享校验器阻止导入/恢复把违反三层金额不变量的数据写入 SQLite。

### 3.2 非目标

- 不接在线汇率 API，不自动下载或后台刷新行情；
- 不做汇兑损益、外汇持仓成本或会计分录平衡；
- 不把 `double/SQLite REAL` 迁移为整数 minor units；
- 不允许一个普通账户持有多个币种；
- 不批量重算已有历史交易；
- 不在本轮给转账新增持久化的“统计本位币金额”；
- 不把退款加入通用交易时间线，该事项仍按 `known-limitations.md` L3 单独评估。

## 4. 统一金额边界

### 4.1 禁止新增无币种上下文的金额 API

本轮不修改 SQLite 模型字段，也不强行给所有领域模型套新的值对象；但所有跨模块边界必须显式
携带 `currencyCode`。新增或替换以下纯函数：

```dart
bool isZeroMoney(num value, String currencyCode);
double normalizeMoney(num value, String currencyCode);

String formatMoneyNumber(
  num value,
  String currencyCode, {
  CurrencyFractionStyle? style,
});

String formatExpenseMoney(
  num value,
  String currencyCode, {
  bool forceUnit = false,
});

String formatIncomeMoney(
  num value,
  String currencyCode, {
  bool forceUnit = false,
});

String formatSignedMoneyValue(
  num value,
  String currencyCode, {
  bool forceUnit = false,
});

String formatCompactMoney(
  AppLocalizations l10n,
  num value,
  String currencyCode,
);
```

已有 `normalizeCurrencyAmount`、`formatCurrencyNumber`、`formatUserMoney` 和
`formatSignedUserMoney` 可作为底层实现；新命名的目的不是复制算法，而是给现有页面提供
语义明确的替代入口。

`ledger_math.dart` 中的以下兼容入口在调用点迁移完成后删除，不再保留“默认两位”的隐式语义：

- `isZeroAmount`；
- `normalizeAmount`；
- `formatAmount`；
- `formatExpenseAmount`；
- `formatIncomeAmount`；
- `formatSignedAmount`；
- 旧签名 `formatCompactAmount`。

迁移期间若必须暂存兼容 wrapper，其签名也必须增加必填 `currencyCode`，避免新调用继续漏传。

### 4.2 金额数字键盘必须直接接收币种

把通用入口调整为：

```dart
Future<double?> showMoneyNumberPad({
  required BuildContext context,
  required String title,
  required String currencyCode,
  double? initialAmount,
  bool allowNegative = false,
  bool allowZero = false,
  double? maxAmount,
});

Future<double?> showRateNumberPad({
  required BuildContext context,
  required String title,
  double? initialRate,
});
```

- `showMoneyNumberPad` 内部从 `CurrencyCatalog.require(currencyCode).minorUnit`
  推导小数位；调用方不得再手写 `2`；
- `showRateNumberPad` 固定使用汇率精度规则，与货币金额分离；
- `NumberPadSheet.maxAmount` 的格式化和比较也使用同一币种容差，不再写死 `0.0001`；
- 快速记账入口根据“将传入详情页的默认账户”推导初始币种；若无默认账户则用账本本位币；
- 从账户详情发起记账、余额调整和信用额度编辑时直接使用账户币种；
- 预算、预算覆盖和 onboarding 预算使用账本本位币；
- 新建账户初始余额改用统一金额入口，或使用受 minor unit 限制的受控字段，不再裸写任意
  `TextFormField<double>`。

### 4.3 Controller 在持久化边界再次规整

UI 输入正确并不足以保护导入、恢复和未来调用点。以下 Controller API 在写入前必须按目标币种
再次 `normalizeCurrencyAmount`：

- 默认/月度/分类/每日预算：账本本位币；
- 账户初始余额、信用额度：账户币种；
- 余额调整目标值：账户币种；
- 导入交易四类金额：各自实际所属币种；
- 导入账户元数据和回推初始余额：账户币种。

该规整只消除亚最小单位尾差，不做汇率换算。

## 5. 共享交易金额草稿状态机

### 5.1 问题

当前 `EntryDetailPage`、`TransactionDetailPage`、`RefundSheet`、`RecurringPage` 和
`CreditRepaymentPage` 各自维护若干 `*_Touched` bool。同一个 bool 同时承担“用户编辑过”、
“这个字段是权威输入”和“日期变化时是否需要重算”三种职责，无法可靠表达已有交易的冻结状态。

### 5.2 新增纯 Dart 状态对象

新增 `lib/app/entry_currency_draft.dart`，不依赖 `BuildContext` 或 Controller：

```dart
enum CurrencyAmountAuthority {
  frozen,
  rateTable,
  manualRate,
  manualAccountAmount,
  manualBaseAmount,
  manualTransferTarget,
}

enum CurrencyDraftChange {
  originalAmount,
  originalCurrency,
  fromAccount,
  toAccount,
  occurredDate,
  manualRate,
  accountAmount,
  baseAmount,
  transferTargetAmount,
}

class EntryCurrencyDraft {
  // 原币、账户、本位币、转入金额、手续费、各币种、authority 与 conversion trace。
}
```

状态对象接收窄的换算回调，不直接读取 Controller：

```dart
typedef DraftCurrencyConverter = CurrencyConversionResult Function({
  required num amount,
  required String sourceCurrencyCode,
  required String targetCurrencyCode,
  required DateTime date,
});
```

页面只负责把用户事件转换为 `CurrencyDraftChange`，金额依赖、缺率集合、转换来源和展示 trace
由状态对象统一计算。退款和周期规则可复用同一内核，并在外围增加各自限制。

### 5.3 已保存交易的冻结规则

已有交易进入编辑页时，初始 authority 一律为 `frozen`，无论其
`conversionSource` 是 manual、rateTable、imported 还是 legacy。`conversionSource` 记录历史来源，
不表示打开编辑器后可以自动覆盖。

| 用户操作 | 目标行为 |
|---|---|
| 只改日期/时间、备注、分类、标签、待报销 | 三层金额完全不变 |
| 改来源账户，但原币不变 | `baseAmount` 保持冻结；新账户金额按交易日汇率生成，缺率时要求手工填写 |
| 改原币金额 | 默认按原交易各端金额比例缩放，保留历史结算比例；用户仍可逐项修正 |
| 改原币币种（无退款） | 清空相关手工权威状态，按交易日汇率生成新草稿并要求复核三层金额 |
| 改原币币种（已有退款） | 禁止，显示“已有退款，原币不可修改”；不允许进入必然保存失败的状态 |
| 点“按当前日期汇率重新计算” | authority 切到 `rateTable`，显式刷新相关金额并展示使用的汇率日期 |
| 编辑汇率 | authority 切到 `manualRate`，以后改原币金额时保持该手工汇率并同比缩放 |
| 编辑账户/本位币/转入实际金额 | 对应字段成为权威；其它字段只在语义明确时联动 |

新建交易仍可在用户没有手工修改换算字段时随日期、账户和原币变化自动刷新。

### 5.4 保存返回类型

把 `saveEntryAggregateDraft` 的 `bool` 返回升级为稳定的领域结果：

```dart
sealed class EntrySaveResult {}
final class EntrySaveSuccess extends EntrySaveResult {}
final class EntryValidationFailure extends EntrySaveResult {
  final EntryValidationCode code;
  final Set<String> currencyCodes;
}
final class EntryPersistenceFailure extends EntrySaveResult {}
```

至少覆盖：缺率、账户引用失效、退款币种不一致、退款超额、金额非正/非有限、转账端缺失、
本位币不一致。UI 按稳定 code 本地化，不显示底层异常，也不再出现“点保存没有反应”。

## 6. 外币退款导入修复

### 6.1 当前错误链路

当前链路是：

```text
RawImportRecord.refunded（原币）
  → plan_builder 按比例算 refundedBaseAmount（本位币）
  → 只把缓存写进原支出
  → applyImportEntries 调 _syncRefundData
  → _migrateLegacyRefunds 把本位币缓存当成退款 amount/accountAmount
```

该路径在单币种下数值相等，测试无法暴露；进入多币种后单位立即分裂。

### 6.2 目标链路

`plan_builder` 必须在 plan 阶段直接生成关联退款条目，不再把当前导入数据伪装成旧标量：

```text
RawImportRecord.refunded（原币）
  → 先生成完整 expense（三层金额）
  → ratio = refundedOriginal / expense.amount
  → 生成 settled refund：
      amount = expense.amount × ratio                 （原币）
      accountAmount = expense.accountAmount × ratio   （原账户币种）
      baseAmount = expense.baseAmount × ratio          （本位币）
  → 三个金额分别按各自币种 minor unit 规整
```

默认规则与旧单币种导入语义保持一致：

- 退款到账账户使用原支出账户；无账户支出生成无账户退款；
- 发起日和到账日使用来源记录日期；
- `conversionSource = imported`；
- 退款原币总额钳制到原支出原币金额；
- 原支出的 `refundedBaseAmount` 仍由最终已到账退款条目派生，不由 plan 任意提交。

### 6.3 ImportPlan 与预览约束

退款条目可以继续进入 `ImportPlan.entries`，但预览层需采用“根交易 + 关联条目”的选择模型：

- 普通列表只展示根交易，退款在对应支出行显示“含退款”摘要；
- 排除一笔原支出时自动排除它的退款；
- 保留原支出时关联退款必须随之保留，不能形成悬空 `refundOf`；
- 账户/分类映射同时改写退款引用；
- 编辑原支出导致金额低于退款总额时，进入明确校验状态，不能静默截断已在预览中确认的退款；
- 最终提交前以完整候选集合调用共享校验器。

### 6.4 旧标量迁移保底

`_migrateLegacyRefunds` 仍需兼容真正的 v1/旧 SQLite 数据，但不得再直接复制本位币数字。保底算法：

```text
ratio = refundedBaseAmount / baseAmount
refund.amount = amount × ratio
refund.accountAmount = accountAmount × ratio
refund.baseAmount = refundedBaseAmount
```

各端分别按自己的币种规整。若旧数据缺少必要账户币种或金额关系，记录隐私友好日志并拒绝
产生违反不变量的退款；不能猜 1:1。

## 7. 跨币种比较、排序与自动识别

### 7.1 报销筛选

全部使用本位币口径：

```dart
pending = entry.reimbursable &&
    !isZeroMoney(entry.netBaseAmount, book.baseCurrencyCode);

reimbursed = !isZeroMoney(
  entry.refundedBaseAmount,
  book.baseCurrencyCode,
);
```

`ReimbursementFilter.matches` 因此需接收 `baseCurrencyCode`，或由调用方传入已计算状态；不再读取
`refundedAmount` 兼容别名。

### 7.2 交易金额排序

增加只用于展示排序的纯函数，不修改收支口径：

```dart
double? comparableBookAmount(
  LedgerEntry entry, {
  required String baseCurrencyCode,
  required CurrencyConversionResult Function(...) convert,
});
```

- 支出：`netBaseAmount`；
- 收入：`baseAmount`；
- 转账：把转出端真实金额按交易日有效汇率临时折算为本位币；
- 缺率转账：排序到有值记录之后，再按日期和 id 保持稳定；
- 退款不进通用列表。

该折算只服务排序，不写回交易、不改变历史统计。筛选菜单在混币账本中把文案改为
“按本位币金额”。

### 7.3 自动识别

`suggestEntry` 增加 `currencyCode`：

- 金额相似度只在历史条目 `entry.currencyCode == currencyCode` 时参与；
- 备注相似度仍可跨币种工作，例如“星巴克”在 USD/CNY 交易中仍可提示同一分类；
- 跨币种历史不得因“数字相同”成为强匹配；
- 类型翻转仍只允许支出/收入，继续排除退款和转账。

### 7.4 AI 转账查询

AI 工具的收支汇总继续只认本位币冻结金额；但交易明细工具处理转账时：

- 摘要展示 `转出账户币种 amount → 转入账户币种 toAccountAmount`；
- `minAmount/maxAmount/sortBy=amount` 对转账复用 `comparableBookAmount`；
- 缺率时保留交易，摘要明确显示原币金额，不把它当 0；
- AI 工具仍只读，不保存为交易字段。

## 8. 余额趋势的双日期口径

增加纯函数：

```dart
DateTime accountEffectDate(LedgerEntry entry) {
  if (entry.type == EntryType.refund && entry.settledAt != null) {
    return entry.settledAt!;
  }
  return entry.occurredAt;
}
```

使用范围必须严格区分：

- **账户余额、账户余额趋势、净资产趋势**：用 `accountEffectDate`；
- **收支、预算、分类排行、原支出净额**：继续用原支出 `occurredAt`；
- **待到账退款**：`accountDeltaForEntry == 0`，不进入余额序列；
- **退款列表排序**：继续以到账日优先、待到账用发起日。

这样既保持“退款冲减原消费月份”的统计口径，又让现金账户曲线只在真实到账日增加。

## 9. 汇率可解释性与待处理状态

### 9.1 保留转换 trace

现有 `ConvertedCurrencyAmount` 已提供：

- `sourceRateToBase/targetRateToBase`；
- `sourceRateDate/targetRateDate`。

页面不得再只返回 `double amount`。`EntryCurrencyDraft` 保存最近一次转换 trace，并派生：

- 使用了哪些币种的哪一天汇率；
- 是否超过 30 个日历日；
- 当前金额来自汇率表、手工汇率、实际金额还是冻结历史；
- 是否存在缺率。

录入/编辑页的目标文案示例：

```text
计入账本：72.00 CNY
按 2026-08-20 的 USD 汇率换算 · 5 天前
```

陈旧时显示 warning，不阻止使用；用户仍可编辑实际金额或汇率。

### 9.2 资产估值 trace

扩展 `ConvertedAccountBalances`，增加每账户使用的汇率日期/陈旧状态，而不仅是最终金额：

```dart
final Map<String, AccountValuationTrace> tracesByAccountId;
```

资产总览至少展示“估值截至日期/最旧汇率”；存在超过 30 日汇率时提示可能过期，但仍展示完整总额。
缺率时维持当前 `completeTotal == null` 规则。

### 9.3 周期记账缺率提示

首页增加紧凑的待处理卡：

```text
2 条周期记账等待汇率
缺少 USD、JPY              [去处理]
```

- 点击进入周期记账页，并定位缺率规则；
- 汇率保存成功后若仍有到期规则，显示“补记到期交易”操作，不在汇率弹窗关闭时静默批量落账；
- 用户点击后调用现有 `applyDueRecurring(now)`，反馈补记数量；
- 失败不推进 `nextRunDate`，保留现有确定性 id 防重复。

## 10. 小组件投影失效机制

### 10.1 新增窄回调

Controller 不直接调用 Android Bridge。新增由根组件注入的窄回调：

```dart
VoidCallback? onWidgetProjectionInvalidated;
```

以下成功变更触发 invalidation：

- 新增、编辑、删除交易或退款；
- 余额调整、账户初始余额、计入资产、隐藏状态变化；
- 默认/月度/分类/每日预算变化；
- 汇率新增、编辑、删除；
- 活动账本切换、本位币确认/重解释；
- 金额单位显示偏好变化。

根组件收到回调后去抖并调用 `pushWidgetData`。Controller 只表达“投影失效”，不依赖平台文件或
小组件实现。

### 10.2 去抖与错误处理

- 连续批量操作在 250ms 内合并为一次推送；
- 推送失败由 `AppLogger` 记录，不影响已经成功的 SQLite/KV 保存；
- 应用退到后台前若有待推送任务，立即 flush；
- Android 原生侧继续保留跨日/跨预算周期自愈。

## 11. 共享数据校验器

新增纯函数 `validateLedgerDataSnapshot`，在以下入口共同使用：

- `saveEntryAggregateDraft`；
- `applyImportEntries` 最终确认；
- `importDataJson` 在替换现有数据之前；
- 测试仓储契约夹具。

校验至少覆盖：

1. 账本、账户、交易、周期规则、汇率 id 非空且同表唯一；
2. 所有跨实体引用存在且属于同一账本；
3. 币种代码受支持并统一大写；
4. 各金额有限、正负号合法，并已规整到所属币种 minor unit；
5. 支出/收入/退款 `baseAmount > 0`，转账 `baseAmount == 0`；
6. 无账户时 `accountAmount == null && fee == 0`；
7. 转账两端金额与账户引用完整，手续费属于转出账户币种；
8. 退款引用有效原支出、原币一致、原币累计不超额；
9. `refundedBaseAmount` 等于已到账退款本位币之和的钳制值；
10. 汇率本位币与账本一致、外币不等于本位币、同日键唯一；
11. 预算非负并按账本本位币 minor unit 规整。

导入/恢复校验失败时必须在任何持久化之前终止，保持现有内存和 SQLite 不变。

## 12. 实施顺序

### 阶段 0：先补回归测试

先写能在当前代码上失败的测试，锁定 MC-01～MC-10；此阶段不改生产行为。

### 阶段 1：数据正确性热修

1. `plan_builder` 直接生成三层金额退款；
2. `_migrateLegacyRefunds` 改为比例保底；
3. 报销筛选改用本位币；
4. 余额趋势改用 `accountEffectDate`；
5. 有退款时锁定原币并显示原因；
6. 导入金额按各自币种规整。

阶段 1 完成后数据写错风险应全部关闭，可独立形成一个 `fix:` 提交。

### 阶段 2：金额格式化与输入收口

1. 增加币种感知格式化/零值 API；
2. 迁移旧 `formatAmount` 族全部调用点；
3. 拆分 money/rate 数字键盘；
4. 预算、账户、快速记账和 onboarding 输入传入正确币种；
5. Controller 预算与账户写入边界规整。

### 阶段 3：共享金额草稿状态机

1. 先给 `entry_currency_draft.dart` 写纯函数单测；
2. 迁移新建记账页；
3. 迁移交易详情页并关闭日期静默重算；
4. 迁移退款、周期规则和信用还款；
5. `saveEntryAggregateDraft` 返回稳定领域结果。

### 阶段 4：比较、可解释性与 AI

1. 本位币金额排序；
2. 自动识别币种隔离；
3. 转账 AI 查询金额语义；
4. 录入/资产展示汇率日期和陈旧状态；
5. 首页周期缺率待处理卡。

### 阶段 5：小组件与全量验收

1. 增加 widget projection invalidation；
2. 覆盖汇率、预算、账户、账本切换等触发点；
3. 执行 format/analyze/full test；
4. 用 GitHub CI release APK 做 Android 真机专项。

本轮预期**不需要 SQLite schema v15**。若实现过程中发现必须新增持久化字段，应暂停并按
`AGENTS.md` 的 schema 迁移流程单独设计，不能顺手加列。

## 13. 测试矩阵

### 13.1 退款导入

- 10 USD 支出、72 CNY 本位币、退款 5 USD：退款 `amount=5 USD`、
  `baseAmount=36 CNY`；
- 原账户为 USD、CNY、无账户三种情况分别验证 `accountAmount`；
- 本应用 CSV 导出后重新导入，外币退款原币、余额和净额一致；
- 排除原支出时不留下退款；映射账户后退款引用同步；
- 真正 v1 CNY 标量退款迁移结果与旧行为一致；
- 持久化失败时原有数据不变。

建议落点：`plan_builder_test.dart`、`payment_import_test.dart`、`refund_test.dart`、
`controller_persistence_test.dart`。

### 13.2 精度与输入

- KWD `0.001` 在首页、预算、看板、统计和图表气泡中不显示为 0；
- KWD 金额键盘允许三位，第四位被阻止；
- JPY 金额键盘不提供小数点或不接受小数；
- JPY/KWD 预算写入、重启、备份往返保持 minor unit；
- 零值颜色按各币种最小单位容差判断，不出现 `-0`。

建议落点：`currency_test.dart`、`budget_test.dart`、`currency_ui_test.dart`、
`home_metrics_test.dart`。

### 13.3 编辑状态机

- manual/imported/legacy 交易只改日期，三层金额完全不变；
- rateTable 新建草稿改日期时按新日期刷新；
- 已保存交易显式点“重新计算”后才更新；
- 手工汇率后改原币金额保持手工汇率；
- 改账户只更新账户金额，不改变冻结统计金额；
- 有退款支出无法改原币，并显示本地化原因；
- 缺率、退款超额等保存失败给出明确领域反馈。

建议新增 `entry_currency_draft_test.dart`，并补 `currency_ui_test.dart`、
`entries_test.dart`。

### 13.4 比较、趋势与 AI

- 100 USD 支出、720 CNY 本位币、已退 360 CNY 仍属于待报销；
- 混币列表按本位币金额排序，缺率转账稳定排后；
- 同为数字 100 的 JPY/CNY 历史不会仅凭金额互相成为强建议；
- 7 月 1 日发起、7 月 4 日到账的退款只在 7 月 4 日改变余额；
- 6 月发起、7 月到账的退款进入 7 月账户趋势，但仍冲减原支出统计月份；
- AI 转账明细不再显示本位币 0，金额筛选和排序有明确定义。

建议落点：`reimbursement_test.dart`、`entries_test.dart`、`category_suggest_test.dart`、
`pure_test.dart`、`ai_query_tool_test.dart`。

### 13.5 汇率状态、周期与小组件

- 录入页显示实际使用的汇率日期；超过 30 日显示陈旧提示；
- 资产估值展示最旧汇率日期，缺率仍不展示部分总额；
- 到期周期规则缺率时首页显示待处理，补率后可显式补记且不重复；
- 新增、修改、删除汇率后触发一次小组件推送；
- 连续批量变更被去抖成一次推送；
- 推送失败不回滚已经成功的账目保存。

建议落点：`currency_ui_test.dart`、`recurring_test.dart`、`home_widget_test.dart`、
`controller_unit_test.dart`。

### 13.6 必跑命令

```bash
dart format .
flutter analyze
flutter test
```

文档阶段只做 diff、链接和路径校验；开始改代码后必须执行全量命令。

## 14. Android 真机专项

正式验收使用 GitHub CI 生成的 `github` flavor release APK，至少覆盖：

1. KWD/JPY 账本的快速记账、预算、余额调整和信用额度输入；
2. 手工/导入外币交易改日期后金额不变；
3. 外币退款导入后的原币、到账账户余额和净支出；
4. 汇率删除/补齐后的资产页、周期待处理和桌面小组件；
5. 应用退后台、跨日、进程被杀后小组件数据自愈；
6. 中文/英文、浅色/深色和 360dp 窄屏下的汇率 trace 与缺率提示。

## 15. 文档与 CHANGELOG 同步

实施时按实际行为同步检查：

- `AGENTS.md`、`CLAUDE.md`：金额 API、保存结果、导入退款与 widget invalidation；
- `docs/product.md`：历史金额冻结、汇率日期和周期缺率用户行为；
- `docs/ui-guidelines.md`：币种感知输入、冻结/重算状态和汇率 trace；
- `docs/dev/components.md`：money/rate 数字键盘与共享草稿组件；
- `docs/dev/tech-decisions.md`：导入退款三层金额、余额生效日和投影失效；
- `docs/dev/known-limitations.md`：若某项最终明确延后，再登记接受理由和触发阈值；
- `docs/dev/ai-tools.md`：转账金额筛选/排序与展示口径；
- `docs/dev/verifin-sample-backup.json`：仅在备份事实发生变化时更新；
- `docs/acceptance-checklist.md`：KWD/JPY、冻结编辑、退款导入和 widget 验收；
- `CHANGELOG.md`：代码落地时记录用户可见修复与交互变化；本设计文档本身不写 CHANGELOG。

## 16. 完成标准

- [ ] 外币退款导入不会混用三种金额单位，CSV 重导入余额与净额一致；
- [ ] 已保存交易只改日期不会改变任何冻结金额；
- [ ] 所有金额展示、输入、零值判断和预算持久化遵循实际币种 minor unit；
- [ ] 报销筛选、交易排序和自动识别不再比较不同币种裸数字；
- [ ] 退款只在 `settledAt` 改变账户/资产趋势；
- [ ] 有关联退款的支出不能进入原币不一致的不可保存状态；
- [ ] 导入/恢复在写库前通过统一三层金额与引用校验；
- [ ] 汇率生效日期、陈旧状态和周期缺率有明确用户可见反馈；
- [ ] 汇率、预算、账户、账本和交易变化能及时刷新桌面小组件；
- [ ] AI 转账查询不再把金额展示为 0；
- [ ] `dart format .`、`flutter analyze`、`flutter test` 全部通过；
- [ ] Android release APK 完成专项真机验收；
- [ ] 相关文档和 `CHANGELOG.md` 与最终实现同步。

## 17. 待结合真实体验继续优化的部分

以下属于体验取舍，不阻塞上述正确性修复，待收集真实使用反馈后再定最终交互：

- 快速记账第一步应先选币种，还是继续根据默认账户推断；
- 三层金额是否默认折叠，何时自动展开；
- 手工编辑“实际扣款”与“编辑汇率”哪一个应是主入口；
- 单币种隐藏单位在桌面小组件和窄卡片中是否仍应保留；
- 汇率过期提醒的视觉强度和默认阈值；
- 保存历史交易时，“保持冻结金额”和“按新日期重算”的文案与动作位置。

用户的实际体验反馈应优先用于决定这些交互，不应被当作次要问题；正确性修复负责保证无论选择
哪种交互，底层金额都不会被写错或静默改变。
