# 多币种与离线汇率

Veri Fin 不接入在线汇率服务，也不为多币种引入账号、服务器或后台联网。本文件是多币种金额语义、汇率口径、迁移和验收的当前依据；实现细节以源码与测试为准。

## 术语与汇率方向

- **本位币（base currency）**：一个账本用于预算、收支统计、总资产和报表的统一币种。
- **账户币种（account currency）**：账户余额、初始余额、信用额度和手续费所属币种。
- **原币/交易币种（transaction currency）**：商户标价、现金收付或用户希望保留的原始币种。
- **原币金额（original amount）**：交易原始金额，对应 `LedgerEntry.amount`。
- **账户金额（account amount）**：银行/钱包实际扣款或入账金额，对应账户币种。
- **转入金额（target amount）**：转账目标账户实际收到的金额，对应目标账户币种。
- **本位币金额（base amount）**：该笔收支在记账当时折算并冻结的本位币金额。
- **冻结**：保存交易后不随汇率表变化而重算。
- **重解释**：只把旧数字认作另一种币种，不做乘除换算；仅用于旧账本的一次性校正。

汇率方向全应用固定为 `rateToBase = 1 单位外币值多少单位本位币`（账本本位币 CNY、1 USD = 7.20 CNY 时 `USD.rateToBase = 7.20`）。UI、模型、导入和测试不得在不同页面使用相反方向。

## 核心领域不变量

以下不变量由模型校验、Controller、导入器和测试共同保护：

1. 一个账本恰有一个本位币；账本内账户、交易、汇率均按 `bookId` 隔离。
2. 一个普通账户恰有一个账户币种。
3. 币种使用大写 ISO 4217 三字母代码；未知、停用或不在目录的代码不能新建数据。
4. 所有业务金额必须为有限正数；零值只用于明确的“不适用”字段，不能表示缺失。
5. 支出、收入和退款保存前必须有正数 `baseAmount`；转账的 `baseAmount` 恒为 0。
6. 有来源账户时必须有 `accountAmount`；无账户时 `accountAmount == null` 且 `fee == 0`。
7. 有转入账户的转账必须有 `toAccountAmount`；无转入账户时该字段为 null。
8. 手续费永远属于转出账户币种，并只影响转出账户余额。
9. 交易本位币金额保存后冻结；修改汇率表不改写任何历史交易。
10. 汇率表中本位币对自身的汇率恒为虚拟值 1，不落库。
11. 某日汇率只能使用该日或更早的记录，不能从未来日期倒灌。
12. 退款条目的原币必须与原支出原币一致；退款到账账户可以与原支出账户不同币种。
13. 退款只在 `settledAt != null` 时影响账户余额和原支出本位币净额。
14. 转账仍不计收入/支出；汇兑差额和手续费造成的净资产变化不伪装成普通收支。
15. 预算全部以账本本位币保存，仍按默认预算/单期覆盖规则工作。
16. 缺少资产估值汇率时，总资产显示“无法完整折算”，不能返回一个看似完整的部分和。
17. 旧 CNY 数据迁移后数值、余额、净额、预算和排序保持不变。

## 领域模型

### 货币目录 `CurrencyDefinition`

`lib/app/models/currency.dart` 定义 `CurrencyDefinition`（`code` / `numericCode` / `nameZh` / `nameEn` / `symbol` / `minorUnit`）；`lib/app/currency_catalog.dart` 提供静态目录、查找、搜索与常用排序；`lib/app/currency_math.dart` 提供归一化、换算、汇率查找和结果类型。目录随安装包提交，不在运行时联网获取，以 ISO 4217 现行法定货币为准。

- 排除资金代码、贵金属、测试代码、无通用货币代码、历史停用币种和加密货币；
- 货币符号可能重复（如 `$`、`¥`），选择器和混币页面必须显示三字母代码；
- 更新目录时提交来源日期和差异测试，不能只改中文名或符号而漏改 minor unit；
- 已存在于用户数据但后来被目录停用的币种必须可读、可展示、可导出，但不再允许新建。

