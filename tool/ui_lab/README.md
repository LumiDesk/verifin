# Veri Fin UI Lab

这是一个与正式应用隔离的 Flutter Web 视觉预览工程，用于在电脑浏览器里快速验证导航、布局和主题方案。

## 运行

```bash
cd tool/ui_lab
flutter pub get
flutter run -d chrome
```

验证命令：

```bash
flutter analyze
flutter test
flutter build web
```

## 隔离边界

- Veri Fin 正式产品仍然只交付 Android；仓库根目录不提供 `web/` 入口。
- UI Lab 不导入 `main.dart`、Controller、repository、SQLite、KV、备份、AI 或平台桥。
- 页面只使用静态演示数据，不允许把浏览器存储当成产品持久化实现。
- UI Lab 可以复用纯主题和纯展示代码；需要真实数据或 Android 能力的组件必须使用预览替身。
- 方案确认后，把可复用组件迁入正式 `lib/`，再在 Android 模拟器或真机完成最终验收。

当前首个实验是“克制版浮动底部导航”：导航与圆形快捷记账分离，快捷记账只在首页出现；导航选中滑块支持横向拖动。导航、滑块和快捷按钮的玻璃层不使用任何渐变或品牌色，只保留均匀中性透明度、背景模糊、单一轮廓和阴影；选中图标/文字在深色模式用白色、浅色模式用黑色，未选中保持灰色。看板位置暂时承载内容丰富的玻璃背景测试页，方便观察内容经过导航后方时的效果。不引入 Shader 或第三方玻璃依赖。
