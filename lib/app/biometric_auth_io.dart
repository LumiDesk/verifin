import 'dart:io';

import 'package:local_auth/local_auth.dart';

/// 移动平台的生物识别实现。只调用系统能力（`local_auth`），不保存任何生物特征
/// 数据；系统指纹录入变化时系统会失效并要求重新验证。仅在 Android/iOS 生效，
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

  Future<bool> authenticate({required String reason}) async {
    if (!_supported) {
      return false;
    }
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // 只用系统生物识别（指纹），不回落到设备 PIN/图案。
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
