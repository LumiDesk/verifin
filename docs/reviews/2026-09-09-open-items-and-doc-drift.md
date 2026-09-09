# 未完成事项与文档漂移核查（2026-09-09）

> 核查日期：2026-09-09<br>
> 基线：`f5eab4a`（= `main`），分支 `talyra42/ui-component-evaluation`<br>
> 核查方式：只读。7 个分域核验并行逐条对照源码 / Gradle / CI / 测试，**不修改任何实现**。<br>
> 触发原因：用户问「为什么还有当前在办？当前还有什么没弄」，并要求随后统一整理文档。

本文件是「未完成事项」与「文档漂移」的**可复核清单**，也是后续统一整理文档的输入。它本身是一次性记录，整理落地后可删除或并入台账。

> **整改进度（2026-09-09）**：核查之后已落地的修复。
>
> | 条目 | 状态 | 提交 |
> | --- | --- | --- |
> | 性能 P2-11 图表 painter 身份比较（3 处） | 已修 | `675ac92` |
> | 产品 P2-3 记账页负号（U+2212 + 空格 → ASCII） | 已修 | `52b4aa2` |
> | 产品 P2-13 退款编辑弹层不可滚动 | 已修 | `52b4aa2` |
> | 产品 P2-11 附件删除 | 部分：补了长按删除；热区仍 28×28 | `52b4aa2` |
> | 产品 P2-12 搜索「退款」 | 部分：补了同义词；✕ 清全部筛选与范围提示未改 | `52b4aa2` |
> | 性能 P2-12 预算快照分类索引 | 已修 | `56f989f` |
> | 性能 P2-13 预算页 6 次全表扫描 | 已修 | `56f989f` |
> | 工程 `dart format` 门禁缺失（`flutter.yml`） | 已修 | `f1faa7b` |
> | 工程两个设计测试不在 PR/main CI 执行 | 已修（并入 release materials 列表） | `f1faa7b` |
> | 工程版本号三方一致性无校验 | 已修（新增 `test/version_consistency_test.dart`） | `dc1ba5a` |
> | 工程样例备份缺 2 个字段 | 已修 | `dc1ba5a` |
> | 工程 `test_harness.dart` 注释指向不存在的目录 | 已修 | `dc1ba5a` |
> | 其余 §2 条目 | 未修 | — |
>
> 注：§2.2 里「搜索框 ✕ 清掉全部筛选」经核实是**有意行为**（tooltip 为「清空筛选」，`entries_test.dart` 依赖它复位筛选），不作为缺陷整改。

---

## 1. 「在办」的真实构成

此前的「当前在办」清单混了五类性质完全不同的东西。只有 **1.1** 是需要写代码的工作。

| 类别 | 含义 | 处理方式 |
| --- | --- | --- |
| 1.1 真正待做 | 有代码证据、确实没实现 | 排期修 |
| 1.2 假「在办」 | 文档状态表过期，代码里已经修了 | 只改文档 |
| 1.3 真机/授权闭环 | 代码没得改，只能验 | 需要设备与授权 |
| 1.4 有意接受 | 已定阈值、明确不打算做 | 不动 |
| 1.5 待拍板 | 等你确认后才能收尾 | 需决策 |

---

## 2. 真正待做（1.1）

### 2.1 性能 —— 状态表准确，无一条被静默修掉

`docs/reviews/2026-09-08-performance-audit.md` 的整改状态表经逐条核对**仍然准确**。

