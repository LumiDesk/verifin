# Veri Fin

Veri Fin 是一个完全免费、数据自主、本地优先的记账工具。当前阶段先实现 Flutter Web 可预览原型，核心目标是打通“快速输入金额 → 完善记账详情 → 保存后回到首页展示记录”的基础流程。

## 当前能力

- 4 个底部 Tab：首页、资产、看板、我的。
- 首页右下角 FAB 快速记账，底部数字键盘输入金额。
- 记账详情页支持支出、收入、转账类型，支持分类、账户、转入账户、单行备注、日期和时间；顶部金额颜色跟随类型（支出红、收入青绿、转账蓝），账户选择框图标跟随所选账户，选择账户弹窗与资产列表一致地展示账户图标和余额。
- 首页交易卡默认展示最近 5 条记录，并可进入全部交易列表。
- 首页支出趋势卡按 7 天周期展示，并可进入收支统计页；交易列表支持时间周期切换、关键词搜索、账户/分类筛选和排序方式选择。
- 首页预算卡可进入月份预算页，查看支出进度、近 6 月趋势、历史对比、历史汇总、剩余额度、剩余日均，并在分类预算临近或超支时展示提醒；本月预算通过顶部“本月可用预算”旁的编辑图标弹窗设置。
- 日历视图按日期展示支出/收入，并可点击具体日期查看当天交易；当天交易页仍可切换到全部时间、本月等筛选视图。
- 交易详情页支持查看、编辑和删除交易，删除前会二次确认。
- 资产页默认按账户类型展示，支持添加账户、管理分组、分类/类型视图切换、分区展开折叠、账户手动排序、分区排序模式（有两个及以上分区时点击“排序”进入，所有分区折叠后拖动手柄调整顺序，点击“完成”退出）、账户详情、账户报告和账户交易筛选，净资产卡片可点击图片图标更换背景；无背景图时使用普通卡片样式。
- 新用户和初始化后的账本默认没有资产账户；账户、账户分组、月份预算和分类预算都按当前账本隔离（旧版本的全局预算数据会自动归入默认账本）。
- 账户详情支持编辑类型、名称、图标、单行备注、分组、计入资产、隐藏状态，余额调整前会弹出确认框，可选择是否计入收支：计入时生成一笔余额调整交易（默认），不计入时直接修改账户初始余额；信用卡和储蓄卡支持卡号后四位，账户名称可自动匹配银行或支付平台图标。
- 转账记录会同时影响转出和转入账户余额，但不计入收入或支出统计。
- 隐藏账户会集中显示在资产页底部入口中，可进入独立列表查看。
- 头像和资产背景支持选择本地图片后进入统一裁剪页，裁剪预览与实际显示比例保持一致，Web 和 Android 均有对应实现。
- 删除有交易的账户时可选择隐藏账户，或删除账户并同步删除所有相关交易；转账记录会按转出和转入任一账户关联删除。
- 数据看板会聚合本月预算执行与分类排行、当前 7 天周期的日趋势和带纵轴的月度收支。
- 首页和看板底部提供“n个面板”入口，可在面板管理页开关各模块并拖动排序，每页至少保留一个开启的面板，并可确认后恢复默认配置。
- 全部自绘图表支持交互：曲线图和柱状图可点击或横向滑动查看单点数据气泡（首页支出走势、收支统计、看板日趋势与月度收支、预算近 6 月趋势、资产净值趋势、账户余额趋势和账户报告），看板分类环形图点击分段后在中心展示该分类金额与占比；首页支出走势卡的图表区域点击展示数据，卡片其余区域进入统计页。
- 个人页支持修改头像、昵称、简介、性别、生日、城市和职业，主题设置位于设置页。
- 我的页支持账本管理、分类管理和数据管理入口；分类可新增、重命名、换图标和拖动排序，已有交易使用的分类会阻止删除。
- 数据管理页（我的页进入）支持导出/导入 JSON 本地备份和双重确认初始化所有本地数据，Android 端默认导出到系统下载目录。
- 数据管理页可选择一个备份目录（Android 走系统文档树 SAF 授权，桌面走目录选择），点「立即备份」把当前数据写入该目录（文件名 `verifin-backup-<时间>.json`，与自动备份 `verifin-auto-` 前缀区分），并展示上次备份时间；可随时清除目录授权。
- 选择备份目录后可开启自动备份：频率支持「每次打开应用 / 每次记账后 / 每隔 N 小时」，并设置保留最近 N 份（超出的旧自动备份自动清理，手动备份不参与清理）。自动备份在应用打开、回到前台或记账后按配置触发，失败静默不打扰。
- 可选设置备份加密密钥：开启后导出与备份文件用 AES-GCM 加密（PBKDF2 派生密钥），导入加密备份时需输入相同密钥（已保存密钥自动尝试，失败可手动输入）；密钥仅存本机，忘记只能清除后重设，清除只影响后续备份、旧加密文件仍需原密钥。
- 设置页支持触感反馈开关、检查 GitHub Release 更新，更新检查使用弹窗展示当前版本、最新版本和下载进度。
- 首次启动会弹出《隐私政策》与《用户协议》同意弹窗，不同意则退出应用；同意状态持久化后不再询问（初始化数据不会清除该同意），设置页可随时再次查看两份文档。
- 设置页「应用锁」支持 6 位数字密码或 3×3 图案：开启时可选择锁定方式，支持修改（含切换方式）和关闭；应用冷启动和从后台回到前台时都会要求解锁。密钥仅以加盐 SHA-256 保存在本机（不存明文、不上传、无法找回），忘记时只能初始化数据后重设；初始化数据不会清除已设置的应用锁。
- 设置了应用锁后，设备支持时可再开启「生物解锁」作为快捷解锁：调用系统生物识别（指纹 / 人脸，以设备为准），本应用不保存任何生物特征数据，系统生物信息变化后需重新验证；锁屏出现时会自动发起一次验证，也可手动点击生物解锁按钮。
- Android 端支持下拉快捷开关“快速记账”，点击后进入应用并打开快速记账数字键盘。
- 账目类核心数据（交易记录、账户、分组、账本、分类、月份预算、分类预算）只存本地 SQLite（`sqflite`；Web 走 `sqflite_common_ffi_web` 的 wasm，测试走 ffi）；全新数据库首次启动会播种默认账本与分类。个人信息、主题偏好、资产视图偏好、资产分区折叠状态、账户排序、分区排序、首页与看板的面板配置、资产卡片背景、隐私政策同意标记和应用锁配置（加盐哈希）等偏好类小数据仍存 `SharedPreferences`。进程被划掉后所有数据仍应保留。
- 支持跟随系统、浅色、深色三种主题模式。
- 日期和时间选择器使用中文本地化。
- 主交互色以 `#346edb` 蓝色为核心，`#3498db` 作为辅助蓝，青绿色仅用于收入和正向状态。
- 当前 UI 已收敛为紧凑型移动端工具风格：图标式底部导航、蓝色胶囊选中态、小圆角卡片、较低字号和更高信息密度。

