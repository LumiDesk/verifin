import 'dart:async';

import 'package:flutter/material.dart';
import 'package:verifin/app/app_theme.dart';
import 'package:verifin/app/feedback.dart';
import 'package:verifin/l10n/app_localizations.dart';

import 'account_icon_preview.dart';
import 'entry_form_preview.dart';
import 'feedback_preview.dart';
import 'navigation_preview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VeriFinUiLabApp());
}

enum UiLabExperiment { entryForm, accountIcons, navigation, feedback }

class VeriFinUiLabApp extends StatefulWidget {
  const VeriFinUiLabApp({
    super.key,
    this.initialExperiment = UiLabExperiment.entryForm,
  });

  final UiLabExperiment initialExperiment;

  @override
  State<VeriFinUiLabApp> createState() => _VeriFinUiLabAppState();
}

class _VeriFinUiLabAppState extends State<VeriFinUiLabApp> {
  final VeriFeedbackController _feedbackController = VeriFeedbackController();
  ThemeMode _themeMode = ThemeMode.dark;
  late UiLabExperiment _experiment = widget.initialExperiment;
  FeedbackTone _feedbackTone = FeedbackTone.info;
  FeedbackLifetime _feedbackLifetime = FeedbackLifetime.standard;
  FeedbackPriority _feedbackPriority = FeedbackPriority.normal;
  bool _feedbackActionEnabled = false;
  bool _feedbackDedupeEnabled = false;
  VeriFeedbackResult? _feedbackLastResult;

  void _showFeedback() {
    final result = _feedbackController.showMessage(
      message: _feedbackTone.message,
      tone: _feedbackTone,
      duration: _feedbackLifetime,
      priority: _feedbackPriority,
      actionLabel: _feedbackActionEnabled ? '撤销' : null,
      dedupeKey: _feedbackDedupeEnabled ? 'ui-lab-${_feedbackTone.name}' : null,
    );
    unawaited(
      result.then((value) {
        if (mounted) setState(() => _feedbackLastResult = value);
      }),
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veri Fin UI Lab',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildVeriFinTheme(Brightness.light),
      darkTheme: buildVeriFinTheme(Brightness.dark),
      themeMode: _themeMode,
      home: _UiLabWorkbench(
        themeMode: _themeMode,
        experiment: _experiment,
        feedbackTone: _feedbackTone,
        feedbackLifetime: _feedbackLifetime,
        feedbackPriority: _feedbackPriority,
        feedbackActionEnabled: _feedbackActionEnabled,
        feedbackDedupeEnabled: _feedbackDedupeEnabled,
        feedbackLastResult: _feedbackLastResult,
        feedbackController: _feedbackController,
        onExperimentChanged: (value) {
          setState(() => _experiment = value);
        },
        onFeedbackToneChanged: (value) {
          setState(() => _feedbackTone = value);
        },
        onFeedbackLifetimeChanged: (value) {
          setState(() => _feedbackLifetime = value);
        },
        onFeedbackPriorityChanged: (value) {
          setState(() => _feedbackPriority = value);
        },
        onFeedbackActionChanged: (value) {
          setState(() => _feedbackActionEnabled = value);
        },
        onFeedbackDedupeChanged: (value) {
          setState(() => _feedbackDedupeEnabled = value);
        },
        onFeedbackResult: (value) {
          setState(() => _feedbackLastResult = value);
        },
        onAddFeedback: _showFeedback,
        onToggleTheme: () {
          setState(() {
            _themeMode = _themeMode == ThemeMode.dark
                ? ThemeMode.light
                : ThemeMode.dark;
          });
        },
      ),
    );
  }
}

class _UiLabWorkbench extends StatelessWidget {
  const _UiLabWorkbench({
    required this.themeMode,
    required this.experiment,
    required this.feedbackTone,
    required this.feedbackLifetime,
    required this.feedbackPriority,
    required this.feedbackActionEnabled,
    required this.feedbackDedupeEnabled,
    required this.feedbackLastResult,
    required this.feedbackController,
    required this.onExperimentChanged,
    required this.onFeedbackToneChanged,
    required this.onFeedbackLifetimeChanged,
    required this.onFeedbackPriorityChanged,
    required this.onFeedbackActionChanged,
    required this.onFeedbackDedupeChanged,
    required this.onFeedbackResult,
    required this.onAddFeedback,
    required this.onToggleTheme,
  });

