# Veri Fin 系统性 Code Review（2026-09-06）

## 审查范围

- 分支：`talyra42/review-systematic-2026-09-06`
- 基线：`v1.16.6`（当前 `HEAD` 与 `origin/main` 一致）
- 对比：重点检查 `v1.15.17..v1.16.6` 的界面、材质和快速记账改动，同时抽查账目模型、Controller、备份、Android 原生入口、CI 与国际化。
- 工作树另有一处未提交的 `pubspec.lock` 修改；该修改不属于 `HEAD`，但会影响本地/CI 操作，单独列在“工作树阻塞项”。

## 验证结果

- `flutter analyze`：通过，无静态分析问题。
- `flutter test`：通过，933 个测试通过，16 个跳过。
- 与发布 CI 相同的统一设计/玻璃材质专项测试（含 `quick_entry_title_test.dart`）：通过，48 个测试通过。
- 本机 Flutter 为 3.44.8；仓库 CI 固定 Flutter 3.47.2。因此本次不能替代 3.47.2 下的 Android debug/release/R8 编译和真机验收。
- 未执行 Android 真机、release/R8、系统字体放大、系统语言切换和桌面小组件跨午夜验收。

## 需要优先处理的问题

### P0 · 工作树中的 `pubspec.lock` 已损坏（当前未提交）

证据：`pubspec.lock:920` 的 `vector_math` 条目为版本 `2.2.0`、截断的 `sha256`，`flutter pub deps --style=compact` 直接报 `Content-hash has incorrect length`。只要这份文件被提交，CI 的 `flutter pub get` 会在分析和测试之前失败。

当前处理建议：先确认这是否是用户本地临时修改；若不是，恢复到 `HEAD` 的 lock 或用仓库规定的 Flutter 3.47.2 重新生成后再提交。Review 分支没有覆盖这处修改。

> **批注 / 回复：** 同意

### P0 · 发布签名私钥已进入 Git，且构建脚本含固定口令

`android/app/verifin-release.jks` 被 Git 跟踪；`android/app/build.gradle.kts:37-40` 直接引用该文件并写入 store/key 口令。通过 `keytool` 可确认它是 `PrivateKeyEntry`。这意味着能读取仓库的人可以签署看似官方的 APK；一旦仓库或历史提交曾公开，后续仅删除文件也不能撤销泄露。

建议立即按发布安全流程处理：撤销/轮换该签名材料，改用 CI Secret 或受保护的签名服务，历史提交做密钥清理，并保留正式包升级策略。此项与“本地稳定 keystore”约定冲突时，应以签名私钥不入库为安全底线。

> **批注 / 回复：** 同意

### P1 · “代还”转账创建后无法在交易详情中正常编辑

信用还款页允许“无账户（代还）”：`credit_repayment_page.dart:337-353` 保存 `accountId == ''` 且 `accountAmount == null`，转入账户仍是真实信用账户。这是技术决策中明确支持的场景。

但 `transaction_detail_page.dart:137` 对所有转账强制 `_noAccount = false`，`transaction_detail_page.dart:151-156` 又要求转出账户和 `accountAmount` 都大于 0；因此打开这类历史还款后会把来源显示成首个账户，并且保存按钮无法启用。若只有一个账户，`:985` 还会直接清空转入账户。用户可以创建代还记录，却无法编辑日期、备注或金额后保存。

建议把“无账户转账”作为还款专用合法形态贯穿详情页：保留空来源、显示本地化的“无账户/代还”、不要求 `accountAmount`，并为单账户场景补回归测试。

> **批注 / 回复：** 同意，另外，我记得选择账户的那个弹窗，好像本来就有一个无账户吧，应该直接用那个就可以了

### P1 · 发布版统一设计会减少首页可见交易条数

`lib/pages/home_page.dart:55-58` 在 `veriUnifiedDesignPreview` 下使用 `.take(3)`，旧外观仍为 5 条。发布工作流的 APK/AAB 构建明确传入 `UNIFIED_DESIGN_PREVIEW=true`（`.github/workflows/flutter.yml:74,80`），所以正式产物会少展示两条最近交易。这是内容变化，不只是间距或字号变化；目前专项测试验证了布局，但没有断言发布开关下的交易条数。

请确认这是有意的产品决定。如果只是为了压缩卡片高度，应保留 5 条并只调整布局，或明确在产品说明中接受“统一设计下首页只显示 3 条”。

> **批注 / 回复：** 我从来没有说过改成3个，这个应该是意外改错了；改成5个吧，这个是未经过我允许的修改

### P1 · 悬空账户引用会冒名显示为当前列表第一个账户

`lib/app/model_lookup.dart:41-51` 的 `accountDisplayName` 对非空但找不到的 id 调用 `accountById`，而 `accountById` 在列表非空时回退 `accounts.first`。这会影响允许保留历史流水的删账户路径、旧备份和异常导入：交易的账户名称、币种和余额可能被显示成另一个账户。`entry_detail_page.dart:727-729,775-783` 还直接重复使用该回退逻辑；交易列表虽然有精确账户金额判断，但名称仍经过 `accountDisplayName`。

建议把“已删除账户”作为稳定占位对象/名称，未知 id 绝不回退首个账户；编辑页需要明确提示引用已失效，并要求用户主动重新选择后才允许改写。

> **批注 / 回复：** 同意

### P1 · 编辑悬空分类时会静默改成该类型的第一个分类

`transaction_detail_page.dart:119-123` 在页面 `build` 中发现当前分类不存在，就把 `_categoryId` 改为 `currentCategories.first.id`。这会把导入/旧备份中的悬空分类在用户仅打开详情页时改成首个分类，保存后造成静默数据重分类；同时在分类列表为空时还会抛 `StateError`。这与项目已确立的“未知分类显示已删除分类占位、不能冒名首个分类”约定不一致。

