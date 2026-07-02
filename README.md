# Veri Fin

Veri Fin 是一个完全免费、数据自主、本地优先的记账工具。当前阶段先实现 Flutter Web 可预览原型，核心目标是打通“快速输入金额 → 完善记账详情 → 保存后回到首页展示记录”的基础流程。

## 当前能力

- 4 个底部 Tab：首页、资产、看板、我的。
- 首页右下角 FAB 快速记账，底部数字键盘输入金额。
- 记账详情页支持支出、收入、转账类型，支持分类、账户、备注、日期和时间。
- 交易记录和主题偏好使用浏览器本地存储保存。
- 支持跟随系统、浅色、深色三种主题模式。
- 主交互色以 `#3498db` 蓝色为核心，青绿色仅作为辅助点缀。

## 项目结构

- `lib/main.dart`：应用入口、路由壳和主要页面。
- `lib/app/`：模型、状态控制、主题、示例数据、工具函数、底部弹窗和通用组件。
- `lib/local_storage/`：Web 本地存储和测试环境内存存储适配。
- `docs/product.md`：产品定位、一期范围和数据策略。
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

如需验证 Web 产物：

```bash
flutter build web
```

Android 安装包不在本机打包，后续通过 GitHub CI 生成。

## 文档

- 产品说明：`docs/product.md`
- UI 参考图：`docs/targetImages/`
- 贡献和 Agent 规范：`AGENTS.md`
