# 多币种与离线汇率设计及开发计划

> 状态：**已实现；自动化验收完成，Android release 真机验收待发版阶段执行**
>
> 调研与代码基线：`main` @ `58cb20b`，应用版本 `1.13.1+93`，SQLite schema v13
>
> 文档分支：`codex/multi-currency-design`
>
> 最后更新：2026-08-18

> 2026-08-25 的落地后代码审查确认了退款导入、历史交易冻结金额、minor-unit
> 展示/输入、跨币种比较和系统投影刷新等后续加固项。修复设计与测试矩阵见
> [`multi-currency-hardening-design.md`](multi-currency-hardening-design.md)。该轮加固已完成自动化
> 验收，Android release 真机项仍待发布后执行。

本文是 Veri Fin 多币种功能的实现依据。它记录产品范围、金额语义、汇率方向、
SQLite/备份兼容、交易/转账/退款/周期记账口径、UI 流程、测试矩阵和分阶段落地顺序。
实现时若代码现状已经变化，应先重新核对源码、测试和 `docs/dev/tech-decisions.md`，再更新本文，
不能直接照抄过期字段或 schema 版本。

## 0. 实现结果（2026-08-18）

- 已按阶段 1–7 落地离线 ISO 4217 目录、minor-unit 格式化、三层金额、跨币转账/退款/周期记账、按日汇率、资产估值、统计/预算/AI/小组件、导入导出和 JSON v2 备份。
- SQLite 最终 schema 为 **v14**；v13→v14 迁移把旧数字原样回填为 CNY，并把旧账本标为 `legacyUnconfirmed`。模型字段、汇率表、Repository 快照和全版本迁移矩阵均已同步。
- 导入 conversion issue 会先自动尝试已有历史汇率；仍缺率时，文件选择后按币种批量输入汇率并用纯 plan builder 重建，取消输入即保留为跳过项。导入汇率默认不保存，预览页开启开关后只保存最终保留交易使用的汇率。
- 为让本应用 CSV 在空账本中也能无歧义重建跨币消费/转账，除原计划五列外又追加了可选 `账户币种`、`转入账户币种` 两列；旧七列表头仍兼容。
- 第三方 parser 只读取真实样例已证实的字段：当前钱迹真实 fixture 的 `币种` 已进入强类型记录；一木/薄荷现有真实 fixture 未提供可验证的多币种列，因此未臆造字段名，仍按当前账本本位币导入。
- 未增加网络请求、权限、后台任务、原生依赖或汇率 SDK。剩余人工项是 Android release APK 上的旧库升级、跨币关键流程、备份恢复和桌面小组件真机验收。

## 1. 结论速览

Veri Fin 不接入在线汇率服务，也不为多币种引入账号、服务器或后台联网。目标方案是：

1. 每个账本有一个**本位币**，预算、收支统计、看板和 AI 汇总统一使用本位币。
2. 每个账户只持有一种**账户币种**，账户余额始终以自己的币种计算和展示。
3. 一笔普通交易同时保存：
   - 用户实际消费/收款的**原币金额**；
   - 银行或钱包真实扣入账的**账户金额**；
   - 记账当时冻结的**本位币金额**。
4. 跨币种转账保存转出和转入两端的真实金额，不把“汇率”当作唯一账务事实。
5. 汇率按账本、币种和生效日期存 SQLite，由用户手工维护；交易可采用汇率表，也可单笔手改。
6. 已保存交易的本位币金额不会因以后修改汇率而变化；账户资产折算才读取汇率表。
7. 缺汇率时不按 1:1 猜测、不静默排除、不显示伪造总额。需要折算才能落账的交易必须先补齐金额或汇率。
8. 货币目录随安装包离线提供，以现行 ISO 4217 法定货币为基础；首版不做加密货币、贵金属、股票或自定义商品货币。

这套设计吸收了钱迹/Spendee 的移动端交互和 GnuCash 的离线汇率思路，同时保持 Veri Fin
“本地优先、数据自主、无自有服务端”的产品原则。

## 2. 实施前基线事实

截至本文最初调研基线（`main` @ `58cb20b`），项目只有隐式的人民币单币种语义；以下仅保留为改造背景，不代表当前实现：

- `LedgerBook`、`Account`、`LedgerEntry`、`RecurringRule` 都没有币种字段；
- `Account.initialBalance`、`LedgerEntry.amount`、预算金额和统计金额默认处在同一单位；
- `accountDeltaForEntry` 直接用 `entry.amount` 改账户余额；
- `signedAmount`、`sumByType`、报表、首页指标和预算直接聚合 `amount/netAmount`；
- 转账两端使用同一个 `amount`，只能表达等额同币种转账；
- `normalizeAmount` 和 `formatAmount` 固定按两位小数处理；
- 账户详情固定显示“货币：人民币”；
- AI 记账提示词把金额解释为“元”，AI 查询结果不带币种；
- 钱迹/一木等导入文件即使带“货币/汇率”列，当前强类型中间层也没有保存；
- SQLite、JSON 备份、样例备份、桌面小组件都没有币种信息。

因此，多币种不是给账户详情加一个下拉框，而是一次贯穿模型、余额、统计、退款、导入、备份、
周期规则和格式化的领域升级。

## 3. 调研结论与采用取舍

### 3.1 同类产品的共同模型

| 产品 | 公开行为 | 对 Veri Fin 的启发 |
|---|---|---|
| 钱迹 | 多币种默认关闭；账户有币种；交易默认跟账户币种、可切换；自动汇率可手改；外币资产折算到人民币 | 账户币种与交易币种必须分开；单笔汇率必须允许覆盖 |
| 薄荷记账 | 公开版本记录显示全币种账户、法定货币汇率趋势、自定义商品货币 | 货币中心是独立入口；首版应收敛为法币，不把商品/股票混入 |
| 一木记账 | Android 端曾提供多币种，导出格式含多币种字段；公开资料对具体汇率口径说明有限 | 导入链路必须保留币种，不能只在 App 内新建交易时支持 |
| Spendee | 主币种、钱包币种、交易币种三层；交易可显示双币金额；已有交易的钱包不能改币种 | 采用三层模型；有流水后锁定账户币种 |
| Toshl | 主币种、账户、预算、交易均支持币种；交易显示主币/账户币；历史汇率与自定义汇率并存 | 录入页应同时说明原币、账户币和本位币；历史交易需要冻结折算值 |
| Wallet | 一个账户一种币；可自动或手工汇率 | 保持账户单币种，避免一个账户内部再建持仓子账本 |
| MoneyWiz | 本地/报表币种、账户币种、交易币种；外汇账户和汇兑属于更高级模型 | 首版只做个人记账需要的三层金额，不做外汇投资和汇兑损益 |
| GnuCash | 本地价格数据库；汇率可手工维护；跨币种交易保存两端金额 | 离线汇率表完全可行；真实两端金额比单独保存一个汇率可靠 |

### 3.2 采用的原则

- 采用“账本本位币 → 账户币种 → 交易原币”的三层模型。
- 采用“一账户一币种”。多币种现金应建多个账户，而不是让同一普通账户同时持有多币种。
- 采用“保存实际金额，汇率可派生”的交易账务模型。
- 采用按日的本地汇率表；查找某日汇率时只向过去找，不使用未来汇率。
- 采用历史交易本位币金额冻结、当前资产按最新有效汇率估值的双口径。
- 不采用静态内置“当前汇率”。安装包中长期不更新的金融报价会给用户造成虚假准确感。
- 不采用自动联网更新、后台刷新或隐式请求第三方服务。

### 3.3 公开资料的证据边界

