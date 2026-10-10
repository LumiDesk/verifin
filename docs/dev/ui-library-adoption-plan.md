# 第三方 UI 组件库选型结论

本文件记录已经做出的组件选型决定，供引入新组件库前查阅。当前实现以源码、测试、[统一设计规范](../design-system.md) 和 [组件目录](components.md) 为准。

## 当前结论

| 领域 | 当前实现 | 结论 |
| --- | --- | --- |
| 统一分段控件 | `animated_toggle_switch` + `VeriSegmentedControl` | 已采用，同类切换条复用包装组件 |
| 图表 | `fl_chart 1.2.0`（适配层 `chart_painters.dart`） | **已采用**（MIT）。数据图表一律用外部图表库，项目不再自绘；所有页面只依赖适配层 `InteractiveTrendChart` / `InteractiveBarChart` / `InteractiveComboChart` / `VeriDonutChart` / `VeriBudgetRing`，纵轴刻度与参考线由适配层自绘以保证对齐 |
| 空状态动画 | `lottie 3.6.1` | **已采用**（MIT）；资产本地打包、不联网加载，缺少资产或系统开启减少动态效果时回退图标 |
| 根导航 | `VeriBottomBar` | 停靠底栏自持实现；不依赖 `bottom_bar_matu` |
| 短反馈 | `VeriFeedbackHost` | 自研队列、去重、优先级与前后台暂停；不用 `toastification` |
| 引导页 | 现有 `onboarding_page.dart` | 不用 `introduction_screen`（业务流程和持久化需自定义） |
| 材质 | 不透明实色表面 + 可选的液态玻璃底栏 | 不引入玻璃材质库或第三方 shader；液态玻璃实现自持 |
| OCR | `google_mlkit_text_recognition` | 已采用（端上离线识别） |

## 选型原则

- 新依赖必须解决现有问题，并通过 Flutter 版本、Android/R8、体积和隐私评估。
- 组件库不能改变账目、备份、退款、多币种或保存语义。
- 页面组件必须复用项目的颜色、圆角、金额格式和弹窗入口。
- 图表必须保留点按/滑动查看数据的交互；新增图表类型必须先查适配层是否能覆盖，不得退回自绘。

如需重新评估组件库，先写清楚新的用户问题和验收指标，再做小范围原型。
