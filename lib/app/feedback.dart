import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

enum VeriFeedbackTone { info, success, warning, error }

enum VeriFeedbackPriority { low, normal, high }

enum VeriFeedbackDuration {
  short(Duration(seconds: 2)),
  standard(Duration(seconds: 4)),
  long(Duration(seconds: 8)),
  persistent(null);

  const VeriFeedbackDuration(this.value);

  final Duration? value;
}

enum VeriFeedbackResult {
  timedOut,
  dismissed,
  action,
  replaced,
  dropped,
  cleared,
}

@immutable
class VeriFeedbackRequest {
  const VeriFeedbackRequest({
    required this.message,
    this.tone = VeriFeedbackTone.info,
    this.duration = VeriFeedbackDuration.standard,
    this.priority = VeriFeedbackPriority.normal,
    this.actionLabel,
    this.dedupeKey,
  }) : assert(message != ''),
       assert(actionLabel == null || actionLabel != ''),
       assert(dedupeKey == null || dedupeKey != '');

  final String message;
  final VeriFeedbackTone tone;
  final VeriFeedbackDuration duration;
  final VeriFeedbackPriority priority;
  final String? actionLabel;
  final String? dedupeKey;
}

class VeriFeedbackController {
  _VeriFeedbackHostState? _host;
  final List<_BufferedFeedback> _buffer = <_BufferedFeedback>[];
  var _disposed = false;

  bool get attached => _host != null;

  Future<VeriFeedbackResult> show(VeriFeedbackRequest request) {
    if (_disposed) {
      throw StateError('VeriFeedbackController has been disposed');
    }
    final host = _host;
    if (host != null) {
      return host._enqueue(request);
    }
    final dedupeKey = request.dedupeKey;
    if (dedupeKey != null) {
      final duplicate = _buffer
          .where((item) => item.request.dedupeKey == dedupeKey)
          .firstOrNull;
      if (duplicate != null) {
        duplicate
          ..request = request
          ..count += 1;
        return Future<VeriFeedbackResult>.value(VeriFeedbackResult.replaced);
      }
    }
    final completer = Completer<VeriFeedbackResult>();
    _buffer.add(_BufferedFeedback(request: request, completer: completer));
    return completer.future;
  }

  Future<VeriFeedbackResult> showMessage({
    required String message,
    VeriFeedbackTone tone = VeriFeedbackTone.info,
    VeriFeedbackDuration duration = VeriFeedbackDuration.standard,
    VeriFeedbackPriority priority = VeriFeedbackPriority.normal,
    String? actionLabel,
    String? dedupeKey,
  }) {
    return show(
      VeriFeedbackRequest(
        message: message,
        tone: tone,
        duration: duration,
        priority: priority,
        actionLabel: actionLabel,
        dedupeKey: dedupeKey,
      ),
    );
  }

  void dismissAll() {
    _host?._clearAll(VeriFeedbackResult.cleared);
    for (final buffered in _buffer) {
      _complete(buffered.completer, VeriFeedbackResult.cleared);
    }
    _buffer.clear();
  }

  void _attach(_VeriFeedbackHostState host) {
    if (_disposed) return;
    final existing = _host;
    if (existing != null && !identical(existing, host)) {
      throw StateError('VeriFeedbackController already has a host');
    }
    _host = host;
    for (final buffered in _buffer) {
      host._enqueueWithCompleter(
        buffered.request,
        buffered.completer,
        initialCount: buffered.count,
        notify: false,
      );
    }
    _buffer.clear();
  }

  void _detach(_VeriFeedbackHostState host) {
    if (identical(_host, host)) {
      _host = null;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final host = _host;
    _host = null;
    host?._clearAll(VeriFeedbackResult.cleared, notify: false);
    for (final buffered in _buffer) {
      _complete(buffered.completer, VeriFeedbackResult.cleared);
    }
    _buffer.clear();
  }
}

class VeriFeedbackHost extends StatefulWidget {
  const VeriFeedbackHost({
    super.key,
    required this.controller,
    required this.child,
    this.maxVisible = 4,
    this.queueLimit = 16,
    this.bottomMargin = 100,
  }) : assert(maxVisible > 0),
       assert(queueLimit > 0),
       assert(bottomMargin >= 0);

  final VeriFeedbackController controller;
  final Widget child;
  final int maxVisible;
  final int queueLimit;

  /// Extra space above the system bottom inset.
  final double bottomMargin;