钱迹、Spendee、Toshl、Wallet、MoneyWiz、GnuCash 和 ISO 有较明确的官方说明；薄荷的主要证据是
官方 App Store 版本记录，一木的公开说明没有完整披露汇率算法。因此，本文不会把无法验证的
薄荷/一木内部实现当成事实，只把它们用于确认用户确实需要账户币种、导入币种和汇率入口。

## 4. 术语

- **本位币（base currency）**：一个账本用于预算、收支统计、总资产和报表的统一币种。
- **账户币种（account currency）**：账户余额、初始余额、信用额度和手续费所属币种。
- **原币/交易币种（transaction currency）**：商户标价、现金收付或用户希望保留的原始币种。
- **原币金额（original amount）**：交易原始金额，对应 `LedgerEntry.amount`。
- **账户金额（account amount）**：银行/钱包实际扣款或入账金额，对应账户币种。
- **转入金额（target amount）**：转账目标账户实际收到的金额，对应目标账户币种。
- **本位币金额（base amount）**：该笔收支在记账当时折算并冻结的本位币金额。
- **汇率表金额**：用于辅助录入或资产估值的按日汇率，不等于已保存交易的账务事实。
- **冻结**：保存交易后不随汇率表变化而重算。
- **重解释**：只把旧数字认作另一种币种，不做乘除换算；仅用于旧账本的一次性校正。

本文固定采用以下汇率方向：

```text
rateToBase = 1 单位外币值多少单位本位币

示例：账本本位币 CNY，1 USD = 7.20 CNY
USD.rateToBase = 7.20
```

UI、模型、导入和测试不得在不同页面使用相反方向。

## 5. 目标与非目标

### 5.1 首版目标

1. 账本可选择本位币，账户可选择账户币种。
2. 支出、收入、转账和退款可表达跨币种实际金额。
3. 用户可离线新增、修改、删除某日汇率。
4. 预算、统计和 AI 汇总使用冻结本位币金额，结果稳定可解释。
5. 资产页同时展示账户原币余额和本位币估值。
6. 周期记账在有可用汇率时生成完整交易，缺汇率时明确等待处理。
7. 旧数据库和旧备份无损迁移，现有人民币用户升级后数值与界面不突变。
8. 钱迹、一木、薄荷和本应用 CSV 的币种/汇率字段能够进入导入预览并被正确处理。
9. 中文、英文、桌面小组件、通知、AI 和备份都带上明确币种。

### 5.2 首版非目标

- 不接在线汇率 API，不做后台刷新、定时下载或联网历史行情。
- 不做加密货币、贵金属、股票、基金、积分、优惠券或用户自定义商品货币。
- 不做外汇持仓成本、已实现/未实现汇兑损益、税务报表或会计平衡账户。
- 不做一个普通账户同时持有多个币种；需要时创建多个账户。
- 不支持任意改写有历史数据账本的本位币或账户币种。
- 不因修改汇率表批量重算历史交易。
- 不允许把缺失汇率默认为 1:1，也不把未知币种静默回退为 CNY。
- 不在本功能中新增多端同步或服务端汇率同步。

## 6. 核心领域不变量

以下不变量应由模型校验、Controller、导入器和测试共同保护：

1. 一个账本恰有一个本位币；账本内账户、交易、汇率均按 `bookId` 隔离。
2. 一个普通账户恰有一个账户币种。
3. 币种使用大写 ISO 4217 三字母代码；未知、停用或不在首版目录的代码不能新建数据。
4. 所有业务金额必须为有限正数；零值只用于明确的“不适用”字段，不能表示缺失。
5. 支出、收入和退款保存前必须有正数 `baseAmount`；转账的 `baseAmount` 恒为 0。
6. 有来源账户时必须有 `accountAmount`；无账户时 `accountAmount == null` 且 `fee == 0`。
7. 有转入账户的转账必须有 `toAccountAmount`；无转入账户时该字段为 null。
8. 手续费永远属于转出账户币种，并只影响转出账户余额，保持现有语义。
9. 交易本位币金额保存后冻结；修改汇率表不改写任何历史交易。
10. 汇率表中本位币对自身的汇率恒为虚拟值 1，不落库。
11. 某日汇率只能使用该日或更早的记录，不能从未来日期倒灌。
12. 退款条目的原币必须与原支出原币一致；退款到账账户可以与原支出账户不同币种。
13. 退款只在 `settledAt != null` 时影响账户余额和原支出本位币净额。
14. 转账仍不计收入/支出；汇兑差额和手续费造成的净资产变化不伪装成普通收支。
15. 预算全部以账本本位币保存，仍按既有默认预算/单期覆盖规则工作。
16. 缺少资产估值汇率时，总资产显示“无法完整折算”，不能返回一个看似完整的部分和。
17. 所有旧 CNY 数据迁移后数值、余额、净额、预算和排序保持不变。

## 7. 领域模型设计

### 7.1 货币目录 `CurrencyDefinition`

新增离线只读模型和目录：

```dart
class CurrencyDefinition {
  const CurrencyDefinition({
    required this.code,
    required this.numericCode,
    required this.nameZh,
    required this.nameEn,
    required this.symbol,
    required this.minorUnit,
  });

  final String code;        // CNY / USD / JPY
  final String numericCode; // 156 / 840 / 392
  final String nameZh;
  final String nameEn;
  final String symbol;
  final int minorUnit;       // JPY=0, CNY/USD=2, KWD=3
}
```

约束：

- 数据随安装包提交，不在运行时联网获取；
- 数据源以 ISO 4217/SIX 的现行法定货币列表为准；
- 首版排除资金代码、贵金属、测试代码、无通用货币代码、历史停用币种和加密货币；
- 货币符号可能重复（如 `$`、`¥`），选择器和混币页面必须显示三字母代码；
- 更新目录时提交来源日期和差异测试，不能只改中文名或符号而漏改 minor unit；
- 已存在于用户数据但后来被目录停用的币种必须可读、可展示、可导出，但不再允许新建。

建议新增：

- `lib/app/models/currency.dart`：`CurrencyDefinition`、`ExchangeRate`、相关枚举；
- `lib/app/currency_catalog.dart`：静态目录、查找、搜索和常用排序；
- `lib/app/currency_math.dart`：归一化、换算、汇率查找和结果类型。

### 7.2 账本 `LedgerBook`

新增字段：

```dart
final String baseCurrencyCode;
final CurrencySetupStatus currencySetupStatus;
```

```dart
enum CurrencySetupStatus {
  legacyUnconfirmed,
  confirmed,
}
```

语义：

- 新安装在首次引导中明确选择本位币，新账本创建时也必须选择；
- 中文首次引导可预选 CNY，英文可预选 USD，但用户保存前可更改；
- 新建账本默认预选当前账本本位币，不能无提示猜测地区币种；
- 旧账本迁移为 `CNY + legacyUnconfirmed`，继续按现有人民币行为运行；
- 用户首次进入货币设置或尝试创建外币账户时，必须先确认旧金额的含义；
- 账本确认且已有财务数据后，本位币锁定。

“已有财务数据”至少包括：交易、非零初始余额、信用额度、预算、周期规则或汇率记录。
纯空账本可以更改本位币；更改时一并更新所有零值空账户币种并清空无意义汇率记录。

### 7.3 账户 `Account`

新增字段：

```dart
final String currencyCode;
```

金额语义同步明确：

- `initialBalance`：账户币种；
- `creditLimit`：账户币种；
- 当前余额：账户币种；
- 信用卡已用/可用额度：账户币种；
- `includeInAssets` 只决定是否进入总资产，不改变原币余额。

账户有任一关联交易，或存在非零初始余额/信用额度后，币种不可直接修改。用户需要另一币种时新建账户。
删除账户、删除账本和导入映射必须继续清理/验证全部引用。

### 7.4 汇率 `ExchangeRate`

