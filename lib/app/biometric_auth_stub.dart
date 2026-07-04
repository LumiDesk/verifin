/// 非移动平台（Web）的生物识别占位实现：始终不可用。
class BiometricAuth {
  const BiometricAuth();

  /// 设备是否可用生物识别（已录入且系统支持）。
  Future<bool> isAvailable() async => false;

  /// 发起一次生物识别验证。返回是否通过。
  Future<bool> authenticate({required String reason}) async => false;
}
