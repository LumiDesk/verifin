import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/feedback.dart';

class NavigationPreview extends StatefulWidget {
  const NavigationPreview({super.key});

  @override
  State<NavigationPreview> createState() => _NavigationPreviewState();
}

class _NavigationPreviewState extends State<NavigationPreview> {
  int _currentIndex = 0;

  static const _destinations = <_LabDestination>[
    _LabDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: '首页',
    ),
    _LabDestination(
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      label: '资产',
    ),
    _LabDestination(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart_rounded,
      label: '看板',
    ),
    _LabDestination(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: '我的',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: <Widget>[
                const _HomePreview(key: Key('lab_page_0')),
                const _SimplePreviewPage(
                  key: Key('lab_page_1'),
                  title: '资产',
                  subtitle: '账户与净资产',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const _GlassBackdropPreview(key: Key('lab_page_2')),
                const _SimplePreviewPage(
                  key: Key('lab_page_3'),
                  title: '我的',
                  subtitle: '设置与数据工具',
                  icon: Icons.person_outline_rounded,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FloatingRootNavigation(
              currentIndex: _currentIndex,
              destinations: _destinations,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
              onQuickEntry: () {
                unawaited(
                  VeriFeedbackHost.of(context).showMessage(
                    message: '预览：打开快速记账',
                    duration: VeriFeedbackDuration.short,
                    dedupeKey: 'navigation-preview',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomePreview extends StatelessWidget {
  const _HomePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 108),
        children: const <Widget>[
          _PreviewHeader(title: '首页', subtitle: '日常账本'),
          SizedBox(height: 14),
          _PeriodSummaryCard(),
          SizedBox(height: 12),
          _BudgetCard(),
          SizedBox(height: 12),
          _RecentEntriesCard(),
        ],
      ),
    );
  }
}

class _SimplePreviewPage extends StatelessWidget {
  const _SimplePreviewPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 108),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PreviewHeader(title: title, subtitle: subtitle),
            const Spacer(),
            Center(
              child: Column(
                children: <Widget>[
                  Icon(
                    icon,
                    size: 40,
                    color: scheme.onSurface.withValues(alpha: 0.24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '这里保持原页面内容',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.42),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// UI Lab 专用的背景采样页：内容故意延伸到导航后方，便于观察玻璃是否
/// 忠实继承背后颜色，而不是由玻璃自身凭空产生色彩。
class _GlassBackdropPreview extends StatelessWidget {
  const _GlassBackdropPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('glass_test_content'),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: const <Widget>[
          _PreviewHeader(title: '玻璃背景测试', subtitle: '滚动观察透光、边缘与可读性'),
          SizedBox(height: 14),
          _BackdropHeroCard(),
          SizedBox(height: 12),
          _BackdropPaletteCard(),
          SizedBox(height: 12),
          _BackdropActivityCard(),
          SizedBox(height: 12),
          _BackdropTextureCard(),
        ],
      ),
    );
  }
}

class _BackdropHeroCard extends StatelessWidget {
  const _BackdropHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('glass_test_hero'),
      height: 176,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[veriRoyal, veriBlue, veriCyan],
        ),
        borderRadius: BorderRadius.circular(veriRadiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '8月现金流',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '+¥6,174',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Row(
            children: <Widget>[
              _BackdropHeroMetric(label: '收入', value: '¥8,200'),
              const SizedBox(width: 28),
              _BackdropHeroMetric(label: '支出', value: '¥2,026'),
              const Spacer(),
              Icon(
                Icons.trending_up_rounded,
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackdropHeroMetric extends StatelessWidget {
  const _BackdropHeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BackdropPaletteCard extends StatelessWidget {
  const _BackdropPaletteCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _PreviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '不同背景层次',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '向下滚动，让色块和文字经过导航后方',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.48),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: <Widget>[
              Expanded(
                child: _BackdropColorTile(
                  label: '收入',
                  value: '+42%',
                  color: veriIncome,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _BackdropColorTile(
                  label: '预算',
                  value: '67%',
                  color: veriRoyal,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _BackdropColorTile(
                  label: '支出',
                  value: '-18%',
                  color: veriExpense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackdropColorTile extends StatelessWidget {
  const _BackdropColorTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(veriRadiusMd),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackdropActivityCard extends StatelessWidget {
  const _BackdropActivityCard();

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '背景内容',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const _EntryRow(
            icon: Icons.restaurant_outlined,
            title: '餐饮',
            detail: '今天 19:20 · 晚餐',
            amount: '-¥68',
            color: veriExpense,
          ),
          const Divider(),
          const _EntryRow(
            icon: Icons.payments_outlined,
            title: '工资',
            detail: '今天 09:00 · 工资卡',
            amount: '+¥8,200',
            color: veriIncome,
          ),
          const Divider(),
          const _EntryRow(
            icon: Icons.shopping_bag_outlined,
            title: '购物',
            detail: '昨天 21:10 · 日用品',
            amount: '-¥126',
            color: veriWarning,
          ),
          const Divider(),
          const _EntryRow(
            icon: Icons.directions_subway_outlined,
            title: '交通',
            detail: '昨天 18:40 · 地铁',
            amount: '-¥6',
            color: veriBlue,
          ),
          const Divider(),
          const _EntryRow(
            icon: Icons.local_cafe_outlined,
            title: '咖啡',
            detail: '昨天 15:12 · 下午咖啡',
            amount: '-¥36',
            color: veriExpense,
          ),
        ],
      ),
    );
  }
}

class _BackdropTextureCard extends StatelessWidget {
  const _BackdropTextureCard();

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      child: Column(
        key: const Key('glass_test_footer'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '继续滚动测试',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const _BackdropBand(
            label: '净资产走势',
            detail: '+3.8%',
            color: veriRoyal,
          ),
          SizedBox(height: 8),
          const _BackdropBand(label: '待退款', detail: '2 笔', color: veriWarning),
          SizedBox(height: 8),
          const _BackdropBand(
            label: '汇率更新',
            detail: 'CNY / USD',
            color: veriCyan,
          ),
        ],
      ),
    );
  }
}

class _BackdropBand extends StatelessWidget {
  const _BackdropBand({
    required this.label,
    required this.detail,
    required this.color,
  });

  final String label;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            color.withValues(alpha: 0.30),
            color.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(veriRadiusMd),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            detail,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.48),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PeriodSummaryCard extends StatelessWidget {
  const _PeriodSummaryCard();

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '本期概览',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '8月',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Row(
            children: <Widget>[
              Expanded(
                child: _Metric(
                  label: '支出',
                  value: '¥2,026',
                  color: veriExpense,
                ),
              ),
              Expanded(
                child: _Metric(label: '收入', value: '¥8,200', color: veriIncome),
              ),
              Expanded(
                child: _Metric(label: '结余', value: '+¥6,174', color: veriRoyal),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.48),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _PreviewCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '月预算',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '剩余 ¥4,174',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(veriRadiusSm),
            child: const LinearProgressIndicator(
              value: 0.33,
              minHeight: 7,
              backgroundColor: Colors.black12,
              color: veriRoyal,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentEntriesCard extends StatelessWidget {
  const _RecentEntriesCard();

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '最近交易',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const _EntryRow(
            icon: Icons.local_cafe_outlined,
            title: '咖啡',
            detail: '今天 15:12 · 下午咖啡',
            amount: '-¥36',
            color: veriExpense,
          ),
          const Divider(),
          const _EntryRow(
            icon: Icons.swap_horiz_rounded,
            title: '转出',
            detail: '今天 12:30 · 工资卡 → 支付宝',
            amount: '¥500',
            color: veriRoyal,
          ),
          const Divider(),
          const _EntryRow(
            icon: Icons.directions_bus_outlined,
            title: '交通',
            detail: '昨天 18:20 · 公交',
            amount: '-¥4',
            color: veriExpense,
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.amount,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 54,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? veriSurfaceDark : veriSurfaceLight,
        borderRadius: BorderRadius.circular(veriRadiusLg),
        border: Border.all(color: isDark ? Colors.white10 : veriLine),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _FloatingRootNavigation extends StatefulWidget {
  const _FloatingRootNavigation({
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
    required this.onQuickEntry,
  });

  final int currentIndex;
  final List<_LabDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onQuickEntry;

  @override
  State<_FloatingRootNavigation> createState() =>
      _FloatingRootNavigationState();
}

class _FloatingRootNavigationState extends State<_FloatingRootNavigation>
    with SingleTickerProviderStateMixin {
  static const _navigationWidth = 298.0;
  static const _pressMoveDuration = Duration(milliseconds: 280);
  static const _snapDuration = Duration(milliseconds: 240);

  late final AnimationController _indicatorController;

  double _displayIndex = 0;
  double _animationStart = 0;
  double _animationEnd = 0;
  bool _indicatorPressed = false;
  bool _dragging = false;
  bool _suppressNextDestinationTap = false;
  int? _activePointer;
  int? _pressedTargetIndex;
  double? _pointerDownX;

  @override
  void initState() {
    super.initState();
    _displayIndex = widget.currentIndex.toDouble();
    _animationStart = _displayIndex;
    _animationEnd = _displayIndex;
    _indicatorController =
        AnimationController(vsync: this, duration: _pressMoveDuration)
          ..addListener(() {
            final progress = Curves.easeOutCubic.transform(
              _indicatorController.value,
            );
            setState(() {
              _displayIndex = lerpDouble(
                _animationStart,
                _animationEnd,
                progress,
              )!;
            });
          });
  }

  @override
  void didUpdateWidget(covariant _FloatingRootNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex &&
        _activePointer == null) {
      _animateIndicatorTo(widget.currentIndex.toDouble(), _snapDuration);
    }
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    super.dispose();
  }

  void _animateIndicatorTo(double target, Duration duration) {
    final clampedTarget = target
        .clamp(0.0, widget.destinations.length - 1.0)
        .toDouble();
    _indicatorController.stop();
    _animationStart = _displayIndex;
    _animationEnd = clampedTarget;
    if ((_animationStart - _animationEnd).abs() < 0.001) {
      if (_displayIndex != clampedTarget) {
        setState(() => _displayIndex = clampedTarget);
      }
      return;
    }
    _indicatorController.duration = duration;
    _indicatorController.forward(from: 0);
  }

  void _handlePointerDown(PointerDownEvent event, double slotWidth) {
    if (_activePointer != null) {
      return;
    }
    final pressedIndex = (event.localPosition.dx / slotWidth).floor().clamp(
      0,
      widget.destinations.length - 1,
    );
    setState(() {
      _activePointer = event.pointer;
      _pointerDownX = event.localPosition.dx;
      _pressedTargetIndex = pressedIndex;
      _dragging = false;
      _indicatorPressed = true;
    });
    _animateIndicatorTo(pressedIndex.toDouble(), _pressMoveDuration);
  }

  void _handlePointerMove(PointerMoveEvent event, double slotWidth) {
    if (event.pointer != _activePointer ||
        _pointerDownX == null ||
        _pressedTargetIndex == null) {
      return;
    }
    final delta = event.localPosition.dx - _pointerDownX!;
    if (!_dragging && delta.abs() < 2) {
      return;
    }
    final desiredIndex = (_pressedTargetIndex! + delta / slotWidth)
        .clamp(0.0, widget.destinations.length - 1.0)
        .toDouble();
    if (!_dragging) {
      setState(() => _dragging = true);
    }
    if (_indicatorController.isAnimating) {
      setState(() => _animationEnd = desiredIndex);
    } else {
      setState(() => _displayIndex = desiredIndex);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    final wasDragging = _dragging;
    final pressedTargetIndex = _pressedTargetIndex;
    final targetIndex = _displayIndex.round().clamp(
      0,
      widget.destinations.length - 1,
    );
    setState(() {
      _activePointer = null;
      _pointerDownX = null;
      _pressedTargetIndex = null;
      _dragging = false;
      _indicatorPressed = false;
    });
    if (wasDragging) {
      _animateIndicatorTo(targetIndex.toDouble(), _snapDuration);
      widget.onDestinationSelected(targetIndex);
    } else if (pressedTargetIndex != null) {
      _suppressNextDestinationTap = true;
      _animateIndicatorTo(pressedTargetIndex.toDouble(), _snapDuration);
      widget.onDestinationSelected(pressedTargetIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _suppressNextDestinationTap = false;
      });
    }
  }

  void _handleDestinationTap(int index) {
    if (_suppressNextDestinationTap) {
      _suppressNextDestinationTap = false;
      return;
    }
    _animateIndicatorTo(index.toDouble(), _snapDuration);
    widget.onDestinationSelected(index);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) {
      return;
    }
    _indicatorController.stop();
    setState(() {
      _activePointer = null;
      _pointerDownX = null;
      _pressedTargetIndex = null;
      _dragging = false;
      _indicatorPressed = false;
    });
    _animateIndicatorTo(widget.currentIndex.toDouble(), _snapDuration);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showQuickEntry = widget.currentIndex == 0;
    return SafeArea(
      top: false,
      child: Padding(
        key: const Key('lab_outer_spacing'),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final quickEntrySpace = showQuickEntry ? 68.0 : 0.0;
            final maximumWidth = (constraints.maxWidth - quickEntrySpace).clamp(
              0.0,
              _navigationWidth,
            );
            return SizedBox(
              height: 60,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: showQuickEntry
                        ? Alignment.centerLeft
                        : Alignment.center,
                    child: AnimatedContainer(
                      key: const Key('lab_nav_capsule'),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: maximumWidth,
                      height: 60,
                      child: _buildGlassCapsule(isDark),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IgnorePointer(
                      key: const Key('lab_quick_entry_visibility'),
                      ignoring: !showQuickEntry,
                      child: ExcludeSemantics(
                        excluding: !showQuickEntry,
                        child: AnimatedScale(
                          key: const Key('lab_quick_entry_scale'),
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          scale: showQuickEntry ? 1 : 0,
                          child: _QuickEntryButton(onTap: widget.onQuickEntry),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGlassCapsule(bool isDark) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            key: const Key('lab_nav_material'),
            color: Colors.transparent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              key: const Key('lab_nav_ink'),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isDark ? 0.055 : 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.black.withValues(alpha: 0.10),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slotWidth =
                      constraints.maxWidth / widget.destinations.length;
                  final visualIndex = _displayIndex;
                  final selectedIndex = visualIndex.round().clamp(
                    0,
                    widget.destinations.length - 1,
                  );
                  return Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) =>
                        _handlePointerDown(event, slotWidth),
                    onPointerMove: (event) =>
                        _handlePointerMove(event, slotWidth),
                    onPointerUp: _handlePointerUp,
                    onPointerCancel: _handlePointerCancel,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Positioned(
                          key: const Key('lab_nav_indicator_position'),
                          left: visualIndex * slotWidth + 3,
                          top: 3,
                          bottom: 3,
                          width: slotWidth - 6,
                          child: IgnorePointer(
                            child: AnimatedScale(
                              key: const Key('lab_nav_indicator_scale'),
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOutCubic,
                              scale: _indicatorPressed || _dragging ? 0.94 : 1,
                              child: DecoratedBox(
                                key: const Key('lab_nav_indicator'),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: isDark ? 0.12 : 0.065),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color:
                                        (isDark ? Colors.white : Colors.black)
                                            .withValues(
                                              alpha: isDark ? 0.16 : 0.08,
                                            ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            for (
                              var index = 0;
                              index < widget.destinations.length;
                              index += 1
                            )
                              Expanded(
                                child: _DestinationButton(
                                  key: Key('lab_tab_$index'),
                                  destination: widget.destinations[index],
                                  selected: index == selectedIndex,
                                  onTap: () => _handleDestinationTap(index),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickEntryButton extends StatelessWidget {
  const _QuickEntryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SizedBox(
            width: 60,
            height: 60,
            child: Material(
              key: const Key('lab_quick_entry_material'),
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                key: const Key('lab_quick_entry_ink'),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: isDark ? 0.055 : 0.14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.black.withValues(alpha: 0.10),
                  ),
                ),
                child: Tooltip(
                  message: '快速记账',
                  child: InkWell(
                    key: const Key('lab_quick_entry'),
                    customBorder: const CircleBorder(),
                    hoverColor: Colors.white.withValues(
                      alpha: isDark ? 0.08 : 0.26,
                    ),
                    splashColor: Colors.white.withValues(
                      alpha: isDark ? 0.12 : 0.34,
                    ),
                    onTap: onTap,
                    child: const Icon(Icons.add_rounded, color: veriRoyal),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationButton extends StatefulWidget {
  const _DestinationButton({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _LabDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DestinationButton> createState() => _DestinationButtonState();
}

class _DestinationButtonState extends State<_DestinationButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.selected
        ? scheme.onSurface.withValues(alpha: 0.94)
        : scheme.onSurface.withValues(alpha: _hovered ? 0.76 : 0.48);
    return Semantics(
      selected: widget.selected,
      button: true,
      label: widget.destination.label,
      child: Tooltip(
        message: widget.destination.label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Material(
            color: Colors.transparent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('lab_tab_ink_${widget.destination.label}'),
              borderRadius: BorderRadius.circular(999),
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onHover: (value) {
                if (_hovered != value) {
                  setState(() => _hovered = value);
                }
              },
              onTap: widget.onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    widget.selected
                        ? widget.destination.selectedIcon
                        : widget.destination.icon,
                    size: 21,
                    color: color,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.destination.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: widget.selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabDestination {
  const _LabDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