建议保持原 id 并显示“已删除分类”占位；只有用户明确选择新分类时才替换。若类型切换必须归一化，也应在交互动作中完成并标记 dirty，而不是在 `build` 中修改状态。

> **批注 / 回复：** 和 P1 一起改，按照你的想法改即可

### P2 · 桌面小组件跨周期后展示旧预算，跨日会忽略已存在的未来交易

Flutter 侧只把当前周期的 `monthBudget` 写入 `KEY_BUDGET_FULL`（`lib/app/home_widget_service.dart:20-60`）。周期到期后，原生 `WidgetData.budgetForMonth`（`android/.../WidgetData.kt:69-80`）直接把这个旧值当作新周期整期预算；如果下期有不同的默认预算或单期覆盖，桌面小组件会在用户打开 App 前显示错误金额。同样，`todayAmountForToday` 跨日固定返回缓存的零值；用户若提前录入了明天的交易，第二天小组件仍会显示 0。

建议让跨期恢复只在能得到新周期投影时进行，或在无法重新计算时显示“需要打开应用刷新”，不要用上一期数值冒充下一期预算。至少应补“不同月度覆盖/自定义周期/未来日期交易”的 Android 集成测试。

> **批注 / 回复：** 可以

### P2 · Android 系统入口存在硬编码中文，英文用户仍看到中文

`android/app/src/main/AndroidManifest.xml:81` 的快捷磁贴 label 是“快速记账”，`android/app/src/main/res/layout/quick_entry_widget.xml` 的按钮也是“记一笔”。这些文案不随 App 的 `LocalePreference` 更新；Flutter 侧虽然会本地化小组件统计标签，但无法覆盖这两个静态资源。项目的国际化规则要求系统入口文案跟随当前语言。

建议提供 Android `values/strings.xml` 与 `values-en/strings.xml` 资源，并在可行时在小组件刷新时覆盖按钮文本；快捷磁贴 label 需通过系统资源而非固定中文声明。

> **批注 / 回复：** 同意

### P2 · 无加密备份归档会丢失附件 MIME 类型

`lib/app/backup/backup_archive.dart:82` 解包时无论原始 data URL 是 PNG、WebP 还是 JPEG，都重建为 `data:image/jpeg;base64,...`。当前图片选择器主要产出压缩 JPEG，因此新拍摄图片通常不触发；但旧备份、导入数据或测试中已有 PNG 附件会在备份往返后改变类型，部分解码器可能无法正确展示。

建议在 zip 元数据中保存每个附件的 MIME，或从原始 data URL 的 header 一并写入 `backup.json`；补 PNG/WebP 往返测试。

> **批注 / 回复：** 同意

## 低优先级但建议补强

### P3 · 快速记账隐藏标题的占位高度不遵循系统字体缩放

`lib/app/entry_sheets.dart:65-69` 用未经过 `MediaQuery.textScalerOf(context)` 的固定 `fontSize × height + 10` 计算隐藏标题的高度。默认字号测试通过，但系统字体放大时真实标题高度会放大，隐藏标题的数字区域会再次发生垂直偏移。应使用同一套文本测量/缩放逻辑，并增加大字体 widget 测试。

> **批注 / 回复：** 压根就不应该有那个标题才对，不知道这块到底是怎么做的，反正我觉得做的可能就是有问题，你研究一下吧。

### P3 · 备份读取和 zip 解包缺少大小/解压上限

Android `MainActivity.kt:1148,1233` 与桌面 `backup_storage_io.dart` 都直接 `readBytes()`；`unpackBackupArchive` 随后一次性解压并重新拼接 base64。用户可从 SAF 选择超大文件或压缩炸弹，导致较高内存峰值甚至 OOM。建议在原生/IO 层限制输入大小，在 zip 层限制条目总大小和附件数量，并在 UI 反馈“文件过大”。

> **批注 / 回复：** 同意

### P3 · 自动备份最外层异常会静默吞掉

`lib/app/backup/backup_coordinator.dart:105` 的兜底 `catch (_) {}` 没有日志或用户反馈。局部本地/WebDAV 失败路径已经记录日志，但导出、加密或其它未预期错误会让用户看不到自动备份失败原因。至少应写隐私友好的结构化日志，并保持“自动任务不打断记账”的静默策略。

> **批注 / 回复：** 同意

## 已确认没有发现回归的部分

- 最近 `v1.16.6` 快速记账修复本身保持了普通金额输入场景的标题；默认字号下数字显示区域位置回归测试通过。
- ARB 中英文 key 数量一致（各 1264 个），未发现本轮新增文案缺失翻译。
- 日期日历算术、金额零值显示、分类/账户图标统一入口、SQLite 仓储契约和迁移矩阵均有对应检查；本轮静态扫描未发现新的裸 `difference().inDays`/`Duration(days:)` 生产调用。
- 统一设计/玻璃专项测试在本机通过；仍需按仓库约定使用 Flutter 3.47.2 做 Android release/R8 与真机验收，尤其是小组件、代还编辑、系统语言、系统字体放大和跨周期投影。

## 建议的修复顺序

1. 先处理签名私钥与损坏 lock（阻断发布/构建及供应链安全）。
2. 修复代还转账编辑、悬空账户/分类展示与保存语义，并补回归测试。
3. 让发布版首页最近交易条数得到产品确认；随后修正小组件跨周期投影。
4. 补齐 Android 系统入口国际化、附件 MIME 往返和大字体测试。
5. 最后做备份大小限制与自动备份异常日志增强，并执行 Flutter 3.47.2 release/R8 真机验收。