```dart
enum ExchangeRateSource {
  manual,
  imported,
}

class ExchangeRate {
  const ExchangeRate({
    required this.id,
    required this.bookId,
    required this.baseCurrencyCode,
    required this.currencyCode,
    required this.effectiveDate,
    required this.rateToBase,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });
}
```

规则：

- `effectiveDate` 是本地日历日，不是绝对时刻；SQLite 建议存 `yyyy-MM-dd` 文本，避免时区/DST 偏移；
- `rateToBase` 必须有限且大于 0；
- 一个账本、一个本位币、一个外币、一个日期只有一条生效记录；
- 用户手工保存覆盖同日记录时更新 `updatedAt`；
- 导入文件携带的汇率默认只服务该批交易，只有用户选择“保存为当日汇率”才写入汇率表；
- 删除汇率不会改历史交易，但可能使资产估值或待生成周期交易缺少汇率，删除前要提示影响；
- 不保存 CNY→CNY、USD→USD 等同币记录。

### 7.5 交易 `LedgerEntry`

保留现有 `amount` 字段名，但把语义明确为**原币金额**，并新增：

```dart
final String currencyCode;
final double? accountAmount;
final double? toAccountAmount;
final double baseAmount;
final ConversionSource conversionSource;
```

```dart
enum ConversionSource {
  identity,  // 原币、本位币相同
  manual,    // 用户在本单手工输入
  rateTable, // 来自本地汇率表
  imported,  // 导入文件提供
  legacy,    // 旧数据迁移
}
```

不在交易上单独持久化一个可变汇率作为唯一事实。展示汇率时由已保存的真实金额相除得到；
这样即使小数舍入或银行实际结算价不同，余额仍以账单真实金额为准。

字段矩阵：

| 类型 | `amount/currencyCode` | `accountAmount` | `toAccountAmount` | `baseAmount` |
|---|---|---|---|---|
| 支出 | 商户/现金原始支出 | 来源账户真实扣款；无账户为 null | null | 冻结本位币支出 |
| 收入 | 原始收入 | 来源账户真实入账；无账户为 null | null | 冻结本位币收入 |
| 转账（双边） | 转出金额/转出币种 | 转出账户真实减少额 | 转入账户真实增加额 | 0 |
| 转账（仅转出） | 转出金额/转出币种 | 转出账户真实减少额 | null | 0 |
| 转账（仅转入） | 转入金额/转入币种 | null | 转入账户真实增加额 | 0 |
| 退款 | 原支出币种中的退款额 | 到账账户真实增加额；无账户为 null | null | 冻结本位币冲抵额 |

现有 `refundedAmount` 语义应改名为 `refundedBaseAmount`：

- 它仍是 Controller 派生缓存，不接受 UI 任意提交；
- 等于关联且已到账退款的 `baseAmount` 之和，并钳制到原支出 `baseAmount`；
- SQLite 可继续复用 `refunded_amount` 列，避免为纯命名再加一列；
- JSON v2 输出 `refundedBaseAmount`，读取时兼容旧 `refundedAmount`；
- 新 getter 为 `netBaseAmount = baseAmount - refundedBaseAmount`，取代统计层的 `netAmount`；
- 账户余额从不读取该缓存，仍由支出全额扣款和退款独立入账共同构成。

### 7.6 周期规则 `RecurringRule`

周期规则必须能生成完整的多币种交易，新增与交易模板对应的币种/金额字段，并增加：

```dart
enum RecurringRatePolicy {
  latestAvailable,
  fixedAmounts,
}
```

- `latestAvailable`：每个到期日按该日或更早的最新本地汇率重新计算账户/本位币/转入金额；
- `fixedAmounts`：每次复用规则保存时的各端金额，适合固定结算价合同；
- 同币种规则不需要汇率，两种策略结果相同；
- 缺少必要汇率时不生成残缺交易、不推进 `nextRunDate`，而是产生可见的“待补汇率”状态；
- 用户补齐汇率后重新执行补记，现有确定性 entry id 继续防重复；
- 旧周期规则迁移为 CNY、`fixedAmounts`，保持历史行为。

### 7.7 预算

月度预算、分类预算和每日预算全部使用账本本位币，现有 SQLite 表与键规则不变：

- 默认预算与单期覆盖优先级不变；
- 自定义预算周期只改变预算窗口，不改变币种；
- 预算页面 Header/说明处显示本位币代码；
- 交易占用预算使用 `netBaseAmount`；
- 旧账本做一次重解释时，预算数字不变、币种标签随账本本位币变化。

## 8. 换算、舍入与历史口径

### 8.1 基础换算

同一账本中，任意 A→B 的交叉汇率从两者对本位币汇率计算：

```text
rate(A → B) = rateToBase(A) / rateToBase(B)
amountB = amountA × rateToBase(A) / rateToBase(B)
```

本位币的虚拟 `rateToBase` 恒为 1。

### 8.2 汇率查找

```text
resolveRate(bookId, currencyCode, date)
  1. currencyCode == baseCurrencyCode → 1
  2. 查 effectiveDate == date
  3. 否则查 effectiveDate < date 中最近的一条
  4. 没有 → null
```

- 绝不使用未来日期记录；
- 当前资产估值使用“今天或更早的最新一条”；
- 历史资产曲线的某个点使用“该点日期或更早的最新一条”；
- 始终展示汇率生效日期；超过 30 个日历日可标记“可能已过期”，但仍由用户决定是否使用；
- 30 天判断使用 `calendarDaysBetween`，不能用 `difference().inDays`。

### 8.3 舍入

首版继续使用现有 `double/SQLite REAL` 存储，避免在同一版本夹带全量整数金额迁移；但所有边界改为
按币种 minor unit 归一化：

```dart
double normalizeCurrencyAmount(num value, CurrencyDefinition currency)
```

- JPY/VND 等 0 位币种按整数归一；
- CNY/USD/EUR 等按 2 位；
- KWD/BHD/OMR 等按 3 位；
- 换算先使用未舍入汇率计算，最后只对目标金额按目标币种舍入；
- 汇率本身至少保留 10 位有效精度，不调用金额的 minor-unit 舍入；
- 金额比较容差由对应币种最小单位推导，不能继续全局写死 `0.0001/0.005`；
- NaN、Infinity、非正汇率和溢出结果一律拒绝。

若未来需要整数 minor units，应单独设计全量数据迁移；首版不在多币种功能中同时承担这项高风险改造。

### 8.4 历史交易与当前资产

两个口径必须明确区分：

- **收支历史**：使用交易保存时冻结的 `baseAmount`，因此修改汇率表不会改历史报表。
- **资产估值**：先在账户币种中计算真实余额，再用目标日期有效汇率折算本位币。

这意味着同一笔外币收入保存时计入 720 CNY，今天账户中的 100 USD 可能估值为 730 CNY。
10 CNY 差额属于汇率变化，不作为普通收入；首版也不单列汇兑损益。

## 9. 各交易类型的数学口径

### 9.1 支出

```text
账户增量 = -accountAmount（有账户时）
统计支出 = baseAmount - refundedBaseAmount
```

示例：美国消费 10 USD，人民币信用卡实际扣 72.35 CNY，账本本位币 CNY：

```text
amount = 10, currencyCode = USD
accountAmount = 72.35 CNY
baseAmount = 72.35 CNY
```

### 9.2 收入

```text
账户增量 = +accountAmount（有账户时）
统计收入 = +baseAmount
```

外币账户收到 100 USD，本位币折算 720 CNY：账户余额加 100 USD，收入统计加 720 CNY。

### 9.3 转账

```text
转出账户增量 = -(accountAmount + fee)
转入账户增量 = +toAccountAmount
收支统计 = 0
```