| 条目 | 现状 | 证据 |
| --- | --- | --- |
| P0-1a `computeHomeMetric` 5 次全表扫描未合并 | 未修 | `lib/app/home_metrics.dart:280-343`（每个指标一次 `_sum`） |
| P0-1b `PageView` 未保活 | 未修 | `lib/pages/shell.dart:164`（无 `allowImplicitScrolling`，全仓无 `AutomaticKeepAliveClientMixin`） |
| P1-9 高频偏好仍全树广播 | 未修（仅 4 个 ValueNotifier，全是基线已有） | 触感 `_ops.dart:969-977`、`fab_action` `:982-989`、`home_metrics` `:992-1001`、资产视图模式 `:1542-1547`、折叠分区 `:1563-1574`、面板配置 `:1698-1747` |
| P2-10 `notifyListeners()` 内 O(E) 扫描 | 未修 | `lib/app/veri_fin_controller_state.dart:245-264` |
| P2-11 三处 `CustomPainter` 身份比较 | 未修 | `reports_page.dart:887-889,959-961`、`budget_trend_chart.dart:350-354` |
| P2-12 每条支出重建分类索引 | 未修 | `budget_snapshots.dart:146-162` → `category_tree.dart:46-58` |
| P2-13 预算页 6 次全表扫描 | 未修 | `budget_snapshots.dart:119-131`、`budget_pages.dart:114-118` |
| P2-14 冷启动首帧前串行 5 个 await | 未修 | `lib/main.dart:34,48,49,71,72` |
| P2-15 玻璃 painter 每次 paint 大量分配 | 未修 | `glass_lighting.dart:49-104`、`navigation_glass_lens.dart:73-197` |
| P2-16 逐键 / 逐滚动 `setState` | 未修 | `profile_info_page.dart:45-48,230-233`、`add_account_page.dart:30-34,238-241`、`transactions_pages.dart:260-265` |

**文档路径漂移**：审计文写 `lib/app/budget_snapshots.dart` / `lib/app/budget_trend_chart.dart`，实际在 `lib/pages/` 下。

### 2.2 产品与交互

| 条目 | 现状 | 证据 |
| --- | --- | --- |
| P1-7 对比度不达 AA | 未修 | `app_theme.dart:41,46,47,48` 四个语义色仍是单一常量；弱化文字 alpha 仍 0.30–0.48 |
| P1-8 触控目标 | 部分：只改了对话框按钮 `Size(48,44)` | `IconButton` 40×40 `app_theme.dart:101-107`；`CompactSwitchRow` 整行不可点 `common_widgets_forms.dart:185-221`；`FilterPill` 36dp `common_widgets_display.dart:53`；分类子级浮标 18×18 `entry_detail_page.dart:2257-2259` |
| P1-11 跨币种还款缺汇率入口 | 部分：资产页缺率卡已可点，还款页仍无 | `assets_pages.dart:379-384`（已修）vs `credit_repayment_page.dart:148-159,259-274`（未修） |
| P2-3 记账页负号是全应用独一份 | 未修 | `entry_detail_page.dart:694-697`（U+2212 + 空格）vs `ledger_math.dart:288,299` |
| P2-5 锚点菜单行高写死 | 未修 | `common_widgets_menu.dart:103-105`（50/58/9） |
| P2-9 轻提示截断 / 无恢复 / 无播报 | 未修 | `feedback.dart:642-643`（`maxLines: 3`）；全仓 `liveRegion` 零命中；`actionLabel` 仅 1 处 |
| P2-10 资产页四项 | 未修 | `assets_pages.dart:283-310`（无 `Expanded`）、`:430-440`（空态无动作槽）、`add_account_page.dart:122-130`（无信用字段）、`credit_repayment_page.dart:276-286`（代还与无账户混用） |
| P2-11 附件删除 | 未修 | `attachments_editor.dart:207-227`（热区 28×28、无 `onLongPress`）、`:283-291`（无确认） |
| P2-12 搜索三项 | 部分：只补了报销状态同义词 | `transactions_pages.dart:464-483`（✕ 仍清全部）、`:714-741`（仍搜不到「退款」字面）、`:1284`（范围仍静默） |
| P2-13 退款编辑弹层 | 未修 | `refund_editor.dart:245-255,645-775`（无滚动容器）、`pending_refunds_page.dart:109-110`（孤儿退款死行） |
| P2-14 导入/设置可发现性 | 未修 | `import_preview_page.dart:543-545,723-733`、`ledger_books_page.dart:92` |
| P2-15 文案与状态不符 | 未修（4 处） | `reminder_settings_page.dart:142`、`recurring_page.dart:196-199`、`ai_settings_page.dart`、`ai_result_view.dart:358-380` |
| N-2 逐笔结余 | 未做 | `series_math.dart:58-75` 仅服务账户余额走势 |
| N-3 无障碍专项 | 未立项 | `docs/` 无专项文档 |