  final ThemeMode themeMode;
  final UiLabExperiment experiment;
  final FeedbackTone feedbackTone;
  final FeedbackLifetime feedbackLifetime;
  final FeedbackPriority feedbackPriority;
  final bool feedbackActionEnabled;
  final bool feedbackDedupeEnabled;
  final VeriFeedbackResult? feedbackLastResult;
  final VeriFeedbackController feedbackController;
  final ValueChanged<UiLabExperiment> onExperimentChanged;
  final ValueChanged<FeedbackTone> onFeedbackToneChanged;
  final ValueChanged<FeedbackLifetime> onFeedbackLifetimeChanged;
  final ValueChanged<FeedbackPriority> onFeedbackPriorityChanged;
  final ValueChanged<bool> onFeedbackActionChanged;
  final ValueChanged<bool> onFeedbackDedupeChanged;
  final ValueChanged<VeriFeedbackResult> onFeedbackResult;
  final VoidCallback onAddFeedback;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Flutter Web 重载时可能先收到一个 1×1 的瞬态视口，等浏览器尺寸
          // 就绪后会立即重建。这里不在无意义的小约束中排版完整工作台。
          if (constraints.maxWidth < 320 || constraints.maxHeight < 320) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Veri Fin UI Lab',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Web 仅用于视觉预览 · 不连接任何真实数据',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurface.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      SegmentedButton<UiLabExperiment>(
                        key: const Key('experiment_switcher'),
                        showSelectedIcon: false,
                        segments: const <ButtonSegment<UiLabExperiment>>[
                          ButtonSegment<UiLabExperiment>(
                            value: UiLabExperiment.entryForm,
                            icon: Icon(Icons.edit_note_rounded, size: 18),
                            label: Text('记一笔'),
                          ),
                          ButtonSegment<UiLabExperiment>(
                            value: UiLabExperiment.accountIcons,
                            icon: Icon(Icons.apps_rounded, size: 18),
                            label: Text('账户图标'),
                          ),
                          ButtonSegment<UiLabExperiment>(
                            value: UiLabExperiment.navigation,
                            icon: Icon(Icons.dock_rounded, size: 18),
                            label: Text('根导航'),
                          ),
                          ButtonSegment<UiLabExperiment>(
                            value: UiLabExperiment.feedback,
                            icon: Icon(
                              Icons.notifications_none_rounded,
                              size: 18,
                            ),
                            label: Text('轻提示'),
                          ),
                        ],
                        selected: <UiLabExperiment>{experiment},
                        onSelectionChanged: (selection) {
                          onExperimentChanged(selection.first);
                        },
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        key: const Key('theme_toggle'),
                        tooltip: isDark ? '切换浅色模式' : '切换深色模式',
                        onPressed: onToggleTheme,
                        icon: Icon(
                          themeMode == ThemeMode.dark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
                if (experiment == UiLabExperiment.feedback)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 12, 10),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          '提示状态',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        SegmentedButton<FeedbackTone>(
                          key: const Key('feedback_tone_switcher'),
                          showSelectedIcon: false,
                          segments: const <ButtonSegment<FeedbackTone>>[
                            ButtonSegment<FeedbackTone>(
                              value: FeedbackTone.info,
                              icon: Icon(Icons.info_outline_rounded, size: 16),
                              label: Text('信息'),
                            ),
                            ButtonSegment<FeedbackTone>(
                              value: FeedbackTone.success,
                              icon: Icon(Icons.check_rounded, size: 16),
                              label: Text('成功'),
                            ),
                            ButtonSegment<FeedbackTone>(
                              value: FeedbackTone.warning,
                              icon: Icon(Icons.priority_high_rounded, size: 16),
                              label: Text('警告'),
                            ),
                            ButtonSegment<FeedbackTone>(
                              value: FeedbackTone.error,
                              icon: Icon(Icons.close_rounded, size: 16),
                              label: Text('错误'),
                            ),
                          ],
                          selected: <FeedbackTone>{feedbackTone},
                          onSelectionChanged: (selection) {
                            onFeedbackToneChanged(selection.first);
                          },
                        ),
                        Text(
                          '展示时长',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        SegmentedButton<FeedbackLifetime>(
                          key: const Key('feedback_lifetime_switcher'),
                          showSelectedIcon: false,
                          segments: const <ButtonSegment<FeedbackLifetime>>[
                            ButtonSegment<FeedbackLifetime>(
                              value: FeedbackLifetime.short,
                              label: Text('2秒'),
                            ),
                            ButtonSegment<FeedbackLifetime>(
                              value: FeedbackLifetime.standard,
                              label: Text('4秒'),
                            ),
                            ButtonSegment<FeedbackLifetime>(
                              value: FeedbackLifetime.long,
                              label: Text('8秒'),
                            ),
                            ButtonSegment<FeedbackLifetime>(
                              value: FeedbackLifetime.persistent,
                              label: Text('常驻'),
                            ),
                          ],
                          selected: <FeedbackLifetime>{feedbackLifetime},
                          onSelectionChanged: (selection) {
                            onFeedbackLifetimeChanged(selection.first);
                          },
                        ),
                        Text(
                          '优先级',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        SegmentedButton<FeedbackPriority>(
                          key: const Key('feedback_priority_switcher'),
                          showSelectedIcon: false,
                          segments: const <ButtonSegment<FeedbackPriority>>[
                            ButtonSegment<FeedbackPriority>(
                              value: FeedbackPriority.low,
                              label: Text('低'),
                            ),
                            ButtonSegment<FeedbackPriority>(
                              value: FeedbackPriority.normal,
                              label: Text('普通'),
                            ),
                            ButtonSegment<FeedbackPriority>(
                              value: FeedbackPriority.high,
                              label: Text('高'),
                            ),
                          ],
                          selected: <FeedbackPriority>{feedbackPriority},
                          onSelectionChanged: (selection) {
                            onFeedbackPriorityChanged(selection.first);
                          },
                        ),
                        FilterChip(
                          key: const Key('feedback_action_toggle'),
                          label: const Text('撤销操作'),
                          selected: feedbackActionEnabled,
                          onSelected: onFeedbackActionChanged,
                        ),
                        FilterChip(
                          key: const Key('feedback_dedupe_toggle'),
                          label: const Text('合并重复'),
                          selected: feedbackDedupeEnabled,
                          onSelected: onFeedbackDedupeChanged,
                        ),
                        FilledButton.tonalIcon(
                          key: const Key('feedback_add'),
                          onPressed: onAddFeedback,
                          icon: const Icon(Icons.add_rounded, size: 17),
                          label: const Text('添加提示'),
                        ),
                        if (feedbackLastResult != null)
                          Text(
                            '最近结果：${feedbackLastResult!.name}',
                            key: const Key('feedback_last_result'),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.62,
                                  ),
                                ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ColoredBox(
                    color: isDark
                        ? const Color(0xFF070A0F)
                        : const Color(0xFFE9EEF5),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.32 : 0.14,
                                  ),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: SizedBox(
                                key: Key('phone_viewport'),
                                width: 390,
                                height: 844,
                                child: VeriFeedbackHost(
                                  controller: feedbackController,
                                  child: switch (experiment) {
                                    UiLabExperiment.entryForm =>
                                      const EntryFormPreview(),
                                    UiLabExperiment.accountIcons =>
                                      const AccountIconPreview(),
                                    UiLabExperiment.navigation =>
                                      const NavigationPreview(),
                                    UiLabExperiment.feedback => FeedbackPreview(
                                      controller: feedbackController,
                                      tone: feedbackTone,
                                      lifetime: feedbackLifetime,
                                      priority: feedbackPriority,
                                      actionEnabled: feedbackActionEnabled,
                                      dedupeEnabled: feedbackDedupeEnabled,
                                      onResult: onFeedbackResult,
                                    ),
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
