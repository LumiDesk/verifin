import 'package:flutter/material.dart';

import '../app/veri_fin_controller.dart';
import '../app/veri_fin_scope.dart';
import 'app_lock_page.dart';

/// 应用锁门卫：覆盖在整个应用（含已 push 的路由）之上。冷启动即锁定；应用退到
/// 后台后回到前台时重新锁定。放在 `MaterialApp.builder` 里以覆盖根 Navigator。
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _initialized = false;
  VeriFinController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = VeriFinScope.of(context);
    if (!_initialized) {
      // 冷启动：已启用应用锁则初始锁定。
      _locked = _controller!.appLockEnabled;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.appLockEnabled) {
      return;
    }
    // 退到后台时预置锁定，回到前台即呈现锁屏。
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (!_locked) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = VeriFinScope.of(context);
    final showLock = _locked && controller.appLockEnabled;
    return Stack(
      children: <Widget>[
        // 半透明材质不能透出锁屏下方的账目；保留页面状态，但停止绘制、语义和焦点访问。
        ExcludeFocus(
          excluding: showLock,
          child: Offstage(offstage: showLock, child: widget.child),
        ),
        if (showLock)
          // 本门卫位于 `MaterialApp.builder`，即在根 Navigator 之上，自身没有
          // Navigator/Overlay 祖先。锁屏里的确认框要走 Navigator，因此必须像
          // PrivacyConsentGate / OnboardingGate 一样自带一个独立 Navigator；
          // 这里根 Navigator 仍在树中，需用 `HeroControllerScope.none` 避免两个
          // Navigator 共用同一个 HeroController。
          HeroControllerScope.none(
            child: Navigator(
              key: const ValueKey('app_lock_gate'),
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => AppLockScreen(
                  onUnlocked: () => setState(() => _locked = false),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