### 2.3 AI

| 条目 | 现状 | 证据 |
| --- | --- | --- |
| 6 个查询工具全部未实现 | 未做 | `ai_query_tool.dart:312-318` 只注册 5 个。`trend`/`compare`/`accountsOverview`/`netWorth`/`creditCardBill` 的底层纯函数已就绪（`report_analysis.dart:393,146`、`home_metrics.dart:280`、`credit_card.dart:49,61`、`ctx.balanceOf`）；`budgetStatus` 需先把预算逻辑从 UI 层抽成纯函数（`budget_snapshots.dart` 目前是 `part of 'budget_pages.dart'`） |
| 结果卡标题仍是中文硬编码 | 未做 | 产生 `ai_query_tool.dart:486,551,616,744,815`；渲染 `ai_result_view.dart`（直接用 `display.title`） |
| 采集 backlog 三项 | 未做 | 磁贴「识别最近截图」`QuickEntryTileService.kt:20-23`；Intent 结构化 extras `ShareReceiverActivity.kt:44-51`；拍照入口 `screenshot_recognizer_io.dart:13-14` |
| 聊天历史 40 条静默丢弃 | 未做 | `ai_chat_page.dart:71,158-160`（截断无提示；「只存本机」说明已补） |

### 2.4 工程与流程

| 条目 | 现状 | 证据 |
| --- | --- | --- |
| `integration_test/` 2 个用例不在任何 CI | 未做 | `ci.yml` / `flutter.yml` 全文无 `integration_test` 引用；只能人工跑 |
| `dart format` 门禁只在 `ci.yml` | 未做 | `flutter.yml` 无格式步骤，打 tag 发版不校验格式 |
| 版本号三方一致性无自动校验 | 未做 | 无测试/脚本校验 pubspec ↔ `appVersionLabel` ↔ CHANGELOG；`publish.sh:41` 的版本正则比 `publish.ps1:134` 松 |
| 样例备份缺 2 个字段 | 未做 | `docs/dev/verifin-sample-backup.json` 缺 `moneyUnitStyle`、`hideUnitInSingleCurrency` |
| 8 个导入平台只有 2 个用真实 fixture | 未做 | `test/fixtures/` 只有钱迹与一木样例；支付宝/微信/薄荷/Tally/CSV 用内联构造字节 |
| `test_harness.dart:5` 注释指向不存在的目录 | 未做 | 注释写「见 `test/data/`」，该目录不存在 |
| 2 个测试在 PR/main CI 永远跑不到 | 未做 | `design_consistency_test.dart:71`、`home_density_test.dart:88`（需 `UNIFIED_DESIGN_PREVIEW`，只在 tag 发版 job 里带 define） |

---

## 3. 假「在办」：文档说未修、代码里已经修了（1.2）

| 条目 | 文档说法 | 真实状态 | 证据 |
| --- | --- | --- | --- |
| 产品 P2-6 图表网格 / 负值 / 空数据假平线 | 未修 | **已修** | `chart_painters.dart:249-268,725-793`；CHANGELOG 1.16.15 属实 |
| 产品 P2-2 有符号零 `+0`/`-0` | 进行中 | **已修** | `ledger_math.dart:288-308` 对零短路；页面手拼符号已清 |
| 产品 P2-1 日期格式三套并存 | 进行中 | **部分**：页面级已清，图表标签 helper 仍手拼 | 残留 `ledger_math.dart:118,120,230,243`、`series_math.dart:17`、`report_analysis.dart:433` |
| 产品 P2-4 硬编码 `Color(0x…)` | 未修 | **部分**：只清了 `chart_painters.dart` | 仍在 `entry_sheets.dart:239-275`、`ai_chat_page.dart:585`、`app_lock_page.dart:188`、`reports_page.dart:802`、`common_widgets_scaffold.dart:29-30,108` |
| 产品 P2-7 图表字号 / 气泡 / 语义 | 未做 | **部分**：字号跟随与气泡夹紧已做，`Semantics` 只覆盖选中点 | `chart_painters.dart:88-90,136-165,612-621,708-717` |
| 产品 P1-8「更多信息胶囊约 30dp」 | 已过时 | 该处现为纯文字小节标题 | `entry_detail_page.dart:923` |
| 产品 P2-10「空态文案指向不存在的按钮」 | 不成立 | 右上角 `+` 菜单按钮存在 | `assets_pages.dart:184-189` |

