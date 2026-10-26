import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../app_version.dart';
import '../app_theme.dart';
import '../common_widgets.dart';
import 'startup_coordinator.dart';
import 'startup_error_sink.dart';

/// 应用启动壳。
///
/// `main()` 不再在 `runApp()` 之前等待数据库/控制器：它先渲染这里，再由
/// [StartupCoordinator] 在**有界面的情况下**逐阶段初始化。这样任何一段慢住
/// 都表现为「可见的启动页 + 阶段 + 重试」，而不是无限停留在启动窗口
/// （浅色白屏 / 深色黑屏）。
class VeriFinBootstrap extends StatefulWidget {
  const VeriFinBootstrap({
    super.key,
    required this.errors,
    required this.createCoordinator,
    required this.buildApp,
  });

  /// 启动早期错误缓冲；[createCoordinator] 打开 KV 后会把 logger 接上去。
  final StartupErrorSink errors;

  /// 每次调用返回一个全新的协调器（重试时使用）。
  final StartupCoordinator Function() createCoordinator;

  /// 启动完成后的真实应用。
  final Widget Function() buildApp;

  @override
  State<VeriFinBootstrap> createState() => _VeriFinBootstrapState();
}

class _VeriFinBootstrapState extends State<VeriFinBootstrap> {
  late StartupCoordinator _coordinator;
  Timer? _ticker;
  bool _ready = false;
  bool _restarting = false;

