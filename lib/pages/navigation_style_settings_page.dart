import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/root_navigation.dart';
import '../app/root_navigation_styles.dart';
import '../l10n/app_localizations.dart';

/// 导航栏样式选择页：逐个预览样式，选中其一。
///
/// 页面只认样式的持久化标识（字符串），不依赖偏好枚举，因此任何实现了
/// [VeriRootNavigationStyle] 的样式都能单独预览与测试。保存只把选中的标识
/// **回传给设置页草稿**（`Navigator.pop(styleId)`），不写 Controller/KV；
/// 真正落盘由设置页的统一保存完成，符合
/// `docs/dev/save-interaction-consistency-design.md` §3.2 的草稿语义。
class NavigationStyleSettingsPage extends StatefulWidget {
  const NavigationStyleSettingsPage({
    super.key,
    required this.initialStyleId,
    this.styles = veriRootNavigationStyles,
  });

  /// 打开时设置页草稿里的样式标识，用于判断是否有修改。
  final String initialStyleId;

  /// 参与选择的样式；默认取全局注册表，测试或画廊可传子集。
  final List<VeriRootNavigationStyle> styles;

  @override
  State<NavigationStyleSettingsPage> createState() =>
      _NavigationStyleSettingsPageState();
}

class _NavigationStyleSettingsPageState
    extends State<NavigationStyleSettingsPage> {
  final EditorExitController _exitController = EditorExitController();
  late String _initialStyleId;
  late String _styleId;

  @override
  void initState() {
    super.initState();
    _initialStyleId = widget.initialStyleId;
    _styleId = widget.initialStyleId;
  }

  bool get _isDirty => _styleId != _initialStyleId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return UnsavedChangesGuard(
      isDirty: _isDirty,
      // 本页不落库：保存只把选择结果回传给设置页草稿，因此永远成功。
      onSave: () async => true,
      popResult: () => _styleId,
      exitController: _exitController,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: <Widget>[
                VeriHeader(
                  title: l10n.navigationStyleLabel,
                  subtitle: l10n.navigationStylePickerHint,
                  showBack: true,
                  actions: <Widget>[
                    SaveHeaderAction(
                      onPressed: _isDirty
                          ? () => _exitController.exit(result: () => _styleId)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final style in widget.styles) ...<Widget>[
                  _NavigationStyleCard(
                    style: style,
                    selected: _styleId == style.id,
                    onTap: () => setState(() => _styleId = style.id),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 单个样式的卡片：上半是样式自己的真实渲染（冻结预览），下半是名称、说明与选中标记。
class _NavigationStyleCard extends StatelessWidget {
  const _NavigationStyleCard({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final VeriRootNavigationStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final mutedColor = scheme.onSurface.withValues(alpha: 0.72);

    return VeriCard(
      key: ValueKey<String>('navigation_style_${style.id}'),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(veriCardRadiusFor()),
            ),
            child: _NavigationStylePreview(style: style),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        style.label(l10n),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        style.description(l10n),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: mutedColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle,
                      size: 20,
                      color: scheme.primary,
                      semanticLabel: l10n.navigationStyleInUse,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 冻结预览：直接复用样式的 [VeriRootNavigationStyle.buildBar]，因此预览与真实导航栏
/// 永远同源。
///
/// 预览里条目不可点击（`onSelect` 置空），键盘/手势留白也不需要，另外用独立的
/// `keyPrefix` 避免与壳层里的导航栏重复 key；`Material` 是停靠样式内部 `InkWell`
/// 所需的最小宿主。
class _NavigationStylePreview extends StatelessWidget {
  const _NavigationStylePreview({required this.style});

  final VeriRootNavigationStyle style;

  @override
  Widget build(BuildContext context) {
    final spec = VeriRootNavigationSpec(
      currentIndex: 0,
      destinations: veriRootNavigationDestinations(
        AppLocalizations.of(context),
      ),
      onSelect: null,
      keyPrefix: 'nav_style_preview_${style.id}',
    );
    // 悬浮胶囊会紧贴预览上沿，补一段顶部留白，让浮空导航在卡片里有正常呼吸
    // 空间；整宽贴底样式同样适用，只是上方多出一条卡片底色。
    const topGap = 12.0;
    return SizedBox(
      height: style.layout.occupiedHeight + topGap,
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: Padding(
          padding: const EdgeInsets.only(top: topGap),
          child: IgnorePointer(
            child: Material(
              type: MaterialType.transparency,
              child: style.buildBar(context, spec),
            ),
          ),
        ),
      ),
    );
  }
}