  static VeriFeedbackController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_VeriFeedbackScope>();
    assert(scope != null, 'No VeriFeedbackHost found in context');
    return scope!.controller;
  }

  @override
  State<VeriFeedbackHost> createState() => _VeriFeedbackHostState();
}

class _VeriFeedbackHostState extends State<VeriFeedbackHost>
    with WidgetsBindingObserver {
  final List<_FeedbackEntry> _visible = <_FeedbackEntry>[];
  final List<_FeedbackEntry> _pending = <_FeedbackEntry>[];
  var _nextId = 0;
  var _paused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _paused = lifecycle != null && lifecycle != AppLifecycleState.resumed;
    widget.controller._attach(this);
  }

  @override
  void didUpdateWidget(covariant VeriFeedbackHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _clearAll(VeriFeedbackResult.cleared, notify: false);
      oldWidget.controller._detach(this);
      widget.controller._attach(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final paused = state != AppLifecycleState.resumed;
    if (_paused != paused && mounted) {
      setState(() => _paused = paused);
    }
  }

  Future<VeriFeedbackResult> _enqueue(VeriFeedbackRequest request) {
    final completer = Completer<VeriFeedbackResult>();
    return _enqueueWithCompleter(request, completer);
  }

  Future<VeriFeedbackResult> _enqueueWithCompleter(
    VeriFeedbackRequest request,
    Completer<VeriFeedbackResult> completer, {
    int initialCount = 1,
    bool notify = true,
  }) {
    final dedupeKey = request.dedupeKey;
    if (dedupeKey != null) {
      final duplicate = <_FeedbackEntry>[
        ..._visible,
        ..._pending,
      ].where((entry) => entry.request.dedupeKey == dedupeKey).firstOrNull;
      if (duplicate != null) {
        duplicate
          ..request = request
          ..count += 1
          ..revision += 1;
        if (_pending.contains(duplicate)) {
          _pending.remove(duplicate);
          _insertPending(duplicate);
        }
        if (notify) setState(() {});
        _complete(completer, VeriFeedbackResult.replaced);
        return completer.future;
      }
    }

    final entry = _FeedbackEntry(
      id: _nextId,
      request: request,
      completer: completer,
      count: initialCount,
    );
    _nextId += 1;
    void add() {
      if (_visible.length < widget.maxVisible) {
        _visible.add(entry);
      } else {
        _addPendingWithLimit(entry);
      }
    }

    if (notify) {
      setState(add);
    } else {
      add();
    }
    return completer.future;
  }

  void _addPendingWithLimit(_FeedbackEntry entry) {
    if (_pending.length < widget.queueLimit) {
      _insertPending(entry);
      return;
    }
    final lowestPriority = _pending
        .map((item) => item.request.priority.index)
        .reduce((a, b) => a < b ? a : b);
    final dropIndex = _pending.indexWhere(
      (item) => item.request.priority.index == lowestPriority,
    );
    if (entry.request.priority.index >= lowestPriority) {
      final dropped = _pending.removeAt(dropIndex);
      _complete(dropped.completer, VeriFeedbackResult.dropped);
      _insertPending(entry);
    } else {
      _complete(entry.completer, VeriFeedbackResult.dropped);
    }
  }

  void _insertPending(_FeedbackEntry entry) {
    final index = _pending.indexWhere(
      (item) => item.request.priority.index < entry.request.priority.index,
    );
    if (index < 0) {
      _pending.add(entry);
    } else {
      _pending.insert(index, entry);
    }
  }

  void _finishEntry(int id, VeriFeedbackResult result) {
    if (!mounted) return;
    setState(() {
      final index = _visible.indexWhere((entry) => entry.id == id);
      if (index < 0) return;
      final entry = _visible.removeAt(index);
      _complete(entry.completer, result);
      if (_pending.isNotEmpty) {
        _visible.add(_pending.removeAt(0));
      }
    });
  }

  void _clearAll(VeriFeedbackResult result, {bool notify = true}) {
    void clear() {
      for (final entry in <_FeedbackEntry>[..._visible, ..._pending]) {
        _complete(entry.completer, result);
      }
      _visible.clear();
      _pending.clear();
    }

    if (notify && mounted) {
      setState(clear);
    } else {
      clear();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearAll(VeriFeedbackResult.cleared, notify: false);
    widget.controller._detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.viewPaddingOf(context).bottom + widget.bottomMargin;
    return _VeriFeedbackScope(
      controller: widget.controller,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          if (_visible.isNotEmpty || _pending.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottom,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_pending.isNotEmpty)
                      Padding(
                        key: const Key('veri_feedback_pending_slot'),
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _PendingFeedbackLabel(count: _pending.length),
                      ),
                    for (var index = 0; index < _visible.length; index += 1)
                      _VeriFeedbackCard(
                        key: ValueKey<int>(_visible[index].id),
                        id: _visible[index].id,
                        request: _visible[index].request,
                        count: _visible[index].count,
                        revision: _visible[index].revision,
                        paused: _paused,
                        bottomSpacing: index == _visible.length - 1 ? 0 : 6,
                        onFinish: _finishEntry,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VeriFeedbackCard extends StatefulWidget {
  const _VeriFeedbackCard({
    super.key,
    required this.id,
    required this.request,
    required this.count,
    required this.revision,
    required this.paused,
    required this.bottomSpacing,
    required this.onFinish,
  });

  final int id;
  final VeriFeedbackRequest request;
  final int count;
  final int revision;
  final bool paused;
  final double bottomSpacing;
  final void Function(int id, VeriFeedbackResult result) onFinish;

  @override
  State<_VeriFeedbackCard> createState() => _VeriFeedbackCardState();
}

class _VeriFeedbackCardState extends State<_VeriFeedbackCard>
    with TickerProviderStateMixin {
  late final AnimationController _entryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 180),
  )..addStatusListener(_handleEntryStatus);
  AnimationController? _lifetimeController;
  var _hovered = false;
  var _dismissing = false;
  VeriFeedbackResult? _result;

  @override
  void initState() {
    super.initState();
    _configureLifetime();
    _entryController.forward();
  }

  @override
  void didUpdateWidget(covariant _VeriFeedbackCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        oldWidget.request.duration != widget.request.duration) {
      _dismissing = false;
      _result = null;
      _configureLifetime();
      _entryController.forward();
    } else if (oldWidget.paused != widget.paused) {
      _syncLifetime();
    }
  }

  void _configureLifetime() {
    _lifetimeController
      ?..removeStatusListener(_handleLifetimeStatus)
      ..dispose();
    final duration = widget.request.duration.value;
    _lifetimeController = duration == null
        ? null
        : (AnimationController(vsync: this, duration: duration)
            ..addStatusListener(_handleLifetimeStatus));
    _syncLifetime(reset: true);
  }

  void _syncLifetime({bool reset = false}) {
    final controller = _lifetimeController;
    if (controller == null) return;
    if (reset) controller.value = 0;
    if (widget.paused || _hovered || _dismissing) {
      controller.stop();
    } else if (controller.status != AnimationStatus.completed) {
      controller.forward();
    }
  }

  void _handleLifetimeStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _dismiss(VeriFeedbackResult.timedOut);
    }
  }

  void _handleEntryStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _dismissing && mounted) {
      widget.onFinish(widget.id, _result ?? VeriFeedbackResult.dismissed);
    }
  }

  void _dismiss(VeriFeedbackResult result) {
    if (_dismissing) return;
    _dismissing = true;
    _result = result;
    _lifetimeController?.stop();
    _entryController.reverse();
  }

  void _pauseLifetime(PointerEnterEvent _) {
    _hovered = true;
    _syncLifetime();
  }

  void _resumeLifetime(PointerExitEvent _) {
    _hovered = false;
    _syncLifetime();
  }

  @override
  void dispose() {
    _lifetimeController
      ?..removeStatusListener(_handleLifetimeStatus)
      ..dispose();
    _entryController
      ..removeStatusListener(_handleEntryStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entrance = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SizeTransition(
      key: Key('veri_feedback_size_${widget.id}'),
      sizeFactor: entrance,
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: widget.bottomSpacing),
        child: MouseRegion(
          onEnter: _pauseLifetime,
          onExit: _resumeLifetime,
          child: FadeTransition(
            opacity: entrance,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.16),
                end: Offset.zero,
              ).animate(entrance),
              child: _buildCard(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final theme = Theme.of(context);
    final request = widget.request;
    final isDark = theme.brightness == Brightness.dark;
    final foreground = theme.colorScheme.onSurface;
    final toneColor = _toneColor(request.tone);
    final hasProgress = _lifetimeController != null;
    final hasAction = request.actionLabel != null;
    final width = hasAction
        ? 240.0
        : widget.count > 1
        ? 188.0
        : 168.0;
    final surface = isDark ? veriSurfaceAltDark : veriSurfaceLight;
    final outline = (isDark ? Colors.white : veriInk).withValues(
      alpha: isDark ? 0.15 : 0.10,
    );
    final track = foreground.withValues(alpha: isDark ? 0.13 : 0.09);

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(veriRadiusMd),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          key: Key('veri_feedback_card_${widget.id}'),
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(veriRadiusMd),
            side: BorderSide(color: outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 40,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: hasProgress
                        ? const EdgeInsets.fromLTRB(8, 4, 4, 3)
                        : const EdgeInsets.fromLTRB(8, 8, 4, 8),
                    child: Row(
                      children: <Widget>[
                        Container(
                          key: Key('veri_feedback_icon_${widget.id}'),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: toneColor.withValues(
                              alpha: isDark ? 0.22 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(veriRadiusSm),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _toneIcon(request.tone),
                            color: toneColor,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            request.message,
                            key: Key('veri_feedback_message_${widget.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: foreground.withValues(alpha: 0.94),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (widget.count > 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Transform.translate(
                              key: Key('veri_feedback_count_${widget.id}'),
                              offset: const Offset(0, 2),
                              child: Text(
                                '×${widget.count}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: foreground.withValues(alpha: 0.50),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        if (hasAction)
                          TextButton(
                            key: Key('veri_feedback_action_${widget.id}'),
                            onPressed: () =>
                                _dismiss(VeriFeedbackResult.action),
                            style: TextButton.styleFrom(
                              foregroundColor: toneColor,
                              minimumSize: const Size(0, 28),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(
                              request.actionLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        SizedBox(
                          width: 24,
                          height: 28,
                          child: InkWell(
                            key: Key('veri_feedback_close_${widget.id}'),
                            customBorder: const CircleBorder(),
                            onTap: () => _dismiss(VeriFeedbackResult.dismissed),
                            child: Icon(
                              Icons.close_rounded,
                              size: 12,
                              color: foreground.withValues(alpha: 0.46),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasProgress)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 5),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(veriRadiusSm),
                      child: ColoredBox(
                        color: track,
                        child: SizedBox(
                          width: double.infinity,
                          height: 1.5,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedBuilder(
                              animation: _lifetimeController!,
                              builder: (context, _) {
                                return FractionallySizedBox(
                                  key: Key(
                                    'veri_feedback_progress_${widget.id}',
                                  ),
                                  widthFactor: (1 - _lifetimeController!.value)
                                      .clamp(0, 1),
                                  heightFactor: 1,
                                  child: ColoredBox(color: toneColor),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingFeedbackLabel extends StatelessWidget {
  const _PendingFeedbackLabel({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      key: const Key('veri_feedback_pending_count'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : veriInk).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(veriRadiusSm),
      ),
      child: Text(
        '+$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _VeriFeedbackScope extends InheritedWidget {
  const _VeriFeedbackScope({required this.controller, required super.child});

  final VeriFeedbackController controller;

  @override
  bool updateShouldNotify(_VeriFeedbackScope oldWidget) {
    return !identical(controller, oldWidget.controller);
  }
}

class _FeedbackEntry {
  _FeedbackEntry({
    required this.id,
    required this.request,
    required this.completer,
    this.count = 1,
  });

  final int id;
  VeriFeedbackRequest request;
  final Completer<VeriFeedbackResult> completer;
  int count;
  int revision = 0;
}

class _BufferedFeedback {
  _BufferedFeedback({required this.request, required this.completer});

  VeriFeedbackRequest request;
  final Completer<VeriFeedbackResult> completer;
  int count = 1;
}

void _complete(
  Completer<VeriFeedbackResult> completer,
  VeriFeedbackResult result,
) {
  if (!completer.isCompleted) {
    completer.complete(result);
  }
}

Color _toneColor(VeriFeedbackTone tone) {
  return switch (tone) {
    VeriFeedbackTone.info => veriRoyal,
    VeriFeedbackTone.success => veriIncome,
    VeriFeedbackTone.warning => veriWarning,
    VeriFeedbackTone.error => veriExpense,
  };
}

IconData _toneIcon(VeriFeedbackTone tone) {
  return switch (tone) {
    VeriFeedbackTone.info => Icons.info_rounded,
    VeriFeedbackTone.success => Icons.check_rounded,
    VeriFeedbackTone.warning => Icons.priority_high_rounded,
    VeriFeedbackTone.error => Icons.close_rounded,
  };
}