### 账本 `LedgerBook`

字段 `baseCurrencyCode` 与 `currencySetupStatus`（`legacyUnconfirmed` / `confirmed`）。

- 新安装在首次引导中明确选择本位币，新账本创建时也必须选择；中文首次引导预选 CNY、英文预选 USD，用户保存前可更改；
- 新建账本默认预选当前账本本位币，不无提示猜测地区币种；
- 旧账本迁移为 `CNY + legacyUnconfirmed`，继续按人民币行为运行，用户首次进入货币设置或创建外币账户时确认旧金额含义；
- 账本确认且已有财务数据后本位币锁定。「已有财务数据」至少包括：交易、非零初始余额、信用额度、预算、周期规则或汇率记录。纯空账本可以更改本位币，更改时一并更新所有零值空账户币种并清空无意义汇率记录。

### 账户 `Account`

字段 `currencyCode`。`initialBalance`、`creditLimit`、当前余额、信用卡已用/可用额度都以账户币种计算；`includeInAssets` 只决定是否进入总资产，不改变原币余额。账户有任一关联交易，或存在非零初始余额/信用额度后币种不可直接修改；用户需要另一币种时新建账户。删除账户、删除账本和导入映射继续清理/验证全部引用。

### 汇率 `ExchangeRate`

`ExchangeRateSource`（`manual` / `imported`）。字段含 `id`、`bookId`、`baseCurrencyCode`、`currencyCode`、`effectiveDate`、`rateToBase`、`source`、`createdAt`、`updatedAt`。

- `effectiveDate` 是本地日历日，SQLite 存 `yyyy-MM-dd` 文本，避免时区/DST 偏移；
- `rateToBase` 必须有限且大于 0；
- 一个账本、一个本位币、一个外币、一个日期只有一条生效记录；手工保存覆盖同日记录时更新 `updatedAt`；
- 导入文件携带的汇率默认只服务该批交易，只有用户选择“保存为当日汇率”才写入汇率表；
- 删除汇率不改历史交易，但可能使资产估值或待生成周期交易缺少汇率，删除前提示影响；
- 不保存同币记录（如 CNY→CNY）。

### 交易 `LedgerEntry`

`amount` 表示**原币金额**，另有 `currencyCode`、`accountAmount`、`toAccountAmount`、`baseAmount` 与 `conversionSource`（`identity` / `manual` / `rateTable` / `imported` / `legacy`）。不在交易上单独持久化一个可变汇率作为唯一事实；展示汇率由已保存的真实金额相除得到，余额始终以账单真实金额为准。

| 类型 | `amount/currencyCode` | `accountAmount` | `toAccountAmount` | `baseAmount` |
|---|---|---|---|---|
| 支出 | 商户/现金原始支出 | 来源账户真实扣款；无账户为 null | null | 冻结本位币支出 |
| 收入 | 原始收入 | 来源账户真实入账；无账户为 null | null | 冻结本位币收入 |
| 转账（双边） | 转出金额/转出币种 | 转出账户真实减少额 | 转入账户真实增加额 | 0 |
| 转账（仅转出） | 转出金额/转出币种 | 转出账户真实减少额 | null | 0 |
| 转账（仅转入） | 转入金额/转入币种 | null | 转入账户真实增加额 | 0 |
| 退款 | 原支出币种中的退款额 | 到账账户真实增加额；无账户为 null | null | 冻结本位币冲抵额 |

原支出缓存 `refundedBaseAmount`：Controller 派生缓存，不接受 UI 任意提交，等于关联且已到账退款的 `baseAmount` 之和并钳制到原支出 `baseAmount`；SQLite 复用 `refunded_amount` 列；JSON 输出 `refundedBaseAmount`，读取时兼容旧 `refundedAmount`。统计使用 `netBaseAmount = baseAmount - refundedBaseAmount`；账户余额从不读取该缓存，仍由支出全额扣款和退款独立入账共同构成。