**结论**：产品审查状态表需要按上表订正；性能审查状态表无需实质更新（只订正两处路径）。

---

## 4. 只能靠真机或授权闭环（1.3）

- 真机 profile 帧时间基线（修复前 / 后各一次）与 release/R8 复测；`debugRepaintRainbowEnabled` 对 P0-2 的实测确认。
- 5000 笔量级基准账本尚未构造（`verifin-sample-backup.json` 仅 29 笔，`scripts/` 无生成脚本）。
- 高级材质：仅在单台 REDMI K90 Pro Max（Android 17）完成验收，不能扩大结论；**代码门控是整平台 Android，保护范围宽于已验范围**。
- 多币种加固、save-interaction 预测性返回、AI Agent 端点验收 —— 均待 Android release 真机。
- play flavor 的 `SCHEDULE_EXACT_ALARM` 在 Android 12–15 的授权 / 回退行为未真机验证。
- 小组件 receiver 均为 `exported=false`，各启动器能否收到系统 `APPWIDGET_UPDATE` 未验证。

---

## 5. 有意接受，不打算做（1.4）

无联网遥测；汇率完全离线、不做汇兑损益；金额底层仍 `double`/`REAL`（L5）；退款不进通用时间线（L3）；schema 只升不降（L2）；偏好 KV 剥离与 `BackupCoordinator` 窄接口化（有意缓做，已定阈值）；记账页「自动识别」标记（用户已否决）；发布签名私钥已入库且用户明确不轮换。

---

## 6. 待拍板（1.5）

`UNIFIED_DESIGN_PREVIEW` 与 `GLASS_DESIGN_PREVIEW` **没有任何最终确认记录**。当前状态是「候选共享排版已覆盖全部页面 + CI 发布包显式开启 + 源码保留开关分支」。按 `AGENTS.md` 约定，用户确认前不得移除旧外观路径，因此临时分支必须继续保留 —— 需要一个明确的「采纳 / 回退」结论才能收尾。

---

## 7. 文档漂移清单（按文件）

### 7.1 准确（13 份，无需改动）

`docs/dev/` 下：architecture.md、ai-tools.md、category-budget-override-design.md、save-interaction-consistency-design.md、anchored-menu-rollout.md、anchored-choice-rollout.md、liquid-glass-navigation.md、glass-material-preview.md、android-development.md、android-visual-stability.md、account-icon-assets.md、auto-capture-plan.md、feedback-system.md。

顶层：`docs/ui-guidelines.md`、`docs/automation.md` 逐条核对无硬事实错误。

### 7.2 需局部订正（10 份 + 顶层 4 份）

**最高优先级三条硬伤：**

1. **schema 版本口径**：`multi-currency-design.md:24`、`multi-currency-hardening-design.md:21,39,594`、`refund-design.md:13` 仍以 **v14** 为「当前」，实为 **16**（v15 = `account_groups` 重建为纯文件夹；v16 = 图标 code 迁移）。证据 `app_database.dart:17,300-330`。
2. **`known-limitations.md` 编号错位**：`:29` 与 `:35` 都是 **L3**（退款时间线 / 无遥测），其后编号顺延错误。引用该文件时不能只按编号定位。
3. **`components.md:45`「VeriHeader 固定高 52」**：实为**最小高度**，且预览构建下为 56。该文档是新建组件的查表依据，属性写错会误导调用方。证据 `common_widgets_scaffold.dart:196-199`、`app_theme.dart:57`。

**顶层四份的具体漂移：**

