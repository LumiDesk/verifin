part of 'platform_bridge.dart';

/// 液态玻璃底栏（原生 QWEA0 栏）的原生桥。
///
/// Flutter 侧样式是「驱动器 + fallback」：原生栏可用时经本桥指挥原生
/// LiquidGlassTabBar（折射、水滴、tab 全部原生绘制）；不可用（非 Android、
/// SDK<33、初始化失败）时 Flutter fallback 样式（自有着色器近似）接管。
class AppGlassBridge {
  AppGlassBridge._();

  /// 原生栏可用与否；null = 尚未探测。
  static final ValueNotifier<bool?> nativeAvailable = ValueNotifier<bool?>(
    null,
  );

  /// 原生 tab 被点击/拖动选中时由原生侧回调。
  static void Function(int index)? onTabSelected;

  /// 挂载原生玻璃底栏。返回是否成功激活。
  ///
  /// [tabs] 的图标必须是**白色剪影**光栅化 PNG 字节：原生侧用 `imageTintList`
  /// 按库内反色配色上色，带颜色的原图 tint 无效。
  ///
  /// [accentOverLight] / [accentOverDark] 为主题主色的两档 ARGB 变体，原生侧按
  /// 背景采样结果选用其一给选中项上色（见 `veriLiquidGlassAccentPair`）。
  static Future<bool> install({
    required int selectedIndex,
    required bool dark,
    required int accentOverLight,
    required int accentOverDark,
    List<({String label, Uint8List? icon})>? tabs,
    double? bottomInset,
  }) async {
    try {
      _ensureInboundDispatcher();
      final ok = await _channel.invokeMethod<bool>('installLiquidGlassBar', {
        'selectedIndex': selectedIndex,
        'dark': dark,
        'accentOverLight': accentOverLight,
        'accentOverDark': accentOverDark,
        if (tabs != null)
          'tabs': <Map<String, Object?>>[
            for (final tab in tabs)
              <String, Object?>{
                'label': tab.label,
                if (tab.icon != null) 'icon': tab.icon,
              },
          ],
        'bottomInset': ?bottomInset,
      });
      nativeAvailable.value = ok ?? false;
      return ok ?? false;
    } on MissingPluginException {
      nativeAvailable.value = false;
      return false;
    } on PlatformException {
      nativeAvailable.value = false;
      return false;
    }
  }

  /// 卸载原生栏（切回其它样式或 fallback）。
  static Future<void> uninstall() async {
    try {
      await _channel.invokeMethod<void>('uninstallLiquidGlassBar');
    } on MissingPluginException {
      // 忽略。
    } on PlatformException {
      // 忽略。
    }
  }

  /// 原生栏激活期间更新几何（主题/键盘避让时重装）。
  static Future<void> updateGeometry({
    required bool dark,
    double? bottomInset,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateLiquidGlassGeometry', {
        'dark': dark,
        'bottomInset': ?bottomInset,
      });
    } on MissingPluginException {
      // 忽略。
    } on PlatformException {
      // 忽略。
    }
  }

  /// 切主题或换主题色时同步原生栏配色。[dark] 为深色主题，决定玻璃与水滴的
  /// 初始亮度基准；选中项颜色由 [accentOverLight] / [accentOverDark] 与原生采样
  /// 结果共同决定。
  static Future<void> updateAppearance({
    required bool dark,
    required int accentOverLight,
    required int accentOverDark,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateLiquidGlassAppearance', {
        'dark': dark,
        'accentOverLight': accentOverLight,
        'accentOverDark': accentOverDark,
      });
    } on MissingPluginException {
      // 忽略。
    } on PlatformException {
      // 忽略。
    }
  }

  /// 有 route 盖在根页面上（设置页、弹层、引导页）时隐藏原生栏；回到根级恢复。
  static Future<void> setHidden(bool hidden) async {
    try {
      await _channel.invokeMethod<void>('setLiquidGlassBarHidden', {
        'hidden': hidden,
      });
    } on MissingPluginException {
      // 忽略。
    } on PlatformException {
      // 忽略。
    }
  }

  /// Flutter 侧切页（返回键、小组件路由）后同步原生水滴位置。
  static Future<void> updateSelection(int index) async {
    try {
      await _channel.invokeMethod<void>('updateLiquidGlassSelection', {
        'index': index,
      });
    } on MissingPluginException {
      // 忽略。
    } on PlatformException {
      // 忽略。
    }
  }

  static void _handleInbound(String method, Map<String, Object?> args) {
    if (method == 'onLiquidGlassTabSelected') {
      final index = args['index'];
      if (index is int) {
        onTabSelected?.call(index);
      }
    }
  }
}