### 周期规则 `RecurringRule`

包含与交易模板对应的币种/金额字段和 `ratePolicy`（`latestAvailable` / `fixedAmounts`）：

- `latestAvailable`：每个到期日按该日或更早的最新本地汇率重新计算账户/本位币/转入金额；
- `fixedAmounts`：每次复用规则保存时的各端金额，适合固定结算价合同；
- 同币种规则不需要汇率，两种策略结果相同；
- 缺少必要汇率时不生成残缺交易、不推进 `nextRunDate`，产生可见的“待补汇率”状态；用户补齐汇率后执行补记，确定性 entry id 防重复；
- 旧周期规则迁移为 CNY、`fixedAmounts`。

### 预算

月度预算、分类预算和每日预算全部使用账本本位币，SQLite 表与键规则不变：默认预算与单期覆盖优先级不变；自定义预算周期只改变预算窗口，不改变币种；交易占用预算使用 `netBaseAmount`。

## 换算、舍入与历史口径

### 基础换算

```text
rate(A → B) = rateToBase(A) / rateToBase(B)
amountB = amountA × rateToBase(A) / rateToBase(B)
```

本位币的虚拟 `rateToBase` 恒为 1。

### 汇率查找

```text
resolveRate(bookId, currencyCode, date)
  1. currencyCode == baseCurrencyCode → 1
  2. 查 effectiveDate == date
  3. 否则查 effectiveDate < date 中最近的一条
  4. 没有 → null
```

绝不使用未来日期记录；当前资产估值使用“今天或更早的最新一条”，历史资产曲线的某个点使用“该点日期或更早的最新一条”。始终展示汇率生效日期，超过 30 个日历日可标记“可能已过期”但仍由用户决定是否使用；30 天判断使用 `calendarDaysBetween`。

### 舍入

底层沿用 `double` / SQLite `REAL`（见 [known-limitations.md](known-limitations.md) L5），所有边界按币种 minor unit 归一化：

- JPY/VND 等 0 位、CNY/USD/EUR 等 2 位、KWD/BHD/OMR 等 3 位；
- 换算先使用未舍入汇率计算，最后只对目标金额按目标币种舍入；
- 汇率本身保留更高精度，不调用金额的 minor-unit 舍入；
- 金额比较容差由对应币种最小单位推导，不全局写死 `0.0001/0.005`；
- NaN、Infinity、非正汇率和溢出结果一律拒绝。

### 历史交易与当前资产

- **收支历史**：使用交易保存时冻结的 `baseAmount`，修改汇率表不改历史报表。
- **资产估值**：先在账户币种中计算真实余额，再用目标日期有效汇率折算本位币。

同一笔外币收入保存时计入的本位币金额，与今天账户余额的估值可以不同；差额属于汇率变化，不作为普通收入，也不单列汇兑损益。

## 各交易类型的数学口径

### 支出

```text
账户增量 = -accountAmount（有账户时）
统计支出 = baseAmount - refundedBaseAmount
```

例：美国消费 10 USD，人民币信用卡实际扣 72.35 CNY，账本本位币 CNY → `amount = 10 USD`、`accountAmount = 72.35 CNY`、`baseAmount = 72.35 CNY`。

### 收入

```text
账户增量 = +accountAmount（有账户时）
统计收入 = +baseAmount
```

### 转账

```text
转出账户增量 = -(accountAmount + fee)
转入账户增量 = +toAccountAmount
收支统计 = 0
```

例：转出 100 USD、转入 720 CNY、手续费 1 USD，保存 100/720/1 三个事实，展示汇率由 `720 / 100 = 7.2` 派生。同币种转账两端金额相等；同账户转账保留“只损失手续费”的既有数学行为。

### 退款/报销回款

