part of 'common_widgets.dart';

// 锚点菜单域：贴近触发器出现的操作菜单、分组与卡片式递进子菜单。

/// An entry displayed by [VeriAnchoredMenuAnchor].
sealed class VeriMenuEntry {
  const VeriMenuEntry();
}

/// A selectable action or a parent that opens another menu card.
class VeriMenuItem extends VeriMenuEntry {
  const VeriMenuItem({
    required this.id,
    required this.title,
    this.icon,
    this.subtitle,
    this.selected = false,
    this.enabled = true,
    this.foregroundColor,
    this.onPressed,
    this.children = const <VeriMenuEntry>[],
    this.submenuWidth,
  });

  /// Stable identifier used for animation state and widget tests.
  final String id;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final Color? foregroundColor;
  final VoidCallback? onPressed;
  final List<VeriMenuEntry> children;
  final double? submenuWidth;

  bool get hasSubmenu => children.isNotEmpty;
}

/// A visual separator between related menu actions.
class VeriMenuDivider extends VeriMenuEntry {
  const VeriMenuDivider();
}

typedef VeriMenuAnchorBuilder =
    Widget Function(BuildContext context, VoidCallback openMenu, bool menuOpen);

/// A controlled single-choice menu built on top of
/// [VeriAnchoredMenuAnchor].
///
/// This convenience adapter is intentionally limited to short, static option
/// lists. Dynamic, searchable or grouped choices should continue to use their
/// dedicated picker sheets.
class VeriAnchoredChoice<T> extends StatelessWidget {
  const VeriAnchoredChoice({
    super.key,
    required this.values,
    required this.selected,
    required this.idOf,
    required this.labelOf,
    required this.onSelected,
    required this.builder,
    required this.semanticLabel,
    this.iconOf,
    this.subtitleOf,
    this.enabledOf,
    this.width = 224,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) idOf;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;
  final IconData? Function(T value)? iconOf;
  final String? Function(T value)? subtitleOf;
  final bool Function(T value)? enabledOf;
  final VeriMenuAnchorBuilder builder;
  final String semanticLabel;
  final double width;

  @override
  Widget build(BuildContext context) {
    return VeriAnchoredMenuAnchor(
      entries: <VeriMenuEntry>[
        for (final value in values)
          VeriMenuItem(
            id: idOf(value),
            icon: iconOf?.call(value),
            title: labelOf(value),
            subtitle: subtitleOf?.call(value),
            selected: value == selected,
            enabled: enabledOf?.call(value) ?? true,
            onPressed: () => onSelected(value),
          ),
      ],
      semanticLabel: semanticLabel,
      width: width,
      builder: builder,
    );
  }
}

const double _veriMenuPanelPadding = 6;
const double _veriMenuDividerExtent = 9;

double _veriMenuEntryExtent(VeriMenuEntry entry) => switch (entry) {
  VeriMenuItem() => entry.subtitle == null ? 50 : 58,
  VeriMenuDivider() => _veriMenuDividerExtent,
};

double _veriMenuPanelExtent(
  List<VeriMenuEntry> entries, {
  VeriMenuItem? parent,
}) {
  var extent = _veriMenuPanelPadding * 2;
  if (parent != null) {
    extent += _veriMenuEntryExtent(parent) + _veriMenuDividerExtent;
  }
  for (final entry in entries) {
    extent += _veriMenuEntryExtent(entry);
  }
  return extent;
}

double _veriMenuEntryOffset(
  List<VeriMenuEntry> entries,
  VeriMenuItem target, {
  VeriMenuItem? parent,
}) {
  var offset = parent == null
      ? 0.0
      : _veriMenuEntryExtent(parent) + _veriMenuDividerExtent;
  for (final entry in entries) {
    if (entry is VeriMenuItem && entry.id == target.id) return offset;
    offset += _veriMenuEntryExtent(entry);
  }
  return offset;
}

/// Attaches a Veri Fin menu to any caller-provided trigger widget.
///
/// The menu follows the trigger, avoids the screen edge, closes on outside tap,
/// and renders submenus as a new rounded card above the previous card.
class VeriAnchoredMenuAnchor extends StatefulWidget {
  const VeriAnchoredMenuAnchor({
    super.key,
    required this.entries,
    required this.builder,
    required this.semanticLabel,
    this.width = 224,
    this.submenuWidth = 232,
  });

