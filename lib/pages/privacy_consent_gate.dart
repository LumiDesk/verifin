import 'package:flutter/material.dart';

import '../app/veri_fin_scope.dart';
import 'legal_pages.dart';

/// 隐私政策 / 用户协议同意门卫：覆盖在整个应用之上。未同意时呈现全屏同意页，
/// 同意后（`acceptPrivacyConsent` 会 notifyListeners）自动切换到主界面。
///
/// 放在 `MaterialApp.builder` 里、应用锁门卫之外（同意先于一切）。相比旧的
/// 一次性弹窗，门卫每次 build 都按 `privacyConsentAccepted` 决定显示，因此
/// 「拒绝退出后进程未被系统杀掉、热启动回到前台」时仍会继续要求同意，不会漏。
class PrivacyConsentGate extends StatelessWidget {
  const PrivacyConsentGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (VeriFinScope.of(context).privacyConsentAccepted) return child;
    // 用独立 Navigator 承载同意页，使页内「查看《隐私政策》」等 push 可用，
    // 且未同意前不构建主界面（避免引导页在同意前抢先触发）。
    return Navigator(
      key: const ValueKey('privacy_gate'),
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const PrivacyConsentPage()),
    );
  }
}
