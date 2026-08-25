import 'dart:async';

import 'package:flutter/material.dart';
import 'package:verifin/app/feedback.dart';

import 'navigation_preview.dart';

typedef FeedbackTone = VeriFeedbackTone;
typedef FeedbackLifetime = VeriFeedbackDuration;
typedef FeedbackPriority = VeriFeedbackPriority;

extension FeedbackTonePreview on VeriFeedbackTone {
  String get label => switch (this) {
    VeriFeedbackTone.info => '信息',
    VeriFeedbackTone.success => '成功',
    VeriFeedbackTone.warning => '警告',
    VeriFeedbackTone.error => '错误',
  };

  String get message => switch (this) {
    VeriFeedbackTone.info => '再按一次退出',
    VeriFeedbackTone.success => '备份已保存',
    VeriFeedbackTone.warning => '请至少保留一个面板',
    VeriFeedbackTone.error => '保存失败，请重试',
  };
}

extension FeedbackLifetimePreview on VeriFeedbackDuration {
  String get label => switch (this) {
    VeriFeedbackDuration.short => '2秒',
    VeriFeedbackDuration.standard => '4秒',
    VeriFeedbackDuration.long => '8秒',
    VeriFeedbackDuration.persistent => '常驻',
  };
}

extension FeedbackPriorityPreview on VeriFeedbackPriority {
  String get label => switch (this) {
    VeriFeedbackPriority.low => '低',
    VeriFeedbackPriority.normal => '普通',
    VeriFeedbackPriority.high => '高',
  };
}

class FeedbackPreview extends StatefulWidget {
  const FeedbackPreview({
    super.key,
    required this.tone,
    required this.lifetime,
    required this.priority,
    required this.requestToken,
    required this.actionEnabled,
    required this.dedupeEnabled,
    this.onResult,
  });

  final VeriFeedbackTone tone;
  final VeriFeedbackDuration lifetime;
  final VeriFeedbackPriority priority;
  final int requestToken;
  final bool actionEnabled;
  final bool dedupeEnabled;
  final ValueChanged<VeriFeedbackResult>? onResult;

  @override
  State<FeedbackPreview> createState() => _FeedbackPreviewState();
}

class _FeedbackPreviewState extends State<FeedbackPreview> {
  final VeriFeedbackController _controller = VeriFeedbackController();

  @override
  void initState() {
    super.initState();
    _show();
  }

  @override
  void didUpdateWidget(covariant FeedbackPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestToken != widget.requestToken) {
      _show();
    }
  }

  void _show() {
    final result = _controller.showMessage(
      message: widget.tone.message,
      tone: widget.tone,
      duration: widget.lifetime,
      priority: widget.priority,
      actionLabel: widget.actionEnabled ? '撤销' : null,
      dedupeKey: widget.dedupeEnabled ? 'ui-lab-${widget.tone.name}' : null,
    );
    unawaited(
      result.then((value) {
        if (mounted) widget.onResult?.call(value);
      }),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VeriFeedbackHost(
      key: const Key('feedback_preview'),
      controller: _controller,
      child: const _FeedbackRouteDemo(),
    );
  }
}

class _FeedbackRouteDemo extends StatelessWidget {
  const _FeedbackRouteDemo();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (context) => Stack(
          children: <Widget>[
            const NavigationPreview(),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton.filledTonal(
                key: const Key('feedback_push_route'),
                tooltip: '测试跨页面提示',
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => const _FeedbackRoutePage(),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackRoutePage extends StatelessWidget {
  const _FeedbackRoutePage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconButton(
                key: const Key('feedback_pop_route'),
                tooltip: '返回',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(height: 24),
              Text(
                '路由测试页',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '提示宿主位于 Navigator 之上，进入和离开此页都不会重建提示。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