## 项目结构

- `lib/main.dart`：应用入口与根组件。
- `lib/pages/`：按功能拆分的页面模块（首页、预算、交易、资产、看板、我的、记账详情、底部导航壳和共享弹窗）。
- `lib/app/`：模型、状态控制、主题、示例数据、工具函数、图表序列计算、底部弹窗和通用组件；`app_version.dart` 保存版本号文案（由发布脚本更新）。
- `lib/l10n/`：国际化 ARB 文案（`app_zh.arb` 为模板）与 gen-l10n 生成的 `AppLocalizations`。
- `lib/data/`：SQLite 数据层——`app_database.dart` 建表与版本迁移，`ledger_repository.dart` 账目类整表读写，`database_factory*.dart` 三端工厂（io 原生 / web wasm / stub）。
- `lib/local_storage/`：偏好类小数据的键值存储适配（Web localStorage、移动端 `SharedPreferences`、测试内存 stub）。
- `docs/product.md`：产品定位、一期范围和数据策略。
- `docs/ui-guidelines.md`：Header、选择器、弹窗、设置行和金额展示规范。
- `docs/dev/development-habits.md`：开发预览、提交节奏和文档同步习惯。
- `docs/dev/verifin-sample-backup.json`：可从数据管理页导入的测试备份数据，用于验证资产、预算、看板和交易列表。
- `docs/acceptance-checklist.md`：当前功能验收清单和后续优先级。
- `docs/targetImages/`：UI 参考图。

## 本地开发

安装依赖：

```bash
flutter pub get
```

通过 Web 预览和调试：

```bash
flutter run -d chrome
```

静态检查和测试：

```bash
flutter analyze
flutter test
```

如需验证 Web 产物，建议禁用 PWA 缓存以避免验收时看到旧版本：

```bash
flutter build web --pwa-strategy=none
```

构建后可在 `build/web` 下启动静态服务进行验收：

```bash
python3 -m http.server 8080 --bind 0.0.0.0
```

Android 安装包不在本机打包，后续通过 GitHub CI 生成。

Android 包名为 `top.talyra42.verifin`。

## GitHub CI 与发布

仓库包含 `.github/workflows/flutter.yml`：

- 只有推送形如 `v1.0.0` 的标签时才会触发 GitHub Actions。
- CI 会执行 `flutter analyze`、`flutter test`、`flutter build web --pwa-strategy=none` 和 `flutter build apk --release`。
- 标签构建会创建 GitHub Release，并把 release APK 附加到发布页；APK 文件名使用 `verifin-v1.0.0-短提交号.apk` 形式。
- Release APK 使用项目内稳定 keystore 签名，后续版本可覆盖安装；从旧的临时 debug 签名版本迁移时，手机可能需要最后卸载一次。

本机仍不进行 Android 交付打包；需要发版时使用 GitHub Actions 产物。

发布新版本时使用脚本：

```bash
scripts/publish.sh patch
```

也可传入 `minor`、`major` 或显式版本号，例如 `scripts/publish.sh 1.1.0`。脚本会更新版本号、提交、创建 `vX.Y.Z` 标签并推送。

## 文档

- 产品说明：`docs/product.md`
- UI 规范：`docs/ui-guidelines.md`
- 开发习惯：`docs/dev/development-habits.md`
- 验收清单：`docs/acceptance-checklist.md`
- UI 参考图：`docs/targetImages/`
- 贡献和 Agent 规范：`AGENTS.md`

## 许可证

Veri Fin 是自由软件，基于 **GNU 通用公共许可证 v3.0 或更高版本（GPL-3.0-or-later）** 发布，完整条款见仓库根目录的 [`LICENSE`](LICENSE)。

> Copyright (C) 2026 Talyra42
>
> This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
>
> This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