  final List<VeriMenuEntry> entries;
  final VeriMenuAnchorBuilder builder;
  final String semanticLabel;
  final double width;
  final double submenuWidth;

  @override
  State<VeriAnchoredMenuAnchor> createState() => _VeriAnchoredMenuAnchorState();
}

class _VeriAnchoredMenuAnchorState extends State<VeriAnchoredMenuAnchor> {
  bool _menuOpen = false;

  Future<void> _openMenu() async {
    if (_menuOpen || widget.entries.isEmpty) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final origin = renderObject.localToGlobal(Offset.zero);
    final anchor = origin & renderObject.size;
    setState(() => _menuOpen = true);

    final selected = await showGeneralDialog<VeriMenuItem>(
      context: context,
      barrierDismissible: false,
      barrierLabel: widget.semanticLabel,
      barrierColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black.withValues(alpha: veriGlassDesignPreview ? 0.12 : 0.28)
          : Colors.black.withValues(alpha: 0.08),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _VeriAnchoredMenuRoute(
            anchor: anchor,
            entries: widget.entries,
            width: widget.width,
            submenuWidth: widget.submenuWidth,
            semanticLabel: widget.semanticLabel,
          ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInOutCubic,
        );
        final scaled = ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          alignment: Alignment.topRight,
          child: child,
        );
        // 不把玻璃放进 Opacity 的离屏层；保留缩放，直接采样下层页面。
        return veriGlassDesignPreview
            ? scaled
            : FadeTransition(opacity: curved, child: scaled);
      },
    );

    if (!mounted) return;
    setState(() => _menuOpen = false);
    selected?.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _openMenu, _menuOpen);
}

/// Header-friendly icon trigger for [VeriAnchoredMenuAnchor].
class VeriAnchoredMenuButton extends StatelessWidget {
  const VeriAnchoredMenuButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.entries,
    this.width = 224,
    this.submenuWidth = 232,
  });

  final IconData icon;
  final String tooltip;
  final List<VeriMenuEntry> entries;
  final double width;
  final double submenuWidth;

  @override
  Widget build(BuildContext context) {
    return VeriAnchoredMenuAnchor(
      entries: entries,
      semanticLabel: tooltip,
      width: width,
      submenuWidth: submenuWidth,
      builder: (context, openMenu, menuOpen) => IconButton(
        tooltip: tooltip,
        onPressed: openMenu,
        isSelected: menuOpen,
        icon: Icon(icon),
      ),
    );
  }
}

class _VeriAnchoredMenuRoute extends StatefulWidget {
  const _VeriAnchoredMenuRoute({
    required this.anchor,
    required this.entries,
    required this.width,
    required this.submenuWidth,
    required this.semanticLabel,
  });

  final Rect anchor;
  final List<VeriMenuEntry> entries;
  final double width;
  final double submenuWidth;
  final String semanticLabel;

  @override
  State<_VeriAnchoredMenuRoute> createState() => _VeriAnchoredMenuRouteState();
}

