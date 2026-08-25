# Veri Fin “记一笔” UI Lab Design QA

## Evidence

- Source visual truth:
  - `C:/Users/Administrator/Documents/xwechat_files/wxid_v97ns488bno22_7e47/temp/RWTemp/2026-08/9e20f478899dc29eb19741386f9343c8/13aa51b63cf260f9998d0a2a1290b2dc.jpg`
  - `C:/Users/Administrator/Documents/xwechat_files/wxid_v97ns488bno22_7e47/temp/RWTemp/2026-08/9e20f478899dc29eb19741386f9343c8/b9221d4e77e5a314d30e47a83bb9847c.jpg`
- Normalized source captures:
  - `design-qa/reference-entry-form-390.png`
  - `design-qa/reference-category-tree-390.png`
- Browser-rendered implementation captures:
  - `design-qa/implementation-entry-form.png`
  - `design-qa/implementation-category-tree.png`
  - `design-qa/implementation-tags.png`
  - `design-qa/implementation-attachment.png`
- Side-by-side comparison evidence:
  - `design-qa/comparison-entry-form.png`
  - `design-qa/comparison-category-tree.png`
- Browser viewport: 1127 × 1272 CSS px; the UI Lab phone viewport rendered at 390 × 844 CSS px.
- Pixel density: browser screenshot matched the CSS viewport at 1×. The 1200 × 2608 source images were downsampled to 390 × 848 for equal-width comparison; the implementation remained 390 × 844 and was vertically padded by 2 px in the combined evidence.
- States reviewed: default expense, existing category picker open, third-level category selection, tag picker, create-tag dialog, attachment source menu, one attachment, three attachments, per-item removal, income, transfer, light theme, dark theme.
- Primary interactions tested: open the existing `CategoryPickerSheet` via the selected capsule’s `…`, select “工作午餐”, choose and create tags, append multiple attachments from both source actions, remove an individual attachment, switch expense/income/transfer, and use the bottom save action.
- Browser console: no warnings or errors in a fresh tab after the final server restart. Transient disposed-view errors caused only by intentionally hot-restarting the Flutter Web debug engine were excluded by repeating the check in a clean tab.

## Intentional Product Constraints

- The reference is an inspiration source rather than a literal clone. Veri Fin keeps its current active-book header, top-right floppy-disk save action, theme tokens, Material category icons, and multi-currency semantics.
- The reference only demonstrates two levels. Veri Fin’s existing `CategoryPickerSheet` remains the source of truth for arbitrary-depth category selection.
- Date, time, tags, reimbursable state, attachments, and currency are condensed into metadata tags. Account and note deliberately remain the formal page’s existing `SelectField` and `TextField` components.
- Quick entry deliberately becomes an exception to the general header-save convention: its frequent one-handed primary action is fixed at the bottom, matching the reference’s ergonomics while preserving the same explicit-save semantics.
- The compact UI Lab type selector is retained as an approved improvement and is intended to migrate with the rest of this screen rather than reverting to the current production `SegmentedButton` appearance.

## Findings

No actionable P0, P1, or P2 findings remain.

- Fonts and typography: the implementation uses Veri Fin’s Flutter theme hierarchy and weights. It intentionally does not copy the reference app’s font; hierarchy remains clear at the 390 px phone width.
- Spacing and layout rhythm: the three-column capsules use a 31 px visual height inside a 40 px grid row, closely matching the reference while retaining separation between rows. Icon plus label stay centered as one group, and the `…` badge overlaps the selected capsule’s lower-right edge without shifting that group. The bottom save bar has no separator line, stays fixed, and the scrollable body remains unobscured when the horizontal multi-attachment strip expands.
- Colors and visual tokens: expense/income/transfer retain Veri Fin semantic colors in both themes. Selection tint, border, and `…` badge have sufficient contrast without introducing the reference app’s teal brand color.
- Image and icon fidelity: visible controls use the existing Material icon family. Multi-attachment previews use real bundled payment/import image assets rather than blank placeholders; each thumbnail has a compact 16 px remove control.
- Copy and content: labels reflect current Veri Fin concepts and the picker uses the existing localized category labels.
- Accessibility and responsiveness: content fits the 390 × 844 viewport, remains scrollable, and both the capsule and its separate `…` entry retain explicit tap targets. Light and dark themes were both checked.

## Focused Comparison

Separate focused crops were not needed: both comparison images normalize each phone screen to 390 px width, and the capsule radius, centered content, lower-right badge, existing account/note fields, metadata tags, picker indentation, icons, and copy remain directly readable. The second comparison is already a dedicated category-picker state.

