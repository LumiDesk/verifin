import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/widget_configuration_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('配置读取已保存的实例值，并在保存后校验再完成系统配置', () async {
    const homeWidget = MethodChannel('home_widget');
    const app = MethodChannel('verifin/app');
    var stored = jsonEncode(<String, String>{'bookId': 'book-2', 'metric': 'netWorth'});
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidget, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'initiallyLaunchedFromHomeWidgetConfigure':
          return '42';
        case 'getWidgetData':
          final key = (call.arguments as Map)['id'] as String;
          if (key == 'verifin.widget.books') {
            return jsonEncode([
              {'id': 'book-1', 'name': '个人'},
              {'id': 'book-2', 'name': '旅行'},
            ]);
          }
          if (key == 'verifin.widget.config.42') return stored;
          return null;
        case 'saveWidgetData':
          final args = call.arguments as Map;
          stored = args['data'] as String;
          return true;
        case 'finishHomeWidgetConfigure':
          return null;
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(app, (call) async {
      if (call.method == 'widgetConfigurationInfo') {
        return <String, Object?>{
          'template': 'net_worth',
          'provider': 'top.talyra42.verifin.NetWorthWidgetProvider',
          'metric': 'netWorth',
        };
      }
      if (call.method == 'refreshWidgetInstance') {
        calls.add(call.method);
        return null;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(homeWidget, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(app, null);
    });

    final session = await WidgetConfigurationSession.load();
    expect(session.id, 42);
    expect(session.bookId, 'book-2');
    expect(session.metric, 'netWorth');
    await session.save(bookId: 'book-1', metric: 'todayExpense');
    expect(jsonDecode(stored), {'bookId': 'book-1', 'metric': 'todayExpense'});
    expect(calls, containsAll(<String>[
      'saveWidgetData',
      'getWidgetData',
      'finishHomeWidgetConfigure',
      'refreshWidgetInstance',
    ]));
  });
}
