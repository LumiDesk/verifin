# 冻结预览不采样实时背景（Issue 72）

**结论**：样式选择页的液态玻璃预览把材质 `blur` 归零、不生成 `BackdropFilter`；真实底栏保持 premium 与实时模糊。

## 背景

Issue 72：ColorOS 16 / Android 16 上，「设置 → 导航栏样式」的液态玻璃预览**首次打开是纯黑胶囊**，滚动或拖动触发一次重绘才恢复。

定位结论：预览走 `GlassQuality.minimal`，`blur > 0` 时库生成 `BackdropFilter(模糊) → 24% 白 tint → BackdropFilter(饱和度)` 三层。这层被 `GlassTabBar` 包在自己的 `RepaintBoundary` 里，边界内玻璃自身之前没有任何绘制内容，背景捕获因此是空的；部分后端（Impeller/Vulkan）把空捕获画成不透明黑，而内层饱和度滤镜又画在 tint 之上，于是整个胶囊纯黑、选中态小胶囊（10% 黑）也跟着看不见。真实底栏是 premium shader、自带捕获，所以只有预览会黑。

本机模拟器是 Impeller **OpenGLES**，空捕获是透明的，**复现不出**原始黑屏。诊断依据是三条：报告截图取色（胶囊内部为纯 `#000000`，不是半透明 tint 压黑后的深灰）、渲染链路代码、以及上游仓库「玻璃适合静态导航 chrome、不适合放进可滚动列表」的既有结论（[liquid_glass_widgets#70](https://github.com/sdegenaar/liquid_glass_widgets/issues/70)）。

## 备选方案

1. **升级 vendored `liquid_glass_widgets`（1.13.0 → 1.17.5）**：核对 changelog 后确认这段区间没有针对该路径的修复（1.17.5 修的是 materialize 过渡里的 `OpacityLayer`，与本树无关），且升级面大、API 漂移风险高。否掉。
2. **首帧后强制重绘 / remount**：只是复刻用户「拖一下就好」的绕法，依赖时序，回答不了「为什么捕获是空的」。否掉。
3. **预览改成离屏渲染一次 + 静态图**：能彻底摆脱实时捕获，但破坏「预览与真机同源（复用 `buildBar`）」的既定约定，还要处理主题/语言变化时重渲染。暂不采用，作为真机仍失败时的后备方案。
4. **保持现状**：已流出可稳定复现缺陷的版本。否掉。

## 决定

预览（`spec.onSelect == null`）改用 `blur: 0` 的预览材质：浅色保留与库默认一致的 24% 白 tint，深色沿用既有 `ios27Dark` 调校，只去掉 blur。库因此走无 backdrop 的纯绘制路径。真实底栏的 `settings` 一行未动。

## 代价 / 风险

- 预览不再有实时模糊；但预览背后永远是卡片纯色，模糊本来就没有可见效果（见验证）。
- 预览材质复刻了库内 `kBottomBarGlassDefaults` 的可见部分（24% 白 tint）。**升级 vendored 库时必须重新核对这个值**。
- 修复针对的是「空捕获被画黑」这条失效链路，不是引擎层根因；引擎或库修好后可以重新评估恢复实时背景。

## 验证方式

- 回归测试：`test/navigation_style_settings_test.dart` 断言浅色/深色预览子树内 `BackdropFilter` 为 `findsNothing`、`settings.blur == 0`，同时保留「真实底栏仍 premium」的反向断言；该用例在修复前失败。
- 视觉等价：模拟器上同屏 A/B（库默认材质 vs `blur: 0`）逐像素比对——浅色 `mean |Δ| = 0.065/255`、`>32` 差异 0 像素；深色 `mean 0.908`、`>16` 差异 0 像素。
- 真机：v1.21.2 预发布交给 Issue 72 报告者（ColorOS 16）确认预览不再变黑，随后提升为正式版。