示例：转出 100 USD，转入 720 CNY，手续费 1 USD。必须保存 100、720、1 三个事实；
展示汇率可由 `720 / 100 = 7.2` 派生。以后汇率变化不影响两个账户的历史余额。

同币种转账自动令两端金额相等。当前实现对同账户转账保留“只损失手续费”的数学兼容，
多币种实现不应顺手改变该既有行为；是否在 UI 禁止同账户转账属于另一项产品决定。

### 9.4 退款/报销回款

退款条目：

- `currencyCode` 强制等于原支出 `currencyCode`；
- `amount` 表示原支出币种中的退款份额；
- `accountAmount` 表示退款账户实际收到的金额；
- `baseAmount` 表示本次冲抵的冻结本位币金额；
- 待到账退款可先保存预计值，核销为已到账时必须再次确认实际到账金额和本位币金额。

限制同时检查：

1. 全部退款（含待到账）的原币 `amount` 合计不得超过原支出 `amount`；
2. 原支出的 `refundedBaseAmount` 只累计已到账退款并钳制到原支出 `baseAmount`；
3. 因汇率变化导致实际到账本位币价值高于原支出时，超出部分不把净支出变成负数；
4. 超出部分只会自然反映在账户资产中，首版不生成人工“汇兑收益”交易。

`saveEntryAggregateDraft` 必须在一个提交边界内校验原支出、全部退款和附件，并按退款
`baseAmount` 重算缓存，继续防止旧页面快照覆盖 Controller 派生值。

### 9.5 无账户交易

无账户交易仍计入收支，但不影响余额：

- 原币等于本位币时，`baseAmount = amount`；
- 原币不同于本位币时，用户必须输入本位币金额或有效汇率；
- `accountAmount == null`；
- 不得用首账户币种解释空 `accountId`。

## 10. UI 与交互设计

### 10.1 首次安装与新建账本

- 首次引导增加“账本本位币”选择，说明“预算、统计和总资产将统一显示为此币种”；
- 选择器支持代码/中英文名搜索，顶部展示本位币和最近使用币种；
- 新建账本表单同时选择名称与本位币，保存后创建账本；
- 空账本可在账本设置中更改本位币；有财务数据后显示锁定说明和“新建另一账本”建议。

### 10.2 旧账本一次性确认

旧账本不在升级启动时强制弹窗，避免普通人民币用户被打断。用户首次进入货币设置或创建外币账户时，
显示一次确认：

1. **现有金额就是人民币**：确认 CNY，不改数字；
2. **现有金额其实是其他币种**：选择币种，把账本、账户、交易、预算和周期规则的数字原样解释为该币种；
3. **稍后处理**：保持 `legacyUnconfirmed`，不能新增外币数据。

“重解释”必须使用 `replaceAllLedgerData` 同一 SQLite 事务完成，不允许出现账本改了而交易没改的半状态。
操作前展示受影响的账户/交易/预算数量，并二次确认“数值不会换算”。确认后不可再次重解释。

### 10.3 账户编辑

- 账户编辑页增加“币种”行，使用统一货币选择器；
- 初始余额、信用额度、当前余额旁显示账户币种代码；
- 已使用账户的币种行只读，点击显示锁定原因；
- 账户详情不再硬编码人民币；
- 账户选择器的余额使用账户原币显示，混币列表必须带单位并遵循用户选择的符号/代码样式；账户币种选择项本身仍显示 ISO 代码。

### 10.4 汇率管理页

入口建议放在“我的 → 数据与工具 → 货币与汇率”，进入后作用于当前账本：

- 顶部显示账本本位币；
- 列表只展示账户/交易/最近使用涉及的外币，可搜索并添加任意支持法币；
- 每行显示 `1 USD = 7.20 CNY`、生效日期、来源和是否过期；
- 点击行进入该币种历史记录；
- 新增/编辑使用日期选择器 + 数字键盘；
- 删除使用 `showConfirmDialog(..., destructive: true)`；
- 页面无“刷新”或联网状态，明确说明“汇率保存在本机，由你维护”。

### 10.5 普通交易录入

金额输入区增加币种按钮：

- 默认原币为已选账户币种；无账户时默认账本本位币；
- 切换账户时，只有用户尚未手动改过币种才跟随新账户；
- 原币、账户币、本位币都相同时，界面与当前单金额体验基本一致；
- 原币与账户币不同时，出现“账户实际扣款/入账”行；
- 原币与本位币不同时，出现“计入账本”行和汇率说明；
- 用户可以编辑汇率，也可以直接编辑实际账户金额/本位币金额；
- 草稿记录最后编辑字段，避免 A 改 B、B 又反算 A 的反馈循环；
- “记住为当日汇率”默认关闭，避免一次银行特殊结算价污染全局汇率表；
- 保存前给出清晰摘要，例如：

```text
消费：USD 10.00
信用卡扣款：CNY 72.35
计入账本：CNY 72.35
```

### 10.6 跨币种转账

- 转出账户和转入账户确定两端币种；
- 同币种只显示一个金额，转入金额自动相等；
- 不同币种同时显示“转出金额”“转入金额”和派生汇率；
- 用户可编辑转入金额或汇率，最后以两端金额为保存事实；
- 手续费显示转出账户币种；
- 单边转账继续支持未跟踪的外部账户，页面明确标注哪一端不计入资产；
- 保存摘要同时列出两端，不能只显示一个换算后的数。

### 10.7 退款编辑

- 退款原币沿用原支出，不允许任意切换；
- 显示原支出原币剩余可退金额；
- 选择退款到账账户后，显示该账户的实际到账金额；
- 本位币冲抵额单独显示；
- 待到账转已到账时再次确认实际到账金额；
- 原支出详情同时展示原币退款进度和本位币净支出，避免跨汇率时只给一个模糊“已退款”。

### 10.8 周期记账

- 规则编辑页显示“每次使用最新本地汇率”与“固定当前金额”选项；
- 缺汇率的到期规则不静默跳过，在首页/周期记账页显示待处理数量；
- 用户补率后可点“立即补记”；
- 同一到期日仍以确定性 id 防重复；
- 生成失败不推进日期，持久化失败要记录日志并给用户可见反馈。

### 10.9 列表、报表和资产展示

- 设置页可选符号后置（`100 ¥`）或代码前置（`CNY 100`），默认符号后置；
- 单币种上下文默认只显示金额，用户可关闭「单币种隐藏单位」；Header/卡片标题通过 `MoneyUnitLabel` 标注币种；
- 混币列表始终显示单位；符号样式可能重复，需要无歧义时用户可切换为 ISO code，货币选择器和汇率管理页仍固定显示 code；
- 交易列表主金额优先显示原币，副行在不同币时显示账户金额/本位币金额；
- 报表、预算、首页概览/日历/收支指标、AI 结果统一使用账本本位币，并在卡片或页头标明单位；
- 账户卡片显示原币余额，资产总览显示本位币折算值和汇率日期；
- 缺资产汇率时，总资产显示 `—` 和“有 N 个账户待设置汇率”，不显示部分总额；
- 历史资产图缺某日折算率时显示断点/缺失态，不把缺失值画成 0；
- 图表仍使用 `InteractiveTrendChart`/`InteractiveBarChart`，点按信息遵循同一单位样式与隐藏规则。

### 10.10 金额格式化

已将用户可见的带币种金额统一到两层入口：

```dart
String formatMoney(
  num value,
  String currencyCode, {
  MoneyCodeDisplay display = MoneyCodeDisplay.code,
})

String formatUserMoney(
  num value,
  String currencyCode, {
  bool forceUnit = false,
})
```

