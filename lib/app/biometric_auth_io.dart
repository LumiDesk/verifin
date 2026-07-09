import 'dart:io';

import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

import '../l10n/app_localizations.dart';

/// 生物识别系统弹窗文案。不传时 `local_auth` 会用英文默认串，与
/// `localizedReason` 语言不一致，故按当前语言组装。
/// local_auth_android 2.x 精简了可定制文案，仅保留标题 / 提示 / 取消三项，
/// 其余（未识别 / 需录入 / 跳转设置等）由系统统一呈现。
AndroidAuthMessages _androidAuthMessages(AppLocalizations l10n) {
  return AndroidAuthMessages(
    signInTitle: l10n.bioSignInTitle,
    signInHint: l10n.bioHint,
    cancelButton: l10n.commonCancel,
  );
}

/// 移动平台的生物识别实现。只调用系统能力（`local_auth`），不保存任何生物特征
/// 数据；系统生物信息录入变化时系统会失效并要求重新验证。仅在 Android/iOS 生效，
/// 其它平台（含测试宿主）一律不可用，因此不会真正触碰平台通道。
class BiometricAuth {
  const BiometricAuth();

  static final LocalAuthentication _auth = LocalAuthentication();

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  Future<bool> isAvailable() async {
    if (!_supported) {
      return false;
    }
    try {
      if (!await _auth.isDeviceSupported()) {
        return false;
      }
      if (!await _auth.canCheckBiometrics) {
        return false;
      }
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({
    required String reason,
    required AppLocalizations l10n,
  }) async {
    if (!_supported) {
      return false;
    }
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        authMessages: <AuthMessages>[_androidAuthMessages(l10n)],
        // 只用系统生物识别，不回落到设备 PIN/图案。3.x 起选项为直接命名参数：
        // stickyAuth → persistAcrossBackgrounding；useErrorDialogs 已移除（错误 UI
        // 由系统统一呈现）。
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
