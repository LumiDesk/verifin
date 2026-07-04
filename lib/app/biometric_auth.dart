/// 生物解锁（系统生物识别）的平台适配入口。测试宿主走占位（不可用），移动端走 `local_auth`。
/// 只调用系统能力，不保存任何生物特征数据。
library;

export 'biometric_auth_stub.dart' if (dart.library.io) 'biometric_auth_io.dart';