`formatMoney` 是显式选择 code/symbol/none 的底层与机器文本入口；UI 必须优先使用
`formatUserMoney` / `formatSignedUserMoney`，由 Controller 同步的全局偏好决定符号/代码及单币种隐藏。
`forceUnit: true` 只用在同一控件同时展示两个币种的换算字段。

当前 `amountForceTwoDecimals` 不能直接用于 JPY/KWD。建议迁移为：

```dart
enum CurrencyFractionStyle {
  compact,  // 在该币种允许精度内移除尾随零
  standard, // 固定显示该币种的 ISO minor unit
}
```

旧偏好 `false → compact`、`true → standard`。JPY 两种模式都是 0 位，KWD 最多/固定 3 位。
金额为零继续使用中性色且不显示 `-0`。

汇率的「保存精度」与「展示精度」分离：`formatRateValue` 对常见值最多保留 4 位小数，
小于 `0.01` / `0.0001` 时逐步放宽到 6 / 8 位，避免极小汇率显示为 0；CSV 导出使用
`formatRateValueExact` 保留最高 10 位小数，不因 UI 舍入损失往返精度。

### 10.11 组件复用与新增注册项

实现前继续遵守 `docs/dev/components.md`：

- 页面使用 `Scaffold > SafeArea > VeriPage`、`VeriHeader` 和 `SaveHeaderAction`；
- 编辑页使用 `UnsavedChangesGuard`；
- 金额输入复用/参数化 `showNumberPadSheet`；
- 2–8 项静态受控单选使用 `VeriAnchoredChoice<T>`；动态/分区简单列表保留 `showOptionSheet`，货币搜索使用统一 `showCurrencyPickerSheet`；
- 账户选择继续走 `showAccountPickerSheet`；
- 确认框继续走 `showConfirmDialog`；
- 带币种换算行复用 `CurrencyAmountField`，聚合卡片的单位提示复用 `MoneyUnitLabel`；新增共享件后同步登记 `docs/dev/components.md`，不能在多个页面复制实现。

### 10.12 国际化与无障碍

- 新增文案同步写入 `app_zh.arb`、`app_en.arb`，不手改生成文件；
- 货币代码不翻译，货币名称按当前 app locale 选择；
- 汇率语句必须显式读成“1 美元等于 7.2 人民币”，不能让读屏只读一串数字；
- 输入框语义标签说明币种和用途（原币/账户实际金额/本位币金额）；
- 系统日期选择器跟随 app locale；
- 不使用国旗代表货币，因为一个币种可能跨多个国家/地区。

## 11. SQLite 与迁移设计

### 11.1 版本策略

实施时使用**当时** `AppDatabase.schemaVersion + 1`。若直接基于本文 v13 开发，则目标是 v14；
若期间已有其他迁移，必须顺延，不能抢占或修改已发布迁移段。

同步要求：

1. 提升 `schemaVersion`；
2. 更新 `_schemaCurrent`；
3. 在 `_migrations` 注册“升到 vN”的新段；
4. 更新 `test/migration_matrix_test.dart`；
5. 更新模型 JSON/row 四向映射和 `test/model_roundtrip_test.dart`；
6. 更新内存/SQLite 仓储契约测试。

### 11.2 表结构草案

`ledger_books` 新增：

```sql
base_currency_code TEXT NOT NULL DEFAULT 'CNY'
currency_setup_status TEXT NOT NULL DEFAULT 'legacyUnconfirmed'
```

`accounts` 新增：

```sql
currency_code TEXT NOT NULL DEFAULT 'CNY'
```

`entries` 新增：

```sql
currency_code TEXT NOT NULL DEFAULT 'CNY'
account_amount REAL
to_account_amount REAL
base_amount REAL NOT NULL DEFAULT 0
conversion_source TEXT NOT NULL DEFAULT 'legacy'
```

`recurring_rules` 新增与交易模板相应的币种/金额列和：

```sql
rate_policy TEXT NOT NULL DEFAULT 'fixedAmounts'
```

新增 `exchange_rates`：

```sql
CREATE TABLE exchange_rates (
  id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL,
  base_currency_code TEXT NOT NULL,
  currency_code TEXT NOT NULL,
  effective_date TEXT NOT NULL,
  rate_to_base REAL NOT NULL,
  source TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE (book_id, base_currency_code, currency_code, effective_date)
);

CREATE INDEX idx_exchange_rates_book_currency_date
ON exchange_rates (book_id, currency_code, effective_date);
```

### 11.3 v13 旧数据迁移

对每个旧账本：

- `base_currency_code = CNY`；
- `currency_setup_status = legacyUnconfirmed`。

对每个旧账户：

- `currency_code = CNY`；
- 初始余额、信用额度数字不变。

对每个旧交易：

- `currency_code = CNY`；
- 有 `account_id` 时 `account_amount = amount`，无账户时为 null；
- 转账有 `to_account_id` 时 `to_account_amount = amount`；
- 支出/收入/退款 `base_amount = amount`；
- 转账 `base_amount = 0`；
- `conversion_source = legacy`；
- 现有 `refunded_amount` 数字按 CNY 本位币缓存解释，数值不变。

对旧周期规则：

- 币种/各端金额按同样方式补齐；
- `rate_policy = fixedAmounts`。

迁移必须在 SQLite 段中完成基础列回填；Controller 的载入自愈只处理跨实体语义校验，
不能让生产库长期依赖“读到 null 再猜 CNY”。

### 11.4 完整性与索引

SQLite 层无法方便表达所有跨表币种约束，Controller 保存前仍需校验：

- 账户/交易/汇率都属于同一账本；
- `baseCurrencyCode` 与账本一致；
- 交易账户金额的币种由关联账户决定；
- 退款与原支出币种一致；
- 汇率 code 合法且不等于本位币；
- 日期键格式严格为 `yyyy-MM-dd`。

如后续启用 SQLite foreign key，应另行评估当前整表替换/写入顺序，不能在本功能中未经测试直接开启。

## 12. Repository 与 Controller 设计

### 12.1 Repository

`LedgerRepository` 增加：

```dart
Future<List<ExchangeRate>> loadExchangeRates();
Future<void> saveExchangeRates(List<ExchangeRate> rates);
```

并把 `exchangeRates` 加入 `LedgerDataSnapshot`、`replaceAllLedgerData` 和内存仓储。

SQLite 实现：

- `exchange_rates` 使用 `_incrementalReplace`，外部语义仍为“落库后表内容等于传入列表”；
- `loadExchangeRates` 后建立行快照；
- 导入/恢复/重置/删账本把汇率与其它核心表放在同一 `replaceAllLedgerData` 事务；
- 删除账本必须删除对应汇率；
- 单笔交易保存同时勾选“记住当日汇率”时，交易/退款/附件/汇率应在一个事务中提交，
  避免页面显示成功但汇率保存失败。可扩展现有聚合保存 API，不能让 UI 直访 repository。

### 12.2 Controller 状态

新增：

```dart
final List<ExchangeRate> _exchangeRates = <ExchangeRate>[];
```

以及当前账本的不可变派生视图。新增派生缓存时同步在 `_invalidateDerivedViews` 中清空。

Controller 提供窄 API：

- 当前账本、本位币和币种定义读取；
- 按账户读取原币余额；
- 按日期解析汇率/交叉汇率；
- 保存/删除汇率草稿；
- 计算资产折算结果；
- 保存多币种交易聚合草稿；
- 确认/重解释旧账本币种；
- 查询账户/账本币种是否可修改；
- 周期规则缺汇率状态和重试。

UI 不拼汇率键、不直接访问 SQLite、不自行用 `amount * rate` 形成另一套算法。

### 12.3 纯函数结果类型

不要用 `double?` 同时表达“成功为 0”和“失败”。建议定义：

