# 退款与报销

退款是挂在原支出上的独立条目，与「报销」共用同一套机制。模型见 `lib/app/models/ledger_entry.dart`，数学见 `ledger_math.dart`，UI 见 `refund_editor.dart`、`pending_refunds_page.dart`。

## 数据模型

- `EntryType.refund`；`refundOf` 指向原支出 `id`（必填），`settledAt` 为到账日期（`null` = 待到账）。
- 三层金额：`amount`/`currencyCode` 保存退款原币，`accountAmount` 保存实际入账账户金额，`baseAmount` 保存冻结的本位币冲减金额。
- 到账账户 `accountId` 可与原支付账户不同；`occurredAt` 为发起日期；`note` 为备注。
- 原支出缓存 `refundedBaseAmount = Σ已到账退款.baseAmount`，是派生缓存。

## 金额口径

- 只有「已到账」（`settledAt != null`）的退款影响账户余额与原支出净额；待到账退款不进余额、不进净额、不进收支统计，只进「待退款」清单。
- 统计使用 `netBaseAmount = max(baseAmount - refundedBaseAmount, 0)`；账户余额使用退款自己的 `accountAmount`。
- 退款不计收入，冲减原支出所在月份与分类；余额/资产趋势按退款 `settledAt` 生效，收支统计按原支出 `occurredAt`。
- 禁止超额：Σ退款不得超过原金额，超出时提示并截到「剩余可退」。

## 生命周期

- 退款只能从「原支出 → 添加退款」创建；普通记账页的类型选择器排除 `refund`。
- 删除原支出级联删除其退款；删除单笔退款后原支出净额恢复。
- 编辑原支出金额低于已退合计时净额下限为 0，并在界面提示。

## 界面

- 原支出详情页的「退款」区列出每笔退款（金额/到账账户/状态/日期/备注）并可添加多笔；每笔可点开编辑。
- 交易详情中的退款随父交易草稿、附件一起经 `saveEntryAggregate` 原子保存；待退款清单核销是独立明确命令。
- 退款明细在原支出与「待退款」清单中管理，当前不进入通用交易时间线，也不提供退款自身的附件入口（见 [known-limitations.md](known-limitations.md) L2）。

## 生成与迁移

- 账单导入在 plan 阶段按原币、到账账户币种和本位币分别生成关联退款。
- 旧标量退款数据按原支出三层金额比例合成为关联退款。
- 退款随交易进入备份 JSON；`refundOf`、`settledAt` 参与序列化。

## 验收

- 单笔/多笔部分退款、全额退款的净额与余额；跨账户退款原账户扣全额、到账账户加退款。
- 待到账退款不进余额/净额/统计，标记已到账后才生效。
- 超额拦截、级联删除、删除退款后净额恢复。
- 备份 round-trip（含待到账退款）一致。
- 退款原币上限与本位币净额分别计算；外币退款遵循 [multi-currency-design.md](multi-currency-design.md)。
