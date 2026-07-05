import 'dart:ui' show Locale, PlatformDispatcher;

import '../l10n/app_localizations.dart';
import 'models.dart';

/// 在无 BuildContext 的场景（桌面小组件推送、本地通知调度等）按语言偏好
/// 解析文案：固定语言直接用，「跟随系统」取系统 locale，解析失败回落中文。
AppLocalizations l10nForPreference(LocalePreference preference) {
  final locale = preference.locale ?? PlatformDispatcher.instance.locale;
  try {
    return lookupAppLocalizations(locale);
  } catch (_) {
    return lookupAppLocalizations(const Locale('zh'));
  }
}
