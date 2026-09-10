# 浮动根导航（已废弃的历史设计）

> **本文已作废，仅作历史留档。** 这里描述的「浮动玻璃胶囊 + 指针拖动状态机」导航在
> 2026-09-10 被整体替换为**停靠式底栏**：整宽、不透明、贴底，条目由 `bottom_bar_matu`
> 绘制，只响应点击（不再有拖动切页与自绘滑块）。

当前根导航的约定请看：

- [统一设计与交互规范](../design-system.md) 的「表面材质」与「导航与输入」两节
- [组件注册表](components.md) 里 `VeriRootNavigation` 的条目（含三条第三方约束与切页时序）

## 为什么作废

- 材质方向改变：磨砂玻璃、方向高光、导航折射透镜与全局背景渐变经用户判定为设计败笔，
  已整体移除（见 `design-system.md`）。玻璃实现本身见 [玻璃材质预览](glass-material-preview.md)
  与 [Android 玻璃调查](android-glass-investigation.md)，两者同为历史记录。
- 交互方向改变：拖动切换 Tab 带来的复杂度（2dp 起步阈值、按住追随、松手吸附、取消回滚、
  跨页目标锁定）被判定为不必要；用户明确要求「整宽不透明、只点击」的高效率形态。

## 仍然成立的经验（已迁走）

原文中关于窄屏适配、Shell 的 `extendBody`/`SafeArea` 处理、以及
`_programmaticPageTarget` 防止跨页动画被中间页重启的结论，**仍然有效**，
已分别并入 `design-system.md` 与 `components.md`。需要原始推导过程时查 git 历史。
