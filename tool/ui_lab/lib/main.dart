import 'package:flutter/material.dart';
import 'package:verifin/app/app_theme.dart';

import 'navigation_preview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VeriFinUiLabApp());
}

class VeriFinUiLabApp extends StatefulWidget {
  const VeriFinUiLabApp({super.key});

  @override
  State<VeriFinUiLabApp> createState() => _VeriFinUiLabAppState();
}

class _VeriFinUiLabAppState extends State<VeriFinUiLabApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veri Fin UI Lab',
      debugShowCheckedModeBanner: false,
      theme: buildVeriFinTheme(Brightness.light),
      darkTheme: buildVeriFinTheme(Brightness.dark),
      themeMode: _themeMode,
      home: _UiLabWorkbench(
        themeMode: _themeMode,
        onToggleTheme: () {
          setState(() {
            _themeMode = _themeMode == ThemeMode.dark
                ? ThemeMode.light
                : ThemeMode.dark;
          });
        },
      ),
    );
  }
}

class _UiLabWorkbench extends StatelessWidget {
  const _UiLabWorkbench({required this.themeMode, required this.onToggleTheme});

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Flutter Web 重载时可能先收到一个 1×1 的瞬态视口，等浏览器尺寸
          // 就绪后会立即重建。这里不在无意义的小约束中排版完整工作台。
          if (constraints.maxWidth < 320 || constraints.maxHeight < 320) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Veri Fin UI Lab',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Web 仅用于视觉预览 · 不连接任何真实数据',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurface.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const Key('theme_toggle'),
                        tooltip: isDark ? '切换浅色模式' : '切换深色模式',
                        onPressed: onToggleTheme,
                        icon: Icon(
                          themeMode == ThemeMode.dark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    color: isDark
                        ? const Color(0xFF070A0F)
                        : const Color(0xFFE9EEF5),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.32 : 0.14,
                                  ),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: const SizedBox(
                                key: Key('phone_viewport'),
                                width: 390,
                                height: 844,
                                child: NavigationPreview(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