```dart
sealed class ConversionResult {}
class ConvertedAmount extends ConversionResult { ... }
class MissingExchangeRate extends ConversionResult { ... }

class ConvertedTotal {
  final double? completeAmount;
  final Set<String> missingCurrencyCodes;
  final Set<String> affectedAccountIds;
}
```

只有 `missingCurrencyCodes.isEmpty` 时 `completeAmount` 才可展示为完整总额。

## 13. 备份、恢复与初始化

### 13.1 JSON 版本

建议把明文 JSON 根字段 `version` 从 1 提升为 2；zip/加密信封字节格式不变。

v2 增加：

- `ledgerBooks[].baseCurrencyCode/currencySetupStatus`；
- `accounts[].currencyCode`；
- `entries[]` 新金额字段和 `conversionSource`；
- `recurringRules[]` 新字段和 `ratePolicy`；
- `exchangeRates[]`；
- 金额显示偏好新枚举值。

旧 v1 备份导入：

- 按“旧数据迁移”规则解释为 CNY；
- 账本标记 `legacyUnconfirmed`；
- 允许用户之后做一次无换算重解释；
- 未知字段继续容忍，但非法币种/金额必须拒绝并保持现有数据不被覆盖。

### 13.2 备份范围

以下属于账目语义，必须进备份：

- 账本本位币和确认状态；
- 账户币种；
- 交易各端金额和转换来源；
- 周期汇率策略；
- 用户维护的汇率表；
- 金额小数显示风格。

货币静态目录不进备份；它属于应用代码。实现时同步更新：

- `exportDataJson` / `importDataJson`；
- `_knownBackupDataKeys`；
- `docs/dev/tech-decisions.md` 的备份范围表；
- `docs/dev/verifin-sample-backup.json`，加入 CNY 本位币、USD 账户、外币消费、跨币转账、退款和汇率；
- 旧备份、v2 备份、zip、加密信封回归测试。

### 13.3 初始化

- “初始化数据”创建的新默认账本必须走首次本位币选择或明确的默认策略；
- 初始化清除账目时一并清除汇率表；
- 设备本地的语言、备份凭证、AI Key 等仍按现有规则保留/清除，不因多币种改变；
- 若保留金额显示风格，需与现有初始化语义一致并加测试。

## 14. 第三方导入与本应用 CSV

### 14.1 强类型中间层

`RawImportRecord` 增加：

- `currencyCode`；
- 可空 `accountAmount`；
- 可空 `toAccountAmount`；
- 可空 `baseAmount`；
- 可空 `rateToBase`；
- 汇率来源/日期（来源格式提供时）。

`RawImportAccount` 增加 `currencyCode`。账户按“名称 + 币种”匹配；同名不同币种不能误合并。

### 14.2 缺汇率导入

导入解析和预览继续零落库副作用。外币记录缺少完整折算信息时：

- 不构造违反模型不变量的 `LedgerEntry`；
- `ImportPlan` 保留可定位的 `conversionIssues` 和原始强类型记录；
- 预览页允许用户批量选择已有日期汇率、手工输入汇率，或排除这些记录；
- 解决后重新运行纯 `plan_builder` 生成有效条目；
- 确认落库时才创建实际被引用的账户、分类、标签和汇率。

### 14.3 来源适配

- 钱迹：读取货币和“相对本位币汇率”，验证方向；
- 一木：读取多币种字段；真实 fixture 确认其值是代码、名称还是展示字符串；
- 薄荷：读取账户/交易货币与导出中可用的换算字段；
- Tally/支付宝/微信等无币种字段的现有来源：默认当前账本本位币，不猜符号；
- 未知代码逐行报错，不回退 CNY；
- 不凭公开截图臆造字段，必须基于用户提供或可公开验证的真实样例更新 parser/fixture。

### 14.4 CSV 模板

在现有模板末尾追加可选列，保持旧模板兼容：

```text
币种,账户金额,本位币金额,转入金额,汇率（1原币=X本位币）
```

规则：

- 缺“币种”时默认账本本位币；
- 外币交易提供“本位币金额”或“汇率”至少一项；
- 两者都提供时必须在目标币种最小单位容差内一致，否则逐行报错；
- 跨币种转账必须提供转入金额；
- 手续费继续按转出账户币种；
- CSV 固定表头和逐行错误沿用现有国际化豁免。

### 14.5 导出

本应用交易导出必须包含原币、账户金额、转入金额、本位币金额和派生汇率，避免用户导出后只剩一个
无法判断单位的 `amount`。派生汇率仅供阅读，重新导入仍以实际金额列优先。

## 15. AI、通知与 Android 小组件

### 15.1 AI 记账

- `AiEntryDraft` 增加 `currencyCode`；提示词不再说“金额单位为元”；
- AI 只能识别原币和原币金额，不能凭常识编造汇率或银行实际扣款；
- 外币草稿进入 `EntryDetailPage` 后必须由用户确认账户金额和本位币金额；
- 缺汇率时仍是草稿，不得静默落账；
- 截图原图、OCR 和隐私边界保持不变。

### 15.2 AI 查询工具

`AiToolContext` 增加当前账本本位币和必要的货币元数据。工具口径：

- 汇总/排行返回本位币金额并显式带 code；
- 交易明细同时提供原币金额，必要时提供账户/本位币金额；
- 账户余额结果保留各账户原币，不把不同币种裸加；
- 工具仍是只读纯函数，不访问 Controller，不允许修改汇率；
- 同步更新 `docs/dev/ai-tools.md` 和全部工具测试。

### 15.3 通知与小组件

- 今日支出、预算小组件使用账本本位币冻结金额；
- 总资产小组件使用当前有效汇率；缺任何必要汇率时显示本地化“汇率缺失”，不显示部分总额；
- 推送给原生侧的字符串应包含币种代码或明确的 base currency 字段；
- 跨天/跨月自愈和 Doze 调度保持现有实现，不新增汇率联网闹钟；
- 本地通知中的金额通过货币感知格式化入口生成。

## 16. 预计代码影响范围

| 领域 | 主要文件/模块 | 变更重点 |
|---|---|---|
| 模型 | `lib/app/models/*.dart`, `models.dart` | 货币/汇率模型、账本/账户/交易/周期字段 |
| 数据库 | `lib/data/app_database.dart` | 新列、新表、新迁移、索引 |
| 仓储 | `lib/data/ledger_repository.dart`, 测试内存仓储 | 汇率 CRUD、row 映射、快照、原子整替 |
| 金额数学 | `ledger_math.dart`, `series_math.dart`, `home_metrics.dart`, `report_analysis.dart` | 账户原币余额、本位币统计、缺率结果 |
| 格式化 | `amount_format.dart` 或新 `money_format.dart` | ISO minor unit、币种代码、偏好迁移 |
| Controller | `veri_fin_controller_state.dart`, `veri_fin_controller_ops.dart` | 状态、汇率解析、保存校验、旧账重解释 |
| 记账 UI | `entry_detail_page.dart`, `transaction_detail_page.dart`, `refund_editor.dart` | 三层金额、跨币转账、退款 |
| 账户/账本 UI | `account_detail_page.dart`, `ledger_books_page.dart`, 新货币页面 | 本位币/账户币种/汇率管理 |
| 报表/资产 | 首页、资产、看板、预算、图表页面 | base 统计、原币余额、缺率态 |
| 周期记账 | `recurring.dart`, `recurring_page.dart`, Controller | rate policy、缺率阻塞、补记 |
| 导入/导出 | `lib/app/backup/import/*`, 预览页 | 币种字段、问题修复、账户按币种匹配 |
| 备份 | Controller export/import、BackupService 测试、样例备份 | JSON v2 和旧版兼容 |
| AI | `lib/app/ai/*`, `docs/dev/ai-tools.md` | 币种草稿、base 汇总、原币明细 |
| Android | `home_widget_service.dart` 与原生 WidgetData/资源 | 币种标识、缺率文案；不新增网络能力 |
| 国际化 | zh/en ARB | 全部新文案 |