- `currencyCode` 强制等于原支出 `currencyCode`；`amount` 是原支出币种中的退款份额；`accountAmount` 是退款账户实际收到的金额；`baseAmount` 是本次冲抵的冻结本位币金额；
- 待到账退款可先保存预计值，核销为已到账时再次确认实际到账金额和本位币金额；
- 全部退款（含待到账）的原币 `amount` 合计不得超过原支出 `amount`；
- `refundedBaseAmount` 只累计已到账退款并钳制到原支出 `baseAmount`；因汇率变化导致到账本位币价值高于原支出时，超出部分不把净支出变成负数，也不生成人工“汇兑收益”交易；
- `saveEntryAggregate` 在一个提交边界内校验原支出、全部退款和附件，并按退款 `baseAmount` 重算缓存。

### 无账户交易

无账户交易仍计入收支，但不影响余额：原币等于本位币时 `baseAmount = amount`；原币不同于本位币时用户必须输入本位币金额或有效汇率；`accountAmount == null`；不得用首账户币种解释空 `accountId`。

## UI 与交互

### 首次安装与新建账本

首次引导增加“账本本位币”选择（说明“预算、统计和总资产将统一显示为此币种”），选择器支持代码/中英文名搜索；新建账本表单同时选择名称与本位币；空账本可在账本设置中更改本位币，有财务数据后显示锁定说明和“新建另一账本”建议。

### 旧账本一次性确认

旧账本不在升级启动时强制弹窗。用户首次进入货币设置或创建外币账户时显示一次确认：① 现有金额就是人民币（确认 CNY，不改数字）；② 现有金额其实是其他币种（选择币种，把账本、账户、交易、预算和周期规则的数字原样解释为该币种）；③ 稍后处理（保持 `legacyUnconfirmed`，不能新增外币数据）。“重解释”使用 `replaceAllLedgerData` 同一 SQLite 事务完成，操作前展示受影响数量并二次确认“数值不会换算”，确认后不可再次重解释。

### 账户编辑

账户编辑页有“币种”行，使用统一货币选择器；初始余额、信用额度、当前余额旁显示账户币种代码；已使用账户的币种行只读，点击显示锁定原因；账户选择器的余额使用账户原币显示，混币列表必须带单位并遵循符号/代码样式。

### 汇率管理页

入口在“我的 → 数据与工具 → 货币与汇率”，作用于当前账本：顶部显示账本本位币；列表展示账户/交易涉及的外币，可搜索并添加任意支持法币；每行显示 `1 USD = 7.20 CNY`、生效日期、来源和是否过期；点击行进入该币种历史记录；新增/编辑使用日期选择器 + 数字键盘；删除使用 `showConfirmDialog(..., destructive: true)`。页面无“刷新”或联网状态；页头问号通过只读弹窗说明“汇率保存在本机，由你维护”及历史交易冻结口径。

### 普通交易录入

金额输入区有币种按钮：默认原币为已选账户币种，无账户时默认账本本位币；切换账户时只有用户尚未手动改过币种才跟随新账户；三层币种都相同时与单金额体验一致；原币与账户币不同时出现“账户实际扣款/入账”行；原币与本位币不同时出现“计入账本”行和汇率说明。用户可以编辑汇率，也可以直接编辑实际账户金额/本位币金额；草稿记录最后编辑字段，避免互相反算的反馈循环；“记住为当日汇率”默认关闭。

### 跨币种转账

转出/转入账户确定两端币种：同币种只显示一个金额、转入金额自动相等；不同币种同时显示“转出金额”“转入金额”和派生汇率，可编辑转入金额或汇率，最后以两端金额为保存事实；手续费显示转出账户币种；单边转账继续支持未跟踪的外部账户，页面明确标注哪一端不计入资产。

### 退款编辑

退款原币沿用原支出，不允许任意切换；显示原支出原币剩余可退金额；选择退款到账账户后显示该账户实际到账金额；本位币冲抵额单独显示；待到账转已到账时再次确认实际到账金额；原支出详情同时展示原币退款进度和本位币净支出。

### 周期记账