  @override
  void initState() {
    super.initState();
    _startRun();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // 首帧已经可见：之后即使某个阶段卡住，用户也不会再面对空白窗口。
      widget.errors.info('Startup: first frame rendered', source: 'startup');
    });
  }

  void _startRun() {
    final coordinator = widget.createCoordinator();
    coordinator.addListener(_handleCoordinatorChanged);
    _coordinator = coordinator;
    unawaited(coordinator.start());
    // 每秒刷新一次已等待时长；只有启动页需要它。
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_ready) {
        setState(() {});
      }
    });
  }

  void _handleCoordinatorChanged() {
    if (!mounted) {
      return;
    }
    final ready =
        _coordinator.stage == StartupStage.ready && _coordinator.error == null;
    final failed = _coordinator.error != null;
    if (ready != _ready) {
      _ready = ready;
    }
    if ((ready || failed) && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
    setState(() {});
  }

  void _retry() {
    if (_restarting) {
      return;
    }
    _restarting = true;
    final previous = _coordinator;
    previous.removeListener(_handleCoordinatorChanged);
    previous.abandon();
    previous.dispose();
    widget.errors.info(
      'Startup: retrying after user request',
      source: 'startup',
    );
    setState(() {
      _ready = false;
      _restarting = false;
      _startRun();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    _coordinator.removeListener(_handleCoordinatorChanged);
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return widget.buildApp();
    }
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildVeriFinTheme(Brightness.light),
      darkTheme: buildVeriFinTheme(Brightness.dark),
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: _StartupPage(
        coordinator: _coordinator,
        onRetry: _retry,
        onCopy: _copyDiagnostics,
      ),
    );
  }

  String _diagnosticsText() {
    final coordinator = _coordinator;
    final buffer = StringBuffer()
      ..writeln('Veri Fin $appVersionLabel')
      ..writeln('stage: ${coordinator.stage.name}')
      ..writeln('elapsed: ${coordinator.elapsed.inMilliseconds}ms')
      ..writeln('timings: ${coordinator.timingSummary}');
    final failedStage = coordinator.failedStage;
    if (failedStage != null) {
      buffer.writeln('failed stage: ${failedStage.name}');
    }
    final error = coordinator.error;
    if (error != null) {
      buffer.writeln('error: $error');
    }
    final stack = coordinator.errorStack;
    if (stack != null) {
      buffer.writeln(stack);
    }
    return buffer.toString().trimRight();
  }

  Future<bool> _copyDiagnostics() async {
    try {
      await Clipboard.setData(ClipboardData(text: _diagnosticsText()));
      widget.errors.info('Startup: diagnostics copied', source: 'startup');
      return true;
    } catch (error, stackTrace) {
      widget.errors.error(
        'Startup: copying diagnostics failed',
        source: 'startup',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}

class _StartupPage extends StatefulWidget {
  const _StartupPage({
    required this.coordinator,
    required this.onRetry,
    required this.onCopy,
  });

  final StartupCoordinator coordinator;
  final VoidCallback onRetry;
  final Future<bool> Function() onCopy;

  @override
  State<_StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<_StartupPage> {
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    final copied = await widget.onCopy();
    if (!mounted || !copied) {
      return;
    }
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final coordinator = widget.coordinator;
    final failed = coordinator.error != null;
    final stalled = coordinator.stalled && !failed;
    final stageLabel = _stageLabel(
      l10n,
      coordinator.failedStage ?? coordinator.stage,
    );
    final databaseFailure = coordinator.failedStage == StartupStage.database;

    final title = failed
        ? (databaseFailure ? l10n.dbErrorTitle : l10n.startupFailedTitle)
        : (stalled ? l10n.startupSlowTitle : l10n.startupPreparingTitle);
    final body = failed
        ? (databaseFailure
              ? l10n.dbErrorBody
              : l10n.startupFailedBody(stageLabel))
        : (stalled
              ? l10n.startupSlowBody(stageLabel)
              : l10n.startupPreparingBody);

    return Scaffold(
      body: SafeArea(
        child: VeriPage(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
            children: <Widget>[
              const SizedBox(height: 72),
              Center(
                child: _StartupMark(failed: failed, stalled: stalled),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (databaseFailure) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  l10n.dbErrorHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                stageLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.startupElapsed(coordinator.elapsed.inSeconds),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (!failed) ...<Widget>[
                const SizedBox(height: 24),
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ],
              if (failed) ...<Widget>[
                const SizedBox(height: 20),
                _FailureDetails(
                  label: l10n.dbErrorDetail,
                  detail: _failureDetail(coordinator),
                ),
              ],
              if (failed || stalled) ...<Widget>[
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _copy,
                        child: Text(
                          _copied
                              ? l10n.startupDiagnosticsCopied
                              : l10n.startupCopyDiagnostics,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: widget.onRetry,
                        child: Text(l10n.startupRetry),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _failureDetail(StartupCoordinator coordinator) {
    final error = coordinator.error;
    final buffer = StringBuffer('stage: ${coordinator.failedStage?.name}');
    if (error != null) {
      buffer.write('\n$error');
    }
    final stack = coordinator.errorStack;
    if (stack != null) {
      buffer.write('\n$stack');
    }
    return buffer.toString();
  }

  static String _stageLabel(AppLocalizations l10n, StartupStage stage) {
    switch (stage) {
      case StartupStage.preferences:
        return l10n.startupStagePreferences;
      case StartupStage.database:
        return l10n.startupStageDatabase;
      case StartupStage.controller:
        return l10n.startupStageController;
      case StartupStage.recurring:
        return l10n.startupStageRecurring;
      case StartupStage.warmUp:
        return l10n.startupStageWarmUp;
      case StartupStage.ready:
        return l10n.startupStageReady;
    }
  }
}

class _StartupMark extends StatelessWidget {
  const _StartupMark({required this.failed, required this.stalled});

  final bool failed;
  final bool stalled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = failed
        ? scheme.error
        : (stalled ? scheme.tertiary : scheme.primary);
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(veriRadiusXl),
      ),
      child: Icon(
        failed ? Icons.error_outline : Icons.savings_outlined,
        size: 36,
        color: color,
      ),
    );
  }
}

class _FailureDetails extends StatelessWidget {
  const _FailureDetails({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(veriRadiusSm),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              detail,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
