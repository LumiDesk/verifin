# 统一磨砂玻璃材质预览

> 当前平台范围（2026-09-05）：已移除 Web 开发预览，使用 [Android 真机流程](android-development.md)。下文涉及浏览器的结果仅保留为历史验证记录，不代表当前支持。

2026-09-05 Android 玻璃修复：旧方向高光的逐段模糊已在 REDMI K90 Pro Max（Android 17）独立复现 GPU 分配失败及 Vulkan 0x14 崩溃；连续透明度网格替换后，Flutter 3.47.2 release/R8 已完成该机开启、保存、冷启动、切页、深浅色及关闭验收，真实导航 Shader 集成测试通过。Android 恢复高级材质，默认关闭，旧 KV 保留；其他平台仍保护。不能据此断言所有 GPU 均已验证。CI 固定 Flutter 3.47.2，升级引擎须重做真机验收；正式包仍由 CI 构建，须用户明确授权发版，禁止要求清除应用数据。

当前约定统一收录于 [设计与交互规范](../design-system.md)。高级光照和透镜还需在设置中开启“高级材质”（默认关闭）；本文相关光学描述仅适用于开启后。

本次原机复现、修复对照、工具链与剩余验收范围见 [Android 玻璃调查](android-glass-investigation.md)。

状态：2026-09-05 用户主动要求内容卡片也探索玻璃质感；这是默认关闭的预览，
不改变预算卡结构、指标方块、宫格、排序或数据流程。

### Android 图形隔离诊断

若 Android 真机报告高级材质导致原生崩溃，不得把旧的不安全实现放回正式应用来复现。
使用独立 applicationId 的 `diagnostic` flavor 和
`tool/advanced_material_diagnostic.dart`，依次验证方向高光、Shader 加载、
以及单次导航纹理读回。该 target 不初始化 Controller、SQLite 或 KV，不能访问
正式应用数据。完成定位后应保留最小复现与验收结论，删除只为临时实验而存在的路径。

```bash
flutter run -d <android-device-id> --flavor diagnostic \
  -t tool/advanced_material_diagnostic.dart
```

## 先恢复预算结构

`f83314a` 已单独恢复原预算卡：左侧支出、中间完整圆环（剩余额度与比例）、右侧
剩余日均、下方预算总额。允许滚动查看完整卡片，不再为了首屏密度重做预算布局。

## 开源研究

- [renancaraujo/liquido](https://github.com/renancaraujo/liquido)：实验性折射实现，明确依赖 Impeller、不支持 Skia，因此不能直接保证当前 Web 与 Android 的共同预览。
- [sdegenaar/liquid_glass_widgets](https://github.com/sdegenaar/liquid_glass_widgets)：查看了 `GlassContainer`、`AdaptiveGlass` 源码和 MIT 许可证。它区分 Impeller、轻量 Shader 与磨砂 fallback，强调共享背景层与独立浮层的区别。
- [Flutter BackdropFilter](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html)：背景过滤应限制在具体区域；不重叠过滤器可通过 BackdropGroup 共享背景输入。

本轮参考上述分层和兼容策略，自己实现小型公共材质组件，未复制第三方源码、没有新增
pub 依赖。实时背景模糊不同于真实折射，不用静态高光或渐变冒充折射。

## 方向高光与导航透镜（按用户参考图更新）

参考用户提供的音乐播放器玻璃面板、Week/Month/Year 滑块截图，以及
[TRAE 文章](https://forum.trae.cn/t/topic/12384)的分离光照层/位移采样思路。
[掘金原文](https://juejin.cn/post/7514618352829448244)直读未返回正文，具体视觉目标以用户附件为准。

- `glass_lighting.dart` 根据边界位置、曲面法线和光照方向绘制高光：左上/右下渐亮，
  右上/左下渐隐。柔光与细高光叠加，移除普通模式的整圈均匀白色 Border。
  Android 修复后以两次连续透明度网格绘制，禁止恢复每个 2dp 片段单独模糊的旧实现。
- `navigation_glass_lens.dart` 仅把导航自己的图标和文字绘制层采样为临时 GPU 纹理；
  不包含账目、不写文件、不发送。源文字在透镜覆盖区裁去，再由 Shader 显示变形结果，
  避免把原文字与放大文字重复叠加。
- `shaders/navigation_lens.frag` 对真实采样坐标执行放大、边缘弯曲和分通道偏移；
  滑块按压时膨胀，随拖动方向改变形状和边缘光，松手/取消时恢复并沿原状态机吸附。
- 导航底座、选中滑块和快捷按钮均使用对应方向高光；原点击、拖动、取消与无障碍入口保留。
- 高级材质由用户选择；关闭时不创建透镜，保留普通磨砂路径。

浏览器端验证使用 `integration_test/glass_navigation_test.dart`；测试要求实际 Shader
和纹理就绪，检查膨胀、拖动与选中结果，不能以 fallback 通过。

```bash
# 历史 Web 命令已移除；当前真机命令见 android-development.md。
```

本轮方向光更新验证：默认回归 919 项通过（6 项候选专用测试跳过）；方向光、材质、
主流程与滑块测试分别通过；真实浏览器集成测试显示 `Glass lens PASS`。静止时恢复
原比例采样，按压/拖动时才加强放大和弯曲，并以较高分辨率采样避免静止文字重影。
正式预览手动跨 Tab 拖动通过，浏览器未记录渲染 error；预算、交易和宫格结构未改。

## 实现范围

- `VeriGlassBackdrop`：在应用内容后方绘制固定低饱和背景，让半透明表面有真实的背景颜色可透出。背景渐变属于底层画布，内容卡片前景没有渐变；预算图表另用截面明暗表现半透明圆环厚度。
- `VeriGlassSurface`：方向性边缘光、均匀中性半透明色、裁切后的 BackdropFilter 和轻阴影；内容卡片的正文、金额和图标保持清晰，不对前景执行 ImageFiltered。导航源图层则单独由透镜 Shader 采样。
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
# 历史 Web 命令已移除；当前真机命令见 android-development.md。
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

## 材质设置与柔光迭代验收

默认回归 923 项通过（7 项候选专用测试跳过），候选专项 16 项通过；圆环弧面调整后再跑首页/材质 7 项通过。format、analyze 和 Web 构建通过。393×852 真实页面检查了浅/深色圆环、设置开关开关切换、保存及刷新持久化、Tab 拖动和普通磨砂切页，浏览器无渲染 error。当前预览保留深色且高级材质开启，方便评审；不替换 `docs/screenshots/` 中正式版本截图。尚未做本轮 Android 真机帧时间验收。

## 实时文字与圆环修正

静止导航不再显示缓存纹理，避免首次字体/布局更新后仍显示旧快照；每次按压重新采样，仅当前 revision 和尺寸匹配时执行折射。松手/取消立即恢复实时文字，光照与形变仍可回弹。浏览器集成验收同时要求“静止无折射绘制”“按压真实 Shader 就绪”“松手恢复实时文字”，不能用一直降级代替通过。

预算圆环移除内外白色细弧，使用宽柔的同色反光与弱暗部，只表现轻微体积感。所有页面的密度和字号以 [统一规范](../design-system.md) 为准，不再仅首页使用紧凑骨架。

本次默认回归 923 项通过（11 项候选专用测试跳过），跨页排版、首页、导航与设置专项 16 项通过；393×852 浏览器集成测试显示 Glass lens PASS。analyze、format、Web 构建通过。此轮仅更新候选预览，不替换正式版本截图；Android 真机验证尚未执行。
