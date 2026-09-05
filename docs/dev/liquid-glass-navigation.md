# 浮动玻璃根导航：设计与实现经验

> 当前平台范围（2026-09-05）：已移除 Web 开发预览，使用 [Android 真机流程](android-development.md)。下文涉及浏览器的结果仅保留为历史验证记录，不代表当前支持。

当前约定统一收录于 [设计与交互规范](../design-system.md)。高级光照和透镜还需在设置中开启“高级材质”（默认关闭）；本文相关光学描述仅适用于开启后。

2026-09-05 Android 高光资源修复及原机 release Shader 验收已完成，证据与平台范围见
[Android 玻璃调查](android-glass-investigation.md)；以下“第一版”记载属于历史方案。

本文记录 Veri Fin 根导航从传统整宽底栏迁移到浮动玻璃胶囊时形成的材质、手势、适配和验证约定。它是后续开发类似玻璃控件的实现依据，不是要求全应用玻璃化。

**后续用户指定的光学预览优先于本文旧材质限制**：`GLASS_DESIGN_PREVIEW` 开启时，
使用左上/右下方向高光及真实导航纹理透镜 Shader，允许按压膨胀到轨道之外；不采用
下面旧版的整圈边缘/94% 缩小视觉。点击命中、连续指针状态机、松手吸附和取消规则仍保持。
详见 [玻璃材质预览](glass-material-preview.md)。

## 产品边界

- Veri Fin 仍是本地优先、紧凑、可信的 Android 记账工具。导航服务于看账和记账，材质不能成为主角。
- 默认设计中玻璃仅用于悬浮导航/控制层。用户主动要求的[内容玻璃预览](glass-material-preview.md)通过独立开关试验磨砂卡片；不改变此处导航材质和手势约定。
- Android 是正式交付渠道；Web 开发预览直接运行真实页面和玻璃导航，使用浏览器独立持久化。边界见 [Android 真机开发](android-development.md)。
- 第一版不引入第三方液态玻璃依赖和 Fragment Shader；Android 真折射必须另做性能、Impeller 和中低端设备专项验证。

## 研究结论

参考实现：

