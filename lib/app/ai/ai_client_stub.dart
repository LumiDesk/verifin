import 'ai_settings.dart';

/// AI 请求失败时抛出，`message` 为已本地化/可读的错误说明。
class AiException implements Exception {
  AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 测试宿主（无 dart:io）不支持网络请求。
Future<String> aiChatComplete({
  required AiSettings settings,
  String? systemPrompt,
  String? userPrompt,
  List<Map<String, String>>? messages,
  double temperature = 0,
  Duration timeout = const Duration(seconds: 45),
}) async {
  throw AiException('当前平台不支持 AI 请求');
}