规则编辑页显示“每次使用最新本地汇率”与“固定当前金额”选项；缺汇率的到期规则不静默跳过，在首页/周期记账页显示待处理数量；用户补率后可点“立即补记”；同一到期日以确定性 id 防重复；生成失败不推进日期，持久化失败记录日志并给用户可见反馈。

### 列表、报表和资产展示

金额单位样式、单币种隐藏、混币列表、报表本位币、账户原币、缺率状态和图表交互遵循 [design-system.md](../design-system.md) 的「货币单位的显示口径」与 [components.md](components.md) 的族 5/7：

- 设置页可选符号后置（`100 ¥`）或代码前置（`CNY 100`），默认符号后置；单币种账本默认隐藏重复单位，多币种或关闭隐藏时显示；
- 报表、预算、首页概览/日历/收支指标、AI 结果统一使用账本本位币；账户卡片显示原币余额，资产总览显示本位币折算值和汇率日期；
- 缺资产汇率时总资产显示缺率状态和“有 N 个账户待设置汇率”，不显示部分总额；历史资产图缺某日折算率时显示断点/缺失态，不把缺失值画成 0；
- 图表使用 `InteractiveTrendChart`/`InteractiveBarChart`，点按信息遵循同一单位样式与隐藏规则。

### 金额格式化

`formatMoney` 是显式选择 code/symbol/none 的底层与机器文本入口；UI 优先使用 `formatUserMoney` / `formatSignedUserMoney`，由 Controller 同步的全局偏好决定符号/代码及单币种隐藏。`forceUnit: true` 只用在同一控件同时展示两个币种的换算字段。`CurrencyFractionStyle`（`compact` / `standard`）控制小数风格；JPY 两种模式都是 0 位，KWD 最多/固定 3 位；金额为零使用中性色且不显示 `-0`。汇率展示精度与保存精度分离：`formatRateValue` 常见值 4 位、极小值自适应 6/8 位，CSV 用 `formatRateValueExact` 保留最高 10 位。完整口径见 [design-system.md](../design-system.md)。

### 国际化与无障碍

新增文案同步写入 `app_zh.arb`、`app_en.arb`；货币代码不翻译，货币名称按当前 app locale 选择；汇率语句读成“1 美元等于 7.2 人民币”；输入框语义标签说明币种和用途；系统日期选择器跟随 app locale；不使用国旗代表货币。

## SQLite 与迁移

当前 `AppDatabase.schemaVersion` 为 **17**。多币种相关的表结构（`ledger_books.base_currency_code`/`currency_setup_status`、`accounts.currency_code`、`entries` 的 `currency_code`/`account_amount`/`to_account_amount`/`base_amount`/`conversion_source`、`recurring_rules` 的币种/金额列与 `rate_policy`、`exchange_rates` 表与索引）以 `lib/data/app_database.dart` 的 `_schemaCurrent` 和迁移段为准。

修改表结构必须：提升 `schemaVersion`、同步 `_schemaCurrent`、在 `_migrations` 注册新迁移段、更新 `test/migration_matrix_test.dart`、更新模型四向映射与 `test/model_roundtrip_test.dart`、更新内存/SQLite 仓储契约测试。

v13→v14 迁移把旧账本/账户/交易/周期规则解释为 CNY：账本 `base_currency_code = CNY`、`currency_setup_status = legacyUnconfirmed`；有 `account_id` 的交易 `account_amount = amount`，转账有 `to_account_id` 时 `to_account_amount = amount`；支出/收入/退款 `base_amount = amount`，转账 `base_amount = 0`；`conversion_source = legacy`；周期规则 `rate_policy = fixedAmounts`。基础列回填在 SQLite 迁移段中完成，Controller 载入自愈只处理跨实体语义校验。

SQLite 层不表达全部跨表币种约束，Controller 保存前仍校验：账户/交易/汇率属于同一账本；`baseCurrencyCode` 与账本一致；交易账户金额币种由关联账户决定；退款与原支出币种一致；汇率 code 合法且不等于本位币；日期键格式严格为 `yyyy-MM-dd`。