class _VeriAnchoredMenuRouteState extends State<_VeriAnchoredMenuRoute>
    with SingleTickerProviderStateMixin {
  final List<VeriMenuItem> _path = <VeriMenuItem>[];
  late final AnimationController _submenuController;

  List<VeriMenuEntry> get _entries =>
      _path.isEmpty ? widget.entries : _path.last.children;

  double _panelOriginForPathIndex(int targetIndex) {
    var origin = 0.0;
    var entries = widget.entries;
    VeriMenuItem? parent;
    for (var index = 0; index <= targetIndex; index++) {
      final item = _path[index];
      origin += _veriMenuEntryOffset(entries, item, parent: parent);
      parent = item;
      entries = item.children;
    }
    return origin;
  }

  @override
  void initState() {
    super.initState();
    _submenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _submenuController.dispose();
    super.dispose();
  }

  void _select(VeriMenuItem item) {
    if (!item.enabled || _submenuController.isAnimating) return;
    if (item.hasSubmenu) {
      setState(() => _path.add(item));
      _submenuController.forward(from: 0);
      return;
    }
    Navigator.of(context).pop(item);
  }

  Future<void> _goBack() async {
    if (_path.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    if (_submenuController.isAnimating) return;
    await _submenuController.reverse(from: 1);
    if (!mounted) return;
    setState(_path.removeLast);
    _submenuController.value = _path.isEmpty ? 0 : 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final viewport = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : mediaSize.width,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : mediaSize.height,
        );
        return _buildMenu(context, viewport);
      },
    );
  }

  Widget _buildMenu(BuildContext context, Size viewport) {
    const edgePadding = 12.0;
    const anchorGap = 6.0;
    final availableWidth = viewport.width - edgePadding * 2;
    double resolveWidth(double requested) {
      final minWidth = availableWidth < 168 ? availableWidth : 168.0;
      return requested.clamp(minWidth, availableWidth).toDouble();
    }

    final rootWidth = resolveWidth(widget.width);
    final spaceBelow = viewport.height - widget.anchor.bottom - edgePadding;
    final spaceAbove = widget.anchor.top - edgePadding;
    final openBelow = spaceBelow >= 180 || spaceBelow >= spaceAbove;
    final maxHeight = (openBelow ? spaceBelow : spaceAbove) - anchorGap;
    final activeParent = _path.isEmpty ? null : _path.last;
    final foregroundWidth = activeParent == null
        ? rootWidth
        : resolveWidth(activeParent.submenuWidth ?? widget.submenuWidth);
    final widestWidth = rootWidth > foregroundWidth
        ? rootWidth
        : foregroundWidth;
    final right = (viewport.width - widget.anchor.right).clamp(
      edgePadding,
      viewport.width - edgePadding - widestWidth,
    );

    Widget buildRootMenu() {
      return _VeriMenuPanel(
        entries: widget.entries,
        width: rootWidth,
        maxHeight: maxHeight,
        onSelect: _select,
        onBack: () => unawaited(_goBack()),
      );
    }

    Widget buildSubmenuTransition() {
      final parent = activeParent!;
      final ancestorLayers =
          <
            ({
              List<VeriMenuEntry> entries,
              VeriMenuItem? parent,
              double width,
              double origin,
              double maxHeight,
              double height,
            })
          >[];

      void addAncestorLayer({
        required List<VeriMenuEntry> entries,
        required VeriMenuItem? parent,
        required double width,
        required double origin,
      }) {
        final availableHeight = maxHeight - origin;
        final layerMaxHeight = availableHeight < 96 ? 96.0 : availableHeight;
        ancestorLayers.add((
          entries: entries,
          parent: parent,
          width: width,
          origin: origin,
          maxHeight: layerMaxHeight,
          height: _veriMenuPanelExtent(
            entries,
            parent: parent,
          ).clamp(0.0, layerMaxHeight),
        ));
      }

      addAncestorLayer(
        entries: widget.entries,
        parent: null,
        width: rootWidth,
        origin: 0,
      );
      for (var index = 0; index < _path.length - 1; index++) {
        final layerParent = _path[index];
        addAncestorLayer(
          entries: layerParent.children,
          parent: layerParent,
          width: resolveWidth(layerParent.submenuWidth ?? widget.submenuWidth),
          origin: _panelOriginForPathIndex(index),
        );
      }

      final backgroundWidth = ancestorLayers.last.width;
      final originY = _panelOriginForPathIndex(_path.length - 1);
      final availableForegroundHeight = maxHeight - originY;
      final foregroundMaxHeight = availableForegroundHeight < 96
          ? 96.0
          : availableForegroundHeight;
      final fullForegroundHeight = _veriMenuPanelExtent(
        _entries,
        parent: parent,
      ).clamp(0.0, foregroundMaxHeight);
      final collapsedHeight =
          (_veriMenuPanelPadding + _veriMenuEntryExtent(parent)).clamp(
            0.0,
            fullForegroundHeight,
          );

      return AnimatedBuilder(
        animation: _submenuController,
        builder: (context, child) {
          final progress = Curves.easeInOutCubic.transform(
            _submenuController.value,
          );
          final reveal = const Interval(
            0.18,
            1,
            curve: Curves.easeOutCubic,
          ).transform(_submenuController.value);
          final animatedWidth =
              backgroundWidth + (foregroundWidth - backgroundWidth) * progress;
          final animatedHeight =
              collapsedHeight +
              (fullForegroundHeight - collapsedHeight) * progress;
          var stackWidth = animatedWidth;
          var stackHeight = originY + animatedHeight;
          for (final layer in ancestorLayers) {
            if (layer.width > stackWidth) stackWidth = layer.width;
            final layerBottom = layer.origin + layer.height;
            if (layerBottom > stackHeight) stackHeight = layerBottom;
          }
          final animatedRadius =
              veriRadiusLg + (veriRadiusXl - veriRadiusLg) * progress;

          double scaleForDistance(int distance) =>
              (1 - 0.03 * distance).clamp(0.88, 1.0);
          double dimForDistance(int distance) {
            if (distance <= 0) return 0;
            return (0.62 + 0.18 * (distance - 1)).clamp(0.0, 1.0);
          }

          return SizedBox(
            width: stackWidth,
            height: stackHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                for (var index = 0; index < ancestorLayers.length; index++)
                  Positioned(
                    top: ancestorLayers[index].origin,
                    right: 0,
                    child: IgnorePointer(
                      child: Transform.scale(
                        key: ValueKey<String>('veri_menu_layer_$index'),
                        scale:
                            scaleForDistance(
                              ancestorLayers.length - index - 1,
                            ) +
                            (scaleForDistance(ancestorLayers.length - index) -
                                    scaleForDistance(
                                      ancestorLayers.length - index - 1,
                                    )) *
                                progress,
                        alignment: Alignment.topRight,
                        child: _VeriMenuPanel(
                          entries: ancestorLayers[index].entries,
                          parent: ancestorLayers[index].parent,
                          width: ancestorLayers[index].width,
                          maxHeight: ancestorLayers[index].maxHeight,
                          onSelect: (_) {},
                          onBack: () {},
                          backgroundProgress:
                              dimForDistance(
                                ancestorLayers.length - index - 1,
                              ) +
                              (dimForDistance(ancestorLayers.length - index) -
                                      dimForDistance(
                                        ancestorLayers.length - index - 1,
                                      )) *
                                  progress,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: originY,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(animatedRadius),
                    child: SizedBox(
                      width: animatedWidth,
                      height: animatedHeight,
                      child: _VeriMenuPanel(
                        entries: _entries,
                        parent: parent,
                        width: animatedWidth,
                        maxHeight: foregroundMaxHeight,
                        onSelect: _select,
                        onBack: () => unawaited(_goBack()),
                        revealProgress: reveal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    final menu = Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: activeParent == null ? buildRootMenu() : buildSubmenuTransition(),
    );

    return PopScope(
      canPop: _path.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _path.isNotEmpty) unawaited(_goBack());
      },
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Stack(
            children: <Widget>[
              Positioned(
                right: right,
                top: openBelow ? widget.anchor.bottom + anchorGap : null,
                bottom: openBelow
                    ? null
                    : viewport.height - widget.anchor.top + anchorGap,
                child: GestureDetector(onTap: () {}, child: menu),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VeriMenuPanel extends StatelessWidget {
  const _VeriMenuPanel({
    required this.entries,
    this.parent,
    required this.width,
    required this.maxHeight,
    required this.onSelect,
    required this.onBack,
    this.backgroundProgress = 0,
    this.revealProgress = 1,
  });

  final List<VeriMenuEntry> entries;
  final VeriMenuItem? parent;
  final double width;
  final double maxHeight;
  final ValueChanged<VeriMenuItem> onSelect;
  final VoidCallback onBack;
  final double backgroundProgress;
  final double revealProgress;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final baseSurface = veriGlassDesignPreview
        ? veriGlassTint(Theme.of(context).brightness, overlay: true)
        : dark
        ? veriSurfaceAltDark
        : veriSurfaceLight;
    final surface = Color.lerp(
      baseSurface,
      Colors.black,
      0.28 * backgroundProgress,
    )!;
    final optionEntries = <Widget>[
      for (final entry in entries)
        switch (entry) {
          VeriMenuItem() => _VeriMenuItemRow(
            key: ValueKey<String>('veri_menu_item_${entry.id}'),
            item: entry,
            reserveLeading: entry.icon != null,
            onTap: () => onSelect(entry),
            mutedProgress: backgroundProgress,
          ),
          VeriMenuDivider() => const _VeriMenuDividerRow(),
        },
    ];
    final panelEntries = <Widget>[
      if (parent != null) ...<Widget>[
        _VeriMenuItemRow(
          item: parent!,
          reserveLeading: parent!.icon != null,
          submenuHeader: true,
          onTap: onBack,
          mutedProgress: backgroundProgress,
        ),
        FadeTransition(
          opacity: AlwaysStoppedAnimation<double>(revealProgress),
          child: Transform.translate(
            offset: Offset(0, 6 * (1 - revealProgress)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[const _VeriMenuDividerRow(), ...optionEntries],
            ),
          ),
        ),
      ] else
        ...optionEntries,
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: maxHeight.clamp(120.0, double.infinity),
      ),
      child: VeriGlassSurface(
        grouped: false,
        radius: veriRadiusXl,
        tint: surface,
        child: Material(
          color: veriGlassDesignPreview ? Colors.transparent : surface,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(veriRadiusXl),
            side: BorderSide(
              color: veriGlassDesignPreview
                  ? Colors.transparent
                  : dark
                  ? Colors.white.withValues(alpha: 0.12)
                  : veriLine,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              vertical: _veriMenuPanelPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: panelEntries,
            ),
          ),
        ),
      ),
    );
  }
}

class _VeriMenuItemRow extends StatelessWidget {
  const _VeriMenuItemRow({
    super.key,
    required this.item,
    required this.reserveLeading,
    required this.onTap,
    this.submenuHeader = false,
    this.mutedProgress = 0,
  });

  final VeriMenuItem item;
  final bool reserveLeading;
  final VoidCallback onTap;
  final bool submenuHeader;
  final double mutedProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = item.foregroundColor ?? theme.colorScheme.onSurface;
    final selectedColor = item.selected ? veriRoyal : baseColor;
    final layerStrength = 1 - 0.58 * mutedProgress;
    final contentColor = selectedColor.withValues(
      alpha: (item.enabled ? 0.92 : 0.34) * layerStrength,
    );
    final subtitleColor = item.selected
        ? veriRoyal.withValues(
            alpha: (item.enabled ? 0.78 : 0.30) * layerStrength,
          )
        : baseColor.withValues(
            alpha: (item.enabled ? 0.50 : 0.26) * layerStrength,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Semantics(
        button: true,
        enabled: item.enabled,
        selected: item.selected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(veriRadiusLg),
            hoverColor: theme.colorScheme.onSurface.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.09 : 0.06,
            ),
            onTap: item.enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: item.subtitle == null ? 44 : 52,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: <Widget>[
                    if (reserveLeading) ...<Widget>[
                      SizedBox(
                        width: 28,
                        child: item.icon == null
                            ? null
                            : Icon(item.icon, size: 22, color: contentColor),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: contentColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (item.subtitle != null) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: subtitleColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (submenuHeader)
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 21,
                        color: baseColor.withValues(
                          alpha: 0.50 * layerStrength,
                        ),
                      )
                    else if (item.hasSubmenu)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 21,
                        color: baseColor.withValues(
                          alpha: (item.enabled ? 0.42 : 0.22) * layerStrength,
                        ),
                      )
                    else if (item.selected)
                      Icon(
                        Icons.check_rounded,
                        size: 21,
                        color: veriRoyal.withValues(alpha: layerStrength),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VeriMenuDividerRow extends StatelessWidget {
  const _VeriMenuDividerRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Divider(height: 1),
    );
  }
}
