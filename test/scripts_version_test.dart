// 仓库脚本（scripts/）里版本号逻辑的单测：递增规则与解析都必须稳定，
// 因为发布脚本会据此改写 pubspec.yaml 与 app_version.dart。

import 'package:flutter_test/flutter_test.dart';

import '../scripts/src/cli.dart';
import '../scripts/src/version.dart';

void main() {
  const current = RepoVersion(major: 1, minor: 18, patch: 20, build: 161);

  test('patch / minor / major 递增并同步提升构建号', () {
    expect(current.bump('patch').label, '1.18.21+162');
    expect(current.bump('minor').label, '1.19.0+162');
    expect(current.bump('major').label, '2.0.0+162');
  });

  test('显式版本号覆盖名称但构建号仍 +1', () {
    expect(current.bump('1.2.3').label, '1.2.3+162');
  });

  test('非法版本参数抛出 ScriptException', () {
    expect(() => current.bump('1.2'), throwsA(isA<ScriptException>()));
    expect(() => current.bump('vnext'), throwsA(isA<ScriptException>()));
  });

  test('解析 X.Y.Z+B 并派生 tag', () {
    final parsed = RepoVersion.parseLabel('1.18.20+161');
    expect(parsed.name, '1.18.20');
    expect(parsed.build, 161);
    expect(parsed.tag, 'v1.18.20');
    expect(
      () => RepoVersion.parseLabel('1.18.20'),
      throwsA(isA<ScriptException>()),
    );
  });

  test('从 pubspec 文本解析 version 行', () {
    const pubspec = '''
name: verifin
version: 1.18.20+161
environment:
  sdk: ^3.12.2
''';
    expect(RepoVersion.parsePubspec(pubspec).label, '1.18.20+161');
    expect(
      () => RepoVersion.parsePubspec('name: verifin\n'),
      throwsA(isA<ScriptException>()),
    );
  });
}
