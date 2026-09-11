# UI 组件库评估记录

本文只记录已经做出的组件选型决定。当前实现与验收以源码、测试、[统一设计规范](../design-system.md) 和 [组件目录](components.md) 为准。

## 当前落地结果

| 领域 | 当前实现 | 结论 |
| --- | --- | --- |
| 统一分段控件 | `animated_toggle_switch` + `VeriSegmentedControl` | 已采用，所有同类切换条复用包装组件 |
| 图表 | `CustomPainter`（`chart_painters.dart` 等） | `fl_chart` 试用后撤回；坐标轴和内边距不符合现有布局，继续自绘 |
| 根导航 | `VeriBottomBar` | 从 `bottom_bar_matu` 的实现思路抄写后自持，并修复状态重建、快速点击和方向问题；依赖已移除 |
| 短反馈 | `VeriFeedbackHost` | 保留自研队列、去重、优先级和前后台暂停，不引入 `toastification` |
| 引导页 | 现有 `onboarding_page.dart` | 不引入 `introduction_screen`，业务流程和持久化逻辑仍需自定义 |
| 材质 | 不透明实色表面 | 玻璃、背景模糊、方向高光、折射透镜和全局背景光效已移除 |

## 评估原则

- 新依赖必须解决现有问题，并通过 Flutter 版本、Android/R8、体积和隐私评估。
- 组件库不能改变账目、备份、退款、多币种或保存语义。
- 页面组件必须复用项目的颜色、圆角、金额格式和弹窗入口。
- 图表必须保留当前点按/滑动查看数据的交互；预算圆环继续使用自绘实现。

## 已撤回方案

- `fl_chart`：试用后发现坐标轴刻度和既有内边距不一致，已移除依赖。
- `bottom_bar_matu`：只借鉴其绘制结构，当前代码已迁入 `VeriBottomBar`，不再依赖上游包。
- 玻璃材质库、`BackdropFilter` 材质层和导航 Shader：方向已由用户否决，相关实现已删除。

如需重新评估组件库，应先写清楚新的用户问题和验收指标，再做小范围原型；不要根据本文件恢复已撤回方案。
