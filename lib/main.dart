import 'package:flutter/material.dart';

import 'app/app_theme.dart';
import 'app/models.dart';
import 'app/veri_fin_controller.dart';
import 'app/veri_fin_scope.dart';
import 'data/app_database.dart';
import 'data/ledger_repository.dart';
import 'l10n/app_localizations.dart';
import 'local_storage/local_storage.dart';
import 'pages/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalKeyValueStore.create();
  LedgerRepository? repository;
  try {
    final database = await AppDatabase.open();
    repository = LedgerRepository(database);
  } catch (error, stack) {
    // 数据库不可用时回退到 KV，保证应用可启动而非白屏。
    debugPrint('SQLite 初始化失败，回退到 KV 存储：$error\n$stack');
  }
  final controller = await VeriFinController.create(
    store,
    repository: repository,
  );
  runApp(VeriFinApp(controller: controller));
}

class VeriFinApp extends StatefulWidget {
  const VeriFinApp({super.key, this.store, this.controller});

  /// 预先构建好的控制器（应用入口使用）。为空时由 [store] 现场构建（测试使用）。
  final VeriFinController? controller;
  final LocalKeyValueStore? store;

  @override
  State<VeriFinApp> createState() => _VeriFinAppState();
}

class _VeriFinAppState extends State<VeriFinApp> {
  late final VeriFinController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        VeriFinController(widget.store ?? LocalKeyValueStore());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VeriFinScope(
      controller: _controller,
      child: ValueListenableBuilder<ThemePreference>(
        valueListenable: _controller.themePreferenceListenable,
        builder: (context, themePreference, _) {
          return MaterialApp(
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            // 语言暂固定中文;应用内语言切换在 i18n 文案迁移完成后提供。
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            themeMode: themePreference.themeMode,
            theme: buildVeriFinTheme(Brightness.light),
            darkTheme: buildVeriFinTheme(Brightness.dark),
            home: const VeriFinShell(),
          );
        },
      ),
    );
  }
}