实施前应再次 `rg` 所有 `formatAmount`、`netAmount`、`entry.amount`、`accountBalance`、
`sumByType` 调用点，逐个标注它期待的是原币、账户币还是本位币，不能批量机械替换。

## 17. 测试计划

### 17.1 货币目录与格式化

1. CNY/USD 2 位、JPY 0 位、KWD 3 位。
2. compact/standard 两种显示风格和旧 bool 偏好迁移。
3. 零值中性色、不出现 `-0`。
4. 符号后置/代码前置偏好，单币种隐藏开/关，多币种强制带单位。
5. 账本在账户、交易、周期规则或汇率任一处出现外币时都能识别为多币种。
6. 常见汇率 4 位、极小汇率 6/8 位的展示边界，及 CSV 10 位精确往返。
7. 非法/停用/未知代码的读取与新建策略。
8. 目录 code 唯一、numeric code 格式、minor unit 合法。

### 17.2 汇率纯函数

1. 同币种恒为 1 且不查表。
2. 精确日期、向前最近记录、无记录、禁止未来记录。
3. A→B 交叉换算。
4. 极大/极小合法汇率、NaN/Infinity/0/负数拒绝。
5. 目标币种舍入顺序正确。
6. DST 时区下按日查找稳定，过期天数用日历日。

### 17.3 交易与余额

1. 同币种支出/收入结果与旧实现一致。
2. 原币≠账户币、账户币=本位币。
3. 原币=账户币、账户币≠本位币。
4. 三种币各不相同。
5. 无账户外币收支。
6. 同币/跨币/单边转账和转账手续费。
7. 修改汇率表不改变历史交易统计和账户原币余额。
8. 账户总资产按最新有效汇率折算，缺率不返回部分总额。
9. 历史资产曲线按点日期汇率，缺失点不是 0。

### 17.4 退款

1. 同币种退款保持现有行为。
2. 外币原支出退到同币账户、不同币账户、无账户。
3. 待到账不影响余额/净额，核销后按实际账户金额入账。
4. 原币累计超额拒绝。
5. 本位币因汇率波动超出原支出时净额 floor 为 0。
6. `refundedBaseAmount` 只从已到账退款 `baseAmount` 派生。
7. 聚合保存失败不更新内存，成功后冷启动一致。

### 17.5 周期记账

1. 同币规则无汇率也能生成。
2. `latestAvailable` 使用到期日或更早最近汇率。
3. `fixedAmounts` 不受汇率表修改影响。
4. 缺率不生成、不推进、显示待处理；补率后只生成一次。
5. 多账本规则读取各自本位币和汇率。

### 17.6 SQLite/Repository

1. 从每个历史 schema 版本升级到当前版本。
2. v13 CNY 数据字段回填与新库 schema 一致。
3. LedgerBook/Account/LedgerEntry/RecurringRule/ExchangeRate JSON 与 row 四向 round-trip。
4. 内存和 SQLite 仓储共跑新增汇率契约。
5. `replaceAllLedgerData` 包含汇率且失败整体回滚。
6. 交易+附件+退款+记住汇率的聚合保存原子性。
7. 删除账本清理汇率，多账本不串数据。

### 17.7 备份与导入

1. v1 纯 JSON/zip/加密备份导入为 CNY 未确认状态。
2. v2 备份完整 round-trip。
3. 样例备份真实导入并校验外币消费、跨币转账、退款和汇率。
4. 非法币种、半残金额、错误汇率不覆盖现有数据。
5. 各第三方真实 fixture 解析币种/汇率。
6. 导入缺率先预览解决，取消/排除全程零落库。
7. 同名不同币种账户不会误合并。

### 17.8 Widget/UI

1. 首次引导选择本位币，新建账本选择币种。
2. 旧账本确认 CNY、一次性重解释、取消、不可重复。
3. 已使用账户/账本币种锁定。
4. 普通 CNY 记账保持简洁；外币时逐步展开三层金额。
5. 账户切换不覆盖用户手动选择的原币。
6. 跨币转账编辑两端金额和手续费。
7. 退款核销确认实际到账金额。
8. 汇率 CRUD、日期、生效方向、过期和删除影响提示。
9. 报表显示本位币，交易列表显示原币，账户显示账户币。
10. 缺率资产总额/小组件/图表状态正确。
11. 中文/英文、浅色/深色、读屏语义和小屏布局。

### 17.9 AI 与 Android

1. AI 草稿识别 USD/JPY 等代码但不编造汇率。
2. AI 查询汇总明确本位币、明细保留原币。
3. 小组件推送包含币种，缺率显示本地化占位。
4. 冷启动、回前台、跨日/跨月自愈保持正确。
5. 不新增汇率网络请求、权限、后台任务或远程日志。

### 17.10 实施完成后的命令与真机检查

```bash
dart format .
flutter analyze
flutter test
```

另需在 Android 模拟器或真机使用 `--flavor github` 验证：旧版数据库升级、中文/英文首次引导、
外币交易、跨币转账、退款核销、周期缺率、备份恢复、桌面小组件和应用重启。
本功能不引入原生汇率 SDK；若实现阶段新增依赖或原生代码，必须重新评估 release/R8 专项。

## 18. 分阶段实施顺序

### 阶段 0：产品决策冻结

- 确认本文第 22 节待确认项；
- 获取各导入平台含多币种的真实样例；
- 确认实现时实际 schema 版本和主分支变化；
- 不在字段语义未冻结前开始 UI。

### 阶段 1：货币目录、格式化与纯数学

- 加入静态法币目录；
- 实现 minor unit 格式化、金额归一和汇率纯函数；
- 迁移金额显示偏好；
- 先用单元测试锁定方向、舍入和缺率语义。

### 阶段 2：模型、SQLite 与 Repository

- 增加模型字段和 `ExchangeRate`；
- 实施新 schema 和旧数据迁移；
- 完成 row/JSON 映射、内存仓储、SQLite 仓储和契约测试；
- 完成 `LedgerDataSnapshot` 原子整替。

### 阶段 3：Controller 与账务数学

- 加载/保存汇率；
- 重写账户余额和本位币统计入口；
- 增加多币种保存校验和旧账本重解释；
- 完成支出、收入、转账、退款的纯函数/Controller 测试。

### 阶段 4：账本、账户与汇率 UI

- 首次引导/新建账本本位币；
- 旧账本确认与重解释；
- 账户币种与锁定态；
- 汇率管理页和共享 picker/sheet；
- 更新组件注册表和中英文文案。

### 阶段 5：记账、转账、退款与周期规则

- 普通交易三层金额草稿；
- 跨币转账两端金额；
- 跨币退款与聚合保存；
- 周期汇率策略、缺率阻塞和补记；
- 完成关键 Widget 回归。

### 阶段 6：报表、预算、资产、AI 与小组件

- 全部统计改用 `baseAmount/netBaseAmount`；
- 资产原币余额与本位币估值；
- 缺率总额/图表状态；
- AI 工具、通知和小组件币种化。

### 阶段 7：导入、导出与备份

- 强类型导入字段和 conversion issues；
- 各平台真实 fixture；
- CSV 模板/导出字段；
- JSON v2、旧备份兼容和样例备份。

### 阶段 8：全量验收与文档收尾

- format/analyze/全量测试；
- Android 真机升级和关键流程；
- 同步产品、技术决策、组件、AI、验收清单和 CHANGELOG；
- 对照本文完成标准，记录最终实现差异和提交。

## 19. 风险与控制措施

