import 'dart:convert';

/// AI 对话记账的连接配置（OpenAI 兼容协议）。
///
/// 用户自带请求地址与 API Key，本地优先——配置只存本机 KV，不进 JSON 备份、
/// 初始化时保留。API Key 明文存本机（与 WebDAV 密码/备份口令同等信任边界）。
class AiSettings {
  const AiSettings({this.baseUrl = '', this.apiKey = '', this.model = ''});

  /// 请求基础地址，填到 `/v1` 为止，如 `https://api.openai.com/v1`。
  /// 也兼容用户直接填写完整的 `.../chat/completions` 地址。
  final String baseUrl;

  /// 鉴权用的 API Key，作为 `Authorization: Bearer <key>` 发送。
  final String apiKey;

  /// 模型名，如 `gpt-4o-mini`、`deepseek-chat`、`qwen-plus`。
  final String model;

  /// 三项齐全才算可用（可发起解析请求）。
  bool get isConfigured =>
      baseUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  /// 聊天补全接口的完整 URL。用户若已填到 `/chat/completions` 则原样使用，
  /// 否则在基础地址后拼接；容错处理多余的结尾斜杠。
  String get chatCompletionsUrl {
    final trimmed = baseUrl.trim();
    final normalized = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    if (normalized.endsWith('/chat/completions')) {
      return normalized;
    }
    return '$normalized/chat/completions';
  }

  AiSettings copyWith({String? baseUrl, String? apiKey, String? model}) {
    return AiSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'model': model,
  };

  static AiSettings fromJson(Map<String, Object?> json) {
    return AiSettings(
      baseUrl: json['baseUrl'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? '',
    );
  }

  static AiSettings decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const AiSettings();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AiSettings.fromJson(Map<String, Object?>.from(decoded));
      }
    } catch (_) {
      // 损坏配置退回默认。
    }
    return const AiSettings();
  }

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is AiSettings &&
      other.baseUrl == baseUrl &&
      other.apiKey == apiKey &&
      other.model == model;

  @override
  int get hashCode => Object.hash(baseUrl, apiKey, model);
}
