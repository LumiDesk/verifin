// 守卫：业务代码只能经 VeriHaptics 发触感。
//
// 统一入口的价值来自「不能绕开」——散落回 `HapticFeedback.xxx()` 后，开关、
// 语义分级与 Material 长按的收编都会重新失守，而 widget 测试很难覆盖每一处点击。
// 这里用源码扫描把这条约定变成 CI 门禁（与 android_manifest_policy_test 同思路）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('业务代码不得直接调用 HapticFeedback，统一走 VeriHaptics', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: '测试需在仓库根目录运行');

    final allowed = <String>{'lib/app/haptics.dart'};
    final offenders = <String>[];

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final path = entity.path.replaceAll(r'\', '/');
      if (allowed.contains(path)) {
        continue;
      }
      if (entity.readAsStringSync().contains('HapticFeedback.')) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '触感必须统一经 lib/app/haptics.dart 的 VeriHaptics 发送；'
          '直接调用会绕过设置开关与语义分级：$offenders',
    );
  });
}