| 风险 | 后果 | 控制措施 |
|---|---|---|
| `amount` 语义混用 | 账户余额或报表用错币种 | 建立显式 helper；逐个审计调用点；禁止 UI 裸算 |
| 汇率方向混乱 | 成倍错误 | 全项目固定 `1 外币 = X 本位币`；导入验证；方向测试 |
| 修改汇率重算历史 | 报表随时间漂移 | 交易冻结 `baseAmount`；汇率表只用于录入/估值 |
| 退款跨币超额 | 净支出变负或余额错误 | 原币与本位币双重校验；缓存按 base 派生并 floor 0 |
| 缺率被当 0/1 | 总资产和统计失真 | 类型化缺率结果；保存阻塞；总额不显示部分和 |
| 账户币种可随意改 | 历史余额失去单位 | 使用后锁定；旧账只允许一次原样重解释 |
| double 与多小数 | 残差/显示错位 | 按币种边界归一；汇率与金额分开精度；专项测试 |
| 旧备份覆盖新数据 | 数据丢失 | 导入前完整验证；事务整替；v1/v2/非法备份测试 |
| 导入同名账户误合 | 不同币种流水混在一起 | 账户匹配加入币种；冲突进预览映射 |
| 功能面过大 | 开发中途出现半币种状态 | 按阶段先底层后 UI；每阶段维持编译/测试可验证 |

## 20. 文档与 CHANGELOG 同步要求

实现时必须检查并按实际变化更新：

- `AGENTS.md`、`CLAUDE.md`：架构、数据流和领域不变量；
- `README.md`、`docs/product.md`：用户能力和本地离线汇率边界；
- `docs/ui-guidelines.md`：混币金额、币种选择和缺率状态；
- `docs/dev/components.md`：新增 Money/货币/汇率共享组件；
- `docs/dev/tech-decisions.md`：三层金额、冻结历史值、汇率表和备份范围；
- `docs/dev/known-limitations.md`：无在线汇率、无汇兑损益、double 存储等已接受边界；
- `docs/dev/ai-tools.md`：AI 工具币种输入输出；
- `docs/dev/verifin-sample-backup.json`：v2 多币种样例；
- `docs/acceptance-checklist.md`：多币种验收项；
- `CHANGELOG.md`：`Unreleased` 记录用户可见功能、迁移和隐私边界。

本文在实现完成后更新状态、最终字段/schema、自动化验证、真机结果和与设计的偏差。

## 21. 完成标准

- [x] 旧数据库升级后所有现有人民币数值与余额不变。
- [x] 新账本/账户可以选择支持的法币，使用后按规则锁定。
- [x] 支出/收入正确保存原币、账户金额和冻结本位币金额。
- [x] 跨币转账两端余额按真实金额变化，手续费只扣转出账户。
- [x] 跨币退款支持待到账、跨账户和实际到账金额，净额不为负。
- [x] 汇率完全离线、可按日手工维护、方向全局一致。
- [x] 修改/删除汇率不改变历史收支；资产估值按目标日有效汇率。
- [x] 缺率不猜 1:1、不静默丢数据、不显示部分总资产。
- [x] 预算、报表、首页、AI 汇总统一使用账本本位币。
- [x] 账户和交易列表保留原币信息，符号/代码样式与单币种隐藏规则可配置，聚合卡片统一标注单位。
- [x] 周期规则缺率时可见、可恢复、不会重复或跳过到期日。
- [x] 第三方导入和本应用 CSV 保留币种，预览可解决缺率。
- [x] v1/v2 备份、zip/加密、样例备份和冷启动往返通过。
- [x] 中英文、无障碍、通知和桌面小组件币种正确。
- [x] migration/model/repository/controller/widget/AI/导入/备份测试通过。
- [x] `dart format .`、`flutter analyze`、`flutter test` 全部通过。
- [ ] Android 真机完成升级、记账、退款、备份和小组件验收。
- [x] 相关文档与 CHANGELOG 已同步。

自动化验收记录（2026-08-18）：`dart format .` 完成；`flutter analyze` 为
`No issues found`；`flutter test` 共 **815** 项通过。当前环境仅检测到 Windows 与 Chrome，
没有 Android 模拟器或真机，因此最后一项保留到 GitHub CI release APK 的真机验收阶段。

## 22. 产品决策记录

用户于 2026-08-18 确认按本文推荐方案实施：

1. **支持范围**：首版只支持现行 ISO 4217 法定货币，不含加密货币、贵金属、股票和自定义货币。
2. **本位币范围**：每个账本独立一个本位币；有财务数据并确认后锁定。
3. **旧账本处理**：旧数据默认按 CNY 继续工作，但允许一次“把所有旧数字原样认作另一币种”的重解释。
4. **汇率来源**：首版只有本地手工汇率和导入文件汇率，不提供任何在线自动更新。
5. **预算口径**：所有预算都使用账本本位币，不允许每个预算单独选币种。
6. **小数显示**：使用各币种 ISO minor unit；现有“强制两位小数”迁移为“标准精度/精简尾零”。
7. **单位样式**：默认使用符号后置并隐藏单币种重复单位；用户可切换为 ISO 代码前置，或让单币种也始终带单位。
8. **汇率小数**：界面可读文本与数据精度分离；常见值显示至多 4 位，极小值自适应 6–8 位，存储/导出仍保留最高 10 位。

实施过程必须按第 18 节阶段推进，在通过与该阶段风险相称的测试后形成独立提交，不把全部改动
拖到最后一次提交；除非出现必须由用户决定的阻塞问题，开发中途不要求额外确认。

## 23. 调研来源

调研日期为 2026-08-18。外部产品会变化，实现时若依赖其导出格式，应以真实样例而不是网页描述为准。

- [钱迹：多币种](https://docs.qianjiapp.com/multiple_currency.html)
- [钱迹：汇率列表](https://api.qianjiapp.com/clientweb/currencylist)
- [钱迹 Android 更新记录（含多币种退款/报销修复）](https://docs.qianjiapp.com/change-log/change_log_android.html)
- [薄荷记账 App Store 版本记录](https://apps.apple.com/pe/app/%E8%96%84%E8%8D%B7%E8%AE%B0%E8%B4%A6-%E8%87%AA%E5%8A%A8%E8%AE%B0%E8%B4%A6/id1613127475)
- [一木记账官网](https://www.yimuapp.com/)
- [一木记账 App Store 页面](https://apps.apple.com/jp/app/%E4%B8%80%E6%9C%A8%E8%AE%B0%E8%B4%A6-%E6%99%BA%E8%83%BD%E8%AF%AD%E9%9F%B3%E8%AE%B0%E8%B4%A6/id1572969723)
- [Spendee：主币种、钱包币种、交易币种与汇率](https://help.spendee.com/article/231-how-to-setchange-the-currency-and-exchange-rate)
- [Toshl：多层币种与历史汇率](https://toshl.com/currencies/)
- [Wallet：多币种与汇率](https://support.budgetbakers.com/hc/en-us/articles/7149418777746-Multiple-Currencies-Exchange-Rates)
- [MoneyWiz：货币管理与本地/报表币种](https://help.wiz.money/en/articles/4440671-how-to-enable-disable-and-manage-currencies)
- [MoneyWiz：旅行与账户币种](https://help.wiz.money/en/articles/4440698-how-to-manage-travel-money-wallet)
- [GnuCash：Multiple Currencies](https://code.gnucash.org/website/docs/v2.6/C/gnucash-guide/chapter_currency.html)
- [ISO 4217：货币代码与 minor unit](https://www.iso.org/iso-4217-currency-codes.html)
- [SIX：ISO 4217 维护机构与更新](https://www.six-group.com/en/products-services/financial-information/market-reference-data/data-standards.html)