## Repository 与 Controller

`LedgerRepository` 提供 `loadExchangeRates()` / `saveExchangeRates()`，并把 `exchangeRates` 纳入 `LedgerDataSnapshot`、`replaceAllLedgerData` 和内存仓储。SQLite 实现中 `exchange_rates` 走 `_incrementalReplace`，外部语义仍为“落库后表内容等于传入列表”；删除账本删除对应汇率；单笔交易与“记住当日汇率”、退款、附件在同一事务中提交。落库策略见 [tech-decisions.md](tech-decisions.md)。

Controller 持有当前账本的汇率列表与不可变派生视图（新增派生缓存时同步在 `_invalidateDerivedViews` 清空），提供窄 API：当前账本/本位币/币种定义读取、按账户读取原币余额、按日期解析汇率/交叉汇率、保存/删除汇率草稿、计算资产折算结果、保存多币种交易聚合草稿、确认/重解释旧账本币种、查询账户/账本币种是否可修改、周期规则缺汇率状态和重试。UI 不拼汇率键、不直接访问 SQLite、不自行形成另一套换算算法。

换算结果用强类型表达「成功」与「缺失」：单笔结果由 `lib/app/currency_math.dart` 的 `CurrencyConversionResult` / `ConvertedCurrencyAmount` / `MissingCurrencyRate` 表达；账户总额类型为 `ConvertedAccountBalances`，字段 `completeTotal`，只有 `missingCurrencyCodes` 为空时 `completeTotal` 才可展示为完整总额，同时返回缺失币种和受影响账户。

## 备份、恢复与初始化

明文 JSON 根字段 `version` 当前为 **3**（zip/加密信封字节格式见 [tech-decisions.md](tech-decisions.md)）。v3 备份携带：`ledgerBooks[].baseCurrencyCode`/`currencySetupStatus`、`accounts[].currencyCode`、`entries[]` 三层金额与 `conversionSource`、`recurringRules[]` 币种字段与 `ratePolicy`、`exchangeRates[]`、金额显示偏好枚举。v1/v2 旧备份按旧数据迁移规则解释为 CNY 并标 `legacyUnconfirmed`，允许一次无换算重解释；未知字段容忍，非法币种/金额拒绝并保持现有数据不被覆盖。货币静态目录不进备份。完整备份范围见 [tech-decisions.md](tech-decisions.md)，样例见 `docs/dev/verifin-sample-backup.json`。

“初始化数据”清除账目时一并清除汇率表；设备本地的语言、备份凭证、AI Key 等仍按现有规则保留/清除。

## 第三方导入与本应用 CSV

`RawImportRecord` 携带 `currencyCode`、可空 `accountAmount`、`toAccountAmount`、`baseAmount`、`rateToBase` 与汇率来源/日期；`RawImportAccount` 携带 `currencyCode`，账户按“名称 + 币种”匹配，同名不同币种不误合并。

导入解析与预览零落库副作用。外币记录缺少完整折算信息时不构造违反不变量的 `LedgerEntry`，`ImportPlan` 保留可定位的 `conversionIssues` 和原始强类型记录；预览页允许批量选择已有日期汇率、手工输入汇率或排除这些记录，解决后重新运行 `plan_builder`，确认落库时才创建实际引用的账户、分类、标签和汇率。

各来源读取真实样例中确认存在的币种/汇率字段（钱迹、一木、薄荷、Tally 等）；无币种字段的来源默认当前账本本位币，不猜符号；未知代码逐行报错，不回退 CNY；不凭公开截图臆造字段。

本应用 CSV 模板在末尾追加可选列 `币种,账户金额,本位币金额,转入金额,汇率（1原币=X本位币）`，保持旧模板兼容：缺“币种”默认账本本位币；外币交易提供“本位币金额”或“汇率”至少一项；两者都提供时必须在目标币种最小单位容差内一致，否则逐行报错；跨币种转账必须提供转入金额；手续费按转出账户币种。导出包含原币、账户金额、转入金额、本位币金额和派生汇率，重新导入以实际金额列优先。