| 文件 | 错误陈述 | 正确事实 | 证据 |
| --- | --- | --- | --- |
| `README.md:39` | 首页 FAB 数字键盘快速记账 | 首页无 FAB；记账按钮是底栏胶囊右侧独立圆形按钮，唯一的 FAB 在交易列表页 | `root_navigation.dart:308-353,553,630`、`transactions_pages.dart:301-303` |
| `README.md:99,123` | 打 tag 创建 GitHub Release | 创建的是**预发布**（`prerelease: true`、`make_latest: 'false'`） | `flutter.yml:137-148` |
| `README.md:122` | 质量 CI 只跑格式 + analyze + test | 还跑设计/材质专项测试并构建不交付的 `github` debug APK 门禁 | `ci.yml:50-57` |
| `README.md:97` | `local_auth`（生物解锁） | 实际仅指纹 | `pubspec.yaml:55-56` |
| `product.md:17` | 提供 Web 开发预览 | Web 已移除，仓库无 `web/` | 仓库根无 `web/` |
| `product.md:26` | 「数据管理和系统工具」 | 实际是「数据与工具」 | `app_zh.arb:1442` |
| `product.md:3` | 工程架构见 CLAUDE.md | CLAUDE.md 仅一行链接 AGENTS.md；架构文档是 `docs/dev/architecture.md` | `CLAUDE.md` |
| `acceptance-checklist.md:120` | main 推送不应触发 Actions | `ci.yml` 就在 PR 与 main 推送时触发；且与同文件 L38 自相矛盾 | `ci.yml:5-9,56-57` |
| `acceptance-checklist.md:120` | APK 名 `verifin-v1.0.0-短提交号.apk` | 实际含架构段 `verifin-vX.Y.Z-arm64-短提交号.apk` | `flutter.yml:88` |
| `acceptance-checklist.md:42` | v13 升级后账本标记待确认 | 「待确认」是 v13→v14 迁移引入，当前 schema 16 | `app_database.dart:17,201-218` |
| `design-system.md:20` | 首页显示三笔 | 现为 5 条 | `home_page.dart:55-58`；CHANGELOG 1.16.9 |
| `design-system.md:21` | 圆环画布 116dp | 实为 118dp | `budget_pages.dart:160-167` |
| `design-system.md:33` | 高级材质在「设置 → 通用」 | 在「设置 → 外观」，同文件 `:53` 已写对，前后矛盾 | `settings_page.dart:98-141` |
| `CONTRIBUTING.md:3,21` | 架构见 CLAUDE.md | 同 `product.md` | `CLAUDE.md` |
| `CONTRIBUTING.md:7` | Flutter stable channel | 仓库固定 3.47.2 | `ci.yml:29` |

**`docs/dev/` 其余需订正项（摘要）：**

- `components.md`：`VeriHeader` 高度（见硬伤 3）；`CompactSwitchRow` 的「浏览器能力」描述（Web 已移除）；`AccountSectionCard` 漏了 `sectionDragImmediate` 参数；漏登记 `VeriFeedbackDuration`/`Priority`/`Tone`、`AccountDeleteAction`、`WidgetGalleryPage`。
- `tech-decisions.md`：`WidgetData.todayAmountForToday` → `todayForToday`；`importFromJson` → `importDataJson`；「CI 只构建 arm64」只对 APK 成立，AAB 未限平台。
- `known-limitations.md`：编号错位（见硬伤 2）；`models/` 「六文件」→ 7；`84 处 notifyListeners` → 113。
- `multi-currency-design.md`：`normalizeCurrencyAmount` 第二参是 `String currencyCode`；结果类型名 `ConversionResult`/`ConvertedAmount`/`MissingExchangeRate`/`ConvertedTotal.completeAmount` 均与实际不符。
- `multi-currency-hardening-design.md`：大量**方案名与最终命名不符**（`isZeroMoney`/`normalizeMoney`/`formatMoneyNumber`/`showMoneyNumberPad`/`EntryCurrencyDraft`/`EntryValidationFailure`/`validateLedgerDataSnapshot`/`comparableBookAmount`/`AccountValuationTrace` 等），`RecurringPage` → `RecurringRulesPage`，「Web build 已通过」已过时。
- `refund-design.md`：`refund_of`/`settled_at` 是 v13 引入（不是 v14）；「历史退款」合成条目 note 为空串、原支出标量并未清零。
- `anchored-menu.md`：根弹层过渡 280ms → 实为 220ms；`veriRadiusLg` 现为条件值（预览 16 / 默认 12）。
- `unified-design-preview.md`：状态「待评审、默认关闭」→ 发布包已显式开启；Header 64dp → 56dp；宫格副标题 11sp → 10sp。
- `i18n-verification.md`：`badgeRefunded` 英文值是 `"Received"` 不是 `"Refunded"`。
- `ai-agent-design.md`：多处方案名未落地（`ai_agent_protocol.dart`、`AiChatEngine`、事件字段名等），§3 已声明为调研基线。