- [`rdev/liquid-glass-react`](https://github.com/rdev/liquid-glass-react)：使用 backdrop blur/saturation、SVG 位移贴图、边缘分通道色差和独立白色高光层；真正“折射”来自位移，不是容器填色。
- [`greyd097/yzrt`](https://gitee.com/greyd097/yzrt)：纯 CSS 版本使用均匀白色低透明背景、低强度 blur、多层 inset shadow，并用 `::after` 白色对角渐变模拟高光。视觉质感很好，但该渐变是作者绘制的高光，不是自动折射。

由此确定：

1. 无 Shader 时只能实现可信的中性玻璃 fallback，不能声称有真实折射。
2. 固定蓝色/灰色渐变会在纯色背景上凭空制造颜色，违背“颜色来自背后内容”的预期。
3. 额外顶部高光线叠在完整轮廓上会形成明显双层边缘；本实现只保留单一轮廓。
4. 导航、选中滑块和快捷按钮的玻璃 decoration 都必须满足 `gradient == null`，测试锁定该约束。

## 组件结构

生产入口为 `lib/app/root_navigation.dart`：

- `VeriNavigationDestination`：图标、选中图标和本地化 label。
- `VeriRootNavigation`：纯 Flutter 受控组件；调用方持有 `currentIndex`，组件只回传目的地和快捷记账手势。
- Shell 继续用 `PageController` 切换首页、资产、看板、我的；组件不访问 Controller、repository 或平台桥。
- 快捷记账按钮保留 `quick_entry_fab` Key、点击与长按回调，因而原手动/AI 行为和现有测试继续复用。

材质层从外到内为：外部投影 → 胶囊/圆形裁切 → `BackdropFilter` → 透明 `Material` → 均匀中性 `Ink` + 单一边框 → 清晰内容。不得在其中插入渐变填色或第二条顶部轮廓。

## 指针状态机

不能直接使用 `GestureDetector.onHorizontalDrag*`：系统 touch-slop 会让滑块在按下后停顿一小段距离，随后突然开始移动；从远端 Tab 按下时，按坐标直接赋值又会造成瞬移。

当前方案使用 `Listener` 接收原始指针事件，并由显式 `AnimationController` 管理可见索引：

1. `PointerDown`：按槽位整型命中一个目的地，滑块缩放到 94%，用 280ms 从当前位置追向按下处。
2. `PointerMove`：位移小于 2px 仍视为点击；超过后进入拖动。若追踪动画尚未完成，只更新其目标端点；动画完成后直接连续跟随指针。
3. `PointerUp`：点击选择按下槽位；拖动则四舍五入到最近完整目的地，并用 240ms 吸附。
4. `PointerCancel`：回到受控 `currentIndex`。
5. 缩放在 160ms 内回弹。Tab 的 Hover/Splash/Highlight 背景透明，只改变图标与文字明度。

原始指针层与内部 `InkWell` 可能在恰好位于槽位边界时命中不同子项。触摸选择必须由根导航层统一决议，并抑制紧随其后的重复 `InkWell.onTap`；键盘/无障碍触发仍由 `InkWell` 入口处理。

Shell 调用 `PageController.animateToPage` 跨越多个页面时，`onPageChanged` 会依次报告途经页。程序化切页期间必须锁定最终 target 并忽略这些中间值，否则它们会通过受控 `currentIndex` 重启滑块动画，形成“从原 Tab 重新移动”的回退。动画完成后解除 target；没有 target 的 PageView 手势翻页仍正常回写导航。

## 尺寸与窄屏

- 标准胶囊最大宽度 298dp，高度 60dp；快捷按钮 60dp，二者间距 8dp；系统安全区之外再留左右和底部各 24dp 外边距。
- 首页可用宽度不足时，胶囊自动收窄为 `availableWidth - 68dp`，避免在 360dp 及更窄设备与快捷按钮重叠。
- 非首页隐藏快捷按钮后，胶囊恢复最大可用宽度并居中。
- Shell 必须设置 `Scaffold.extendBody: true`，让页面内容绘制到浮动导航背后；否则 Scaffold 为 `bottomNavigationBar` 预留的整宽区域会看起来像旧底栏背景。
- Shell 外层 `SafeArea` 必须关闭 bottom 裁切，并用 `VeriRootNavigationBody` 先保存 Scaffold 注入的底栏高度、再从页面子树移除 `MediaQuery.padding.bottom`；否则 `padding == null` 的嵌套日历/宫格会自动继承整段底栏高度并凭空增高。四个根页面列表统一使用 `veriRootPageListPadding(context)`，按保存的实际底栏高度再加 12dp 内容留白，避免末项被玻璃覆盖。
- 滑块四周间距 3dp；上下用 `top/bottom` 等距约束，不用 `top + 固定高度`。
- 每个 Tab 的触控区仍覆盖完整槽位，不能跟随视觉滑块一起缩小。

## 真实应用预览与验证

电脑预览：

```bash
flutter pub get
flutter run -d <android-device-id> --flavor diagnostic --dart-define=UNIFIED_DESIGN_PREVIEW=true --dart-define=GLASS_DESIGN_PREVIEW=true
```

必须验证：

- 深浅色选中态（深色白、浅色黑）和灰色未选中态；
- Hover 只有内容变色，没有背景矩形；
- 按压 94% 缩放与 160ms 回弹；
- 点击槽位边界最终落到一个完整 Tab；
- 从第一项按住第四项再拖动时先柔顺追向手指，不瞬移；
- 拖动松手吸附、PageView 左右滑动和 Android 返回首页行为；
- 从第三、第四项之间偏右处松手后，滑块每一帧只向第四项前进，不得回到原 Tab；
- 快捷记账只在首页出现，点击/长按分别保持用户配置的手动/AI 语义；
- 360dp 视口无溢出；
- decoration 无渐变，浏览器/Flutter 日志无异常。

提交前运行根项目的 format、analyze、test，并执行 Android release/R8 真机验收。正式交付仍需 Android 模拟器或真机检查触控、性能、系统安全区和不同刷新率下的动画手感。

高级透镜静止时直接绘制实时图标/文字，仅交互期间使用本次采样且尺寸/revision 匹配的纹理；不得缓存初始文字作为静态选中项。松手恢复实时内容，避免首次显示或切换主题后字形失真。