## Comparison History

1. Initial pass found P1/P2 drift: category controls were oversized rounded rectangles, icon/text were left-weighted, the `…` badge occupied layout space, account/note were unnecessarily redesigned, and category selection used a custom modal instead of Veri Fin’s component.
2. Fixes: category controls now use compact `StadiumBorder` capsules; icon and label are centered independently of an 18 px lower-right overlay badge; account and note reuse `SelectField`, `AccountIconBox`, and the existing note `TextField`; the custom modal and its search code were removed; the nested phone navigator now presents the existing `CategoryPickerSheet` in the standard bottom-sheet chrome.
3. The next feedback pass identified P2 ergonomic and completeness gaps: an unexplained “轻点修改” label, header save on a frequent one-handed flow, capsules still taller than the visual target, and no demonstrated tag-input or attachment-after-upload state.
4. Fixes: the hint was removed; save moved to a fixed 50 px bottom stadium button; capsules reduced to a 31 px visual height; tags now use the existing `TagSelectorSheet` with multi-select and create-tag dialog; attachment source selection opens beside the metadata chip and the result appears immediately below as a removable preview strip.
5. Final pass compared the normalized default state, reviewed tag and attachment states, exercised their interactions, and checked a clean browser console. No actionable P0/P1/P2 issues remained.
6. The latest clarification found two remaining P2 mismatches: the save bar had an unnecessary top divider, and the attachment demo incorrectly implied a single-file limit with an oversized remove control. A proposed reversion of the compact type selector was explicitly cancelled because the optimized version was approved.
7. Fixes: the save divider was removed; attachment state became an appendable list; the preview changed to a horizontally scrollable thumbnail strip with per-item deletion; the visual `×` shrank to 16 px with a 10 px glyph; the optimized type selector remained unchanged. The three-attachment state and clean console were rechecked with no actionable P0/P1/P2 findings.

## Follow-up Polish

- P3: after the product direction is approved, validate long English category names and large text-scale behavior in the formal Android implementation.
- P3: confirm on an Android device that the 18 px visual badge still has a sufficiently forgiving semantic tap target when migrated.
- P3: validate the fixed bottom save bar with the Android IME open and test horizontal scrolling with a long attachment list before production migration.

final result: passed

---

# Veri Fin “轻提示” UI Lab Design QA

## Evidence

- Source visual truth: `design-qa/reference-feedback-card-390.png`（选中的第二个 ImageGen 方案，853 × 1844 px）。
- Normalized source: `design-qa/reference-feedback-card-390-normalized.png`（390 × 844 px）。
- Browser-rendered implementation:
  - `design-qa/implementation-feedback-dark.png`（信息态、深色）。
  - `design-qa/implementation-feedback-light.png`（错误态、浅色）。
- Side-by-side comparison:
  - `design-qa/comparison-feedback-card.png`（完整手机画面）。
  - `design-qa/comparison-feedback-card-focused.png`（轻提示与根导航局部）。
- Browser viewport: 1400 × 1100 CSS px；UI Lab 手机画布以 390 × 844 CSS px、1× 像素密度渲染。
- Density normalization: 源图先按宽度缩放到 390 × 847，再居中裁为 390 × 844；实现截图直接从浏览器 1× 画布裁取为 390 × 844。
- States reviewed: 信息、成功、警告、错误；深色与浅色；进度进行中与两秒后自动消失。
- Primary interactions tested: 切换四种语义、重播提示、观察两秒进度递减、确认自动消失、切换深浅主题。
- Browser console: final pass 中无 warning 或 error。

## Intentional Product Constraints

- 本轮只验证轻提示组件，不把 ImageGen 中生成的首页卡片当作正式首页改版目标；背景继续复用 UI Lab 现有根导航预览。
- 组件使用 Veri Fin 的 Roboto 字体、Material 图标和 `veriRoyal` / `veriIncome` / `veriWarning` / `veriExpense` 语义色，不复制生成图中的非项目字体或不稳定图形细节。
- 状态切换与重播只存在于手机画布外的 UI Lab 工具栏，不会迁入正式应用画面。

## Findings

Latest compact revision is awaiting refreshed browser evidence.