### 7.3 属历史记录稿（3 份，需加统一抬头）

`design-density-research.md`、`android-glass-investigation.md`、`code-review-2026-07.md`。

另：**`docs/code-review-2026-09-06.md` 问题最大** —— 它是历史记录，但多数 P0/P1 已在 HEAD 修复（`pubspec.lock`、`.take(3)`、代还转账编辑、悬空账户/分类、Android 硬编码中文已部分修复），按「当前缺陷清单」读会误导。仅「签名私钥入库」仍成立（用户已接受）。

### 7.4 引用健康度

- 相对链接扫描：7 份文档的 `.md/.json/.png/.svg/.sh/.yml` 链接**0 处缺失**。
- 引用了但磁盘上不存在的路径：`ai_chat_engine.dart`、`ai_agent_protocol.dart`、`test/ai_agent_protocol_test.dart`、`test/ai_chat_engine_test.dart`（均在 ai-agent-design.md，属方案基线）、`local_storage_io.dart`（code-review-2026-07.md）。

---

## 8. 建议的统一整理方案

### 第一步：事实订正（无需决策，可直接做）

按 §7.2 逐条改，只改与代码不符的事实，不改规范语义、不删历史信息。同时给 §7.3 的四份历史稿加统一抬头：

```
> 本文件是 <日期> 的历史记录，描述当时的状态；当前实现以源码、测试与 docs/design-system.md 为准。
```

### 第二步：结构问题（需要定调）

1. **权威链是否显式化**：目前 `AGENTS.md`（执行规范）、`docs/design-system.md`（视觉规范）、`docs/ui-guidelines.md`（页面细则）、`docs/dev/components.md`（组件查表）、`tech-decisions.md`（取舍）、`known-limitations.md`（台账）之间没有一张总表说明「哪份说了算」。建议在 `docs/` 加一份索引 README，或在 `architecture.md` 顶部列权威顺序。
2. **`ui-guidelines.md` 与 `design-system.md` 是否合并**：两份都在写页面骨架、间距、弹窗规则，目前靠「以 design-system 为准」的口头约定。
3. **`known-limitations.md` 编号重排**：L1–L6 重新编号，并在文件头声明「编号稳定，不得复用」。
4. **历史稿的去留**：保留但加抬头（推荐），还是移到 `docs/archive/`。
5. **是否需要一份「未完成事项」的常驻台账**：本文件的 §2–§6 可以并入 `known-limitations.md` 的「整改中」，避免下次又要靠评审记录反推。

### 第三步：随代码同步

若先修 §2 里的条目，涉及区域（`app_theme.dart` 语义色、`ai-tools.md` 工具清单、`components.md`、`design-system.md`）的文档会在修完后再次变动。**建议先定「§2 修不修、修哪些」，再决定文档整理的时机**，避免同一批文档改两遍。

---

## 9. 核查边界

- 全部结论基于 `f5eab4a` 的源码、Gradle、CI 配置与测试，未运行 Flutter 测试，未做真机验证。
- 「已修 / 未修」判断基于代码是否存在对应实现，不代表真机行为已验证。
- 本文件不构成对 §2 各项的修复承诺，仅记录核查结果。
