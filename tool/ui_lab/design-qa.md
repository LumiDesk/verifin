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
