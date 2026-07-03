# Veri Fin

Veri Fin 是一个完全免费、数据自主、本地优先的记账工具。当前阶段先实现 Flutter Web 可预览原型，核心目标是打通“快速输入金额 → 完善记账详情 → 保存后回到首页展示记录”的基础流程。

## 当前能力

- 4 个底部 Tab：首页、资产、看板、我的。
- 首页右下角 FAB 快速记账，底部数字键盘输入金额。
- 记账详情页支持支出、收入、转账类型，支持分类、账户、转入账户、备注、日期和时间。
- 首页交易卡默认展示最近 5 条记录，并可进入全部交易列表。
- 首页支出趋势卡按 7 天周期展示，并可进入收支统计页；交易列表支持时间周期切换、关键词搜索、账户/分类筛选和排序方式选择。
- 首页预算卡可进入月份预算页，查看支出进度、近 6 月趋势、历史对比、历史汇总、剩余额度、剩余日均，并在分类预算临近或超支时展示提醒。
- 日历视图按日期展示支出/收入，并可点击具体日期查看当天交易；当天交易页仍可切换到全部时间、本月等筛选视图。
- 交易详情页支持查看、编辑和删除交易，删除前会二次确认。
- 资产页支持添加账户、管理分组、查看账户详情、账户报告和账户交易筛选，净资产卡片可点击图片图标更换背景；无背景图时使用普通卡片样式。
- 新用户和初始化后的账本默认没有资产账户；账户和账户分组按当前账本隔离。
- 账户详情支持编辑类型、名称、图标、备注、分组、计入资产、隐藏状态，并可通过余额调整自动生成对账交易。
- 转账记录会同时影响转出和转入账户余额，但不计入收入或支出统计。
- 隐藏账户会集中显示在资产页底部入口中，可进入独立列表查看。
- 头像和资产背景支持选择本地图片后进入统一裁剪页。
- 账户删除会保护已有交易的账户，避免历史记录失去账户来源。
- 数据看板会按已保存支出记录聚合预算执行、分类排行、7 天日趋势和带纵轴的月度收支。
- 个人页支持修改头像、昵称和简介，主题设置位于设置页。
- 我的页支持账本管理和分类管理；分类可新增、重命名、换图标和拖动排序，已有交易使用的分类会阻止删除。
- 设置页支持初始化所有本地数据，并支持导出/导入 JSON 本地备份。
- 交易记录、账户、分组、账本、分类、月份预算、分类预算、个人信息、主题偏好和资产卡片背景使用浏览器本地存储保存。
- 支持跟随系统、浅色、深色三种主题模式。
- 日期和时间选择器使用中文本地化。
- 主交互色以 `#346edb` 蓝色为核心，`#3498db` 作为辅助蓝，青绿色仅用于收入和正向状态。
- 当前 UI 已收敛为紧凑型移动端工具风格：图标式底部导航、蓝色胶囊选中态、小圆角卡片、较低字号和更高信息密度。

## 项目结构

- `lib/main.dart`：应用入口、路由壳和主要页面。
- `lib/app/`：模型、状态控制、主题、示例数据、工具函数、底部弹窗和通用组件。
- `lib/local_storage/`：Web 本地存储和测试环境内存存储适配。
- `docs/product.md`：产品定位、一期范围和数据策略。
- `docs/ui-guidelines.md`：Header、选择器、弹窗、设置行和金额展示规范。
- `docs/dev/development-habits.md`：开发预览、提交节奏和文档同步习惯。
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

## GitHub CI 与发布

仓库包含 `.github/workflows/flutter.yml`：

- Pull Request 和 `main` 推送会执行 `flutter analyze`、`flutter test` 和 `flutter build web --pwa-strategy=none`。
- `main` 推送、手动触发和 `v*` 标签会在 GitHub Actions 中执行 `flutter build apk --release`，并上传 `verifin-android-apk` artifact。
- 推送形如 `v0.1.0` 的标签时，CI 会创建 GitHub Release，并把 release APK 附加到发布页。

本机仍不进行 Android 交付打包；需要发版时使用 GitHub Actions 产物。

## 文档

- 产品说明：`docs/product.md`
- UI 规范：`docs/ui-guidelines.md`
- 开发习惯：`docs/dev/development-habits.md`
- 验收清单：`docs/acceptance-checklist.md`
- UI 参考图：`docs/targetImages/`
- 贡献和 Agent 规范：`AGENTS.md`
