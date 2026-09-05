# 统一磨砂玻璃材质预览

状态：2026-09-05 用户主动要求内容卡片也探索玻璃质感；这是默认关闭的预览，
不改变预算卡结构、指标方块、宫格、排序或数据流程。

## 先恢复预算结构

`f83314a` 已单独恢复原预算卡：左侧支出、中间完整圆环（剩余额度与比例）、右侧
剩余日均、下方预算总额。允许滚动查看完整卡片，不再为了首屏密度重做预算布局。

## 开源研究

- [renancaraujo/liquido](https://github.com/renancaraujo/liquido)：实验性折射实现，明确依赖 Impeller、不支持 Skia，因此不能直接保证当前 Web 与 Android 的共同预览。
- [sdegenaar/liquid_glass_widgets](https://github.com/sdegenaar/liquid_glass_widgets)：查看了 `GlassContainer`、`AdaptiveGlass` 源码和 MIT 许可证。它区分 Impeller、轻量 Shader 与磨砂 fallback，强调共享背景层与独立浮层的区别。
- [Flutter BackdropFilter](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html)：背景过滤应限制在具体区域；不重叠过滤器可通过 BackdropGroup 共享背景输入。

本轮参考上述分层和兼容策略，自己实现小型公共材质组件，未复制第三方源码、没有新增
pub 依赖。实时背景模糊不同于真实折射，不用静态高光或渐变冒充折射。

## 实现范围

- `VeriGlassBackdrop`：在应用内容后方绘制固定低饱和背景，让半透明表面有真实的背景颜色可透出。背景渐变属于底层画布，玻璃前景没有渐变。
- `VeriGlassSurface`：单层轮廓、均匀中性半透明色、裁切后的 BackdropFilter 和轻阴影；正文、金额和图标保持清晰，不对前景执行 ImageFiltered。
- 普通卡片、账户分组、无自定义图片的资产卡使用公共玻璃表面；用户设置的资产图片仍作为内容保留。
- 锚点菜单和 `sheets.dart` 的统一底部弹层使用独立过滤层，避免和下方内容重叠时错误共享背景。
- 内容表面采用轻染色；菜单/弹层使用同一材质的较高遮盖度变体，避免下层内容干扰阅读。
- 输入区域和分段控制的主题底色半透明化，复用同一材质色系。不会给每个列表行/每个小图标再堆一层模糊；系统原生界面仍由系统绘制。
- `VeriPage` 为同页非重叠卡片提供 BackdropGroup。玻璃内容表面在高对比度下关闭模糊并使用不透明底色。
- 应用锁遮罩期间下层页面 Offstage 并排除焦点，避免半透明锁屏透出账目；解锁后恢复原页面状态。

布局、触控与保存语义保持原样，包括 quietTap 卡片不新增长按高亮行为。Web 和 Android
共用 Flutter 实现，不增加 Web 专属文案或另一套页面。

## 运行与验证

```bash
flutter build web --no-web-resources-cdn --dart-define=UNIFIED_DESIGN_PREVIEW=true --dart-define=GLASS_DESIGN_PREVIEW=true
flutter test test/glass_material_test.dart test/home_density_test.dart test/unified_design_preview_test.dart --dart-define=UNIFIED_DESIGN_PREVIEW=true --dart-define=GLASS_DESIGN_PREVIEW=true
```

两个开关都需要显式开启；仅开统一设计时仍是普通表面，不带参数时保持默认外观。
浏览器使用 393×852，并补 360dp 流程测试。检查正文可读性、菜单/键盘、滚动、图表点选、
返回与保存，以及高对比度降级。自动化测试检查材质裁切/分组、前景不模糊和点击行为；
这不能替代 Android 真机滚动帧率、功耗或全页面对比度测试，当前不宣称这些验证已完成。

本轮结果：默认回归 917 项通过（5 项候选专用测试在默认构建跳过）；玻璃、首页布局、
应用锁及主流程专项组合 23 项通过，高对比度/深浅色材质再次验证通过。analyze、format
和 Web 构建通过。浏览器实际检查浅/深色、资产菜单、数字键盘、原预算卡与滚动显示；
已恢复预览的浅色主题，未改变演示账目数据。
