import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/common_widgets.dart';
import '../app/home_metrics.dart';
import '../app/ledger_math.dart';
import '../app/veri_fin_scope.dart';
import '../l10n/app_localizations.dart';
import 'home_page.dart';

/// 首页走势卡片自定义页：点击每个槽位在底部弹窗里挑选要展示的数据 / 曲线序列，
/// 顶部实时预览。改动先进入页面草稿，点击保存后写入设备本地偏好。
class HomeMetricsSettingsPage extends StatefulWidget {
  const HomeMetricsSettingsPage({super.key});

  @override
  State<HomeMetricsSettingsPage> createState() =>
      _HomeMetricsSettingsPageState();
}

class _HomeMetricsSettingsPageState extends State<HomeMetricsSettingsPage> {
  final EditorExitController _exitController = EditorExitController();
  final TextEditingController _titleController = TextEditingController();
  bool _titleInitialized = false;
  late HomeTrendConfig _initialConfig;
  late HomeTrendConfig _draftConfig;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_titleInitialized) {
      _titleInitialized = true;
      final config = VeriFinScope.of(context).homeTrendConfig;
      _initialConfig = _draftConfig = config;
      _titleController.text = config.title;
      _titleController.addListener(_handleTitleChanged);
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_handleTitleChanged);
    _titleController.dispose();
    super.dispose();
  }

  HomeTrendConfig get _config => _draftConfig;

  void _update(HomeTrendConfig config) {
    setState(() => _draftConfig = config);
  }

  void _handleTitleChanged() {
    if (mounted && _draftConfig.title != _titleController.text) {
      setState(
        () =>
            _draftConfig = _draftConfig.copyWith(title: _titleController.text),
      );
    }
  }

  Future<void> _pickSlotMetric(int slot) async {
    final selected = await _showMetricPicker(_config.slotMetric(slot));
    if (selected != null && mounted) {
      _update(_config.withSlot(slot, selected));
    }
  }

  Future<void> _pickSeries() async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<HomeTrendSeries>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                l10n.pickChartSeriesTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final series in HomeTrendSeries.values)
              ListTile(
                title: Text(homeTrendSeriesLabel(l10n, series)),
                trailing: series == _config.series
                    ? const Icon(Icons.check, color: veriRoyal)
                    : null,
                onTap: () => Navigator.of(context).pop(series),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      _update(_config.copyWith(series: selected));
    }
  }

  Future<HomeMetric?> _showMetricPicker(HomeMetric current) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<HomeMetric>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (context, scrollController) => Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.pickMetricTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: <Widget>[
                  for (final group in homeMetricGroups(l10n)) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
                      child: Text(
                        group.label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.55),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    for (final metric in group.metrics)
                      ListTile(
                        dense: true,
                        title: Text(homeMetricLabel(l10n, metric)),
                        trailing: metric == current
                            ? const Icon(Icons.check, color: veriRoyal)
                            : null,
                        onTap: () => Navigator.of(context).pop(metric),
                      ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.trendResetTitle,
      message: l10n.trendResetMessage,
      confirmLabel: l10n.trendResetConfirm,
    );
    if (confirmed && mounted) {
      setState(() => _draftConfig = HomeTrendConfig.defaults);
      _titleController.text = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = VeriFinScope.of(context);
    final config = _draftConfig;
    final now = DateTime.now();
    final window = cumulativeWeekWindowFor(now);
    final monthEntries = controller.entries
        .where(
          (entry) =>
              entry.occurredAt.year == now.year &&
              entry.occurredAt.month == now.month,
        )
        .toList();
    final trendEntries = entriesInWindow(monthEntries, window);
    final accountValuation = controller.accountBalancesInBase(date: now);
    final metricContext = HomeMetricContext(
      entries: controller.entries,
      accounts: controller.accounts,
      balanceOf: controller.accountBalance,
      balanceInBaseOf: (account) =>
          accountValuation.amountsByAccountId[account.id],
      now: now,
    );

    return UnsavedChangesGuard(
      isDirty: _isDirty,
      onSave: _save,
      exitController: _exitController,
      child: Scaffold(
        body: SafeArea(
          child: VeriPage(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: <Widget>[
                VeriHeader(
                  title: l10n.trendCustomizeTitle,
                  showBack: true,
                  actions: <Widget>[
                    HeaderAction(
                      key: const Key('trend_reset'),
                      icon: Icons.restart_alt,
                      tooltip: l10n.trendResetConfirm,
                      onPressed: _confirmReset,
                    ),
                    SaveHeaderAction(onPressed: _isDirty ? _saveAndExit : null),
                  ],
                ),
                const SizedBox(height: 8),
                // 实时预览（点击无效，仅展示）。
                HomeTrendPanel(
                  window: window,
                  config: config,
                  metricContext: metricContext,
                  chartValues: trendSeriesValues(
                    config.series,
                    trendEntries,
                    window,
                  ),
                  currencyCode: controller.activeBook.baseCurrencyCode,
                  onTap: () {},
                ),
                const SizedBox(height: 16),
                // 卡片标题：紧跟预览，最先设置。
                VeriCard(
                  child: TextField(
                    controller: _titleController,
                    maxLength: 12,
                    decoration: InputDecoration(
                      labelText: l10n.trendCustomizeTitleField,
                      hintText: l10n.trendCustomizeTitleHint,
                      prefixIcon: const Icon(Icons.title),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SectionTitle(title: l10n.trendCustomizeDisplayData),
                const SizedBox(height: 8),
                VeriCard(
                  child: Column(
                    children: <Widget>[
                      _SlotField(
                        label: l10n.trendSlotBig,
                        value: homeMetricLabel(l10n, config.big),
                        onTap: () => _pickSlotMetric(0),
                      ),
                      _SlotField(
                        label: l10n.trendSlotPill,
                        value: homeMetricLabel(l10n, config.pill),
                        onTap: () => _pickSlotMetric(1),
                      ),
                      _SlotField(
                        label: l10n.trendSlotCard1,
                        value: homeMetricLabel(l10n, config.card1),
                        onTap: () => _pickSlotMetric(2),
                      ),
                      _SlotField(
                        label: l10n.trendSlotCard2,
                        value: homeMetricLabel(l10n, config.card2),
                        onTap: () => _pickSlotMetric(3),
                      ),
                      _SlotField(
                        label: l10n.trendSlotCard3,
                        value: homeMetricLabel(l10n, config.card3),
                        onTap: () => _pickSlotMetric(4),
                        last: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionTitle(title: l10n.trendCustomizeChart),
                const SizedBox(height: 8),
                VeriCard(
                  child: _SlotField(
                    label: l10n.trendSlotChart,
                    value: homeTrendSeriesLabel(l10n, config.series),
                    onTap: _pickSeries,
                    last: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _isDirty => _draftConfig != _initialConfig;

  Future<void> _saveAndExit() async {
    if (await _save() && mounted) {
      setState(() => _initialConfig = _draftConfig);
      _exitController.exit();
    }
  }

  Future<bool> _save() =>
      VeriFinScope.of(context).saveHomeTrendConfigDraft(_draftConfig);
}

class _SlotField extends StatelessWidget {
  const _SlotField({
    required this.label,
    required this.value,
    required this.onTap,
    this.last = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  /// 卡片内最后一行不再画分隔线。
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(veriRadiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.tune,
                  size: 18,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: veriRoyal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
        if (!last)
          Divider(
            height: 1,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.08),
          ),
      ],
    );
  }
}
