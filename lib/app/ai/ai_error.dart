import '../../l10n/app_localizations.dart';

/// AI 请求失败的分类码。UI 按码本地化；无法预先翻译的补充信息放 [AiException.detail]
/// （上游错误原文、状态码、异常文本等，保持原样不翻译）。
enum AiErrorCode {
  notConfigured,
  notSupported,
  timeout,
  network,
  tls,
  badUrl,
  authFailed,
  notFound,
  rateLimited,
  serverError,
  badResponse,
  incompleteStream,
  responseTooLarge,
  requestTooLarge,
  protocolUnsupported,
  visionUnsupported,
  modelListUnsupported,
  upstream,
  unknown,
}

/// AI 请求失败异常。[code] 供 UI 本地化，[detail] 为不翻译的补充说明。
class AiException implements Exception {
  AiException(this.code, {this.detail});

  final AiErrorCode code;
  final String? detail;

  @override
  String toString() => detail == null ? code.name : '${code.name}: $detail';
}

/// 把 [AiException] 映射为本地化文案。上游原文只进本地日志，不直接展示给用户。
String aiErrorMessage(AppLocalizations l10n, AiException error) {
  final base = switch (error.code) {
    AiErrorCode.notConfigured => l10n.aiErrNotConfigured,
    AiErrorCode.notSupported => l10n.aiErrNotSupported,
    AiErrorCode.timeout => l10n.aiErrTimeout,
    AiErrorCode.network => l10n.aiErrNetwork,
    AiErrorCode.tls => l10n.aiErrTls,
    AiErrorCode.badUrl => l10n.aiErrBadUrl,
    AiErrorCode.authFailed => l10n.aiErrAuthFailed,
    AiErrorCode.notFound => l10n.aiErrNotFound,
    AiErrorCode.rateLimited => l10n.aiErrRateLimited,
    AiErrorCode.serverError => l10n.aiErrServer,
    AiErrorCode.badResponse => l10n.aiErrBadResponse,
    AiErrorCode.incompleteStream => l10n.aiErrBadResponse,
    AiErrorCode.responseTooLarge => l10n.aiErrResponseTooLarge,
    AiErrorCode.requestTooLarge => l10n.aiErrRequestTooLarge,
    AiErrorCode.protocolUnsupported => l10n.aiErrNotSupported,
    AiErrorCode.visionUnsupported => l10n.visionEntryUnsupported,
    AiErrorCode.modelListUnsupported => l10n.aiErrModelListUnsupported,
    AiErrorCode.upstream => l10n.aiErrUpstream,
    AiErrorCode.unknown => l10n.aiErrUnknown,
  };
  return base;
}

/// 上游错误是否明确表示“不接受图片输入”。用于把 400/422 的图片能力错误与
/// 其它请求错误区分开；只匹配同时出现图片/视觉与不支持语义的详情。
bool isUnsupportedVisionError(AiException error) {
  final detail = error.detail?.toLowerCase() ?? '';
  if (!detail.contains('image') &&
      !detail.contains('vision') &&
      !detail.contains('multimodal')) {
    return false;
  }
  return detail.contains('unsupported') ||
      detail.contains('not support') ||
      detail.contains('invalid') ||
      detail.contains('unknown');
}