## AI、通知与小组件

- `AiEntryDraft` 含 `currencyCode`；AI 只识别原币和原币金额，不编造汇率或银行实际扣款；外币草稿进入 `EntryDetailPage` 后由用户确认账户金额和本位币金额；缺汇率时仍是草稿，不静默落账；
- AI 查询汇总使用账本本位币冻结金额，明细保留原币；摘要与结果卡片的币种标识跟随 `AiToolContext.currencyDisplay`（见 [ai-tools.md](ai-tools.md)）；
- 桌面小组件与通知的金额使用账本本位币冻结金额，总资产使用当前有效汇率；缺必要汇率时显示本地化“汇率缺失”，不显示部分总额；推送包含币种标识；不新增汇率联网闹钟。

## 风险与控制

| 风险 | 后果 | 控制 |
|---|---|---|
| 用汇率反推而非保存真实金额 | 银行结算舍入或特殊价被覆盖 | 交易保存原币/账户/本位币三个事实 |
| 修改汇率重算历史 | 报表随时间漂移 | 交易冻结 `baseAmount`；汇率表只用于录入/估值 |
| 账户币种可随意改 | 历史余额失去单位 | 使用后锁定；旧账只允许一次原样重解释 |
| 缺率按 1:1 猜测 | 静默错误的账 | 返回强类型缺失状态，阻止保存或显示缺率 |

## 测试范围

- **货币目录与格式化**：CNY/USD 2 位、JPY 0 位、KWD 3 位；compact/standard 与旧 bool 偏好兼容；零值中性色；符号/代码样式与单币种隐藏；CSV 10 位精确往返。
- **汇率纯函数**：同币恒为 1；精确日期/向前最近/无记录/禁未来；交叉换算；非法汇率拒绝；DST 下按日查找稳定，过期天数用日历日。
- **交易与余额**：同币与原币≠账户币≠本位币各组合；无账户外币收支；同币/跨币/单边转账与手续费；修改汇率表不改历史统计和账户原币余额；缺率不返回部分总额。
- **退款**：外币退到同币/异币/无账户；待到账不影响余额净额、核销后生效；原币超额拒绝；`refundedBaseAmount` 只从已到账退款派生；聚合保存失败不更新内存、成功后冷启动一致。
- **周期记账**：同币规则无汇率可生成；`latestAvailable` 用到期日或更早汇率；`fixedAmounts` 不受汇率表修改影响；缺率不生成不推进、补率后只生成一次。
- **SQLite/Repository**：每个历史 schema 版本升级到当前；v13 CNY 数据回填；模型 JSON/row 四向 round-trip；内存与 SQLite 共跑汇率契约；`replaceAllLedgerData` 含汇率且失败整体回滚；交易+附件+退款+记住汇率的聚合保存原子性；删账本清汇率、多账本不串数据。
- **备份与导入**：v1/v2 旧备份导入为待确认 CNY；v3 完整 round-trip；样例备份真实导入；非法数据不覆盖现有数据；同名不同币种账户不误合并。
- **UI**：首次引导/新建账本选本位币；旧账本确认与一次性重解释；已使用币种锁定；原币/账户/本位币三层金额；跨币转账两端金额与手续费；退款核销；汇率 CRUD 与影响提示；报表本位币、交易原币、账户账户币；缺率状态；中英文、浅深色、读屏与小屏。
- **AI 与 Android**：AI 草稿识别币种但不编造汇率；AI 查询汇总本位币、明细原币；小组件缺率占位；冷启动/回前台/跨日跨月自愈；不新增汇率网络请求或权限。

提交前执行 `dart format .`、`flutter analyze`、`flutter test`；并在 Android 真机上验证旧库升级、外币交易、跨币转账、退款核销、周期缺率、备份恢复和桌面小组件。