- Fonts and typography: 最新实现改用项目 `labelLarge` 和 700 字重；退出文案缩短为“再按一次退出”。Widget 测试已确认四种中文样例存在，仍待浏览器刷新后确认真实 Web 字形无挤压。
- Spacing and layout rhythm: 用户反馈 274 × 64 px 仍不像轻提示后，卡片进一步缩至 168 × 40 px（面积为上一版约 38%）、8 px 圆角，图标盒缩至 24 px，进度线缩至 1.5 px；仍待最新浏览器截图确认视觉比例。
- Colors and visual tokens: 深浅主题均使用稳定实体表面、单一轮廓和轻阴影；品牌/语义色只出现在图标底、图标和进度线，没有退回整宽高饱和 `SnackBar`。
- Image quality and asset fidelity: 组件不需要位图资产；所有图标来自项目现用 Material 图标族，没有占位图、自绘 SVG 或模拟资产。
- Copy and content: 信息态进一步压缩为“再按一次退出”；其余三种样例分别覆盖成功、操作受限和保存失败。
- Behavior and accessibility: 最新提示宿主最多同时显示四条并向上堆叠，更多消息进入 FIFO 等待队列；每条可独立关闭，可选 2/4/8 秒或常驻，Web 悬停暂停倒计时。常驻态不再创建进度区域，内容垂直居中。关闭动画由每条提示自身的 `SizeTransition` 收缩，列表直接子项使用稳定 Key，剩余提示不重建且倒计时不会重置。状态、时长、堆叠、排队、手动关闭、逐帧收拢和恢复计时均已有 Widget 测试覆盖。

## Focused Comparison

`comparison-feedback-card-focused.png` 把选定方案与实现的提示区域放在同一张图中。实现保留了左侧小型语义图标、单行主文案、底部进度线、紧凑实体表面以及导航上方悬浮关系；为适配 Veri Fin 真实字号和四种中文样例，成品比生成图略宽，但仍明显窄于屏幕和旧版整宽 `SnackBar`。

## Comparison History

1. 初版浏览器截图发现 P2 宽度漂移：334 px 状态卡横向接近整块屏幕，也延伸到独立快捷记账按钮上方，不如选定方案轻巧。
2. 修复：卡片收窄至 274 px并保持居中；单行中文样例仍完整，进度线与图标比例不变。
3. 最终 pass 重新构建、在相同 390 × 844 画布捕获深色信息态，并与归一化源图做完整和局部合并对比；同时复核成功、警告、错误、浅色和自动消失状态。无剩余 P0/P1/P2。
4. 用户复核后认为 274 × 64 px 仍过大。最新修订将卡片缩至 168 × 40 px，缩小图标、内边距、阴影、滑入距离和进度线，并补测试锁定面积小于上一版的 40%。Analyze、18 项测试和 Web build 已通过；当前浏览器安全策略拒绝自动刷新本地标签页，因此新尺寸尚缺浏览器渲染截图。
5. 用户继续要求多提示堆叠、手动关闭和可配置时长。实现已升级为四条可见栈 + FIFO 等待队列，工具栏提供 2/4/8 秒与常驻，单条带关闭入口，Web 悬停暂停倒计时。Analyze、19 项全量测试与最新 Web build 已通过；当前打开标签页仍是旧 bundle，需要用户手动刷新后才能完成浏览器视觉 pass。
6. 用户复核发现常驻态透明进度槽仍占高度，且关闭一条时其他提示会卡顿。修复后常驻态完全移除进度子树并按 40 px 全高居中内容；列表 Key 提升到直接子项，移除整组 `AnimatedSize`，改为单条 180 ms 收缩。新增回归测试逐帧检查被关闭项的尺寸递减，并确认其他提示的进度继续递减、不被重置。Analyze、20 项全量测试与 Web build 已通过。
7. 原型已抽取为正式 `lib/app/feedback.dart`，`VeriFinApp` 在 `MaterialApp.builder` 的 Navigator 之上安装根级 Host；UI Lab 删除复制渲染并直接使用正式组件。通用 API 新增单操作 Future 结果、后台暂停/恢复、显式 `dedupeKey`、低/普通/高优先级、四条可见栈和 16 条等待上限。根项目 analyze、855 项全量测试，UI Lab analyze、22 项测试与 Web build 均通过。当前打开的浏览器仍是旧 bundle，缺少优先级、撤销、去重和跨路由入口，需要刷新后完成最终视觉与交互 pass。

## Follow-up Polish

- P3: 正式迁移前补英文长文案和窄屏 360 dp 验证，并决定超长信息是换行还是省略。
- P3: Android 真机确认浮层与手势导航安全区、浮动根导航及系统返回预测动画的节奏。
- P3: 根据首批真实调用点确认默认底部避让高度是否需要按根页/子页动态调整。

final result: blocked

Blocker: 需要用户手动刷新当前 UI Lab 标签页，之后才能重新捕获正式组件的优先级、撤销、去重、跨路由和等待队列状态并完成最终视觉比较。
